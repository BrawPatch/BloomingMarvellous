#!/usr/bin/env node
/**
 * ingest-trefle-gb.mjs — pulls Trefle's Great-Britain-distributed plant list
 * (distribution id 127, ~4,261 species) and adds new entries to library.json.
 *
 * Source: GET /api/v1/distributions/127/plants — the WGSRPD "Great Britain"
 * (TDWG code GRB) bucket, covering the native + naturalised UK flora.
 * Anything not already in the library is appended as `pro` tier with the
 * Trefle image URL when available. Type defaults to "perennial" and is
 * refined by the next fix-types.mjs pass using genus overrides + Wikipedia
 * description.
 *
 * Common-name resolution: Trefle's own common_name field is used as a first
 * pass; rows without one get a Wikipedia summary mined via the same regex
 * bank as enrich-common-names.mjs.
 *
 * Idempotent. Cached per page in /tmp to survive Trefle hiccups mid-walk.
 *
 * Usage:
 *   node scripts/ingest-trefle-gb.mjs               # writes in place
 *   node scripts/ingest-trefle-gb.mjs --limit 200   # cap for testing
 *   node scripts/ingest-trefle-gb.mjs --dry-run     # report-only
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";

const LIBRARY    = fileURLToPath(new URL("../data/library.json",      import.meta.url));
const KEY_FILE   = fileURLToPath(new URL("../../API_Keys/TrefleKey.txt", import.meta.url));
const PAGE_CACHE = "/tmp/blooming-trefle-gb-pages";

const dryRun = process.argv.includes("--dry-run");
const limit  = (() => {
  const ix = process.argv.indexOf("--limit");
  return ix > -1 ? parseInt(process.argv[ix + 1], 10) : Infinity;
})();

if (!existsSync(KEY_FILE)) {
  console.error(`✗ Trefle key not found at ${KEY_FILE}`);
  process.exit(1);
}
const TREFLE_KEY = readFileSync(KEY_FILE, "utf-8").trim();
const UA = "BloomingMarvellousApp/1.0 (chance.hooper@gmail.com; Trefle GB ingest)";

mkdirSync(PAGE_CACHE, { recursive: true });

function slugify(s) {
  return s.toLowerCase()
          .replace(/[×]/g, "x")
          .replace(/['''']/g, "")
          .replace(/[^a-z0-9]+/g, "-")
          .replace(/^-+|-+$/g, "");
}

// ── Wikipedia summary + common-name mining (shared) ──────────────────────────

async function fetchSummary(title, attempt = 0) {
  const safe = encodeURIComponent(title.replace(/ /g, "_"));
  const url  = `https://en.wikipedia.org/api/rest_v1/page/summary/${safe}`;
  const ctl  = new AbortController();
  const tid  = setTimeout(() => ctl.abort(), 10000);
  try {
    const res = await fetch(url, { signal: ctl.signal, headers: { "User-Agent": UA } });
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

// ── Trefle paginator ─────────────────────────────────────────────────────────

async function fetchPage(page) {
  const cachePath = `${PAGE_CACHE}/page-${page}.json`;
  if (existsSync(cachePath)) {
    return JSON.parse(readFileSync(cachePath, "utf-8"));
  }
  const url = `https://trefle.io/api/v1/distributions/127/plants?token=${encodeURIComponent(TREFLE_KEY)}&page=${page}`;
  const r = await fetch(url, { headers: { "User-Agent": UA, Accept: "application/json" } });
  if (!r.ok) throw new Error(`Trefle HTTP ${r.status} on page ${page}`);
  const j = await r.json();
  writeFileSync(cachePath, JSON.stringify(j));
  // Trefle free tier ≈120 req/min — 350 ms between live pages is safe.
  await new Promise(res => setTimeout(res, 350));
  return j;
}

// ── Pipeline ─────────────────────────────────────────────────────────────────

const data  = JSON.parse(readFileSync(LIBRARY, "utf-8"));
const items = data.items;
const existingIds   = new Set(items.map(p => p.id));
const existingLatin = new Set(items.map(p => p.latin));

console.log(`Library currently holds ${items.length} plants.`);
console.log("→ Walking Trefle /distributions/127 (Great Britain) …");

// First call — determine total pages.
const first = await fetchPage(1);
const totalPages = first.meta?.total ? Math.ceil(first.meta.total / first.data.length) : 1;
const totalSpecies = first.meta?.total ?? first.data.length;
console.log(`  Trefle reports ${totalSpecies} species in GB across ~${totalPages} pages.`);

const harvest = []; // { latin, common, image }

function ingestPage(page) {
  for (const row of page.data || []) {
    const latin = row.scientific_name?.trim();
    if (!latin) continue;
    if (existingLatin.has(latin)) continue;
    harvest.push({
      latin,
      common: row.common_name?.trim() || null,
      image:  row.image_url?.trim() || null,
    });
  }
}
ingestPage(first);

for (let p = 2; p <= totalPages && harvest.length < limit; p++) {
  let pg;
  try { pg = await fetchPage(p); }
  catch (err) {
    console.warn(`  ⚠ ${err.message} — skipping page`);
    continue;
  }
  ingestPage(pg);
  if (p % 20 === 0) console.log(`  page ${p}/${totalPages} — candidates so far: ${harvest.length}`);
}
console.log(`  collected ${harvest.length} candidate new taxa (limit=${limit === Infinity ? "none" : limit}).`);

// ── Wikipedia enrichment pass: descriptions + common-name backfill ───────────

const todo = harvest.slice(0, limit);
console.log(`→ Wikipedia enrichment for ${todo.length} entries (batches of 8)…`);

const BATCH = 8;
let added = 0;
let descsFilled = 0;
let commonFilled = 0;

for (let i = 0; i < todo.length; i += BATCH) {
  const slice = todo.slice(i, i + BATCH);
  const results = await Promise.allSettled(slice.map(t => fetchSummary(t.latin)));

  results.forEach((res, k) => {
    const t = slice[k];
    const extract = res.status === "fulfilled" ? res.value : null;
    if (extract) descsFilled++;

    const minedCommon = extract ? mineCommonName(extract, t.latin) : null;
    const common = t.common || minedCommon || t.latin;
    if (!t.common && minedCommon) commonFilled++;

    const id = slugify(t.latin);
    if (existingIds.has(id)) return;

    const row = {
      id,
      name: common,
      latin: t.latin,
      type: "perennial",
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
    if (t.image && !t.image.toLowerCase().endsWith(".svg")) row.imageUrl = t.image;

    items.push(row);
    existingIds.add(id);
    existingLatin.add(t.latin);
    added++;
  });

  await new Promise(r => setTimeout(r, 200));
  if ((i / BATCH) % 100 === 0) {
    const done = Math.min(i + BATCH, todo.length);
    console.log(`   ${done}/${todo.length} — added ${added}, descs ${descsFilled}, mined-common ${commonFilled}`);
  }
}

console.log("");
console.log("=== Trefle GB ingest summary ===");
console.log(`Added:               ${added}`);
console.log(`Descriptions filled: ${descsFilled}`);
console.log(`Common names mined:  ${commonFilled}`);
console.log(`Library size now:    ${items.length}`);

if (dryRun) {
  console.log("\nDRY RUN — no write.");
} else {
  data.generated = new Date().toISOString();
  data.source = (data.source ?? "") + " + Trefle GB distribution (id 127)";
  writeFileSync(LIBRARY, JSON.stringify(data, null, 2) + "\n");
  console.log(`\n✓ wrote ${LIBRARY}`);
}
