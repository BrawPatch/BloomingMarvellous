#!/usr/bin/env node
/**
 * retag-packs.mjs — reclassifies plants in backend/data/library.json
 * across the four content packs and the free / pro tiers.
 *
 * Rules (in order — first match wins):
 *
 *   1. Genus is in FRUIT_GENERA → `pack_fruit`
 *   2. Genus is in ALPINE_GENERA → `pack_rockery`
 *   3. type === "shrub" → `pack_rockery`
 *   4. type === "vegetable" or "herb" → `pack_edible`
 *   5. Otherwise: keep existing `access` value, except plants previously
 *      tagged `pack_edible` that don't satisfy rule 4 get moved back to
 *      `pro` (catches the Dracaena-as-vegetable mis-tags from the ingest).
 *
 * Idempotent: re-running collapses to the same output, since every
 * decision is taken from genus + type only.
 *
 * Usage:
 *   node scripts/retag-packs.mjs            # writes library.json in place
 *   node scripts/retag-packs.mjs --dry-run  # just print the summary
 */

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const LIBRARY = fileURLToPath(new URL("../data/library.json", import.meta.url));
const dryRun = process.argv.includes("--dry-run");

// Fruit-producing genera — soft fruit, orchard trees, vines, berries.
const FRUIT_GENERA = new Set([
  "Malus", "Pyrus", "Prunus", "Cydonia", "Mespilus",
  "Fragaria", "Rubus",
  "Ribes",
  "Vitis", "Actinidia", "Passiflora",
  "Vaccinium", "Empetrum", "Gaylussacia",
  "Ficus", "Morus",
  "Citrus", "Fortunella", "Poncirus",
  "Persea", "Punica", "Diospyros", "Annona", "Carica",
  "Sambucus", "Aronia", "Amelanchier", "Hippophae",
  "Physalis",
  "Rheum",
  "Olea",
]);

// Alpine / rockery garden classics.
const ALPINE_GENERA = new Set([
  "Sempervivum", "Sedum", "Saxifraga", "Aubrieta", "Aubretia",
  "Armeria", "Helianthemum", "Iberis", "Erinus", "Lewisia",
  "Phlox",
  "Aurinia", "Alyssum", "Arabis", "Draba", "Erysimum",
  "Aethionema", "Edraianthus", "Campanula",
  "Gentiana", "Pulsatilla", "Anemone",
  "Primula", "Androsace", "Cyclamen",
  "Antennaria", "Aster", "Erigeron",
  "Thymus",
  "Lithops", "Echeveria", "Crassula",
  "Sagina", "Silene", "Cerastium",
  "Dianthus", "Gypsophila",
  "Aquilegia",
  "Erica", "Calluna", "Daboecia",
]);

const data = JSON.parse(readFileSync(LIBRARY, "utf-8"));
const items = data.items;

let changed = 0;
const transitions = {};

for (const p of items) {
  const before = p.access;
  const genus = typeof p.latin === "string" ? p.latin.split(/\s+/)[0] : "";
  const after = decide(p, genus);
  if (after && after !== before) {
    p.access = after;
    changed++;
    const key = `${before} → ${after}`;
    transitions[key] = (transitions[key] || 0) + 1;
  }
}

function decide(p, genus) {
  if (FRUIT_GENERA.has(genus)) return "pack_fruit";
  if (ALPINE_GENERA.has(genus)) return "pack_rockery";
  if (p.type === "shrub") return "pack_rockery";
  if (p.type === "vegetable" || p.type === "herb") return "pack_edible";
  // Catch the "Dracaena tagged as vegetable but living in pack_edible"
  // mis-tags from the ingest: anything still in pack_edible without
  // satisfying the rules above is more naturally a Pro perennial.
  if (p.access === "pack_edible") return "pro";
  return p.access;
}

if (dryRun) {
  console.log("DRY RUN — no writes");
}
console.log(`\nRetag complete: ${changed}/${items.length} plants moved\n`);
for (const [k, v] of Object.entries(transitions).sort((a, b) => b[1] - a[1])) {
  console.log(`  ${k.padEnd(40)} ${v}`);
}

const finalCounts = {};
for (const p of items) finalCounts[p.access] = (finalCounts[p.access] || 0) + 1;
console.log("\nFinal access distribution:");
for (const [k, v] of Object.entries(finalCounts).sort((a, b) => b[1] - a[1])) {
  console.log(`  ${k.padEnd(20)} ${v}`);
}

if (!dryRun) {
  data.generated = new Date().toISOString();
  writeFileSync(LIBRARY, JSON.stringify(data, null, 2) + "\n");
  console.log("\n✓ wrote " + LIBRARY);
}
