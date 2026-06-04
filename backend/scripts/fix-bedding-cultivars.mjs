#!/usr/bin/env node
/**
 * fix-bedding-cultivars.mjs — patches the bedding cultivars added by
 * add-bedding-plants.mjs to fix two issues:
 *
 *   1. Cultivar display names used only the first word of the parent's
 *      common name (e.g. "Garden 'Obsession Burgundy'" instead of
 *      "Garden Verbena 'Obsession Burgundy'"). Rebuilds the name using
 *      the full parent common name + cultivar epithet.
 *
 *   2. Cultivar rows had no imageUrl — the original script `delete`d the
 *      inherited URL on the assumption we'd back-fill with cultivar-
 *      specific images. We don't have those, so falling back to the
 *      parent species photo is much better than a generic flower emoji.
 *      Inherits the parent species' imageUrl when the cultivar lacks one.
 *
 * Idempotent: re-running with the same parent table is a no-op.
 *
 * Usage:
 *   node scripts/fix-bedding-cultivars.mjs           # writes in place
 *   node scripts/fix-bedding-cultivars.mjs --dry-run
 */

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const LIBRARY = fileURLToPath(new URL("../data/library.json", import.meta.url));
const dryRun  = process.argv.includes("--dry-run");

// Parent species latin → common name (full, no splitting).
// Must mirror BEDDING_PARENTS in add-bedding-plants.mjs.
const BEDDING_PARENT_COMMON = {
  "Petunia × atkinsiana":   "Petunia",
  "Pelargonium × hortorum": "Zonal Pelargonium",
  "Pelargonium peltatum":   "Ivy-leaved Pelargonium",
  "Viola × wittrockiana":   "Pansy",
  "Viola cornuta":          "Horned Viola",
  "Begonia semperflorens":  "Wax Begonia",
  "Begonia × tuberhybrida": "Tuberous Begonia",
  "Impatiens walleriana":   "Busy Lizzie",
  "Impatiens hawkeri":      "New Guinea Impatiens",
  "Lobelia erinus":         "Trailing Lobelia",
  "Antirrhinum majus":      "Snapdragon",
  "Tagetes patula":         "French Marigold",
  "Tagetes erecta":         "African Marigold",
  "Calendula officinalis":  "Pot Marigold",
  "Salvia splendens":       "Scarlet Sage",
  "Salvia farinacea":       "Mealy-cup Sage",
  "Nicotiana × sanderae":   "Flowering Tobacco",
  "Verbena × hybrida":      "Garden Verbena",
  "Zinnia elegans":         "Zinnia",
  "Cosmos bipinnatus":      "Mexican Aster",
  "Cosmos sulphureus":      "Yellow Cosmos",
  "Cleome hassleriana":     "Spider Flower",
  "Dahlia variabilis":      "Bedding Dahlia",
  "Lobularia maritima":     "Sweet Alyssum",
  "Ageratum houstonianum":  "Floss Flower",
  "Dianthus chinensis":     "Chinese Pink",
  "Bidens ferulifolia":     "Tickseed",
  "Sutera cordata":         "Bacopa",
  "Coleus scutellarioides": "Coleus",
};

const data  = JSON.parse(readFileSync(LIBRARY, "utf-8"));
const items = data.items;

// Index parents by latin so we can inherit imageUrl in O(1).
const parentByLatin = new Map();
for (const p of items) {
  if (BEDDING_PARENT_COMMON[p.latin]) parentByLatin.set(p.latin, p);
}

let renamedCount = 0;
let imageFilledCount = 0;

for (const p of items) {
  // Cultivar latins always look like "<Parent latin> 'Cultivar Name'"
  // (curly or straight quotes). Strip the suffix to find the parent.
  const cvMatch = p.latin.match(/^(.+?)\s+['‘"]([^'’"]+)['’"]$/);
  if (!cvMatch) continue;
  const parentLatin = cvMatch[1].trim();
  const cultivarEpithet = cvMatch[2].trim();
  const parentCommon = BEDDING_PARENT_COMMON[parentLatin];
  if (!parentCommon) continue; // not a bedding cultivar we authored

  // 1. Rebuild display name with the full common name.
  const expectedName = `${parentCommon} '${cultivarEpithet}'`;
  if (p.name !== expectedName) {
    p.name = expectedName;
    renamedCount++;
  }

  // 2. Inherit parent imageUrl when cultivar lacks one.
  if (!p.imageUrl) {
    const parent = parentByLatin.get(parentLatin);
    if (parent?.imageUrl) {
      p.imageUrl = parent.imageUrl;
      imageFilledCount++;
    }
  }
}

console.log("=== Bedding cultivar fix ===");
console.log(`Names rebuilt:        ${renamedCount}`);
console.log(`Image URLs inherited: ${imageFilledCount}`);

if (dryRun) {
  console.log("\nDRY RUN — no write.");
} else {
  data.generated = new Date().toISOString();
  writeFileSync(LIBRARY, JSON.stringify(data, null, 2) + "\n");
  console.log(`\n✓ wrote ${LIBRARY}`);
}
