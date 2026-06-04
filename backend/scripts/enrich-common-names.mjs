#!/usr/bin/env node
/**
 * enrich-common-names.mjs — backfill common names on backend/data/library.json.
 *
 * Pipeline (each step short-circuits if the plant already has a non-Latin name):
 *   1. Apply existing backend/data/trefle-cache.json (instant).
 *   2. Mine the plant's current `description` for "Latin, the COMMON, ...",
 *      "commonly called/known as COMMON", or "also called/known as COMMON".
 *   3. For anything still Latin, fetch the Wikipedia REST summary in parallel
 *      batches and re-mine. Description is filled too so the detail screen
 *      gets richer copy.
 *
 * Idempotent: re-running only does network work for plants still Latin and
 * lacking a description.
 *
 * Usage:
 *   node scripts/enrich-common-names.mjs           # writes library.json in place
 *   node scripts/enrich-common-names.mjs --dry-run # report only
 *   node scripts/enrich-common-names.mjs --no-wiki # skip the slow Wikipedia pass
 */

import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";

const ROOT          = new URL("../data/", import.meta.url);
const LIBRARY_PATH  = fileURLToPath(new URL("library.json",      ROOT));
const TREFLE_PATH   = fileURLToPath(new URL("trefle-cache.json", ROOT));

const dryRun = process.argv.includes("--dry-run");
const noWiki = process.argv.includes("--no-wiki");

const data  = JSON.parse(readFileSync(LIBRARY_PATH, "utf-8"));
const items = data.items;

console.log(`Loaded ${items.length} plants.`);

function isLatinName(p) {
  if (!p.name) return true;
  const n = p.name.trim().toLowerCase();
  const l = (p.latin || "").trim().toLowerCase();
  if (!l) return false;
  return n === l || n.startsWith(l);
}

function looksLikeBinomial(s) {
  // Exactly two words, Capital + lowercase, no other punctuation.
  return /^[A-Z][a-z]+\s+[a-z-]+$/.test(s.trim());
}

function capitalize(s) {
  if (!s) return s;
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function cleanCandidate(raw) {
  if (!raw) return null;
  let s = raw.trim();
  // Strip surrounding quotes.
  s = s.replace(/^["'‘’“”]+|["'‘’“”]+$/g, "");
  s = s.replace(/^the\s+/i, "");
  s = s.replace(/\s+/g, " ");
  s = s.replace(/[.,;:]+$/, "");
  // Trim trailing prepositional / conjunction phrases.
  s = s.replace(/\s+(?:and|or|in|of|on|from|at|with|by|the)\b.*$/i, "");
  if (!s) return null;
  if (s.length < 3 || s.length > 50) return null;
  if (looksLikeBinomial(s)) return null;
  // Parens usually mean a Wikipedia disambiguator ("Dracaena (lizard)").
  if (/[()]/.test(s)) return null;
  // Reject if it's a single Capital word — typically a bare genus.
  if (/^[A-Z][a-z]+$/.test(s)) return null;
  // Reject obvious filler.
  if (/^(?:a|an|the|is|are|species|genus|family|plant|tree|shrub|herb)$/i.test(s)) return null;
  return capitalize(s);
}

// Mine a description for the species' common name. Looks at the first
// sentence only (where Wikipedia's lede convention puts the alternates).
function mineCommonName(description, latin) {
  if (!description || !latin) return null;
  const firstSentence = description.split(/\.\s/)[0];
  if (!firstSentence) return null;

  const latinEsc = latin.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

  const STOP = "(?=,|\\.|\\s+is\\b|\\s+or\\b|\\s+and\\b|$)";

  // 1. "<Latin>, the <COMMON>,"
  let m = firstSentence.match(
    new RegExp(`${latinEsc}\\s*,\\s*(?:also\\s+known\\s+as\\s+)?the\\s+([^,]+?)${STOP}`, "i"));
  if (m) { const c = cleanCandidate(m[1]); if (c) return c; }

  // 2. "commonly called/known as (the) <COMMON>".
  m = firstSentence.match(
    new RegExp(`commonly\\s+(?:called|known\\s+as)\\s+(?:the\\s+)?([^,]+?)${STOP}`, "i"));
  if (m) { const c = cleanCandidate(m[1]); if (c) return c; }

  // 3. "also/variously/sometimes/popularly called/known as (the) <COMMON>".
  m = firstSentence.match(
    new RegExp(`(?:also|variously|sometimes|popularly|widely|locally)\\s+(?:called|known\\s+as)\\s+(?:the\\s+)?([^,]+?)${STOP}`, "i"));
  if (m) { const c = cleanCandidate(m[1]); if (c) return c; }

  // 4. "known by the common name X" / "known under the common name X".
  m = firstSentence.match(
    new RegExp(`known\\s+(?:by|under)\\s+the\\s+common\\s+names?\\s+(?:of\\s+)?(?:the\\s+)?([^,]+?)${STOP}`, "i"));
  if (m) { const c = cleanCandidate(m[1]); if (c) return c; }

  // 5. "common name is X" / "common name of X".
  m = firstSentence.match(
    new RegExp(`common\\s+names?\\s+(?:is|of|are)\\s+(?:the\\s+)?([^,]+?)${STOP}`, "i"));
  if (m) { const c = cleanCandidate(m[1]); if (c) return c; }

  return null;
}

// ── 1. Apply Trefle cache ────────────────────────────────────────────────────

let appliedFromTrefle = 0;
if (existsSync(TREFLE_PATH)) {
  const trefle = JSON.parse(readFileSync(TREFLE_PATH, "utf-8"));
  for (const p of items) {
    if (!isLatinName(p)) continue;
    const hit = trefle[p.latin];
    if (hit && hit.commonName) {
      const candidate = cleanCandidate(hit.commonName);
      if (candidate && candidate.toLowerCase() !== p.latin.toLowerCase()) {
        p.name = candidate;
        appliedFromTrefle++;
      }
    }
  }
}
console.log(`1. Trefle cache → ${appliedFromTrefle} common names applied.`);

// ── 2. Mine existing descriptions ────────────────────────────────────────────

let minedFromDesc = 0;
for (const p of items) {
  if (!isLatinName(p)) continue;
  const mined = mineCommonName(p.description, p.latin);
  if (mined) {
    p.name = mined;
    minedFromDesc++;
  }
}
console.log(`2. Description mining → ${minedFromDesc} additional names.`);

// ── 3. Wikipedia summary fetch for remaining Latin-only plants ───────────────

async function fetchSummary(title, attempt = 0) {
  const safe = encodeURIComponent(title.replace(/ /g, "_"));
  const url  = `https://en.wikipedia.org/api/rest_v1/page/summary/${safe}`;
  const ctl  = new AbortController();
  const tid  = setTimeout(() => ctl.abort(), 10000);
  try {
    const res = await fetch(url, {
      signal: ctl.signal,
      headers: { "User-Agent": "BloomingMarvellousApp/1.0 (chance.hooper@gmail.com)" },
    });
    // Retry once on rate-limit or transient server error.
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

let wikiFetched = 0;
let wikiMined   = 0;
let wikiDescFilled = 0;

if (!noWiki) {
  const todo = items.filter(p => isLatinName(p) && (!p.description || p.description.length < 50));
  console.log(`3. Wikipedia fetch for ${todo.length} plants (batches of 24)…`);

  const BATCH = 8;
  for (let i = 0; i < todo.length; i += BATCH) {
    const slice = todo.slice(i, i + BATCH);
    const results = await Promise.allSettled(slice.map(p => fetchSummary(p.latin)));
    results.forEach((res, k) => {
      const p = slice[k];
      const extract = res.status === "fulfilled" ? res.value : null;
      if (!extract) return;
      wikiFetched++;
      if (!p.description || p.description.length < extract.length) {
        p.description = extract;
        wikiDescFilled++;
      }
      const mined = mineCommonName(extract, p.latin);
      if (mined && isLatinName(p)) {
        p.name = mined;
        wikiMined++;
      }
    });
    // 200 ms gap between batches keeps us well under Wikipedia's 200 req/s
    // soft ceiling so we don't drop 90% of results to throttling like the
    // first run did.
    await new Promise(r => setTimeout(r, 200));
    if ((i / BATCH) % 100 === 0) {
      const done = Math.min(i + BATCH, todo.length);
      console.log(`   ${done}/${todo.length} — fetched ${wikiFetched}, named ${wikiMined}, descs ${wikiDescFilled}`);
    }
  }
  console.log(`   Done — fetched ${wikiFetched}, named ${wikiMined}, descs filled ${wikiDescFilled}.`);
}

// ── Summary ──────────────────────────────────────────────────────────────────

let stillLatin = 0;
for (const p of items) if (isLatinName(p)) stillLatin++;

console.log("");
console.log("=== Final ===");
console.log(`Total plants:        ${items.length}`);
console.log(`Still Latin-only:    ${stillLatin} (${(stillLatin / items.length * 100).toFixed(1)}%)`);
console.log(`Fixed via Trefle:    ${appliedFromTrefle}`);
console.log(`Fixed via desc:      ${minedFromDesc}`);
console.log(`Fixed via Wikipedia: ${wikiMined}`);
console.log(`Descriptions filled: ${wikiDescFilled}`);

if (dryRun) {
  console.log("\nDRY RUN — no write.");
} else {
  data.generated = new Date().toISOString();
  writeFileSync(LIBRARY_PATH, JSON.stringify(data, null, 2) + "\n");
  console.log(`\n✓ wrote ${LIBRARY_PATH}`);
}
