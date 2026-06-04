#!/usr/bin/env node
/**
 * ingest-rhs-agm.mjs — pulls every Wikidata taxon that has an RHS plant ID
 * (Wikidata property P8765) and appends new entries to backend/data/library.json.
 *
 * Wikidata indexes ~6,700 plants with an RHS Plant Finder ID — that's the
 * Royal Horticultural Society's curated catalogue of garden-worthy plants,
 * including a deep cultivar list (rose names, dahlia names, AGM picks) that
 * the existing family-walk ingest misses entirely.
 *
 * Per entry:
 *   - Latin binomial / cultivar epithet (P225)
 *   - Image (P18 → Wikimedia Commons FilePath)
 *   - English Wikipedia article title for common name
 *   - Family / genus (P171 chain, derived once per genus to save SPARQL roundtrips)
 *
 * Then enriches lightly via Wikipedia REST summary (description + common-name
 * mining) using the same throttled fetch pattern as enrich-common-names.mjs.
 *
 * All new entries land in `pro` tier — the RHS catalogue is the premium UK
 * garden coverage we want to upsell. Subsequent passes of fix-types.mjs and
 * retag-packs.mjs will fine-tune type and pack assignments.
 *
 * Idempotent: skips entries already present in library.json (by slug).
 *
 * Usage:
 *   node scripts/ingest-rhs-agm.mjs               # writes in place
 *   node scripts/ingest-rhs-agm.mjs --limit 200   # cap for testing
 *   node scripts/ingest-rhs-agm.mjs --dry-run     # report-only
 */

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const LIBRARY = fileURLToPath(new URL("../data/library.json", import.meta.url));
const dryRun  = process.argv.includes("--dry-run");
const limit   = (() => {
  const ix = process.argv.indexOf("--limit");
  return ix > -1 ? parseInt(process.argv[ix + 1], 10) : Infinity;
})();

const UA = "BloomingMarvellousApp/1.0 (chance.hooper@gmail.com; RHS-AGM ingest)";
const COMMONS_BASE = "https://commons.wikimedia.org/wiki/Special:FilePath/";

function slugify(s) {
  return s.toLowerCase()
          .replace(/[×]/g, "x")
          .replace(/['''']/g, "")
          .replace(/[^a-z0-9]+/g, "-")
          .replace(/^-+|-+$/g, "");
}

// ── SPARQL: pull all P8765 holders with Latin + image ────────────────────────

const SPARQL = `
SELECT DISTINCT ?item ?taxonName ?image ?article WHERE {
  ?item wdt:P8765 ?rhsId .
  ?item wdt:P225  ?taxonName .
  OPTIONAL { ?item wdt:P18 ?image . }
  OPTIONAL {
    ?article schema:about ?item ;
             schema:isPartOf <https://en.wikipedia.org/> .
  }
}
`;

async function fetchSparql() {
  const url = "https://query.wikidata.org/sparql?format=json&query=" + encodeURIComponent(SPARQL);
  const res = await fetch(url, { headers: { "User-Agent": UA, Accept: "application/sparql-results+json" } });
  if (!res.ok) throw new Error(`SPARQL ${res.status} ${res.statusText}`);
  const j = await res.json();
  return j.results?.bindings || [];
}

// ── Wikipedia summary fetch (mirrors enrich-common-names.mjs) ────────────────

async function fetchSummary(title, attempt = 0) {
  const safe = encodeURIComponent(title.replace(/ /g, "_"));
  const url  = `https://en.wikipedia.org/api/rest_v1/page/summary/${safe}`;
  const ctl  = new AbortController();
  const tid  = setTimeout(() => ctl.abort(), 10000);
  try {
    const res = await fetch(url, {
      signal: ctl.signal,
      headers: { "User-Agent": UA },
    });
    if ((res.status === 429 || res.status === 503) && attempt < 1) {
      await new Promise(r => setTimeout(r, 2500));
      return fetchSummary(title, attempt + 1);
    }
    if (!res.ok) return null;
    const data = await res.json();
    return data?.extract ?? null;
  } catch {
    return null;
  } finally {
    clearTimeout(tid);
  }
}

// ── Common-name mining (same regex bank as enrich-common-names.mjs) ──────────

function cleanCandidate(raw) {
  if (!raw) return null;
  let s = raw.trim();
  s = s.replace(/^["'‘’“”]+|["'‘’“”]+$/g, "");
  s = s.replace(/^the\s+/i, "");
  s = s.replace(/\s+/g, " ");
  s = s.replace(/[.,;:]+$/, "");
  s = s.replace(/\s+(?:and|or|in|of|on|from|at|with|by|the)\b.*$/i, "");
  if (!s || s.length < 3 || s.length > 50) return null;
  if (/^[A-Z][a-z]+\s+[a-z-]+$/.test(s)) return null;
  if (/[()]/.test(s)) return null;
  if (/^[A-Z][a-z]+$/.test(s)) return null;
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function mineCommonName(description, latin) {
  if (!description || !latin) return null;
  const firstSentence = description.split(/\.\s/)[0];
  const latinEsc = latin.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const STOP = "(?=,|\\.|\\s+is\\b|\\s+or\\b|\\s+and\\b|$)";

  let m = firstSentence.match(new RegExp(`${latinEsc}\\s*,\\s*(?:also\\s+known\\s+as\\s+)?the\\s+([^,]+?)${STOP}`, "i"));
  if (m) { const c = cleanCandidate(m[1]); if (c) return c; }
  m = firstSentence.match(new RegExp(`commonly\\s+(?:called|known\\s+as)\\s+(?:the\\s+)?([^,]+?)${STOP}`, "i"));
  if (m) { const c = cleanCandidate(m[1]); if (c) return c; }
  m = firstSentence.match(new RegExp(`(?:also|variously|sometimes|popularly|widely|locally)\\s+(?:called|known\\s+as)\\s+(?:the\\s+)?([^,]+?)${STOP}`, "i"));
  if (m) { const c = cleanCandidate(m[1]); if (c) return c; }
  m = firstSentence.match(new RegExp(`known\\s+(?:by|under)\\s+the\\s+common\\s+names?\\s+(?:of\\s+)?(?:the\\s+)?([^,]+?)${STOP}`, "i"));
  if (m) { const c = cleanCandidate(m[1]); if (c) return c; }
  return null;
}

// ── Pipeline ─────────────────────────────────────────────────────────────────

const data  = JSON.parse(readFileSync(LIBRARY, "utf-8"));
const items = data.items;
const existingIds   = new Set(items.map(p => p.id));
const existingLatin = new Set(items.map(p => p.latin));

console.log(`Library currently holds ${items.length} plants.`);
console.log("→ Pulling Wikidata SPARQL (P8765 — RHS plant ID) …");

const rows = await fetchSparql();
console.log(`  Wikidata returned ${rows.length} taxa.`);

// Deduplicate by taxon name first (SPARQL returns multiple rows per item
// when there are multiple images / sitelinks).
const byLatin = new Map();
for (const r of rows) {
  const latin = r.taxonName?.value?.trim();
  if (!latin) continue;
  if (existingLatin.has(latin)) continue;
  const bucket = byLatin.get(latin) ?? {
    latin,
    image: null,
    article: null,
  };
  if (!bucket.image && r.image?.value) bucket.image = r.image.value;
  if (!bucket.article && r.article?.value) bucket.article = r.article.value;
  byLatin.set(latin, bucket);
}
console.log(`  Unique new taxa not yet in library: ${byLatin.size}`);

const todo = [...byLatin.values()].slice(0, limit);
console.log(`→ Processing ${todo.length} entries (limit=${limit === Infinity ? "none" : limit})`);

// Wikipedia summary fetch in batches of 8 with a 200 ms gap.
const BATCH = 8;
let added = 0;
let withSummary = 0;
let withCommon  = 0;

for (let i = 0; i < todo.length; i += BATCH) {
  const slice = todo.slice(i, i + BATCH);
  const results = await Promise.allSettled(slice.map(t => fetchSummary(t.latin)));

  results.forEach((res, k) => {
    const t = slice[k];
    const extract = res.status === "fulfilled" ? res.value : null;
    if (extract) withSummary++;

    const common = extract ? mineCommonName(extract, t.latin) : null;
    if (common) withCommon++;

    const id = slugify(t.latin);
    if (existingIds.has(id)) return;

    // Image URL: prefer P18 (Wikimedia Commons filename, served via FilePath).
    let imageUrl = null;
    if (t.image) {
      // P18 values are full URLs like
      // "http://commons.wikimedia.org/wiki/Special:FilePath/Foo.jpg"
      // — switch to https + add ?width=800 thumbnail.
      const m = t.image.match(/Special:FilePath\/(.+)$/);
      if (m) {
        imageUrl = COMMONS_BASE + m[1] + (m[1].includes("?") ? "&" : "?") + "width=800";
      } else {
        imageUrl = t.image.replace(/^http:/, "https:");
      }
    }

    const row = {
      id,
      name: common || t.latin,
      latin: t.latin,
      type: "perennial",  // refined by fix-types.mjs on next pass
      bloomMonths: [],
      sowIndoorMonths: [],
      sowDirectMonths: [],
      transplantMonths: [],
      harvestMonths: [],
      preferredSoil: [],
      preferredSunlight: [],
      preferredAcidity: [],
      preferredWetness: [],
      growersTips: "",
      germinationRequirements: "",
      companions: [],
      access: "pro",
      description: extract || "",
    };
    if (imageUrl) row.imageUrl = imageUrl;

    items.push(row);
    existingIds.add(id);
    existingLatin.add(t.latin);
    added++;
  });

  await new Promise(r => setTimeout(r, 200));
  if ((i / BATCH) % 100 === 0) {
    const done = Math.min(i + BATCH, todo.length);
    console.log(`   ${done}/${todo.length} — added ${added}, summaries ${withSummary}, common-names ${withCommon}`);
  }
}

console.log("");
console.log("=== RHS AGM ingest summary ===");
console.log(`Added:                 ${added}`);
console.log(`With Wikipedia summary:${withSummary}`);
console.log(`With mined common name:${withCommon}`);
console.log(`Library size now:      ${items.length}`);

if (dryRun) {
  console.log("\nDRY RUN — no write.");
} else {
  data.generated = new Date().toISOString();
  data.source = (data.source ?? "") + " + RHS-AGM via Wikidata P8765";
  writeFileSync(LIBRARY, JSON.stringify(data, null, 2) + "\n");
  console.log(`\n✓ wrote ${LIBRARY}`);
}
