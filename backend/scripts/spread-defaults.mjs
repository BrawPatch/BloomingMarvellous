// spread-defaults.mjs — single source of truth for plant spread (canopy
// diameter, cm). Trefle exposes a `spread` field structurally but returns
// null for every species we've sampled, so we synthesise the value from a
// three-step lookup:
//
//   1. ID override          — hand-authored for the bundled-17, exact match.
//   2. Genus override        — Latin name's first token, covers most of the
//                              3,264-row library at species-level fidelity.
//   3. PlantType default     — last-resort fallback so nothing is null.
//
// Numbers are typical mature-canopy diameters for a single UK garden plant
// (cm), aimed at the Bed Planting Map capacity model rather than botanical
// precision. The data can be overwritten later as it becomes available.

const ID_OVERRIDES = {
  // Bundled-17 (PlantLibrary.swift)
  "lavender":          40,
  "sunflower":         60,
  "cosmos":            45,
  "sweet-pea":         30,
  "marigold":          25,
  "nasturtium":        45,
  "delphinium":        60,
  "foxglove":          50,
  "dahlia":            60,
  "peony":             90,
  "hellebore":         45,
  "echinacea":         45,
  "phalaenopsis":      30,
  "bird-of-paradise":  90,
  "tomato-gardener":   50,
  "courgette":        120,
  "basil":             25,
};

const GENUS_DEFAULTS = {
  // Bundled-17 genera (also seed coverage for whole library rows that share a genus)
  Lavandula:      40,
  Helianthus:     60,
  Cosmos:         45,
  Lathyrus:       30,
  Tagetes:        25,
  Tropaeolum:     45,
  Delphinium:     60,
  Digitalis:      50,
  Dahlia:         60,
  Paeonia:        90,
  Helleborus:     45,
  Echinacea:      45,
  Phalaenopsis:   30,
  Strelitzia:     90,
  Solanum:        50,
  Cucurbita:     120,
  Ocimum:         25,

  // Wide-coverage genera in the ingested library (top-30 by row count)
  Rosa:           90,
  Tulipa:         12,
  Magnolia:      400,
  Hosta:          60,
  Hydrangea:     150,
  Clematis:      100,
  Geranium:       50,
  Crocus:          8,
  Lilium:         30,
  Dianthus:       30,
  Aquilegia:      45,
  Fuchsia:        60,
  Crassula:       30,
  Dracaena:       60,
  Calochortus:    15,
  Arctostaphylos:120,
  Babiana:        15,
  Rumex:          40,
  Dudleya:        20,
  Persicaria:     60,
  Cardamine:      20,
  Clarkia:        30,
  Asparagus:      60,
  Maireana:      100,
  Cotoneaster:   120,
  Eriogonum:      45,
  Epilobium:      45,
  Cypripedium:    40,
  Polygonum:      60,
  Kalanchoe:      30,
  Micranthes:     20,
};

const TYPE_DEFAULTS = {
  annual:     30,
  perennial:  45,
  biennial:   40,
  bulb:       20,
  shrub:     120,
  herb:       25,
  vegetable:  40,
};

/**
 * Resolve a spreadCm for the given plant record (or a partial during
 * ingest). Lookup priority: id override → genus override → type default → 45.
 * The fallback `45` matches the perennial default so unknown rows look
 * reasonable when the picker sums them.
 */
export function resolveSpreadCm({ id, latin, type } = {}) {
  if (id && ID_OVERRIDES[id] != null) return ID_OVERRIDES[id];
  const genus = typeof latin === "string" ? latin.split(/\s+/)[0] : null;
  if (genus && GENUS_DEFAULTS[genus] != null) return GENUS_DEFAULTS[genus];
  if (type && TYPE_DEFAULTS[type] != null) return TYPE_DEFAULTS[type];
  return 45;
}

export const SPREAD_DEFAULTS_DEBUG = { ID_OVERRIDES, GENUS_DEFAULTS, TYPE_DEFAULTS };
