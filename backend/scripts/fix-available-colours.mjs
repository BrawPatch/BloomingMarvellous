#!/usr/bin/env node
/**
 * fix-available-colours.mjs — backfills `availableColours` on every
 * bedding cultivar in library.json.
 *
 * Heuristic: cultivars are usually sold as a series (Begonia 'Cocktail
 * Brandy', 'Cocktail Vodka', 'Cocktail Whiskey'). The colour palette of
 * the series is the union of every primary colour across the cultivars
 * in that series. So we sweep all cultivars, group them by
 *   (parent latin, first word of cultivar epithet),
 * and set every cultivar's `availableColours` to the deduplicated
 * palette of its series.
 *
 * Plus a hand-curated table of known wider series palettes (e.g.
 * Pelargonium 'Rocky Mountain' which ships in 8+ colours we may not
 * have authored cultivars for) so the picker's colour filter behaves
 * naturally even for cultivars we haven't enumerated.
 *
 * Idempotent.
 *
 * Usage:
 *   node scripts/fix-available-colours.mjs           # writes in place
 *   node scripts/fix-available-colours.mjs --dry-run
 */

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const LIBRARY = fileURLToPath(new URL("../data/library.json", import.meta.url));
const dryRun  = process.argv.includes("--dry-run");

// Hand-curated series palette overrides — hex codes for every colour
// commonly available in this series, regardless of which cultivar
// names we ship. Apply to every cultivar whose latin starts with the
// listed parent + space + ' + series stem.
const SERIES_PALETTES = {
  "Pelargonium × hortorum::Rocky Mountain": ["#c8262a","#f5f5f5","#e87aa8","#f08a8a","#f4b8b0","#9a1a2a"],
  "Pelargonium × hortorum::Caliente":       ["#f06a4a","#c8262a","#f08a8a","#e85aa0"],
  "Pelargonium × hortorum::Maverick":       ["#f0908a","#c8262a","#f5f5f5","#e87aa8"],
  "Petunia × atkinsiana::Surfinia":         ["#7a4aa8","#e07ac0","#f5f5f5","#5a55a8","#f48aa8","#c8a8dc"],
  "Petunia × atkinsiana::Wave":             ["#6a3aa0","#f48aa8","#f0e0e8","#7a3a9c","#e85aa0","#5a4a82"],
  "Petunia × atkinsiana::Million Bells":    ["#d62a4a","#f5f5f5","#f5d020","#7a4aa8","#e87aa8","#f0801a"],
  "Viola × wittrockiana::Matrix":           ["#f5d020","#5a2a8a","#f5f5f5","#f0801a","#c82a4a","#3a55a8","#f08aa8"],
  "Viola × wittrockiana::Delta":            ["#f5f5f5","#f0801a","#5a2a8a","#f5d020","#e85aa0","#3a55a8"],
  "Viola × wittrockiana::Cool Wave":        ["#e8d8e8","#f5d020","#5a2a8a","#f48aa8","#3a55a8"],
  "Viola × wittrockiana::Frizzle Sizzle":   ["#4a55a8","#f4a8b8","#f5d020","#5a2a8a","#e85aa0"],
  "Begonia semperflorens::Cocktail":        ["#f0e0d0","#c83a4a","#f4a0a8","#f5f5f5","#e87aa8"],
  "Begonia semperflorens::Senator":         ["#f5f5f5","#f0a8c0","#c83a4a","#e85aa0"],
  "Begonia semperflorens::Olympia":         ["#e88aa8","#c83a4a","#f5f5f5"],
  "Begonia × tuberhybrida::Nonstop":        ["#f5d020","#c8262a","#f5f5f5","#e87aa8","#f0801a","#f4a8b8"],
  "Impatiens walleriana::Beacon":           ["#f4708a","#7a4aa8","#c8262a","#f5f5f5","#e85aa0"],
  "Impatiens walleriana::Imara":            ["#c8262a","#e85aa0","#f5f5f5","#7a4aa8","#f08a8a"],
  "Impatiens walleriana::Super Elfin":      ["#f5f5f5","#c8262a","#e87aa8","#f48a8a","#7a4aa8"],
  "Impatiens hawkeri::SunPatiens":          ["#e85aa0","#f0801a","#f5f5f5","#7a4aa8","#c8262a","#f48a8a"],
  "Lobelia erinus::Cascade":                ["#3a55a8","#c83a5a","#5a7adc","#f5f5f5","#7a4aa8"],
  "Lobelia erinus::Riviera":                ["#5a7adc","#8aaad8","#3a55a8","#c83a5a"],
  "Antirrhinum majus::Rocket":              ["#c8262a","#f5d020","#f0a8c0","#f5f5f5","#f0801a","#7a4aa8"],
  "Antirrhinum majus::Sonnet":              ["#f0a8c0","#6a1a2a","#f5d020","#f5f5f5","#c8262a"],
  "Antirrhinum majus::Snapshot":            ["#f5d850","#f0801a","#f5f5f5","#c8262a","#e85aa0"],
  "Tagetes patula::Bonanza":                ["#c8401a","#f5d020","#f0801a","#f4a040"],
  "Tagetes patula::Disco":                  ["#f5a020","#c8401a","#f5d020"],
  "Tagetes patula::Boy":                    ["#f0801a","#c82a1a","#f5d020"],
  "Tagetes erecta::Antigua":                ["#f08020","#f5d020","#f0801a"],
  "Tagetes erecta::Inca":                   ["#f0801a","#f5d020","#f08020"],
  "Calendula officinalis::Pacific Beauty":  ["#f5a040","#f0c890","#d8602a","#f0801a"],
  "Calendula officinalis::Calypso":         ["#f0801a","#f5d020","#f5a040"],
  "Salvia splendens::Sizzler":              ["#d62a2a","#f08a8a","#a888d8","#f5f5f5"],
  "Salvia splendens::Vista":                ["#d62a2a","#5a2a8a","#f48a8a","#f5f5f5"],
  "Salvia farinacea::Victoria":             ["#3a55a8","#f5f5f5"],
  "Salvia farinacea::Cathedral":            ["#5a7adc","#3a55a8","#f5f5f5"],
  "Salvia farinacea::Evolution":            ["#5a2a8a","#3a55a8"],
  "Nicotiana × sanderae::Domino":           ["#c82a4a","#f5f5f5","#e8a8c0","#c8d050"],
  "Nicotiana × sanderae::Perfume":          ["#5a2a8a","#c8d050","#f5f5f5"],
  "Nicotiana × sanderae::Saratoga":         ["#c8d050","#e8a8c0","#f5f5f5"],
  "Verbena × hybrida::Quartz":              ["#7a3a9c","#c8262a","#e87aa0","#f5f5f5","#f4b890"],
  "Verbena × hybrida::Obsession":           ["#7a1a2a","#d6404a","#e85aa0","#f4a8b8"],
  "Verbena × hybrida::Lascar":              ["#f06a3a","#7a3a9c","#e85aa0"],
  "Zinnia elegans::Magellan":               ["#c82a4a","#f4708a","#f5d020","#f5f5f5","#f0801a"],
  "Zinnia elegans::Profusion":              ["#d62a4a","#f5f5f5","#f0801a","#f5d020","#e85aa0"],
  "Zinnia elegans::Zahara":                 ["#f5d050","#c82a4a","#f0801a","#f5f5f5"],
  "Zinnia elegans::Benary's Giant":         ["#c8d050","#6a1a2a","#c8262a","#f5d020","#e85aa0","#f5f5f5"],
  "Cosmos bipinnatus::Sonata":              ["#e8a8c0","#f5f5f5","#e85aa0"],
  "Cosmos bipinnatus::Sensation":           ["#e87aa8","#f5f5f5","#c82a4a"],
  "Cosmos bipinnatus::Double Click":        ["#a01838","#f0e8e0","#e85aa0","#f5f5f5"],
  "Cosmos sulphureus::Cosmic":              ["#f06a1a","#f5d020","#c8262a","#f0801a"],
  "Cosmos sulphureus::Bright Lights":       ["#f0801a","#f5d020","#c8262a"],
  "Cleome hassleriana::Sparkler":           ["#a888d8","#f5f5f5","#e87aa8"],
  "Cleome hassleriana::Senorita":           ["#e87aa8","#f5f5f5","#a888d8"],
  "Dahlia variabilis::Figaro":              ["#c8262a","#f5d020","#f0801a","#f5f5f5","#e85aa0"],
  "Dahlia variabilis::Mignon":              ["#e87aa8","#f5d020","#c8262a"],
  "Dahlia variabilis::Diablo":              ["#c8404a","#f5d020","#f0801a"],
  "Dahlia variabilis::Unwins":              ["#e85a70","#c8262a","#f5d020","#f5f5f5"],
  "Lobularia maritima::Easter Bonnet":      ["#7a3a9c","#f5f5f5"],
  "Lobularia maritima::Carpet":             ["#f5f5f5"],
  "Ageratum houstonianum::Hawaii":          ["#7a8fc8","#f5f5f5"],
  "Ageratum houstonianum::Aloha":           ["#5a7adc","#e8a0c0","#f5f5f5"],
  "Dianthus chinensis::Coronet":            ["#c82a4a","#e87aa0","#f5f5f5"],
  "Dianthus chinensis::Floral Lace":        ["#f0a8c0","#a01838","#f5f5f5"],
  "Dianthus chinensis::Telstar":            ["#f4a8c0","#c8262a","#f5f5f5"],
  "Bidens ferulifolia::Goldilocks":         ["#f5c020"],
  "Bidens ferulifolia::Solaire":            ["#f5d020"],
  "Bidens ferulifolia::Beedance":           ["#d8404a","#f5d020"],
  "Sutera cordata::Snowtopia":              ["#f5f5f5"],
  "Sutera cordata::Bluetopia":              ["#7a8fc8"],
  "Sutera cordata::Scopia":                 ["#f5f5f5","#c8a8dc"],
  "Coleus scutellarioides::Wizard":         ["#7a1a2a","#c8d050","#9c2a3a"],
  "Coleus scutellarioides::Kong":           ["#e87aa0","#c8404a","#7a1a2a"],
};

const data  = JSON.parse(readFileSync(LIBRARY, "utf-8"));
const items = data.items;

// Pass 1: build series → set of colour hex values from existing cultivar
// `colorHex` fields. Series key = parent latin + "::" + first word of
// cultivar epithet.
const seriesPalette = new Map();

function seriesKey(latin) {
  // Match "Parent latin 'Series Word Optional Modifier'"
  const m = latin.match(/^(.+?)\s+['‘"]([A-Z][A-Za-z]+)/);
  if (!m) return null;
  return `${m[1].trim()}::${m[2]}`;
}

for (const p of items) {
  const key = seriesKey(p.latin);
  if (!key) continue;
  if (!p.colorHex) continue;
  if (!seriesPalette.has(key)) seriesPalette.set(key, new Set());
  seriesPalette.get(key).add(p.colorHex.toLowerCase());
}

// Pass 2: apply the union palette (or the hand-curated override) to
// every cultivar in the series.
let updated = 0;
for (const p of items) {
  const key = seriesKey(p.latin);
  if (!key) continue;

  const override = SERIES_PALETTES[key];
  const observed = seriesPalette.get(key);

  // Use the override if available, otherwise the observed union. We only
  // populate if the series has > 1 distinct colour (no point with a
  // single-colour series).
  let palette;
  if (override) {
    palette = override;
  } else if (observed && observed.size > 1) {
    palette = Array.from(observed);
  } else {
    continue;
  }

  // Exclude the cultivar's own primary colour from availableColours to
  // keep "additional colours" semantics — the iOS UI prepends colorHex
  // when displaying the full palette.
  const primary = (p.colorHex || "").toLowerCase();
  const extras = palette.filter(h => h.toLowerCase() !== primary);
  if (extras.length === 0) continue;

  // Deduplicate while preserving order.
  const seen = new Set();
  const dedup = [];
  for (const h of extras) {
    const norm = h.toLowerCase();
    if (!seen.has(norm)) { seen.add(norm); dedup.push(h); }
  }
  if (JSON.stringify(p.availableColours || []) === JSON.stringify(dedup)) continue;
  p.availableColours = dedup;
  updated++;
}

console.log("=== availableColours backfill ===");
console.log(`Series detected:    ${seriesPalette.size}`);
console.log(`Override series:    ${Object.keys(SERIES_PALETTES).length}`);
console.log(`Cultivars updated:  ${updated}`);

if (dryRun) {
  console.log("\nDRY RUN — no write.");
} else {
  data.generated = new Date().toISOString();
  writeFileSync(LIBRARY, JSON.stringify(data, null, 2) + "\n");
  console.log(`\n✓ wrote ${LIBRARY}`);
}
