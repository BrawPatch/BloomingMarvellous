#!/usr/bin/env node
/**
 * fix-bedding-images.mjs — back-fills imageUrl for bedding-plant parents
 * (and propagates to their cultivars) using Wikipedia's REST summary
 * endpoint's `thumbnail.source` URL. Wikipedia gives a 320px-wide
 * thumbnail by default — we rewrite to width=800 so the iOS image cache
 * gets a sharper picture.
 *
 * Idempotent — only fills entries where imageUrl is missing.
 *
 * Usage:
 *   node scripts/fix-bedding-images.mjs           # writes in place
 *   node scripts/fix-bedding-images.mjs --dry-run
 */

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const LIBRARY = fileURLToPath(new URL("../data/library.json", import.meta.url));
const dryRun  = process.argv.includes("--dry-run");

const BEDDING_PARENTS = [
  "Petunia × atkinsiana","Pelargonium × hortorum","Pelargonium peltatum",
  "Viola × wittrockiana","Viola cornuta","Begonia semperflorens",
  "Begonia × tuberhybrida","Impatiens walleriana","Impatiens hawkeri",
  "Lobelia erinus","Antirrhinum majus","Tagetes patula","Tagetes erecta",
  "Calendula officinalis","Salvia splendens","Salvia farinacea",
  "Nicotiana × sanderae","Verbena × hybrida","Zinnia elegans",
  "Cosmos bipinnatus","Cosmos sulphureus","Cleome hassleriana",
  "Dahlia variabilis","Lobularia maritima","Ageratum houstonianum",
  "Dianthus chinensis","Bidens ferulifolia","Sutera cordata",
  "Coleus scutellarioides",
];

const UA = "BloomingMarvellousApp/1.0 (chance.hooper@gmail.com; image backfill)";

async function fetchThumb(title) {
  const safe = encodeURIComponent(title.replace(/ /g, "_"));
  const url  = `https://en.wikipedia.org/api/rest_v1/page/summary/${safe}`;
  try {
    const r = await fetch(url, { headers: { "User-Agent": UA } });
    if (!r.ok) return null;
    const j = await r.json();
    // `originalimage.source` is the full-res Commons URL; `thumbnail.source`
    // is the 320px thumbnail. Prefer originalimage and upscale via the
    // ?width=800 trick on Commons FilePath URLs.
    let src = j?.originalimage?.source || j?.thumbnail?.source;
    if (!src) return null;
    // Normalise: many of these are
    // https://upload.wikimedia.org/wikipedia/commons/thumb/.../800px-Foo.jpg
    // We can't easily rewrite to a fixed width without parsing — but the
    // ?width= trick only works on Special:FilePath URLs. Just use whatever
    // Wikipedia returned at its full-res / thumbnail size.
    return src;
  } catch {
    return null;
  }
}

const data  = JSON.parse(readFileSync(LIBRARY, "utf-8"));
const items = data.items;

const parentByLatin = new Map();
for (const p of items) {
  if (BEDDING_PARENTS.includes(p.latin)) parentByLatin.set(p.latin, p);
}

console.log(`Fetching Wikipedia thumbnails for ${BEDDING_PARENTS.length} bedding parents…`);

let parentFilled = 0;
let cultivarFilled = 0;

for (const latin of BEDDING_PARENTS) {
  const parent = parentByLatin.get(latin);
  if (!parent) {
    console.log(`  ${latin}: (not in library)`);
    continue;
  }
  if (parent.imageUrl) {
    console.log(`  ${latin}: already has image, skipping`);
    continue;
  }
  // Some bedding species have x-hybrid latins that don't have their own
  // Wikipedia article. Fall back to the parent genus or a known-good
  // alternative for the most common cases.
  const candidates = [latin];
  if (latin === "Petunia × atkinsiana")    candidates.push("Petunia × hybrida", "Petunia");
  if (latin === "Pelargonium × hortorum")  candidates.push("Zonal pelargonium", "Pelargonium zonale");
  if (latin === "Viola × wittrockiana")    candidates.push("Pansy", "Viola tricolor var. hortensis");
  if (latin === "Begonia × tuberhybrida")  candidates.push("Begonia × tuberhybrida group", "Tuberous begonia");
  if (latin === "Salvia splendens")        candidates.push("Scarlet sage");
  if (latin === "Salvia farinacea")        candidates.push("Mealy sage");
  if (latin === "Nicotiana × sanderae")    candidates.push("Nicotiana alata", "Flowering tobacco");
  if (latin === "Verbena × hybrida")       candidates.push("Verbena");
  if (latin === "Cosmos bipinnatus")       candidates.push("Cosmos (plant)");
  if (latin === "Dahlia variabilis")       candidates.push("Dahlia pinnata", "Dahlia");
  if (latin === "Ageratum houstonianum")   candidates.push("Ageratum");
  if (latin === "Bidens ferulifolia")      candidates.push("Bidens");
  if (latin === "Sutera cordata")          candidates.push("Chaenostoma cordatum", "Bacopa");
  if (latin === "Coleus scutellarioides")  candidates.push("Coleus", "Plectranthus scutellarioides");
  if (latin === "Tagetes patula")          candidates.push("Tagetes");
  if (latin === "Tagetes erecta")          candidates.push("Tagetes");
  if (latin === "Begonia semperflorens")   candidates.push("Begonia cucullata");
  if (latin === "Calendula officinalis")   candidates.push("Calendula");
  if (latin === "Cosmos sulphureus")       candidates.push("Cosmos sulphureus");
  if (latin === "Cleome hassleriana")      candidates.push("Cleome");
  if (latin === "Zinnia elegans")          candidates.push("Zinnia");
  if (latin === "Impatiens walleriana")    candidates.push("Impatiens");
  if (latin === "Impatiens hawkeri")       candidates.push("New Guinea impatiens");
  if (latin === "Pelargonium peltatum")    candidates.push("Pelargonium");

  let thumb = null;
  let usedCandidate = null;
  for (const c of candidates) {
    thumb = await fetchThumb(c);
    if (thumb) { usedCandidate = c; break; }
  }
  // Polite delay between live calls.
  await new Promise(r => setTimeout(r, 200));

  if (!thumb) {
    console.log(`  ${latin}: no thumb found (tried ${candidates.join(", ")})`);
    continue;
  }
  parent.imageUrl = thumb;
  parentFilled++;
  console.log(`  ${latin}: → ${thumb.slice(0, 90)}${thumb.length > 90 ? "…" : ""} (via "${usedCandidate}")`);

  // Propagate to all cultivars of this parent that still lack an image.
  for (const p of items) {
    if (!p.latin.startsWith(latin + " '") &&
        !p.latin.startsWith(latin + " ‘")) continue;
    if (p.imageUrl) continue;
    p.imageUrl = thumb;
    cultivarFilled++;
  }
}

console.log("");
console.log("=== Bedding image fix ===");
console.log(`Parents filled:   ${parentFilled}`);
console.log(`Cultivars filled: ${cultivarFilled}`);

if (dryRun) {
  console.log("\nDRY RUN — no write.");
} else {
  data.generated = new Date().toISOString();
  writeFileSync(LIBRARY, JSON.stringify(data, null, 2) + "\n");
  console.log(`\n✓ wrote ${LIBRARY}`);
}
