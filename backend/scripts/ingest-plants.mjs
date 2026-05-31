#!/usr/bin/env node
/**
 * ingest-plants.mjs — refreshes backend/data/library.json from free public
 * data sources, with cultivar → species → genus → family inheritance for
 * sparse fields. Output is the same v2 LIBRARY shape that seed-content.mjs
 * uploads to S3 (and that the iOS Plant Codable consumes).
 *
 * Data sources (all free, no auth):
 *   • Wikidata SPARQL — taxonomy + RHS Award of Garden Merit list + photos.
 *   • Wikipedia REST  — page summaries used for tip / sun / soil keyword
 *                       inference.
 *   • Wikimedia Commons — Special:FilePath URL for the image referenced by
 *                         Wikidata (always photographic species records).
 *
 * Inheritance:
 *   We collect raw records, group them by genus and family, and fill any
 *   sparse field on a child from its genus aggregate, then from family
 *   defaults. Anything still missing falls back to the species' UK-garden
 *   defaults (well-drained loam + full sun + Jun–Aug bloom) so the picker
 *   always has a match — the comment from the user is that the data can
 *   be overwritten later as it becomes available.
 *
 * Usage:
 *   node scripts/ingest-plants.mjs                  # full run
 *   node scripts/ingest-plants.mjs --limit 25       # smoke test
 *   node scripts/ingest-plants.mjs --out custom.json
 *   node scripts/ingest-plants.mjs --dry-run        # don't write
 *
 * Idempotent (re-running overwrites the same file). Skips records where a
 * required field is still empty after inheritance (logged at the end).
 */

import { writeFileSync, readFileSync, existsSync, mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

// ── Args ─────────────────────────────────────────────────────────────────────

function parseArgs(argv) {
  const args = { limit: null, out: null, dryRun: false, verbose: false, softFail: false, noTips: false, refreshTips: false };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--limit") args.limit = parseInt(argv[++i], 10);
    else if (a === "--out") args.out = argv[++i];
    else if (a === "--dry-run") args.dryRun = true;
    else if (a === "--soft-fail") args.softFail = true;
    else if (a === "--no-tips") args.noTips = true;
    else if (a === "--refresh-tips") args.refreshTips = true;
    else if (a === "--verbose" || a === "-v") args.verbose = true;
  }
  return args;
}

const args = parseArgs(process.argv);
const OUT_PATH = args.out
  ? path.resolve(args.out)
  : fileURLToPath(new URL("../data/library.json", import.meta.url));

// ── Vocab (mirrors Sources/Models/Plant.swift + Garden.swift) ────────────────

const SOIL_TYPES = ["clay", "loam", "sandy", "chalky", "peaty", "silty"];
const SUNLIGHT   = ["sunny_always", "sunny_am", "sunny_pm", "shaded_always"];
const ACIDITY    = ["very_acidic", "mildly_acidic", "neutral", "mildly_alkaline", "very_alkaline"];
const WETNESS    = ["soggy", "normal_poor", "normal_well", "slightly_dry", "arid"];
const PLANT_TYPES = ["annual", "perennial", "biennial", "bulb", "shrub", "herb", "vegetable"];

const MONTHS = [
  "january","february","march","april","may","june",
  "july","august","september","october","november","december",
];

// Family-level defaults — used as the last fallback when neither the species
// nor its genus aggregate filled the field. Wider defaults > empty data:
// the user told us to "inherit from cultivar then genus", and that the data
// can always be overwritten later. preferredAcidity follows known family pH
// preferences (Ericaceae acidic, most veg neutral, etc.). sow/transplant/
// harvest months are typical UK garden rules-of-thumb so the Plant Detail
// "Sowing details" card always has something actionable even when Wikipedia
// didn't volunteer it.
const FAMILY_DEFAULTS = {
  Lamiaceae:    { type: "perennial", preferredSoil: ["loam","sandy","chalky"], preferredSunlight: ["sunny_always","sunny_pm"], preferredAcidity: ["neutral","mildly_alkaline"], preferredWetness: ["normal_well","slightly_dry"], bloomMonths: [6,7,8], sowIndoorMonths: [3,4], sowDirectMonths: [4,5], transplantMonths: [5,6], harvestMonths: [], colorHex: "#b8a0d8",
    tips: ["Prefers free-draining soil — never wet feet.","Full sun for the strongest fragrance.","Prune lightly after flowering to keep compact.","Hardy down to about −10 °C once established.","Excellent companion for pollinators."] },
  Asteraceae:   { type: "annual",    preferredSoil: ["loam","sandy"],          preferredSunlight: ["sunny_always"],            preferredAcidity: ["neutral","mildly_acidic","mildly_alkaline"], preferredWetness: ["normal_well"], bloomMonths: [6,7,8,9], sowIndoorMonths: [3,4], sowDirectMonths: [4,5], transplantMonths: [5], harvestMonths: [9,10], colorHex: "#e8b070",
    tips: ["Deadhead to keep flowers coming through autumn.","Sun-loving — give the brightest spot you have.","Tolerates poor soil; don't over-feed.","Leave seed heads in winter for birds.","Tall varieties may need staking."] },
  Rosaceae:     { type: "shrub",     preferredSoil: ["loam","clay"],           preferredSunlight: ["sunny_always","sunny_pm"], preferredAcidity: ["neutral","mildly_acidic"],   preferredWetness: ["normal_well"], bloomMonths: [5,6,7], sowIndoorMonths: [], sowDirectMonths: [], transplantMonths: [10,11,3], harvestMonths: [], colorHex: "#f4b8b0",
    tips: ["Mulch in spring with well-rotted manure.","Prune after flowering on summer-flowerers.","Water deeply at the base, not on foliage.","Watch for blackspot and aphids — act early.","Feed with a rose fertiliser in spring + midsummer."] },
  Ranunculaceae:{ type: "perennial", preferredSoil: ["loam","peaty"],          preferredSunlight: ["sunny_pm","shaded_always"],preferredAcidity: ["neutral","mildly_acidic"],   preferredWetness: ["normal_well","normal_poor"], bloomMonths: [4,5,6], sowIndoorMonths: [], sowDirectMonths: [9], transplantMonths: [9,10], harvestMonths: [], colorHex: "#c0a0d8",
    tips: ["Most members enjoy dappled shade.","Mulch annually to retain spring moisture.","Many are toxic — handle with gloves.","Cut back hard after flowering for a second flush.","Lift and divide every 3–4 years."] },
  Fabaceae:     { type: "annual",    preferredSoil: ["loam","sandy"],          preferredSunlight: ["sunny_always"],            preferredAcidity: ["neutral","mildly_alkaline"], preferredWetness: ["normal_well"], bloomMonths: [6,7,8], sowIndoorMonths: [2,3], sowDirectMonths: [3,4], transplantMonths: [5], harvestMonths: [], colorHex: "#88c8e0",
    tips: ["Fix nitrogen in soil — good rotation crop.","Soak seed overnight to speed germination.","Provide canes or trellis for climbers.","Pinch tips to encourage branching.","Pick pods regularly to keep cropping."] },
  Iridaceae:    { type: "bulb",      preferredSoil: ["loam","sandy"],          preferredSunlight: ["sunny_always","sunny_pm"], preferredAcidity: ["neutral"],                   preferredWetness: ["normal_well"], bloomMonths: [4,5,6], sowIndoorMonths: [], sowDirectMonths: [], transplantMonths: [9,10,11], harvestMonths: [], colorHex: "#c0a0d8",
    tips: ["Plant corms 3× their height deep.","Leave foliage to die back naturally — feeds next year's bloom.","Lift and divide congested clumps in late summer.","Free-draining soil is essential — they hate wet feet.","Underplant with hardy annuals for continuity."] },
  Liliaceae:    { type: "bulb",      preferredSoil: ["loam"],                   preferredSunlight: ["sunny_always","sunny_pm"], preferredAcidity: ["neutral","mildly_acidic"],   preferredWetness: ["normal_well"], bloomMonths: [5,6,7], sowIndoorMonths: [], sowDirectMonths: [], transplantMonths: [9,10,11], harvestMonths: [], colorHex: "#f4b8b0",
    tips: ["Plant bulbs at 3× their height for stable stems.","Add grit to heavy soil before planting.","Stake tall varieties before they flop.","Watch for red lily beetle — pick off by hand.","Leave foliage to die back to feed next year's bulbs."] },
  Solanaceae:   { type: "vegetable", preferredSoil: ["loam"],                   preferredSunlight: ["sunny_always"],            preferredAcidity: ["mildly_acidic","neutral"],   preferredWetness: ["normal_well"], bloomMonths: [6,7,8], sowIndoorMonths: [2,3], sowDirectMonths: [], transplantMonths: [5,6], harvestMonths: [7,8,9,10], colorHex: "#e07070",
    tips: ["Start indoors in heat (20 °C+) for best germination.","Pinch out side-shoots on cordon tomatoes.","Feed weekly with high-potash food once fruit sets.","Keep watering even and consistent to avoid splits.","Watch for blight in damp summers — remove affected foliage."] },
  Apiaceae:     { type: "herb",      preferredSoil: ["loam","sandy"],          preferredSunlight: ["sunny_always","sunny_pm"], preferredAcidity: ["neutral"],                   preferredWetness: ["normal_well"], bloomMonths: [6,7], sowIndoorMonths: [3,4], sowDirectMonths: [4,5,6], transplantMonths: [5,6], harvestMonths: [6,7,8,9], colorHex: "#7aaa8a",
    tips: ["Direct-sow once soil is reliably warm — they dislike root disturbance.","Pinch tips often to delay bolting.","Harvest leaves before flowers form for best flavour.","Allow some plants to flower — beneficial insects love them.","Some self-seed prolifically — let them or deadhead before set."] },
  Cucurbitaceae:{ type: "vegetable", preferredSoil: ["loam"],                   preferredSunlight: ["sunny_always"],            preferredAcidity: ["mildly_acidic","neutral"],   preferredWetness: ["normal_well"], bloomMonths: [6,7,8,9], sowIndoorMonths: [4,5], sowDirectMonths: [5,6], transplantMonths: [6], harvestMonths: [7,8,9], colorHex: "#7aaa8a",
    tips: ["Hungry feeders — work plenty of compost into planting holes.","Water deeply at the base, especially when fruiting.","Pick courgettes/cucumbers young for tender best flavour.","Mulch to keep moisture in and slugs out.","Hand-pollinate early flowers if pollinators are scarce."] },
  Orchidaceae:  { type: "perennial", preferredSoil: ["peaty"],                  preferredSunlight: ["sunny_am","sunny_pm"],     preferredAcidity: ["mildly_acidic","neutral"],   preferredWetness: ["normal_well"], bloomMonths: [1,2,3,4,11,12], sowIndoorMonths: [], sowDirectMonths: [], transplantMonths: [4,5], harvestMonths: [], colorHex: "#c0a0d8",
    tips: ["Bright indirect light — no direct midday sun.","Water by soaking once weekly, then let drain fully.","Use orchid bark mix, not normal compost.","Re-pot every 2 years after flowering.","Feed weakly, weekly — `feed-weak-weekly`."] },
  Ericaceae:    { type: "shrub",     preferredSoil: ["peaty"],                  preferredSunlight: ["sunny_pm","shaded_always"],preferredAcidity: ["very_acidic","mildly_acidic"], preferredWetness: ["normal_well"], bloomMonths: [4,5,6], sowIndoorMonths: [], sowDirectMonths: [], transplantMonths: [10,11,3], harvestMonths: [], colorHex: "#c0a0d8",
    tips: ["Acid soil (pH 4.5–5.5) is essential — use ericaceous compost.","Mulch with pine needles or bark.","Water with rainwater where possible (tap water is alkaline).","Light dappled shade gives best leaf colour.","Avoid feeding with general fertilisers — use ericaceous feed."] },
  Brassicaceae: { type: "vegetable", preferredSoil: ["loam"],                   preferredSunlight: ["sunny_always","sunny_pm"], preferredAcidity: ["neutral","mildly_alkaline"], preferredWetness: ["normal_well"], bloomMonths: [4,5,6], sowIndoorMonths: [2,3], sowDirectMonths: [3,4,5], transplantMonths: [5], harvestMonths: [6,7,8,9,10], colorHex: "#f4b8b0",
    tips: ["Lime the soil if pH is below 6.5 to prevent club root.","Net against cabbage white butterflies from May.","Firm the soil before planting — they like compaction.","Water in well at transplanting and during dry spells.","Rotate crops on a 3–4 year cycle."] },
  Hydrangeaceae:{ type: "shrub",     preferredSoil: ["loam"],                   preferredSunlight: ["sunny_pm","shaded_always"],preferredAcidity: ["mildly_acidic","neutral"],   preferredWetness: ["normal_well","normal_poor"], bloomMonths: [6,7,8], sowIndoorMonths: [], sowDirectMonths: [], transplantMonths: [10,11,12,3], harvestMonths: [], colorHex: "#c0a0d8",
    tips: ["Acidic soil keeps flowers blue; alkaline turns them pink.","Mulch in spring; never let roots dry out in summer.","Prune dead wood + last year's flower stems in early spring.","Tolerates light shade — great for north-facing borders.","Cut blooms for drying once papery — Aug/Sep."] },
};

// Generic UK-garden defaults, used when family is unknown.
const GENERIC_DEFAULT = {
  type: "perennial",
  preferredSoil: ["loam"],
  preferredSunlight: ["sunny_always", "sunny_pm"],
  preferredAcidity: ["mildly_acidic", "neutral"],
  preferredWetness: ["normal_well"],
  bloomMonths: [6, 7, 8],
  sowIndoorMonths: [3, 4],
  sowDirectMonths: [4, 5],
  transplantMonths: [5],
  harvestMonths: [],
  colorHex: "#a8d8bc",
  tips: [
    "Plant in a sheltered spot until established.",
    "Water deeply during dry spells in the first year.",
    "Mulch in spring to suppress weeds and retain moisture.",
    "Feed once in spring with a balanced fertiliser.",
    "Watch for slugs and aphids on tender new growth.",
  ],
};

// ── HTTP helpers ─────────────────────────────────────────────────────────────

const USER_AGENT = "BloomingMarvellous-DataIngest/1.0 (https://blooming-marvellous.app; contact: hello@blooming-marvellous.app)";

async function getJson(url, { timeoutMs = 20000 } = {}) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      headers: { "User-Agent": USER_AGENT, Accept: "application/json" },
      signal: ctrl.signal,
    });
    if (!res.ok) throw new Error(`HTTP ${res.status} ${res.statusText} from ${url}`);
    return await res.json();
  } finally {
    clearTimeout(timer);
  }
}

// ── Gemini growers' tips (optional, cached) ──────────────────────────────────
//
// When GEMINI_API_KEY (or GOOGLE_API_KEY) is set in the environment, the
// ingest asks Google Gemini for 5 short cultivar-specific UK gardening tips
// per plant. Results are cached at backend/data/tips-cache.json keyed by the
// plant's slug id; subsequent ingests reuse the cache so we only pay for new
// taxa or refreshes. Falls back to FAMILY_DEFAULTS.tips when no key is set
// or the call fails.
//
// Cost guard: at the time of writing Gemini 2.0 Flash is roughly $0.10 per
// million input tokens / $0.40 per million output tokens. 382 plants × ~150
// in + ~120 out tokens ≈ a few US cents per full refresh — safe enough to
// rerun. Re-running without `--refresh-tips` is free past the first time.

const GEMINI_API_KEY = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY || null;
const GEMINI_MODEL   = process.env.GEMINI_MODEL   || "gemini-2.0-flash";
const TIPS_CACHE_PATH = fileURLToPath(new URL("../data/tips-cache.json", import.meta.url));

function loadTipsCache() {
  if (!existsSync(TIPS_CACHE_PATH)) return {};
  try { return JSON.parse(readFileSync(TIPS_CACHE_PATH, "utf-8")); }
  catch { return {}; }
}

function saveTipsCache(cache) {
  try {
    mkdirSync(path.dirname(TIPS_CACHE_PATH), { recursive: true });
    writeFileSync(TIPS_CACHE_PATH, JSON.stringify(cache, null, 2) + "\n");
  } catch (err) {
    console.warn(`⚠️ Failed to save tips cache: ${err.message}`);
  }
}

async function geminiTipsFor({ id, name, latin, type, familyLabel }) {
  if (!GEMINI_API_KEY) return null;
  const prompt = [
    `Give me the FIVE most useful practical UK gardening tips specific to`,
    `${name} (Latin name: ${latin}; family: ${familyLabel ?? "unknown"};`,
    `growth habit: ${type ?? "unknown"}).`,
    `Rules:`,
    `- Output exactly five lines, one tip per line, with no numbering, no markdown,`,
    `  no bold, no leading dash or bullet.`,
    `- Each line must be 100 characters or less.`,
    `- Each tip must be specific and actionable (planting depth, watering pattern,`,
    `  pest watch, pruning timing, soil prep, companion plants, cultivar-specific`,
    `  quirks). Avoid generic gardening clichés that apply to anything.`,
    `- Focus on UK-relevant climate and the typical home gardener.`,
  ].join(" ");
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(GEMINI_MODEL)}:generateContent?key=${GEMINI_API_KEY}`;
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", "User-Agent": USER_AGENT },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.4,
          maxOutputTokens: 320,
          // Block obvious safety mishaps; gardening shouldn't trip them but
          // explicit thresholds avoid surprises across model upgrades.
          responseMimeType: "text/plain",
        },
      }),
    });
    if (!res.ok) return null;
    const data = await res.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    const bullets = text
      .split(/\r?\n/)
      .map(s => s.replace(/^[\-•*•]\s*/, "").replace(/^\d+[.)\s]+\s*/, "").trim())
      .filter(b => b.length > 0)
      .slice(0, 5);
    return bullets.length ? bullets.join("\n") : null;
  } catch {
    return null;
  }
}

async function enrichTips(records) {
  if (args.noTips || !GEMINI_API_KEY) {
    if (!GEMINI_API_KEY && !args.noTips) {
      console.log("ℹ︎  GEMINI_API_KEY not set — keeping family-level grower's tips. Set the env var to enable per-plant tips.");
    }
    return records;
  }

  console.log(`→ Gemini per-plant grower's tips (model: ${GEMINI_MODEL})…`);
  const cache = loadTipsCache();
  let calls = 0;
  let cacheHits = 0;
  let i = 0;
  for (const r of records) {
    i++;
    const cached = cache[r.id];
    if (cached && !args.refreshTips) {
      r.growersTips = cached;
      cacheHits++;
    } else {
      const tips = await geminiTipsFor({
        id: r.id,
        name: r.name,
        latin: r.latin,
        type: r.type,
        familyLabel: r.family ?? r.familyLabel ?? null,
      });
      if (tips) {
        r.growersTips = tips;
        cache[r.id] = tips;
        calls++;
        // Light throttle to stay under Gemini's free-tier RPM.
        await new Promise(res => setTimeout(res, 250));
      }
    }
    if (i % 20 === 0) console.log(`  ${i}/${records.length} (live ${calls}, cached ${cacheHits})`);
  }
  saveTipsCache(cache);
  console.log(`✓ Tips ready — ${calls} fresh, ${cacheHits} cached, ${records.length - calls - cacheHits} fallback to family.`);
  return records;
}

// ── Seed list: curated UK garden Latin names ─────────────────────────────────
//
// We tried discovering taxa via a single SPARQL query on Wikidata's RHS Award
// of Garden Merit catalogue, but that property was empty / had moved. Far more
// reliable: maintain a seed list of well-known UK garden taxa and look each one
// up individually via Wikidata's `wbsearchentities` API. The list can be
// extended freely — duplicates and unknown taxa are skipped gracefully.

const SEED_LATINS = [
  // Lamiaceae (mints / sages / lavenders)
  "Lavandula angustifolia", "Lavandula stoechas", "Lavandula × intermedia",
  "Salvia nemorosa", "Salvia officinalis", "Rosmarinus officinalis",
  "Nepeta × faassenii", "Stachys byzantina", "Thymus serpyllum",
  "Origanum vulgare", "Mentha spicata", "Mentha piperita",
  "Monarda didyma", "Perovskia atriplicifolia",
  // Asteraceae (composites — daisies / sunflowers / asters)
  "Helianthus annuus", "Cosmos bipinnatus", "Cosmos sulphureus",
  "Echinacea purpurea", "Rudbeckia fulgida", "Rudbeckia hirta",
  "Tagetes patula", "Tagetes erecta", "Calendula officinalis",
  "Aster amellus", "Symphyotrichum novi-belgii", "Achillea millefolium",
  "Leucanthemum × superbum", "Coreopsis grandiflora", "Dahlia pinnata",
  "Chrysanthemum × morifolium", "Gaillardia × grandiflora",
  // Rosaceae
  "Rosa rugosa", "Rosa canina", "Geum chiloense", "Geum rivale",
  "Alchemilla mollis", "Filipendula ulmaria", "Potentilla fruticosa",
  "Prunus laurocerasus", "Prunus avium", "Pyracantha coccinea",
  // Ranunculaceae
  "Helleborus orientalis", "Helleborus niger", "Helleborus foetidus",
  "Aquilegia vulgaris", "Anemone blanda", "Anemone × hybrida",
  "Clematis montana", "Clematis viticella", "Delphinium elatum",
  "Aconitum napellus", "Ranunculus acris",
  // Fabaceae (legumes)
  "Lathyrus odoratus", "Lupinus polyphyllus", "Wisteria sinensis",
  "Trifolium repens", "Vicia faba",
  // Iridaceae / Liliaceae (bulbs and bulb-like)
  "Iris germanica", "Iris reticulata", "Iris sibirica",
  "Crocus vernus", "Crocus tommasinianus",
  "Tulipa gesneriana", "Narcissus pseudonarcissus", "Narcissus poeticus",
  "Galanthus nivalis", "Hyacinthoides non-scripta", "Lilium regale",
  "Lilium martagon", "Allium giganteum", "Allium hollandicum",
  "Fritillaria meleagris", "Hyacinthus orientalis",
  // Solanaceae (mostly edible)
  "Solanum lycopersicum", "Solanum tuberosum", "Capsicum annuum",
  "Solanum melongena", "Petunia × hybrida", "Nicotiana sylvestris",
  // Apiaceae (umbellifers)
  "Petroselinum crispum", "Coriandrum sativum", "Anethum graveolens",
  "Foeniculum vulgare", "Daucus carota subsp. sativus",
  "Astrantia major", "Eryngium giganteum",
  // Cucurbitaceae (squash family)
  "Cucurbita pepo", "Cucurbita maxima", "Cucumis sativus", "Cucurbita moschata",
  // Brassicaceae (cabbages / kale)
  "Brassica oleracea", "Lobularia maritima", "Erysimum cheiri",
  "Hesperis matronalis",
  // Caryophyllaceae (pinks / dianthus)
  "Dianthus barbatus", "Dianthus caryophyllus", "Lychnis coronaria",
  "Silene dioica",
  // Saxifragaceae / Boraginaceae / Polemoniaceae mix
  "Bergenia cordifolia", "Heuchera micrantha",
  "Pulmonaria officinalis", "Brunnera macrophylla", "Borago officinalis",
  "Phlox paniculata", "Phlox subulata",
  // Ericaceae (acid lovers)
  "Rhododendron ponticum", "Camellia japonica", "Erica carnea",
  "Calluna vulgaris", "Pieris japonica",
  // Hydrangeaceae / Onagraceae
  "Hydrangea macrophylla", "Hydrangea paniculata", "Hydrangea arborescens",
  "Oenothera biennis", "Fuchsia magellanica",
  // Tropaeolaceae / Geraniaceae
  "Tropaeolum majus", "Geranium pratense", "Geranium sanguineum",
  "Pelargonium × hortorum",
  // Papaveraceae
  "Papaver orientale", "Papaver rhoeas", "Eschscholzia californica",
  // Plantaginaceae / Scrophulariaceae
  "Digitalis purpurea", "Digitalis grandiflora", "Antirrhinum majus",
  "Penstemon barbatus", "Verbascum thapsus",
  // Crassulaceae
  "Sedum spectabile", "Hylotelephium telephium", "Sempervivum tectorum",
  // Buxaceae / Aquifoliaceae (evergreen structure)
  "Buxus sempervirens", "Ilex aquifolium",
  // Lamiaceae continued + Verbenaceae
  "Verbena bonariensis", "Verbena × hybrida",
  // Lythraceae / Onagraceae
  "Lythrum salicaria",
  // Paeoniaceae
  "Paeonia lactiflora", "Paeonia officinalis",
  // Strelitziaceae / Orchidaceae (exotic pack)
  "Strelitzia reginae", "Phalaenopsis amabilis",
  "Cymbidium hybrid", "Dendrobium nobile",
  // Misc edibles
  "Fragaria × ananassa", "Rheum × hybridum", "Rubus idaeus", "Ribes nigrum",
  "Vaccinium corymbosum",
  "Ocimum basilicum", "Mentha × piperita",

  // ── Expanded set: more UK herbaceous border perennials ─────────────────
  "Astilbe chinensis", "Astilbe × arendsii", "Astrantia maxima",
  "Hosta plantaginea", "Hosta fortunei", "Hosta sieboldiana",
  "Heuchera sanguinea", "Heucherella", "Tiarella cordifolia",
  "Acanthus mollis", "Acanthus spinosus",
  "Anemone hupehensis", "Anemone nemorosa", "Anemone coronaria",
  "Aquilegia chrysantha", "Aquilegia canadensis",
  "Campanula persicifolia", "Campanula glomerata", "Campanula medium",
  "Centaurea cyanus", "Centaurea montana",
  "Crocosmia × crocosmiiflora", "Crocosmia aurea",
  "Delphinium grandiflorum",
  "Echinops ritro", "Eryngium planum",
  "Gaura lindheimeri",
  "Helleborus argutifolius", "Helleborus × hybridus",
  "Iberis sempervirens",
  "Knautia macedonica",
  "Kniphofia uvaria", "Kniphofia rooperi",
  "Leucanthemum vulgare", "Leucanthemella serotina",
  "Liatris spicata",
  "Linaria purpurea",
  "Lupinus arboreus",
  "Lychnis chalcedonica",
  "Lysimachia clethroides", "Lysimachia punctata",
  "Macleaya cordata",
  "Meconopsis betonicifolia",
  "Nigella damascena",
  "Polemonium caeruleum",
  "Primula vulgaris", "Primula veris", "Primula denticulata",
  "Pulsatilla vulgaris",
  "Salvia × sylvestris", "Salvia farinacea", "Salvia uliginosa",
  "Sanguisorba officinalis",
  "Scabiosa caucasica", "Scabiosa columbaria",
  "Sedum 'Autumn Joy'", "Sedum acre",
  "Solidago canadensis",
  "Stachys macrantha",
  "Thalictrum delavayi", "Thalictrum aquilegiifolium",
  "Verbascum bombyciferum", "Verbascum chaixii",
  "Veronica spicata", "Veronica longifolia",
  "Viola odorata", "Viola tricolor", "Viola × wittrockiana",

  // ── Shrubs and woody plants (UK garden mainstays) ──────────────────────
  "Buddleja davidii", "Buddleja globosa",
  "Forsythia × intermedia",
  "Weigela florida",
  "Spiraea japonica", "Spiraea × vanhouttei",
  "Viburnum opulus", "Viburnum tinus", "Viburnum × bodnantense",
  "Mahonia aquifolium", "Mahonia × media",
  "Sambucus nigra",
  "Cotoneaster horizontalis",
  "Berberis darwinii", "Berberis thunbergii",
  "Hamamelis × intermedia", "Hamamelis mollis",
  "Cornus alba", "Cornus sericea", "Cornus florida", "Cornus kousa",
  "Magnolia stellata", "Magnolia × soulangeana", "Magnolia grandiflora",
  "Acer palmatum", "Acer japonicum", "Acer griseum",
  "Skimmia japonica",
  "Choisya ternata",
  "Daphne odora", "Daphne mezereum",
  "Ceanothus thyrsiflorus",
  "Hibiscus syriacus",
  "Lonicera periclymenum", "Lonicera nitida",
  "Jasminum officinale", "Jasminum nudiflorum",
  "Pittosporum tobira",
  "Phormium tenax",
  "Yucca filamentosa",
  "Sarcococca confusa",
  "Aucuba japonica",
  "Photinia × fraseri",
  "Olearia × haastii",
  "Escallonia rubra",
  "Garrya elliptica",

  // ── Climbers ───────────────────────────────────────────────────────────
  "Clematis armandii", "Clematis tangutica", "Clematis alpina",
  "Clematis × jackmanii",
  "Hedera helix", "Hedera colchica",
  "Akebia quinata",
  "Passiflora caerulea",
  "Trachelospermum jasminoides",
  "Solanum crispum",
  "Parthenocissus tricuspidata", "Parthenocissus quinquefolia",
  "Vitis vinifera", "Vitis coignetiae",
  "Humulus lupulus",
  "Eccremocarpus scaber",

  // ── Bulbs & corms ──────────────────────────────────────────────────────
  "Tulipa kaufmanniana", "Tulipa greigii",
  "Narcissus tazetta", "Narcissus jonquilla",
  "Cyclamen hederifolium", "Cyclamen coum",
  "Colchicum autumnale",
  "Allium christophii", "Allium schoenoprasum",
  "Camassia leichtlinii",
  "Eranthis hyemalis",
  "Leucojum aestivum", "Leucojum vernum",
  "Muscari armeniacum",
  "Ornithogalum umbellatum",
  "Scilla siberica",
  "Crocus sativus", "Crocus chrysanthus",
  "Gladiolus communis",
  "Iris pumila", "Iris pseudacorus",
  "Lilium candidum", "Lilium speciosum",

  // ── Grasses, ferns, and architectural ──────────────────────────────────
  "Stipa tenuissima", "Stipa gigantea",
  "Miscanthus sinensis",
  "Pennisetum alopecuroides",
  "Festuca glauca",
  "Calamagrostis × acutiflora",
  "Carex oshimensis", "Carex pendula",
  "Hakonechloa macra",
  "Dryopteris filix-mas",
  "Athyrium filix-femina",
  "Polystichum setiferum",
  "Asplenium scolopendrium",

  // ── Alpines & ground cover ─────────────────────────────────────────────
  "Aubrieta deltoidea",
  "Saxifraga × urbium",
  "Arabis caucasica",
  "Helianthemum nummularium",
  "Armeria maritima",
  "Pulmonaria saccharata",
  "Vinca minor", "Vinca major",
  "Ajuga reptans",
  "Lamium maculatum",
  "Cerastium tomentosum",
  "Phlox stolonifera",

  // ── Trees (small / ornamental) ─────────────────────────────────────────
  "Prunus serrulata", "Prunus subhirtella", "Prunus sargentii",
  "Malus floribunda", "Malus 'John Downie'",
  "Sorbus aucuparia", "Sorbus aria",
  "Betula pendula", "Betula utilis",
  "Crataegus monogyna", "Crataegus laevigata",
  "Cercis canadensis", "Cercis siliquastrum",
  "Liquidambar styraciflua",
  "Stewartia pseudocamellia",

  // ── More edibles ───────────────────────────────────────────────────────
  "Solanum tuberosum", "Allium cepa", "Allium sativum",
  "Daucus carota",
  "Beta vulgaris",
  "Pisum sativum", "Phaseolus vulgaris",
  "Lactuca sativa",
  "Spinacia oleracea",
  "Brassica rapa", "Brassica napus",
  "Capsicum annuum",
  "Citrullus lanatus",
  "Cynara cardunculus", "Cynara scolymus",
  "Rosmarinus officinalis", "Thymus vulgaris",
  "Salvia rosmarinus",
  "Anethum graveolens",
  "Petroselinum crispum",
  "Allium tuberosum",
  "Origanum majorana",
  "Levisticum officinale",
  "Vaccinium myrtillus",
  "Ribes rubrum", "Ribes uva-crispa",
  "Rubus fruticosus", "Rubus loganobaccus",
  "Prunus domestica", "Prunus armeniaca", "Prunus persica",
  "Pyrus communis",
  "Malus domestica",
  "Cydonia oblonga",
  "Ficus carica",

  // ── Aquatic / bog / pond ───────────────────────────────────────────────
  "Nymphaea alba", "Nymphaea odorata",
  "Iris versicolor", "Iris laevigata",
  "Caltha palustris",
  "Lythrum salicaria",
  "Pontederia cordata",
  "Mentha aquatica",
  "Hosta lancifolia",
  "Equisetum hyemale",
];

// ── Wikidata search + entity fetch ───────────────────────────────────────────
//
// `wbsearchentities` finds the QID for a Latin taxon name. `wbgetentities`
// returns the full entity payload, from which we extract image (P18), parent
// taxon / genus (P171), and the taxon rank chain up to family (Q35409).

async function wikidataSearch(latin) {
  const url = `https://www.wikidata.org/w/api.php?action=wbsearchentities&search=${encodeURIComponent(latin)}&language=en&type=item&limit=10&format=json&origin=*`;
  try {
    const data = await getJson(url, { timeoutMs: 8000 });
    const hits = data?.search ?? [];
    if (hits.length === 0) return null;
    // Strongly prefer hits whose description mentions "species" or "taxon"
    // (rules out cultivars / lexemes / brand names that share a Latin name).
    // Reject cultivar matches outright.
    const isCultivar = (h) => /\bcultivar\b/i.test(h.description ?? "");
    const isSpecies  = (h) => /\bspecies\b|\btaxon\b/i.test(h.description ?? "");
    const speciesHit = hits.find(h => isSpecies(h) && !isCultivar(h));
    if (speciesHit) return speciesHit.id;
    // Fallback: first non-cultivar hit, else first hit.
    const nonCultivar = hits.find(h => !isCultivar(h));
    return (nonCultivar ?? hits[0]).id;
  } catch { return null; }
}

async function wikidataGetEntity(qid) {
  const url = `https://www.wikidata.org/w/api.php?action=wbgetentities&ids=${qid}&props=claims|labels|aliases|sitelinks&languages=en&sitefilter=enwiki&format=json&origin=*`;
  try {
    const data = await getJson(url, { timeoutMs: 8000 });
    return data?.entities?.[qid] ?? null;
  } catch { return null; }
}

function claimValueIds(entity, prop) {
  return (entity?.claims?.[prop] ?? [])
    .map(c => c?.mainsnak?.datavalue?.value?.id)
    .filter(Boolean);
}

function claimValueStrings(entity, prop) {
  return (entity?.claims?.[prop] ?? [])
    .map(c => c?.mainsnak?.datavalue?.value)
    .filter(v => typeof v === "string");
}

function entityLabel(entity, lang = "en") {
  return entity?.labels?.[lang]?.value ?? null;
}

// Common name from the English aliases. Picks the shortest *multi-word*
// alias to favour human names like "English lavender" over single-word
// cultivar nicknames like "Mariflor" or branded product names. Reject
// Latin binomials outright.
function commonName(entity) {
  const aliases = (entity?.aliases?.en ?? []).map(a => a?.value).filter(Boolean);
  if (aliases.length === 0) return null;
  const candidates = aliases.filter(a => {
    if (/^[A-Z]\w+\s[a-z]+$/.test(a)) return false;     // "Lavandula officinalis"
    if (/^[A-Z]\w+\s×\s[a-z]+/.test(a)) return false;   // hybrid binomial
    if (!/\s/.test(a)) return false;                    // single word — cultivar/brand
    if (/^[A-Z\s]+$/.test(a)) return false;             // all caps
    return true;
  });
  if (candidates.length === 0) return null;
  return candidates.sort((a, b) => a.length - b.length)[0];
}

const COMMONS_FILE_BASE = "https://commons.wikimedia.org/wiki/Special:FilePath/";

async function fetchSeedTaxon(latin) {
  const qid = await wikidataSearch(latin);
  if (!qid) return null;
  const entity = await wikidataGetEntity(qid);
  if (!entity) return null;

  // Image: P18 stores a Commons filename like "Lavandula_angustifolia.jpg".
  // Append `?width=800` so iOS receives an 800px-wide thumbnail rather than
  // the full original (often 4000+ px, multi-MB). The thumbnail is enough
  // for both the picker tile (96 px) and the detail hero (180 px @ retina).
  const imageFile = claimValueStrings(entity, "P18")[0] ?? null;
  const imageUrl  = imageFile
    ? `${COMMONS_FILE_BASE}${encodeURIComponent(imageFile)}?width=800`
    : null;

  // Parent taxa chain — walk up to family.
  let genusLabel = null;
  let familyLabel = null;
  const parentQids = claimValueIds(entity, "P171");
  for (const pQid of parentQids.slice(0, 1)) {
    const parent = await wikidataGetEntity(pQid);
    if (!parent) continue;
    genusLabel = entityLabel(parent);
    const grandParents = claimValueIds(parent, "P171");
    for (const gpQid of grandParents.slice(0, 1)) {
      const grand = await wikidataGetEntity(gpQid);
      if (!grand) continue;
      // Walk up at most 4 levels searching for family.
      let cursor = grand;
      for (let depth = 0; depth < 4; depth++) {
        const ranks = claimValueIds(cursor, "P105");
        if (ranks.includes("Q35409")) { familyLabel = entityLabel(cursor); break; }
        const upQids = claimValueIds(cursor, "P171");
        if (upQids.length === 0) break;
        const next = await wikidataGetEntity(upQids[0]);
        if (!next) break;
        cursor = next;
      }
    }
  }

  // Prefer the English Wikipedia article title (e.g. "Sunflower" for
  // Helianthus annuus, "Cosmos (plant)" for Cosmos bipinnatus) — that's the
  // canonical common name. Fall back to a clean alias, then the entity label
  // (often Latin binomial). The Latin is always preserved on `latin`.
  const wikiTitle = entity?.sitelinks?.enwiki?.title ?? null;
  const niceName = cleanCommonName(wikiTitle)
    ?? commonName(entity)
    ?? entityLabel(entity)
    ?? latin;

  return {
    qid,
    label: capitalize(niceName),
    latin,
    imageUrl,
    genusLabel,
    familyLabel,
  };
}

function capitalize(s) {
  if (!s) return s;
  return s.charAt(0).toUpperCase() + s.slice(1);
}

// Strip Wikipedia disambiguation suffixes and reject titles that are
// themselves Latin binomials (the article uses the scientific name as its
// title — no common name available).
function cleanCommonName(title) {
  if (!title) return null;
  const stripped = title.replace(/\s*\([^)]*\)\s*$/, "").trim();
  if (!stripped) return null;
  if (/^[A-Z]\w+\s[a-z]+/.test(stripped)) return null;            // "Lavandula angustifolia"
  if (/^[A-Z]\w+\s×\s[a-z]+/.test(stripped)) return null;         // "Aster × frikartii"
  return stripped;
}

async function fetchAgmList(limit) {
  const slice = limit ? SEED_LATINS.slice(0, limit) : SEED_LATINS;
  console.log(`→ Wikidata lookup for ${slice.length} seed taxa (search + entity fetch + parent taxa)…`);
  const out = [];
  let n = 0;
  for (const latin of slice) {
    n++;
    const row = await fetchSeedTaxon(latin);
    if (row) {
      out.push(row);
    } else if (args.verbose) {
      console.log(`  · skipped ${latin} (no Wikidata match)`);
    }
    if (n % 10 === 0) console.log(`  ${n}/${slice.length} (${out.length} resolved)`);
  }
  console.log(`  ${out.length} unique taxa retrieved.`);
  return out;
}

// ── Wikipedia REST: page summary for tips + heuristic field inference ────────

async function fetchWikipediaSummary(title) {
  const safe = encodeURIComponent(title.replace(/ /g, "_"));
  const url = `https://en.wikipedia.org/api/rest_v1/page/summary/${safe}`;
  try {
    const data = await getJson(url, { timeoutMs: 10000 });
    return data?.extract ?? "";
  } catch {
    return "";
  }
}

// Heuristic field extractors. Conservative: we'd rather inherit from the genus
// than guess wrong. Returns null when we have no signal.

function parseSunlight(text) {
  if (!text) return null;
  const t = text.toLowerCase();
  const out = new Set();
  if (/\bfull sun\b/.test(t))                         out.add("sunny_always");
  if (/\bpartial sun\b|\bpart sun\b|\bdappled\b/.test(t)) { out.add("sunny_am"); out.add("sunny_pm"); }
  if (/\bpartial shade\b|\bpart shade\b/.test(t))     out.add("sunny_pm");
  if (/\bfull shade\b|\bdeep shade\b/.test(t))        out.add("shaded_always");
  return out.size ? [...out] : null;
}

function parseSoil(text) {
  if (!text) return null;
  const t = text.toLowerCase();
  const out = new Set();
  if (/\bwell[- ]?drained\b|\bsandy\b/.test(t)) out.add("sandy");
  if (/\bloam\b|\bloamy\b/.test(t))             out.add("loam");
  if (/\bchalk\b|\balkaline\b|\blimestone\b/.test(t)) out.add("chalky");
  if (/\bclay\b/.test(t))                       out.add("clay");
  if (/\bpeat\b|\bacidic?\b|\bericaceous\b/.test(t))  out.add("peaty");
  if (/\bsilt\b/.test(t))                        out.add("silty");
  return out.size ? [...out] : null;
}

function parseBloomMonths(text) {
  if (!text) return null;
  const t = text.toLowerCase();
  const monthsFound = new Set();

  // Range like "blooms from June to August" / "May–July" / "May to July".
  const range = t.match(/(?:bloom|flower)[a-z\s]{0,30}?from\s+([a-z]+)\s+(?:to|through|until|[–-])\s+([a-z]+)/);
  if (range) {
    const a = MONTHS.indexOf(range[1]);
    const b = MONTHS.indexOf(range[2]);
    if (a !== -1 && b !== -1) {
      const span = (b - a + 12) % 12;
      for (let i = 0; i <= span; i++) monthsFound.add(((a + i) % 12) + 1);
    }
  }

  // Individual mentions: "blooms in July" or "spring-flowering".
  for (let i = 0; i < MONTHS.length; i++) {
    const m = MONTHS[i];
    if (new RegExp(`\\b(?:bloom|flower|flowering)[a-z\\s]{0,12}\\b${m}\\b`).test(t)) {
      monthsFound.add(i + 1);
    }
  }
  if (/\bspring[- ]flower/.test(t))  [3, 4, 5].forEach(m => monthsFound.add(m));
  if (/\bsummer[- ]flower/.test(t))  [6, 7, 8].forEach(m => monthsFound.add(m));
  if (/\bautumn[- ]flower|\bfall[- ]flower/.test(t)) [9, 10, 11].forEach(m => monthsFound.add(m));
  if (/\bwinter[- ]flower/.test(t))  [12, 1, 2].forEach(m => monthsFound.add(m));

  return monthsFound.size ? [...monthsFound].sort((a, b) => a - b) : null;
}

function parsePlantType(text, familyDefault) {
  if (!text) return familyDefault ?? null;
  const t = text.toLowerCase();
  if (/\bperennial\b/.test(t))  return "perennial";
  if (/\bbiennial\b/.test(t))   return "biennial";
  if (/\bannual\b/.test(t))     return "annual";
  if (/\bbulb\b|\btuber\b|\brhizome\b/.test(t)) return "bulb";
  if (/\bshrub\b|\btree\b/.test(t)) return "shrub";
  if (/\bherb\b/.test(t))        return "herb";
  if (/\bvegetable\b/.test(t))   return "vegetable";
  return familyDefault ?? null;
}

function parseWetness(text) {
  if (!text) return null;
  const t = text.toLowerCase();
  const out = new Set();
  if (/\bboggy?\b|\bwetlands?\b|\bmarsh\b|\bsaturated\b/.test(t))   out.add("soggy");
  if (/\bmoist\b|\bdamp\b|\bmoisture[- ]?retentive\b/.test(t))      out.add("normal_poor");
  if (/\bwell[- ]?drained\b|\baverage\s+moisture\b|\bevenly\s+moist\b/.test(t)) out.add("normal_well");
  if (/\bdrought[- ]?tolerant\b|\bdry\b|\bxeric\b/.test(t))         out.add("slightly_dry");
  if (/\barid\b|\bdesert\b|\bsucculent\b/.test(t))                  out.add("arid");
  return out.size ? [...out] : null;
}

function parseAcidity(text) {
  if (!text) return null;
  const t = text.toLowerCase();
  const out = new Set();
  if (/\bericaceous\b|\bvery\s+acidic?\b|\bstrongly\s+acidic?\b/.test(t)) out.add("very_acidic");
  if (/\bacidic?\b|\bacid[- ]loving\b|\blow\s+pH\b/.test(t))             out.add("mildly_acidic");
  if (/\bneutral\s+pH\b|\bneutral\s+soil\b|\bneutral\b/.test(t))         out.add("neutral");
  if (/\bmildly\s+alkaline\b|\bslightly\s+alkaline\b/.test(t))           out.add("mildly_alkaline");
  if (/\balkaline\b|\bchalky\b|\blime[- ]?loving\b|\bcalcareous\b/.test(t)) out.add("mildly_alkaline");
  if (/\bstrongly\s+alkaline\b|\bvery\s+alkaline\b/.test(t))             out.add("very_alkaline");
  return out.size ? [...out] : null;
}

function parseSeedDepthMm(text) {
  if (!text) return null;
  // "sow 5 mm deep" / "1.5 cm deep" / "2 cm deep"
  let m = text.match(/(\d+(?:\.\d+)?)\s*mm\s+deep/i);
  if (m) return Math.round(parseFloat(m[1]));
  m = text.match(/(\d+(?:\.\d+)?)\s*cm\s+deep/i);
  if (m) return Math.round(parseFloat(m[1]) * 10);
  return null;
}

function parseGerminationTempC(text) {
  if (!text) return null;
  // "at 18-22°C" / "at 21°C" / "18°C to 24°C"
  const m = text.match(/(\d{2})\s*(?:[°º]?C|degrees)/i);
  if (!m) return null;
  const v = parseInt(m[1], 10);
  return (v >= 5 && v <= 35) ? v : null;
}

function parseGerminationDays(text) {
  if (!text) return null;
  // "7-14 days" / "5–10 days" / "14 to 21 days"
  const m = text.match(/(\d{1,3})\s*(?:[-–—]|to)\s*(\d{1,3})\s*days?/i);
  if (m) return `${m[1]}–${m[2]}`;
  const single = text.match(/(\d{1,3})\s*days?/i);
  if (single) return single[1];
  return null;
}

function parseLightForGermination(text) {
  if (!text) return null;
  const t = text.toLowerCase();
  if (/\blight\s+required\b|\bsurface[- ]sow\b|\bneeds\s+light/.test(t)) return "Light required (surface sow)";
  if (/\bdark\b.*germin|\bcover\s+seeds?\s+(?:well|fully)/.test(t))      return "Cover seed (excludes light)";
  if (/\beither\b|\beither\s+dark\s+or\s+light/.test(t))                  return "Either";
  return null;
}

function parseHeight(text) {
  if (!text) return null;
  // "grows to 60 cm" / "reaches 1.2 m" / "up to 200 cm tall".
  const cm = text.match(/(\d{2,4})\s*cm\b/i);
  if (cm) return parseInt(cm[1], 10);
  const m  = text.match(/(\d+(?:\.\d+)?)\s*m\b/i);
  if (m)   return Math.round(parseFloat(m[1]) * 100);
  return null;
}

// ── Wikimedia Commons: photographic image URL from the Wikidata file value ───
//
// Wikidata `wdt:P18` already returns a Commons file URL. We just want to make
// sure it's a photo, not an illustration. Commons file extensions are .jpg/
// .jpeg/.png/.tif/.tiff/.svg — we reject .svg (drawings).

function isPhotographic(url) {
  if (!url) return false;
  // Strip a `?width=` query so the extension test still works after we
  // append a thumbnail size to the Commons URL.
  const u = url.split("?")[0].toLowerCase();
  if (!/\.(jpg|jpeg|png|tif|tiff)$/.test(u)) return false;
  // Strip known illustration / engraving / botanical plate markers. The
  // Wikidata default image for a species is *often* a 19th-century plate;
  // we'd rather have no image than ship a drawing in a photo tile. The
  // gardener can swap in a photographic URL by editing library.json.
  const illust = [
    "medizinal-pflanzen", "köhler", "kohler", "thome",
    "illustration", "illustr.", "drawing", "engraving",
    "watercolor", "watercolour", "lithograph",
    "botanical_plate", "_plate_", " plate ", "%20plate%20",
    "icones", "flora_", "tab.", "%20tab%20",
    "sketch", "pen_and_ink", "woodcut",
    ".svg",
  ];
  return !illust.some(marker => u.includes(marker));
}

// ── Slug + ID helpers ────────────────────────────────────────────────────────

function slugify(s) {
  return s
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function genusOf(latin) {
  return latin.split(/\s+/)[0]; // "Lavandula angustifolia" → "Lavandula"
}

// ── Build raw record from a Wikidata row ─────────────────────────────────────

async function buildRawRecord(row, ix) {
  // Always use the Latin binomial for Wikipedia lookups — that's the canonical
  // article title for taxa. The pretty `label` may be a common name that
  // doesn't have its own article.
  const summary = await fetchWikipediaSummary(row.latin);

  const family   = row.familyLabel ?? null;
  const familyDefaults = (family && FAMILY_DEFAULTS[family]) ?? null;

  return {
    id: slugify(row.latin),
    name: row.label,
    latin: row.latin,
    qid: row.qid,
    genus: genusOf(row.latin),
    family,
    type: parsePlantType(summary, familyDefaults?.type ?? null),
    heightCm: parseHeight(summary),
    colorHex: null,
    bloomMonths: parseBloomMonths(summary),
    sowIndoorMonths: [],
    sowDirectMonths: [],
    transplantMonths: [],
    harvestMonths: [],
    preferredSoil: parseSoil(summary),
    preferredSunlight: parseSunlight(summary),
    preferredAcidity: parseAcidity(summary),
    preferredWetness: parseWetness(summary),
    seedDepthMm: parseSeedDepthMm(summary),
    germinationTempC: parseGerminationTempC(summary),
    germinationDays: parseGerminationDays(summary),
    lightForGermination: parseLightForGermination(summary),
    // Wikipedia narrative now lives on `description`; `growersTips` is
    // populated from FAMILY_DEFAULTS during inheritance as bullet text.
    description: summary ? summary.slice(0, 600).trim() : "",
    growersTips: "",
    germinationRequirements: "",
    companions: [],
    access: pickAccessTier(ix),
    imageUrl: isPhotographic(row.imageUrl) ? row.imageUrl : null,
  };
}

// Free tier: first 50 results. Pro tier: 51..200. Pack-edible: vegetables/herbs.
// Pack-exotic: anything in Orchidaceae or non-UK families. Otherwise pro.
function pickAccessTier(ix) {
  if (ix < 50) return "free";
  return "pro";
}

// ── Inheritance ──────────────────────────────────────────────────────────────
//
// For each genus and family, aggregate the union of values found across all
// member records. Then for each record, fill any null/empty field from genus
// → family → generic defaults.

function aggregateByKey(records, keyFn) {
  const agg = new Map(); // key -> { field: Set/Number aggregations }
  for (const r of records) {
    const k = keyFn(r);
    if (!k) continue;
    const cur = agg.get(k) ?? {
      type: null,
      preferredSoil: new Set(),
      preferredSunlight: new Set(),
      preferredAcidity: new Set(),
      preferredWetness: new Set(),
      bloomMonths: new Set(),
      sowIndoorMonths: new Set(),
      sowDirectMonths: new Set(),
      transplantMonths: new Set(),
      harvestMonths: new Set(),
      heightSamples: [],
      colorHex: null,
    };
    cur.type ??= r.type;
    (r.preferredSoil ?? []).forEach(s => cur.preferredSoil.add(s));
    (r.preferredSunlight ?? []).forEach(s => cur.preferredSunlight.add(s));
    (r.preferredAcidity ?? []).forEach(s => cur.preferredAcidity.add(s));
    (r.preferredWetness ?? []).forEach(s => cur.preferredWetness.add(s));
    (r.bloomMonths ?? []).forEach(m => cur.bloomMonths.add(m));
    (r.sowIndoorMonths ?? []).forEach(m => cur.sowIndoorMonths.add(m));
    (r.sowDirectMonths ?? []).forEach(m => cur.sowDirectMonths.add(m));
    (r.transplantMonths ?? []).forEach(m => cur.transplantMonths.add(m));
    (r.harvestMonths ?? []).forEach(m => cur.harvestMonths.add(m));
    if (r.heightCm != null) cur.heightSamples.push(r.heightCm);
    cur.colorHex ??= r.colorHex;
    agg.set(k, cur);
  }
  return agg;
}

function inherit(records) {
  const byGenus  = aggregateByKey(records, r => r.genus);
  const byFamily = aggregateByKey(records, r => r.family);

  function pickFrom(field, ...sources) {
    for (const s of sources) {
      if (Array.isArray(s) && s.length) return s;
      if (typeof s === "string" && s.length) return s;
      if (typeof s === "number" && !isNaN(s)) return s;
    }
    return null;
  }

  return records.map(r => {
    const genus  = byGenus.get(r.genus);
    const family = byFamily.get(r.family);
    const famD   = FAMILY_DEFAULTS[r.family] ?? null;
    const gen    = GENERIC_DEFAULT;

    const inherited = {
      ...r,
      type: r.type
        ?? genus?.type
        ?? family?.type
        ?? famD?.type
        ?? gen.type,
      preferredSoil: pickFrom(
        "preferredSoil",
        r.preferredSoil ?? null,
        genus && [...genus.preferredSoil],
        family && [...family.preferredSoil],
        famD?.preferredSoil,
        gen.preferredSoil,
      ) || [],
      preferredSunlight: pickFrom(
        "preferredSunlight",
        r.preferredSunlight ?? null,
        genus && [...genus.preferredSunlight],
        family && [...family.preferredSunlight],
        famD?.preferredSunlight,
        gen.preferredSunlight,
      ) || [],
      preferredAcidity: pickFrom(
        "preferredAcidity",
        r.preferredAcidity ?? null,
        genus && [...genus.preferredAcidity],
        family && [...family.preferredAcidity],
        famD?.preferredAcidity,
        gen.preferredAcidity,
      ) || [],
      preferredWetness: pickFrom(
        "preferredWetness",
        r.preferredWetness ?? null,
        genus && [...genus.preferredWetness],
        family && [...family.preferredWetness],
        famD?.preferredWetness,
        gen.preferredWetness,
      ) || [],
      growersTips: (famD?.tips ?? gen.tips ?? []).join("\n"),
      bloomMonths: pickFrom(
        "bloomMonths",
        r.bloomMonths ?? null,
        genus && [...genus.bloomMonths].sort((a,b)=>a-b),
        family && [...family.bloomMonths].sort((a,b)=>a-b),
        famD?.bloomMonths,
        gen.bloomMonths,
      ) || [],
      sowIndoorMonths: pickFrom(
        "sowIndoorMonths",
        (r.sowIndoorMonths?.length ? r.sowIndoorMonths : null),
        genus && [...genus.sowIndoorMonths].sort((a,b)=>a-b),
        family && [...family.sowIndoorMonths].sort((a,b)=>a-b),
        famD?.sowIndoorMonths,
        gen.sowIndoorMonths,
      ) || [],
      sowDirectMonths: pickFrom(
        "sowDirectMonths",
        (r.sowDirectMonths?.length ? r.sowDirectMonths : null),
        genus && [...genus.sowDirectMonths].sort((a,b)=>a-b),
        family && [...family.sowDirectMonths].sort((a,b)=>a-b),
        famD?.sowDirectMonths,
        gen.sowDirectMonths,
      ) || [],
      transplantMonths: pickFrom(
        "transplantMonths",
        (r.transplantMonths?.length ? r.transplantMonths : null),
        genus && [...genus.transplantMonths].sort((a,b)=>a-b),
        family && [...family.transplantMonths].sort((a,b)=>a-b),
        famD?.transplantMonths,
        gen.transplantMonths,
      ) || [],
      harvestMonths: pickFrom(
        "harvestMonths",
        (r.harvestMonths?.length ? r.harvestMonths : null),
        genus && [...genus.harvestMonths].sort((a,b)=>a-b),
        family && [...family.harvestMonths].sort((a,b)=>a-b),
        famD?.harvestMonths,
        gen.harvestMonths,
      ) || [],
      heightCm: r.heightCm
        ?? (genus?.heightSamples?.length ? Math.round(genus.heightSamples.reduce((a,b)=>a+b,0)/genus.heightSamples.length) : null)
        ?? null,
      colorHex: r.colorHex
        ?? genus?.colorHex
        ?? family?.colorHex
        ?? famD?.colorHex
        ?? gen.colorHex,
    };
    return inherited;
  });
}

// ── Validate (skip records still missing required fields) ────────────────────

function validate(records) {
  const kept = [];
  const dropped = [];
  for (const r of records) {
    const ok = r.id
      && r.name
      && r.latin
      && r.type && PLANT_TYPES.includes(r.type)
      && Array.isArray(r.preferredSoil) && r.preferredSoil.length
      && Array.isArray(r.preferredSunlight) && r.preferredSunlight.length
      && Array.isArray(r.bloomMonths) && r.bloomMonths.length;
    if (ok) kept.push(r);
    else dropped.push(r);
  }
  return { kept, dropped };
}

// ── Trim record to LIBRARY schema (drop scratch fields) ──────────────────────

function toLibraryItem(r) {
  const item = {
    id: r.id,
    name: r.name,
    latin: r.latin,
    type: r.type,
    bloomMonths: r.bloomMonths,
    sowIndoorMonths: r.sowIndoorMonths ?? [],
    sowDirectMonths: r.sowDirectMonths ?? [],
    transplantMonths: r.transplantMonths ?? [],
    harvestMonths: r.harvestMonths ?? [],
    preferredSoil: r.preferredSoil,
    preferredSunlight: r.preferredSunlight,
    growersTips: r.growersTips ?? "",
    germinationRequirements: r.germinationRequirements ?? "",
    companions: r.companions ?? [],
    access: r.access ?? "free",
  };
  if (r.heightCm != null) item.heightCm = r.heightCm;
  if (r.colorHex)         item.colorHex = r.colorHex;
  if (r.imageUrl)         item.imageUrl = r.imageUrl;
  if (Array.isArray(r.preferredAcidity) && r.preferredAcidity.length) {
    item.preferredAcidity = r.preferredAcidity;
  }
  if (Array.isArray(r.preferredWetness) && r.preferredWetness.length) {
    item.preferredWetness = r.preferredWetness;
  }
  if (r.description) item.description = r.description;
  if (r.seedDepthMm != null)        item.seedDepthMm = r.seedDepthMm;
  if (r.germinationTempC != null)   item.germinationTempC = r.germinationTempC;
  if (r.germinationDays)            item.germinationDays = r.germinationDays;
  if (r.lightForGermination)        item.lightForGermination = r.lightForGermination;
  return item;
}

// ── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log("Blooming Marvellous — plant ingest");
  console.log(`Output: ${OUT_PATH}${args.dryRun ? " (dry run)" : ""}`);
  if (args.limit) console.log(`Limit:  ${args.limit}`);

  const rows = await fetchAgmList(args.limit);
  if (rows.length === 0) {
    const msg = "No rows returned from Wikidata.";
    if (args.softFail) {
      console.warn(`⚠️ ${msg} --soft-fail set — leaving existing backend/data/library.json untouched.`);
      return;
    }
    console.error(`${msg} Aborting.`);
    process.exit(1);
  }

  console.log(`→ Wikipedia summaries for ${rows.length} taxa…`);
  const raw = [];
  let i = 0;
  for (const row of rows) {
    raw.push(await buildRawRecord(row, i));
    i++;
    if (args.verbose && i % 25 === 0) console.log(`  ${i}/${rows.length}`);
  }

  console.log("→ Applying cultivar → genus → family inheritance…");
  const inherited = inherit(raw);

  // Per-cultivar tips from Gemini (optional). Runs after inheritance so the
  // prompt can include the resolved family label even when Wikidata didn't
  // provide one directly.
  await enrichTips(inherited);

  const { kept, dropped } = validate(inherited);
  console.log(`✓ ${kept.length} plants ready, ${dropped.length} dropped (still missing required fields after inheritance).`);

  const payload = {
    version: 2,
    generated: new Date().toISOString(),
    source: "wikidata-rhs-agm + wikipedia + commons + inheritance",
    items: kept.map(toLibraryItem),
  };

  if (args.dryRun) {
    console.log("→ Dry run — sample item:");
    console.log(JSON.stringify(payload.items[0], null, 2));
    console.log(`\nTotal: ${payload.items.length} plants. Use --out to specify file or drop --dry-run to write to ${OUT_PATH}.`);
    return;
  }

  writeFileSync(OUT_PATH, JSON.stringify(payload, null, 2) + "\n");
  console.log(`✓ Wrote ${OUT_PATH} (${payload.items.length} items).`);
  console.log(`\nNext step: run \`node scripts/seed-content.mjs --env development\` (and prod) to publish to S3.`);
  console.log(`The deploy script (./scripts/deploy.sh <env>) runs seed-content automatically.`);
}

main().catch(err => {
  console.error("Ingest failed:", err);
  if (args.softFail) {
    console.warn("⚠️ --soft-fail set — leaving existing backend/data/library.json untouched and exiting 0 so the surrounding deploy continues.");
    process.exit(0);
  }
  process.exit(1);
});
