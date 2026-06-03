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

// Species-level overrides for genera that contain BOTH fruit-bearing and
// purely-ornamental species (Lonicera, etc.). Listed by full Latin
// binomial of the parent species so a cultivar like
// "Lonicera caerulea 'Aurora'" still routes into pack_fruit.
const FRUIT_SPECIES = new Set([
  "Lonicera caerulea",
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
  // Species-level fruit override (e.g. Lonicera caerulea). Strip the
  // cultivar suffix before checking so cultivar rows still match.
  const speciesLatin = p.latin.replace(/\s+['‘].*$/u, "").trim();
  if (FRUIT_SPECIES.has(speciesLatin)) return "pack_fruit";
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

// MARK: - Free-tier rebalance
//
// After the genus/type sort, sample the Free pool deliberately so it
// reads as a friendly starter selection rather than the alphabetical
// slice the ingest gives by default: 350 ornamentals chosen at random
// across families, plus 50 fruit-pack picks and 50 edible-pack picks
// so new gardeners see colour, fruit and dinner from day one.
const FREE_ORNAMENTAL = 350;
const FREE_FRUIT      = 50;
const FREE_EDIBLE     = 50;

function shuffle(arr, seed = 1337) {
  // Deterministic Fisher-Yates with a tiny LCG so the Free starter
  // pack is stable across re-runs but still spreads families evenly.
  let s = seed;
  const next = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
  const out = arr.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(next() * (i + 1));
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}

function rebalanceFree() {
  // First, clear every existing Free tag so we start from the rebalanced
  // pools (Pro / pack_*). Plants already in a pack stay in their pack;
  // anything tagged "free" rolls back into Pro for the carve below.
  for (const p of items) {
    if (p.access === "free") p.access = "pro";
  }

  // Ornamentals = anything tagged pro after the carve, minus the shrubs
  // and alpines we just sent to pack_rockery (decide() above already did
  // that, so what remains in "pro" is genuine ornamental perennial /
  // annual / bulb material).
  const proPool   = shuffle(items.filter(p => p.access === "pro"));
  const fruitPool = shuffle(items.filter(p => p.access === "pack_fruit"));
  const edPool    = shuffle(items.filter(p => p.access === "pack_edible"));

  proPool.slice(0, FREE_ORNAMENTAL).forEach(p => p.access = "free");
  fruitPool.slice(0, FREE_FRUIT).forEach(p => p.access = "free");
  edPool.slice(0, FREE_EDIBLE).forEach(p => p.access = "free");
}

rebalanceFree();

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
