#!/usr/bin/env node
/**
 * fix-types.mjs — corrects mis-tagged `type` values on plants and cultivars
 * in backend/data/library.json.
 *
 * Root cause: ingest-plants.mjs defaulted `type` to the family's kitchen-garden
 * archetype (e.g. Brassicaceae → "vegetable") whenever Wikipedia summary text
 * didn't contain a structural keyword. With most plants missing descriptions
 * after the initial ingest, almost every taxon in a "vegetable"-archetype
 * family — including ornamental wallflowers, candytufts, dame's rocket, stocks
 * etc. — landed under `type: "vegetable"`. The follow-on effect was that the
 * UI grouped them under "Vegetables", harvest months were generated for them,
 * and the bed planner treated them as kitchen-garden crops.
 *
 * Fix order (first match wins):
 *
 *   1. ORNAMENTAL_GENUS_TYPE — hand-curated genus-level overrides for
 *      ornamental genera trapped under "vegetable" / "herb" family defaults.
 *      These are the genera the original FAMILY_DEFAULTS table got wrong.
 *
 *   2. EDIBLE_GENUS_TYPE — explicit edible/herb genera kept as veg/herb
 *      regardless of any description quirks (lettuce, tomato, basil, …).
 *
 *   3. Description-based re-parse using the same regex as parsePlantType
 *      in ingest-plants.mjs. If the description carries a clear structural
 *      signal (perennial / annual / biennial / bulb / shrub) we trust it
 *      over a stale family default.
 *
 *   4. Otherwise leave the type alone.
 *
 * Side-effect: if a fix changes type from "vegetable"/"herb" to a structural
 * type, the row's `harvestMonths` are cleared (harvest only makes sense for
 * crops). The cultivar's `access` is also re-evaluated against retag-packs's
 * rules so an ornamental wallflower stops claiming pack_edible.
 *
 * Idempotent.
 *
 * Usage:
 *   node scripts/fix-types.mjs           # writes library.json in place
 *   node scripts/fix-types.mjs --dry-run
 */

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const LIBRARY = fileURLToPath(new URL("../data/library.json", import.meta.url));
const dryRun  = process.argv.includes("--dry-run");

// ── 1. Ornamental genera trapped under veg/herb family defaults ──────────────

const ORNAMENTAL_GENUS_TYPE = {
  // Brassicaceae ornamentals (family default = vegetable)
  Erysimum:     "perennial",  // wallflower
  Cheiranthus:  "perennial",  // wallflower (older name for Erysimum)
  Iberis:       "perennial",  // candytuft
  Aubrieta:     "perennial",  // rock cress
  Aubretia:     "perennial",
  Aurinia:      "perennial",  // basket of gold
  Arabis:       "perennial",  // rock cress
  Draba:        "perennial",  // whitlow grass
  Hesperis:     "biennial",   // dame's rocket
  Lunaria:      "biennial",   // honesty
  Matthiola:    "annual",     // stock
  Alyssum:      "perennial",  // sweet alyssum
  Lobularia:    "annual",     // sweet alyssum
  Schivereckia: "perennial",
  Aethionema:   "perennial",  // stone cress
  Berteroa:     "biennial",   // hoary alyssum
  Cardamine:    "perennial",  // bittercress (not the edible Cardamine sativa)
  Crambe:       "perennial",  // sea kale — type-wise perennial (foliage display)

  // Lamiaceae ornamentals (family default = vegetable+herbs)
  Salvia:       "perennial",  // mostly ornamental; culinary sages are sub-set
  Lavandula:    "perennial",
  Nepeta:       "perennial",  // catmint
  Stachys:      "perennial",  // lamb's ears
  Monarda:      "perennial",  // bee balm
  Agastache:    "perennial",  // hyssop
  Caryopteris:  "shrub",      // bluebeard
  Phlomis:      "perennial",  // Jerusalem sage
  Perovskia:    "shrub",      // Russian sage
  Ajuga:        "perennial",  // bugle
  Lamium:       "perennial",  // dead-nettle
  Scutellaria:  "perennial",  // skullcap
  Teucrium:     "perennial",  // germander
  Westringia:   "shrub",
  Prostanthera: "shrub",      // mint bush

  // Apiaceae ornamentals (family default = vegetable)
  Eryngium:     "perennial",  // sea holly
  Astrantia:    "perennial",  // masterwort
  Angelica:     "biennial",   // mostly ornamental cultivars
  Bupleurum:    "perennial",  // hare's ear
  Ferula:       "perennial",  // giant fennel (ornamental species)
  Heracleum:    "biennial",   // hogweed
  Pleurospermum:"perennial",
  Pseudocymopterus:"perennial",
  Selinum:      "perennial",
  Conium:       "biennial",   // poison hemlock
  Daucus:       "biennial",   // carrot is the cultivated species; wild ones are biennial

  // Amaranthaceae ornamentals (family default = vegetable)
  Amaranthus:   "annual",     // love-lies-bleeding, ornamental + grain types
  Celosia:      "annual",     // cockscomb
  Atriplex:     "annual",     // orache (mostly ornamental forms)
  Gomphrena:    "annual",     // globe amaranth
  Iresine:      "perennial",  // bloodleaf

  // Amaryllidaceae ornamentals (family default = vegetable; alliums)
  Narcissus:    "bulb",
  Galanthus:    "bulb",       // snowdrop
  Leucojum:     "bulb",       // snowflake
  Hippeastrum:  "bulb",       // amaryllis
  Nerine:       "bulb",
  Crinum:       "bulb",
  Agapanthus:   "perennial",  // African lily
  Amaryllis:    "bulb",
  Sternbergia:  "bulb",
  Lycoris:      "bulb",
  Zephyranthes: "bulb",       // rain lily
  Habranthus:   "bulb",
  Hymenocallis: "bulb",       // spider lily
  Eucharis:     "bulb",
  Pancratium:   "bulb",
  // (Allium itself stays — culinary onions/garlics dominate the genus)

  // Polygonaceae ornamentals (family default = vegetable)
  Persicaria:   "perennial",
  Polygonum:    "perennial",
  Bistorta:     "perennial",
  Rumex:        "perennial",  // sorrels — leaving as perennial; edible R. acetosa is a special case
  Eriogonum:    "perennial",  // wild buckwheat
  Fagopyrum:    "annual",     // buckwheat — ornamental ground cover or grain
  Fallopia:     "perennial",  // bindweed / knotweed
};

// ── 2. Explicit edible/herb genera — keep regardless of description quirks ───

const EDIBLE_GENUS_TYPE = {
  // Brassicaceae edibles
  Brassica:     "vegetable", // cabbages, broccoli, kale
  Raphanus:     "vegetable", // radish
  Nasturtium:   "herb",      // watercress
  Lepidium:     "herb",      // garden cress
  Eruca:        "vegetable", // rocket
  Sinapis:      "vegetable", // mustard
  Armoracia:    "vegetable", // horseradish
  Wasabia:      "herb",      // wasabi

  // Lamiaceae herbs
  Mentha:       "herb",
  Thymus:       "herb",
  Origanum:     "herb",
  Ocimum:       "herb",
  Rosmarinus:   "herb",
  Salvia_officinalis: "herb", // handled by species rule below
  Melissa:      "herb",       // lemon balm
  Satureja:     "herb",       // savory
  Hyssopus:     "herb",       // hyssop

  // Apiaceae edibles/herbs
  Petroselinum: "herb",       // parsley
  Foeniculum:   "herb",       // fennel
  Levisticum:   "herb",       // lovage
  Pimpinella:   "herb",       // anise (P. anisum)
  Carum:        "herb",       // caraway
  Coriandrum:   "herb",       // coriander
  Anethum:      "herb",       // dill
  Apium:        "vegetable",  // celery
  Pastinaca:    "vegetable",  // parsnip

  // Solanaceae edibles
  Solanum_lycopersicum: "vegetable", // tomato — species rule
  Solanum_tuberosum:    "vegetable", // potato — species rule
  Solanum_melongena:    "vegetable", // aubergine — species rule
  Capsicum:     "vegetable",  // peppers
  Physalis:     "vegetable",  // tomatillo, cape gooseberry

  // Amaranthaceae edibles
  Beta:         "vegetable",  // beetroot, chard
  Spinacia:     "vegetable",  // spinach

  // Cucurbitaceae — all edible
  Cucurbita:    "vegetable",
  Cucumis:      "vegetable",
  Citrullus:    "vegetable",
};

// Species-level overrides (some genera straddle ornamental + edible).
const SPECIES_TYPE = {
  "Salvia officinalis": "herb",
  "Salvia rosmarinus":  "herb",
  "Salvia splendens":   "annual", // bedding scarlet sage — UK half-hardy
  "Salvia farinacea":   "annual", // bedding mealy-cup sage — UK half-hardy
  "Solanum lycopersicum": "vegetable",
  "Solanum tuberosum":    "vegetable",
  "Solanum melongena":     "vegetable",
  "Allium sativum":       "vegetable", // garlic
  "Allium cepa":          "vegetable", // onion
  "Allium porrum":        "vegetable", // leek
  "Allium fistulosum":    "vegetable", // spring onion
  "Allium schoenoprasum": "herb",      // chives
  "Allium ampeloprasum":  "vegetable", // elephant garlic
  "Allium tuberosum":     "herb",      // garlic chives
  "Rumex acetosa":        "herb",      // common sorrel
  "Rumex scutatus":       "herb",      // French sorrel
  "Rheum rhabarbarum":    "vegetable", // rhubarb is botanically perennial but culinary veg
};

// ── 3. Description parser (mirrors ingest-plants.mjs) ────────────────────────

function parseTypeFromDescription(text) {
  if (!text) return null;
  const t = text.toLowerCase();
  // Stronger signals first: explicit structural lifecycle words.
  if (/\bbiennial\b/.test(t))   return "biennial";
  if (/\bperennial\b/.test(t))  return "perennial";
  if (/\bannual\b/.test(t))     return "annual";
  if (/\b(bulb|corm|tuber|rhizome)\b/.test(t)) return "bulb";
  if (/\b(shrub|tree)\b/.test(t)) return "shrub";
  // Reverse direction: detect edible/herb hints.
  if (/\b(culinary herb|kitchen herb|aromatic herb)\b/.test(t)) return "herb";
  if (/\b(vegetable crop|leaf vegetable|root vegetable)\b/.test(t)) return "vegetable";
  return null;
}

// ── Pack-access logic (mirrors retag-packs.mjs decide() order) ───────────────

const FRUIT_GENERA = new Set([
  "Malus","Pyrus","Prunus","Cydonia","Mespilus","Fragaria","Rubus","Ribes",
  "Vitis","Actinidia","Passiflora","Vaccinium","Empetrum","Gaylussacia",
  "Ficus","Morus","Citrus","Fortunella","Poncirus","Persea","Punica",
  "Diospyros","Annona","Carica","Sambucus","Aronia","Amelanchier","Hippophae",
  "Physalis","Rheum","Olea",
]);

const ALPINE_GENERA = new Set([
  "Sempervivum","Sedum","Saxifraga","Aubrieta","Aubretia","Armeria",
  "Helianthemum","Iberis","Erinus","Lewisia","Phlox","Aurinia","Alyssum",
  "Arabis","Draba","Erysimum","Aethionema","Edraianthus","Campanula",
  "Gentiana","Pulsatilla","Anemone","Primula","Androsace","Cyclamen",
  "Antennaria","Aster","Erigeron","Thymus","Lithops","Echeveria","Crassula",
  "Sagina","Silene","Cerastium","Dianthus","Gypsophila","Aquilegia","Erica",
  "Calluna","Daboecia",
]);

function intendedAccess(p, genus, type, currentAccess) {
  // Preserve free-tier curation.
  if (currentAccess === "free") return "free";
  // Fruit override comes first (same as retag-packs).
  if (FRUIT_GENERA.has(genus)) return "pack_fruit";
  if (ALPINE_GENERA.has(genus)) return "pack_rockery";
  if (type === "shrub") return "pack_rockery";
  if (type === "vegetable" || type === "herb") return "pack_edible";
  // Anything else stays where it is unless it was edible by mistake.
  if (currentAccess === "pack_edible") return "pro";
  return currentAccess;
}

// ── Pipeline ─────────────────────────────────────────────────────────────────

const data  = JSON.parse(readFileSync(LIBRARY, "utf-8"));
const items = data.items;

const stats = {
  unchanged: 0,
  speciesOverride: 0,
  ornamentalGenus: 0,
  edibleGenus: 0,
  descParse: 0,
  harvestCleared: 0,
  accessUpdated: 0,
};

const sampleChanges = [];

for (const p of items) {
  const genus = (p.latin || "").split(/\s+/)[0];
  const beforeType = p.type;
  let nextType = null;
  let reason = null;

  // 1. Species-level override (highest priority).
  // Strip cultivar suffix so "Salvia officinalis 'Berggarten'" still matches.
  const speciesLatin = (p.latin || "").replace(/\s+['‘].*$/u, "").trim();
  if (SPECIES_TYPE[speciesLatin]) {
    nextType = SPECIES_TYPE[speciesLatin];
    reason = "species";
  }
  // 2. Ornamental genus override (forces correct flowering type).
  else if (ORNAMENTAL_GENUS_TYPE[genus]) {
    nextType = ORNAMENTAL_GENUS_TYPE[genus];
    reason = "ornamentalGenus";
  }
  // 3. Edible genus pin (forces vegetable/herb even if description waffles).
  else if (EDIBLE_GENUS_TYPE[genus]) {
    nextType = EDIBLE_GENUS_TYPE[genus];
    reason = "edibleGenus";
  }
  // 4. Description-based re-parse — only when the current type is one of the
  //    family-default fall-throughs that frequently swallowed ornamentals.
  else if (beforeType === "vegetable" || beforeType === "herb") {
    const parsed = parseTypeFromDescription(p.description);
    if (parsed && parsed !== beforeType
        && parsed !== "vegetable" && parsed !== "herb") {
      nextType = parsed;
      reason = "descParse";
    }
  }

  if (!nextType || nextType === beforeType) {
    stats.unchanged++;
    continue;
  }

  p.type = nextType;
  if (reason === "species")          stats.speciesOverride++;
  if (reason === "ornamentalGenus")  stats.ornamentalGenus++;
  if (reason === "edibleGenus")      stats.edibleGenus++;
  if (reason === "descParse")        stats.descParse++;

  // Side-effect: if we moved out of vegetable/herb, harvest months no longer
  // make sense (annual flowers don't have harvest in the kitchen-garden sense).
  if ((beforeType === "vegetable" || beforeType === "herb")
      && nextType !== "vegetable" && nextType !== "herb"
      && Array.isArray(p.harvestMonths) && p.harvestMonths.length) {
    p.harvestMonths = [];
    stats.harvestCleared++;
  }

  // Side-effect: re-evaluate access tag with the new type.
  const nextAccess = intendedAccess(p, genus, nextType, p.access);
  if (nextAccess !== p.access) {
    p.access = nextAccess;
    stats.accessUpdated++;
  }

  if (sampleChanges.length < 18) {
    sampleChanges.push({ latin: p.latin, from: beforeType, to: nextType, reason });
  }
}

console.log("=== Type fix-up ===");
console.log("Unchanged:                ", stats.unchanged);
console.log("Fixed (species override): ", stats.speciesOverride);
console.log("Fixed (ornamental genus): ", stats.ornamentalGenus);
console.log("Pinned (edible genus):    ", stats.edibleGenus);
console.log("Fixed (description parse):", stats.descParse);
console.log("Harvest months cleared:   ", stats.harvestCleared);
console.log("Access tags updated:      ", stats.accessUpdated);

console.log("\nSample changes:");
for (const c of sampleChanges) {
  console.log(`  ${c.latin.padEnd(40)} ${c.from} → ${c.to.padEnd(9)} (${c.reason})`);
}

if (dryRun) {
  console.log("\nDRY RUN — no write.");
} else {
  data.generated = new Date().toISOString();
  writeFileSync(LIBRARY, JSON.stringify(data, null, 2) + "\n");
  console.log(`\n✓ wrote ${LIBRARY}`);
}
