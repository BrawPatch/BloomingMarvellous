#!/usr/bin/env node
/**
 * add-bedding-plants.mjs — hand-authored UK bedding-plant canon.
 *
 * The original SPARQL ingest is excellent for botanical species but the
 * UK garden centre canon — Petunia 'Surfinia', Pelargonium 'Rocky Mountain
 * White', Viola 'Matrix', Tagetes 'Bonanza' — is almost entirely commercial
 * hybrids absent from Wikidata. This script seeds them directly so the
 * gallery covers what gardeners actually buy in March–May for their borders,
 * baskets and patio pots.
 *
 * Each parent species gets a curated stub (type, family, default bloom
 * months, soil/sun/wetness preferences and a UK-flavoured grower's-tips
 * paragraph), then 5–10 named cultivars inherit those defaults with their
 * own colour, height and spread overrides.
 *
 * All bedding rows are tagged as half-hardy annuals (`type: "annual"`) since
 * that's how UK gardeners treat them, regardless of the species' tropical
 * perenniality. The top-12 species sit in the free tier so the broadest
 * audience gets the bedding upgrade; the rest land in `pro`.
 *
 * Idempotent: re-running skips any cultivar id already in the library.
 *
 * Usage:
 *   node scripts/add-bedding-plants.mjs            # writes in place
 *   node scripts/add-bedding-plants.mjs --dry-run
 */

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const LIBRARY = fileURLToPath(new URL("../data/library.json", import.meta.url));
const dryRun  = process.argv.includes("--dry-run");

function slugify(s) {
  return s.toLowerCase()
          .replace(/[×]/g, "x")
          .replace(/['''']/g, "")
          .replace(/[^a-z0-9]+/g, "-")
          .replace(/^-+|-+$/g, "");
}

// ── Parent species stubs ─────────────────────────────────────────────────────
//
// Each parent provides the default field set every cultivar inherits.
// `freeTier: true` puts both the parent and its cultivars in the free pool
// so the broadest audience gets the most popular bedding picks. Everything
// else lands in pro.

const BEDDING_PARENTS = {
  "Petunia × atkinsiana": {
    common: "Petunia", type: "annual", family: "Solanaceae", freeTier: true,
    height: 30, spread: 45, hex: "#c477b5",
    bloomMonths: [5, 6, 7, 8, 9, 10],
    sowIndoorMonths: [2, 3], transplantMonths: [5, 6],
    preferredSoil: ["loam", "sandy"],
    preferredSunlight: ["sunny_always", "sunny_pm"],
    preferredAcidity: ["neutral", "mildly_alkaline"],
    preferredWetness: ["normal_well"],
    tips: [
      "Plant out only after the last frost — typically late May in the UK.",
      "Deadhead spent flowers weekly to keep the show going until October.",
      "Feed weekly with a high-potash tomato feed once flowering starts.",
      "Pinch out trailing types early to encourage bushier growth.",
      "Surfinia and Wave types perform best in hanging baskets — water daily in summer.",
    ],
  },
  "Pelargonium × hortorum": {
    common: "Zonal Pelargonium", type: "annual", family: "Geraniaceae", freeTier: true,
    height: 40, spread: 35, hex: "#d44c5a",
    bloomMonths: [5, 6, 7, 8, 9, 10],
    sowIndoorMonths: [1, 2], transplantMonths: [5, 6],
    preferredSoil: ["loam", "sandy"],
    preferredSunlight: ["sunny_always", "sunny_pm"],
    preferredAcidity: ["neutral", "mildly_alkaline"],
    preferredWetness: ["normal_well", "slightly_dry"],
    tips: [
      "Overwinter indoors on a frost-free windowsill — they're tender perennials.",
      "Let the compost dry slightly between waterings to prevent rot.",
      "Cut back by a third in October before bringing plants indoors.",
      "Plant out after the last frost — they sulk if temperatures dip below 10 °C.",
      "Pinch off faded flower heads at the base of the stalk to keep blooms coming.",
    ],
  },
  "Pelargonium peltatum": {
    common: "Ivy-leaved Pelargonium", type: "annual", family: "Geraniaceae", freeTier: false,
    height: 35, spread: 60, hex: "#e070a0",
    bloomMonths: [5, 6, 7, 8, 9, 10],
    sowIndoorMonths: [1, 2], transplantMonths: [5, 6],
    preferredSoil: ["loam", "sandy"],
    preferredSunlight: ["sunny_always", "sunny_pm"],
    preferredAcidity: ["neutral", "mildly_alkaline"],
    preferredWetness: ["normal_well", "slightly_dry"],
    tips: [
      "Ideal for window boxes and hanging baskets — let the stems trail naturally.",
      "Less thirsty than zonal types; let compost dry between waterings.",
      "Plant alongside trailing lobelia and bacopa for a classic basket combination.",
      "Avoid overhead watering to prevent petal staining and disease.",
      "Bring indoors before the first frost to overwinter on a cool windowsill.",
    ],
  },
  "Viola × wittrockiana": {
    common: "Pansy", type: "annual", family: "Violaceae", freeTier: true,
    height: 20, spread: 25, hex: "#7a4a9c",
    bloomMonths: [10, 11, 12, 1, 2, 3, 4, 5],
    sowIndoorMonths: [6, 7], transplantMonths: [9, 10],
    preferredSoil: ["loam"],
    preferredSunlight: ["sunny_always", "sunny_pm"],
    preferredAcidity: ["neutral"],
    preferredWetness: ["normal_well"],
    tips: [
      "Plant in September for autumn-to-spring colour through the British winter.",
      "Deadhead regularly — pansies sulk into seed-setting if you don't.",
      "Tolerates light frost beautifully; just protect from prolonged hard freezes.",
      "Use winter-flowering varieties (Matrix, Delta) for the coldest months.",
      "Lift and replace in late May when summer bedding goes in.",
    ],
  },
  "Viola cornuta": {
    common: "Horned Viola", type: "annual", family: "Violaceae", freeTier: false,
    height: 15, spread: 20, hex: "#9a5ab8",
    bloomMonths: [4, 5, 6, 7, 8, 9, 10],
    sowIndoorMonths: [2, 3], transplantMonths: [4, 5],
    preferredSoil: ["loam"],
    preferredSunlight: ["sunny_pm", "sunny_am"],
    preferredAcidity: ["neutral"],
    preferredWetness: ["normal_well"],
    tips: [
      "More heat-tolerant than pansies — keeps blooming through July and August.",
      "Smaller-flowered cousins of pansies, perfect for the front of borders.",
      "Self-seed freely; let some go to seed for next year's surprises.",
      "Sorbet and Penny series are bred for compact, weather-resistant displays.",
      "Cut back by a third in midsummer to refresh the display.",
    ],
  },
  "Begonia semperflorens": {
    common: "Wax Begonia", type: "annual", family: "Begoniaceae", freeTier: true,
    height: 20, spread: 25, hex: "#f4a8b8",
    bloomMonths: [5, 6, 7, 8, 9, 10],
    sowIndoorMonths: [1, 2], transplantMonths: [5, 6],
    preferredSoil: ["loam"],
    preferredSunlight: ["sunny_pm", "shaded_always", "sunny_am"],
    preferredAcidity: ["neutral", "mildly_acidic"],
    preferredWetness: ["normal_well"],
    tips: [
      "One of the few bedding plants happy in light shade — ideal for north-facing borders.",
      "Bronze-leaved varieties (Cocktail series) cope with more sun.",
      "Tolerates dry spells better than most bedding plants — perfect for forgetful waterers.",
      "Sow seed in January for transplants ready in late May.",
      "Self-cleaning — no deadheading needed for a tidy display.",
    ],
  },
  "Begonia × tuberhybrida": {
    common: "Tuberous Begonia", type: "annual", family: "Begoniaceae", freeTier: false,
    height: 30, spread: 30, hex: "#f06a4a",
    bloomMonths: [6, 7, 8, 9, 10],
    sowIndoorMonths: [2, 3], transplantMonths: [5, 6],
    preferredSoil: ["loam", "peaty"],
    preferredSunlight: ["sunny_pm", "shaded_always", "sunny_am"],
    preferredAcidity: ["neutral", "mildly_acidic"],
    preferredWetness: ["normal_well"],
    tips: [
      "Start tubers in February-March on a warm windowsill, hollow-side up.",
      "Pendula types cascade beautifully from hanging baskets and tall pots.",
      "Lift tubers after the first frost, dry off and store cool over winter.",
      "Feed weekly with a high-potash feed once buds appear.",
      "Snap off the small female flowers either side of the large male bloom for show-quality displays.",
    ],
  },
  "Impatiens walleriana": {
    common: "Busy Lizzie", type: "annual", family: "Balsaminaceae", freeTier: false,
    height: 25, spread: 25, hex: "#e4577a",
    bloomMonths: [5, 6, 7, 8, 9, 10],
    sowIndoorMonths: [2, 3], transplantMonths: [5, 6],
    preferredSoil: ["loam"],
    preferredSunlight: ["sunny_pm", "shaded_always"],
    preferredAcidity: ["neutral", "mildly_acidic"],
    preferredWetness: ["normal_well", "normal_poor"],
    tips: [
      "Look for downy-mildew-resistant Beacon and Imara series — older varieties suffer.",
      "Thrives in shaded borders where most bedding plants sulk.",
      "Keep compost evenly moist — wilting plants soon shed their buds.",
      "Self-cleans nicely; no deadheading required.",
      "Pinch out the growing tips at planting to encourage bushier growth.",
    ],
  },
  "Impatiens hawkeri": {
    common: "New Guinea Impatiens", type: "annual", family: "Balsaminaceae", freeTier: false,
    height: 35, spread: 35, hex: "#e84090",
    bloomMonths: [5, 6, 7, 8, 9, 10],
    sowIndoorMonths: [2, 3], transplantMonths: [5, 6],
    preferredSoil: ["loam"],
    preferredSunlight: ["sunny_pm", "sunny_am"],
    preferredAcidity: ["neutral", "mildly_acidic"],
    preferredWetness: ["normal_well"],
    tips: [
      "SunPatiens varieties handle full sun — most other Impatiens prefer partial shade.",
      "Resistant to the downy mildew that wiped out classic Busy Lizzies.",
      "Larger flowers and bolder foliage than walleriana — great as a feature plant.",
      "Don't let compost dry out — drought-stressed plants flop dramatically.",
      "Pinch back leggy stems mid-summer for a fresh autumn display.",
    ],
  },
  "Lobelia erinus": {
    common: "Trailing Lobelia", type: "annual", family: "Campanulaceae", freeTier: true,
    height: 15, spread: 20, hex: "#3a5fa8",
    bloomMonths: [5, 6, 7, 8, 9, 10],
    sowIndoorMonths: [1, 2], transplantMonths: [5, 6],
    preferredSoil: ["loam"],
    preferredSunlight: ["sunny_always", "sunny_pm"],
    preferredAcidity: ["neutral"],
    preferredWetness: ["normal_well"],
    tips: [
      "Sow in tiny clumps and prick out as multiples — single seedlings are too small to handle.",
      "Cascade types trail spectacularly from baskets; Riviera series stays compact.",
      "Trim back hard in late July for a fresh autumn flush.",
      "Don't let baskets dry out — lobelia is the first to wilt and the slowest to bounce back.",
      "Combines beautifully with white alyssum and yellow bidens.",
    ],
  },
  "Antirrhinum majus": {
    common: "Snapdragon", type: "annual", family: "Plantaginaceae", freeTier: true,
    height: 60, spread: 30, hex: "#e85090",
    bloomMonths: [6, 7, 8, 9, 10],
    sowIndoorMonths: [2, 3], transplantMonths: [5, 6],
    preferredSoil: ["loam", "sandy"],
    preferredSunlight: ["sunny_always", "sunny_pm"],
    preferredAcidity: ["neutral", "mildly_alkaline"],
    preferredWetness: ["normal_well"],
    tips: [
      "Pinch out the leading shoot at six weeks to encourage side branching.",
      "Stake taller cut-flower varieties — Rocket and Liberty series get top-heavy.",
      "Deadhead spent spikes at the base for repeat blooms into October.",
      "Mild UK winters often see snapdragons survive as short-lived perennials.",
      "Watch for rust on the underside of leaves — pick off affected foliage and improve airflow.",
    ],
  },
  "Tagetes patula": {
    common: "French Marigold", type: "annual", family: "Asteraceae", freeTier: true,
    height: 30, spread: 30, hex: "#f5a020",
    bloomMonths: [6, 7, 8, 9, 10],
    sowIndoorMonths: [3, 4], sowDirectMonths: [5], transplantMonths: [5, 6],
    preferredSoil: ["loam", "sandy"],
    preferredSunlight: ["sunny_always"],
    preferredAcidity: ["neutral"],
    preferredWetness: ["normal_well"],
    tips: [
      "Brilliant companion plant — deters whitefly from tomatoes and beans.",
      "Sow direct in May once soil is warm; deadhead regularly for non-stop colour.",
      "French marigolds are bushier and rain-tolerant than African (T. erecta) types.",
      "Pinch out the central bud after transplanting to bulk up the plant.",
      "Save seed from open-pollinated varieties — F1 hybrids won't come true.",
    ],
  },
  "Tagetes erecta": {
    common: "African Marigold", type: "annual", family: "Asteraceae", freeTier: false,
    height: 70, spread: 40, hex: "#f5b53a",
    bloomMonths: [7, 8, 9, 10],
    sowIndoorMonths: [3, 4], transplantMonths: [5, 6],
    preferredSoil: ["loam"],
    preferredSunlight: ["sunny_always"],
    preferredAcidity: ["neutral"],
    preferredWetness: ["normal_well"],
    tips: [
      "Larger pompon flowers than French marigolds — Antigua and Inca series are reliable.",
      "Pinch tips early to prevent the lanky 'Eiffel Tower' habit.",
      "Big blooms can collapse after summer downpours — stake or choose compact F1s.",
      "Excellent cut flower — lasts 10+ days in the vase.",
      "Avoid overhead watering to stop botrytis on the dense flower heads.",
    ],
  },
  "Calendula officinalis": {
    common: "Pot Marigold", type: "annual", family: "Asteraceae", freeTier: true,
    height: 50, spread: 35, hex: "#f59020",
    bloomMonths: [5, 6, 7, 8, 9, 10],
    sowIndoorMonths: [3], sowDirectMonths: [4, 5, 8, 9], transplantMonths: [5],
    preferredSoil: ["loam", "sandy"],
    preferredSunlight: ["sunny_always", "sunny_pm"],
    preferredAcidity: ["neutral"],
    preferredWetness: ["normal_well"],
    tips: [
      "Direct-sow in autumn (Sep) for the earliest spring flowers next year.",
      "Edible petals brighten salads and rice dishes — the original 'poor man's saffron'.",
      "Deadhead constantly or it sets seed within a fortnight and stops flowering.",
      "Self-seeds reliably — let one plant set seed for next year's freebies.",
      "Combines beautifully with the blue spires of borage and cornflower.",
    ],
  },
  "Salvia splendens": {
    common: "Scarlet Sage", type: "annual", family: "Lamiaceae", freeTier: false,
    height: 40, spread: 30, hex: "#d8262a",
    bloomMonths: [6, 7, 8, 9, 10],
    sowIndoorMonths: [2, 3], transplantMonths: [5, 6],
    preferredSoil: ["loam"],
    preferredSunlight: ["sunny_always", "sunny_pm"],
    preferredAcidity: ["neutral", "mildly_acidic"],
    preferredWetness: ["normal_well"],
    tips: [
      "Plant out only when nights are reliably above 10 °C — they hate cold soil.",
      "Vista and Sizzler series are bred for shorter, neater plants than older heritage strains.",
      "Pinch out faded flower spikes at the base to keep new ones coming.",
      "Mulch around plants to keep roots cool and moist during heat waves.",
      "Combines stunningly with silver-leaved senecio and white lobelia.",
    ],
  },
  "Salvia farinacea": {
    common: "Mealy-cup Sage", type: "annual", family: "Lamiaceae", freeTier: false,
    height: 50, spread: 30, hex: "#4a55a8",
    bloomMonths: [6, 7, 8, 9, 10],
    sowIndoorMonths: [2, 3], transplantMonths: [5, 6],
    preferredSoil: ["loam", "sandy"],
    preferredSunlight: ["sunny_always", "sunny_pm"],
    preferredAcidity: ["neutral"],
    preferredWetness: ["normal_well"],
    tips: [
      "Tall blue spikes punctuate mixed borders beautifully — a far cry from the formal red salvias.",
      "Victoria Blue is the classic UK garden-centre cultivar — reliable and statuesque.",
      "Pollinator magnet — bees, butterflies and hoverflies all love it.",
      "Cuts well for the vase; pick when half the florets on a spike are open.",
      "Treated as half-hardy in the UK but often overwinters in mild south-coast gardens.",
    ],
  },
  "Nicotiana × sanderae": {
    common: "Flowering Tobacco", type: "annual", family: "Solanaceae", freeTier: false,
    height: 70, spread: 30, hex: "#e8a8c0",
    bloomMonths: [6, 7, 8, 9],
    sowIndoorMonths: [2, 3], transplantMonths: [5, 6],
    preferredSoil: ["loam"],
    preferredSunlight: ["sunny_always", "sunny_pm"],
    preferredAcidity: ["neutral", "mildly_acidic"],
    preferredWetness: ["normal_well"],
    tips: [
      "Evening fragrance is the headline feature — plant near patios and back-door beds.",
      "Domino and Perfume series stay neatly upright; older N. alata flops without staking.",
      "Self-seeds prolifically — pull seedlings ruthlessly if you don't want a takeover.",
      "Sow seed on the compost surface — light is needed for germination.",
      "Watch for the lily beetle's tobacco-eating cousin in southern gardens.",
    ],
  },
  "Verbena × hybrida": {
    common: "Garden Verbena", type: "annual", family: "Verbenaceae", freeTier: false,
    height: 25, spread: 35, hex: "#a8408a",
    bloomMonths: [5, 6, 7, 8, 9, 10],
    sowIndoorMonths: [1, 2], transplantMonths: [5, 6],
    preferredSoil: ["loam", "sandy"],
    preferredSunlight: ["sunny_always"],
    preferredAcidity: ["neutral", "mildly_alkaline"],
    preferredWetness: ["normal_well", "slightly_dry"],
    tips: [
      "Loves the heat — gives its best in baking, well-drained spots.",
      "Trim back by a third in mid-July to refresh the display.",
      "Mildew can strike in damp summers — improve airflow and avoid overhead watering.",
      "Bonariensis types (tall, see-through) are a different beast — for back-of-border drama.",
      "Quartz and Lascar series are bred for vigorous, weather-tolerant bedding displays.",
    ],
  },
  "Zinnia elegans": {
    common: "Zinnia", type: "annual", family: "Asteraceae", freeTier: false,
    height: 60, spread: 30, hex: "#e85a40",
    bloomMonths: [7, 8, 9, 10],
    sowIndoorMonths: [3, 4], sowDirectMonths: [5], transplantMonths: [5, 6],
    preferredSoil: ["loam"],
    preferredSunlight: ["sunny_always"],
    preferredAcidity: ["neutral"],
    preferredWetness: ["normal_well"],
    tips: [
      "Direct-sow in late May once soil is reliably warm — they resent transplanting.",
      "Benary's Giant series produces 10 cm dahlia-like blooms — peerless cut flowers.",
      "Pinch out the leading shoot at 30 cm tall to encourage branching.",
      "Avoid wetting the foliage — powdery mildew is the main pest.",
      "Cut for the vase when the petal-touch test feels firm — wobbly stems mean too early.",
    ],
  },
  "Cosmos bipinnatus": {
    common: "Mexican Aster", type: "annual", family: "Asteraceae", freeTier: true,
    height: 90, spread: 40, hex: "#e8a8b8",
    bloomMonths: [6, 7, 8, 9, 10],
    sowIndoorMonths: [3, 4], sowDirectMonths: [4, 5], transplantMonths: [5],
    preferredSoil: ["loam", "sandy"],
    preferredSunlight: ["sunny_always", "sunny_pm"],
    preferredAcidity: ["neutral"],
    preferredWetness: ["normal_well"],
    tips: [
      "Don't over-feed — rich soil grows leaves at the expense of flowers.",
      "Pinch out at 20 cm to encourage bushy, multi-stemmed plants.",
      "Sonata series stays under 60 cm; Sensation series towers to 1.2 m.",
      "Deadhead constantly — let one plant set seed for self-sowing next year.",
      "Brilliant cut flower; cut when buds are just opening for longest vase life.",
    ],
  },
  "Cosmos sulphureus": {
    common: "Yellow Cosmos", type: "annual", family: "Asteraceae", freeTier: false,
    height: 70, spread: 35, hex: "#f5a040",
    bloomMonths: [6, 7, 8, 9, 10],
    sowIndoorMonths: [3, 4], sowDirectMonths: [4, 5], transplantMonths: [5],
    preferredSoil: ["loam", "sandy"],
    preferredSunlight: ["sunny_always"],
    preferredAcidity: ["neutral"],
    preferredWetness: ["normal_well"],
    tips: [
      "Warmer-toned cousin of C. bipinnatus — oranges, yellows and reds rather than pinks.",
      "More heat-tolerant and drought-resistant than C. bipinnatus.",
      "Bright Lights and Cosmic series stay compact for the front of borders.",
      "Self-seeds; weed out unwanted seedlings in April.",
      "Pollinator favourite — especially honeybees and hoverflies.",
    ],
  },
  "Cleome hassleriana": {
    common: "Spider Flower", type: "annual", family: "Cleomaceae", freeTier: false,
    height: 120, spread: 50, hex: "#e8a0c0",
    bloomMonths: [7, 8, 9, 10],
    sowIndoorMonths: [2, 3], transplantMonths: [5, 6],
    preferredSoil: ["loam", "sandy"],
    preferredSunlight: ["sunny_always"],
    preferredAcidity: ["neutral"],
    preferredWetness: ["normal_well"],
    tips: [
      "Striking back-of-border architectural plant — long whiskery seed pods follow the flowers.",
      "Sparkler and Señorita series are bred to be thornless and shorter.",
      "Self-seeds prolifically — pull excess seedlings in spring.",
      "Pinch out at 30 cm to bulk up before flowering starts.",
      "Heat- and drought-tolerant once established — great for hot south-facing borders.",
    ],
  },
  "Dahlia variabilis": {
    common: "Bedding Dahlia", type: "annual", family: "Asteraceae", freeTier: false,
    height: 50, spread: 35, hex: "#e84060",
    bloomMonths: [7, 8, 9, 10],
    sowIndoorMonths: [2, 3], transplantMonths: [5, 6],
    preferredSoil: ["loam"],
    preferredSunlight: ["sunny_always", "sunny_pm"],
    preferredAcidity: ["neutral", "mildly_acidic"],
    preferredWetness: ["normal_well"],
    tips: [
      "Seed-raised dahlias for first-year colour — no tuber storage required.",
      "Pinch out the central shoot at six weeks to encourage branching.",
      "Slug protection is essential — they devour young plants overnight.",
      "Tubers form by autumn and can be lifted and stored cool over winter for a head-start next year.",
      "Feed fortnightly with a high-potash feed once buds appear.",
    ],
  },
  "Lobularia maritima": {
    common: "Sweet Alyssum", type: "annual", family: "Brassicaceae", freeTier: true,
    height: 15, spread: 25, hex: "#f0e8d8",
    bloomMonths: [4, 5, 6, 7, 8, 9, 10],
    sowIndoorMonths: [3], sowDirectMonths: [4, 5], transplantMonths: [4, 5],
    preferredSoil: ["loam", "sandy"],
    preferredSunlight: ["sunny_always", "sunny_pm"],
    preferredAcidity: ["neutral", "mildly_alkaline"],
    preferredWetness: ["normal_well", "slightly_dry"],
    tips: [
      "Honey-scented carpet of bloom — classic for edging paths and patio pots.",
      "Trim back hard mid-summer to refresh for an autumn flush.",
      "Snow Princess (sterile cultivar) blooms non-stop without setting seed.",
      "Pollinator magnet — bees and hoverflies cover it on warm days.",
      "Self-seeds freely from open-pollinated varieties; weed out unwanted seedlings in spring.",
    ],
  },
  "Ageratum houstonianum": {
    common: "Floss Flower", type: "annual", family: "Asteraceae", freeTier: false,
    height: 25, spread: 25, hex: "#7a8fc8",
    bloomMonths: [6, 7, 8, 9, 10],
    sowIndoorMonths: [2, 3], transplantMonths: [5, 6],
    preferredSoil: ["loam"],
    preferredSunlight: ["sunny_always", "sunny_pm"],
    preferredAcidity: ["neutral", "mildly_acidic"],
    preferredWetness: ["normal_well"],
    tips: [
      "Powder-blue fluffy flower clusters — rare in the UK bedding palette.",
      "Hawaii and Aloha series stay tight and weather-resistant.",
      "Keep moist but not waterlogged — wilting plants drop their buds.",
      "Trim spent flower heads with shears for a fresh second flush.",
      "Combines beautifully with yellow bidens and pink petunias.",
    ],
  },
  "Dianthus chinensis": {
    common: "Chinese Pink", type: "annual", family: "Caryophyllaceae", freeTier: false,
    height: 25, spread: 25, hex: "#e85aa0",
    bloomMonths: [5, 6, 7, 8, 9, 10],
    sowIndoorMonths: [2, 3], transplantMonths: [4, 5],
    preferredSoil: ["loam", "sandy", "chalky"],
    preferredSunlight: ["sunny_always", "sunny_pm"],
    preferredAcidity: ["neutral", "mildly_alkaline"],
    preferredWetness: ["normal_well"],
    tips: [
      "Carnation-scented blooms with the classic 'pink' fringed petals.",
      "Often perennial in mild UK gardens — overwinters reliably south of the Midlands.",
      "Deadhead to keep flowers coming through summer.",
      "Tolerates poor, alkaline soil — perfect for chalky south-coast gardens.",
      "Floral Lace and Coronet series bloom in the first year from seed.",
    ],
  },
  "Bidens ferulifolia": {
    common: "Tickseed", type: "annual", family: "Asteraceae", freeTier: false,
    height: 35, spread: 60, hex: "#f5c020",
    bloomMonths: [5, 6, 7, 8, 9, 10],
    sowIndoorMonths: [2, 3], transplantMonths: [5, 6],
    preferredSoil: ["loam", "sandy"],
    preferredSunlight: ["sunny_always"],
    preferredAcidity: ["neutral", "mildly_alkaline"],
    preferredWetness: ["normal_well", "slightly_dry"],
    tips: [
      "Cheerful yellow daisies cascade from baskets and tumble over pot edges.",
      "Goldilocks Rocks holds up to summer downpours better than older bidens.",
      "Drought-tolerant once established — better dry than soggy.",
      "Combines well with trailing lobelia and white bacopa in baskets.",
      "Trim back hard mid-July for a fresh autumn display.",
    ],
  },
  "Sutera cordata": {
    common: "Bacopa", type: "annual", family: "Plantaginaceae", freeTier: false,
    height: 15, spread: 50, hex: "#f0e8e0",
    bloomMonths: [5, 6, 7, 8, 9, 10],
    sowIndoorMonths: [2, 3], transplantMonths: [5, 6],
    preferredSoil: ["loam"],
    preferredSunlight: ["sunny_pm", "sunny_am"],
    preferredAcidity: ["neutral"],
    preferredWetness: ["normal_well"],
    tips: [
      "Pearly white stars cascade non-stop from baskets all summer.",
      "Sensitive to drought — wilts dramatically and is slow to recover. Keep moist!",
      "Snowtopia and Scopia series resist the weather better than older bacopas.",
      "Trim back lightly if growth becomes leggy mid-summer.",
      "Self-cleans; no deadheading needed.",
    ],
  },
  "Coleus scutellarioides": {
    common: "Coleus", type: "annual", family: "Lamiaceae", freeTier: false,
    height: 45, spread: 35, hex: "#9c2a3a",
    bloomMonths: [],
    sowIndoorMonths: [2, 3], transplantMonths: [5, 6],
    preferredSoil: ["loam"],
    preferredSunlight: ["sunny_pm", "sunny_am", "shaded_always"],
    preferredAcidity: ["neutral", "mildly_acidic"],
    preferredWetness: ["normal_well"],
    tips: [
      "Grown for its foliage — pinch out flower spikes to keep leaves bold.",
      "Wizard and Black Dragon series tolerate sun; older varieties prefer shade.",
      "Cuttings root in water within a fortnight — easy way to overwinter favourites indoors.",
      "Pinch out tips every 3-4 weeks to keep plants bushy.",
      "Kong series has truly enormous leaves — give them space to spread.",
    ],
  },
};

// ── Cultivars per parent species ─────────────────────────────────────────────
//
// Each cultivar overrides colour, height and spread; everything else inherits
// from the parent stub above. heightCm and spreadCm are typical UK garden-
// centre tags for the cultivar; hex is the dominant flower colour.

const BEDDING_CULTIVARS = {
  "Petunia × atkinsiana": [
    { name: "Surfinia Purple",      hex: "#7a4aa8", h: 30, s: 75 },
    { name: "Surfinia Pink Vein",   hex: "#e07ac0", h: 30, s: 70 },
    { name: "Wave Purple",          hex: "#6a3aa0", h: 25, s: 90 },
    { name: "Wave Tidal Wave Silver", hex: "#f0e0e8", h: 50, s: 90 },
    { name: "Easy Wave Burgundy",   hex: "#7a1a2a", h: 30, s: 100 },
    { name: "Cascadia Indian Summer", hex: "#e8902a", h: 25, s: 75 },
    { name: "Sophistica Lime Bicolor", hex: "#c8c83a", h: 30, s: 40 },
    { name: "Shock Wave Coral Crush", hex: "#f08a8a", h: 20, s: 60 },
    { name: "Million Bells Cherry", hex: "#d62a4a", h: 25, s: 35 },
    { name: "Picobella Cascade Blue", hex: "#4a55a0", h: 25, s: 60 },
  ],
  "Pelargonium × hortorum": [
    { name: "Rocky Mountain Red",   hex: "#c8262a", h: 45, s: 35 },
    { name: "Rocky Mountain White", hex: "#f5f5f5", h: 45, s: 35 },
    { name: "Maverick Salmon",      hex: "#f0908a", h: 35, s: 30 },
    { name: "Pinto Premium Lavender", hex: "#c89adc", h: 35, s: 30 },
    { name: "Calliope Crimson Flame", hex: "#a01828", h: 50, s: 40 },
    { name: "Caliente Hot Coral",   hex: "#f06a4a", h: 40, s: 40 },
    { name: "Americana Coral",      hex: "#f48a70", h: 40, s: 35 },
    { name: "Horizon Appleblossom", hex: "#f4c4c8", h: 40, s: 35 },
  ],
  "Pelargonium peltatum": [
    { name: "Cascade Red",          hex: "#c8262a", h: 25, s: 75 },
    { name: "Cascade Lilac",        hex: "#c89adc", h: 25, s: 75 },
    { name: "Decora White",         hex: "#f5f5f5", h: 30, s: 80 },
    { name: "Ville de Paris Pink",  hex: "#e87aa8", h: 30, s: 80 },
    { name: "Pacific Burgundy",     hex: "#7a1a3a", h: 30, s: 75 },
    { name: "Pacific Lavender",     hex: "#b48ad8", h: 30, s: 75 },
    { name: "Royal Lavender",       hex: "#9a6ec8", h: 25, s: 70 },
  ],
  "Viola × wittrockiana": [
    { name: "Matrix Yellow Blotch", hex: "#f5d020", h: 20, s: 25 },
    { name: "Matrix Purple",        hex: "#5a2a8a", h: 20, s: 25 },
    { name: "Delta Pure White",     hex: "#f5f5f5", h: 20, s: 25 },
    { name: "Delta Orange",         hex: "#f0801a", h: 20, s: 25 },
    { name: "Cool Wave Frost",      hex: "#e8d8e8", h: 20, s: 50 },
    { name: "Cool Wave Yellow",     hex: "#f5d020", h: 20, s: 50 },
    { name: "Frizzle Sizzle Blue",  hex: "#4a55a8", h: 18, s: 22 },
    { name: "Frizzle Sizzle Lemonberry", hex: "#f4a8b8", h: 18, s: 22 },
    { name: "Ultima Morpho",        hex: "#3a5fa8", h: 22, s: 28 },
  ],
  "Viola cornuta": [
    { name: "Sorbet Yellow Frost",  hex: "#f5d020", h: 15, s: 20 },
    { name: "Sorbet XP Lemon Chiffon", hex: "#f5e8a8", h: 15, s: 20 },
    { name: "Penny Mickey",         hex: "#5a2a8a", h: 12, s: 18 },
    { name: "Penny Orange",         hex: "#f0801a", h: 12, s: 18 },
    { name: "Endurio Pink Shades",  hex: "#e87aa0", h: 15, s: 22 },
    { name: "Endurio Sky Blue Martien", hex: "#7a9adc", h: 15, s: 22 },
  ],
  "Begonia semperflorens": [
    { name: "Cocktail Whisky",      hex: "#f0e0d0", h: 20, s: 25 },
    { name: "Cocktail Vodka",       hex: "#c83a4a", h: 20, s: 25 },
    { name: "Cocktail Brandy",      hex: "#f4a0a8", h: 20, s: 25 },
    { name: "Senator White",        hex: "#f5f5f5", h: 25, s: 28 },
    { name: "Senator Pink",         hex: "#f0a8c0", h: 25, s: 28 },
    { name: "Olympia Rose",         hex: "#e88aa8", h: 22, s: 25 },
    { name: "Inferno Pink",         hex: "#f08a90", h: 22, s: 25 },
    { name: "Ambassador Scarlet",   hex: "#d62a3a", h: 20, s: 25 },
  ],
  "Begonia × tuberhybrida": [
    { name: "Nonstop Mocca Yellow", hex: "#f5d020", h: 25, s: 30 },
    { name: "Nonstop Red",          hex: "#c8262a", h: 25, s: 30 },
    { name: "Nonstop White",        hex: "#f5f5f5", h: 25, s: 30 },
    { name: "Roseform Pink",        hex: "#e87aa8", h: 30, s: 30 },
    { name: "Picotee Lace Apricot", hex: "#f4b890", h: 25, s: 30 },
    { name: "AmeriHybrid Roseform Rose", hex: "#e85aa0", h: 35, s: 35 },
    { name: "Illumination Orange",  hex: "#f0801a", h: 30, s: 45 },
  ],
  "Impatiens walleriana": [
    { name: "Beacon Coral",         hex: "#f4708a", h: 25, s: 25 },
    { name: "Beacon Violet",        hex: "#7a4aa8", h: 25, s: 25 },
    { name: "Imara XDR Red",        hex: "#c8262a", h: 25, s: 25 },
    { name: "Super Elfin White",    hex: "#f5f5f5", h: 20, s: 22 },
    { name: "Accent Coral",         hex: "#f48a8a", h: 20, s: 22 },
    { name: "Xtreme Lipstick",      hex: "#e83a4a", h: 25, s: 25 },
  ],
  "Impatiens hawkeri": [
    { name: "SunPatiens Compact Tropical Rose", hex: "#e85aa0", h: 40, s: 40 },
    { name: "SunPatiens Vigorous Tropical Orange", hex: "#f0801a", h: 60, s: 60 },
    { name: "Tamarinda Magic Salmon", hex: "#f48a70", h: 35, s: 35 },
    { name: "Magnum Lavender",      hex: "#a888d8", h: 40, s: 40 },
    { name: "Painted Paradise Lilac", hex: "#c0a0d8", h: 35, s: 35 },
  ],
  "Lobelia erinus": [
    { name: "Cascade Sapphire",     hex: "#3a55a8", h: 15, s: 30 },
    { name: "Cascade Ruby",         hex: "#c83a5a", h: 15, s: 30 },
    { name: "Riviera Blue Splash",  hex: "#5a7adc", h: 12, s: 18 },
    { name: "Riviera Sky Blue",     hex: "#8aaad8", h: 12, s: 18 },
    { name: "Crystal Palace",       hex: "#1a2a78", h: 15, s: 20 },
    { name: "Regatta Lilac Splash", hex: "#c8a8dc", h: 15, s: 25 },
    { name: "String of Pearls Mixed", hex: "#9aaadc", h: 15, s: 25 },
  ],
  "Antirrhinum majus": [
    { name: "Rocket Red",           hex: "#c8262a", h: 75, s: 30 },
    { name: "Rocket Lemon",         hex: "#f5d020", h: 75, s: 30 },
    { name: "Sonnet Pink",          hex: "#f0a8c0", h: 55, s: 28 },
    { name: "Sonnet Burgundy",      hex: "#6a1a2a", h: 55, s: 28 },
    { name: "Snapshot Yellow",      hex: "#f5d850", h: 30, s: 25 },
    { name: "Snapshot Orange",      hex: "#f0801a", h: 30, s: 25 },
    { name: "Floral Showers White", hex: "#f5f5f5", h: 25, s: 22 },
    { name: "Twinny Peach",         hex: "#f4b890", h: 35, s: 28 },
    { name: "Liberty Classic Cherry", hex: "#c82a4a", h: 60, s: 30 },
  ],
  "Tagetes patula": [
    { name: "Bonanza Bolero",       hex: "#c8401a", h: 30, s: 30 },
    { name: "Bonanza Yellow",       hex: "#f5d020", h: 30, s: 30 },
    { name: "Bonanza Flame",        hex: "#f0801a", h: 30, s: 30 },
    { name: "Disco Marietta",       hex: "#f5a020", h: 25, s: 25 },
    { name: "Janie Spry",           hex: "#f0a01a", h: 25, s: 25 },
    { name: "Boy Orange",           hex: "#f0801a", h: 20, s: 22 },
    { name: "Boy Spry",             hex: "#c82a1a", h: 20, s: 22 },
    { name: "Honeycomb",            hex: "#f4a040", h: 35, s: 30 },
  ],
  "Tagetes erecta": [
    { name: "Antigua Orange",       hex: "#f08020", h: 30, s: 35 },
    { name: "Antigua Yellow",       hex: "#f5d020", h: 30, s: 35 },
    { name: "Inca II Orange",       hex: "#f0801a", h: 35, s: 40 },
    { name: "Inca II Yellow",       hex: "#f5d020", h: 35, s: 40 },
    { name: "Marvel Gold",          hex: "#f5b020", h: 45, s: 40 },
    { name: "Crackerjack Mixed",    hex: "#f5a040", h: 80, s: 45 },
  ],
  "Calendula officinalis": [
    { name: "Pacific Beauty Mixed", hex: "#f5a040", h: 60, s: 35 },
    { name: "Sunset Buff",          hex: "#f0c890", h: 50, s: 35 },
    { name: "Indian Prince",        hex: "#d8602a", h: 60, s: 35 },
    { name: "Calypso Orange",       hex: "#f0801a", h: 30, s: 30 },
    { name: "Touch of Red Buff",    hex: "#e8b070", h: 45, s: 35 },
    { name: "Snow Princess",        hex: "#f5e8d0", h: 45, s: 35 },
  ],
  "Salvia splendens": [
    { name: "Sizzler Red",          hex: "#d62a2a", h: 35, s: 30 },
    { name: "Sizzler Salmon",       hex: "#f08a8a", h: 35, s: 30 },
    { name: "Sizzler Lavender",     hex: "#a888d8", h: 35, s: 30 },
    { name: "Vista Red",            hex: "#d62a2a", h: 30, s: 28 },
    { name: "Vista Purple",         hex: "#5a2a8a", h: 30, s: 28 },
    { name: "Vista Salmon",         hex: "#f48a8a", h: 30, s: 28 },
  ],
  "Salvia farinacea": [
    { name: "Victoria Blue",        hex: "#3a55a8", h: 50, s: 30 },
    { name: "Victoria White",       hex: "#f5f5f5", h: 50, s: 30 },
    { name: "Strata",               hex: "#7a8fc8", h: 50, s: 30 },
    { name: "Cathedral Sky Blue",   hex: "#5a7adc", h: 50, s: 30 },
    { name: "Evolution Violet",     hex: "#5a2a8a", h: 50, s: 30 },
  ],
  "Nicotiana × sanderae": [
    { name: "Domino Crimson",       hex: "#c82a4a", h: 35, s: 25 },
    { name: "Domino White",         hex: "#f5f5f5", h: 35, s: 25 },
    { name: "Perfume Deep Purple",  hex: "#5a2a8a", h: 50, s: 30 },
    { name: "Perfume Lime",         hex: "#c8d050", h: 50, s: 30 },
    { name: "Saratoga Lime",        hex: "#c8d050", h: 35, s: 25 },
    { name: "Saratoga Mixed",       hex: "#e8a8c0", h: 35, s: 25 },
  ],
  "Verbena × hybrida": [
    { name: "Quartz Purple",        hex: "#7a3a9c", h: 25, s: 35 },
    { name: "Quartz Red",           hex: "#c8262a", h: 25, s: 35 },
    { name: "Obsession Burgundy",   hex: "#7a1a2a", h: 20, s: 30 },
    { name: "Obsession Twister Red", hex: "#d6404a", h: 20, s: 30 },
    { name: "Lascar Mango Orange",  hex: "#f06a3a", h: 25, s: 40 },
    { name: "Empress Sun Lavender", hex: "#9a7adc", h: 30, s: 45 },
    { name: "Endurascape Pink Bicolor", hex: "#e87aa0", h: 25, s: 50 },
  ],
  "Zinnia elegans": [
    { name: "Magellan Cherry",      hex: "#c82a4a", h: 35, s: 30 },
    { name: "Magellan Coral",       hex: "#f4708a", h: 35, s: 30 },
    { name: "Magellan Yellow",      hex: "#f5d020", h: 35, s: 30 },
    { name: "Profusion Cherry",     hex: "#d62a4a", h: 30, s: 30 },
    { name: "Profusion White",      hex: "#f5f5f5", h: 30, s: 30 },
    { name: "Zahara Yellow",        hex: "#f5d050", h: 30, s: 30 },
    { name: "Benary's Giant Lime",  hex: "#c8d050", h: 100, s: 40 },
    { name: "Benary's Giant Wine",  hex: "#6a1a2a", h: 100, s: 40 },
  ],
  "Cosmos bipinnatus": [
    { name: "Sonata Pink",          hex: "#e8a8c0", h: 60, s: 35 },
    { name: "Sonata White",         hex: "#f5f5f5", h: 60, s: 35 },
    { name: "Sensation Mixed",      hex: "#e87aa8", h: 120, s: 45 },
    { name: "Double Click Cranberries", hex: "#a01838", h: 100, s: 40 },
    { name: "Double Click Snow Puff", hex: "#f0e8e0", h: 100, s: 40 },
    { name: "Apricot Lemonade",     hex: "#f4c490", h: 80, s: 40 },
    { name: "Velouette",            hex: "#c8404a", h: 80, s: 40 },
  ],
  "Cosmos sulphureus": [
    { name: "Bright Lights Mixed",  hex: "#f0801a", h: 70, s: 35 },
    { name: "Cosmic Orange",        hex: "#f06a1a", h: 40, s: 30 },
    { name: "Cosmic Yellow",        hex: "#f5d020", h: 40, s: 30 },
    { name: "Cosmic Red",           hex: "#c8262a", h: 40, s: 30 },
    { name: "Polidor Mixed",        hex: "#f4a040", h: 90, s: 40 },
  ],
  "Cleome hassleriana": [
    { name: "Sparkler Lavender",    hex: "#a888d8", h: 90, s: 50 },
    { name: "Sparkler White",       hex: "#f5f5f5", h: 90, s: 50 },
    { name: "Senorita Rosalita",    hex: "#e87aa8", h: 100, s: 60 },
    { name: "Helen Campbell",       hex: "#f5f5f5", h: 110, s: 50 },
    { name: "Violet Queen",         hex: "#7a3a9c", h: 110, s: 50 },
  ],
  "Dahlia variabilis": [
    { name: "Figaro Red Shades",    hex: "#c8262a", h: 35, s: 30 },
    { name: "Figaro Yellow Shades", hex: "#f5d020", h: 35, s: 30 },
    { name: "Figaro Orange",        hex: "#f0801a", h: 35, s: 30 },
    { name: "Mignon Mixed",         hex: "#e87aa8", h: 40, s: 30 },
    { name: "Mystery Day",          hex: "#7a1a2a", h: 45, s: 35 },
    { name: "Unwins Bedding Mix",   hex: "#e85a70", h: 50, s: 40 },
    { name: "Diablo Mix",           hex: "#c8404a", h: 40, s: 35 },
  ],
  "Lobularia maritima": [
    { name: "Snow Princess",        hex: "#f5f5f5", h: 20, s: 60 },
    { name: "Easter Bonnet Violet", hex: "#7a3a9c", h: 15, s: 25 },
    { name: "Easter Bonnet White",  hex: "#f5f5f5", h: 15, s: 25 },
    { name: "Carpet of Snow",       hex: "#f5f5f5", h: 12, s: 22 },
    { name: "Royal Carpet",         hex: "#7a3a9c", h: 12, s: 22 },
    { name: "Lavender Stream",      hex: "#c8a8dc", h: 15, s: 40 },
  ],
  "Ageratum houstonianum": [
    { name: "Hawaii Blue",          hex: "#7a8fc8", h: 25, s: 25 },
    { name: "Hawaii White",         hex: "#f5f5f5", h: 25, s: 25 },
    { name: "Aloha Blue",           hex: "#5a7adc", h: 20, s: 22 },
    { name: "Aloha Pink",           hex: "#e8a0c0", h: 20, s: 22 },
    { name: "Blue Mink",            hex: "#7a8fc8", h: 30, s: 30 },
    { name: "Patina Delft",         hex: "#7a8fc8", h: 25, s: 25 },
  ],
  "Dianthus chinensis": [
    { name: "Coronet Cherry",       hex: "#c82a4a", h: 25, s: 25 },
    { name: "Coronet Strawberry",   hex: "#e87aa0", h: 25, s: 25 },
    { name: "Coronet White",        hex: "#f5f5f5", h: 25, s: 25 },
    { name: "Floral Lace Picotee",  hex: "#f0a8c0", h: 25, s: 25 },
    { name: "Floral Lace Crimson",  hex: "#a01838", h: 25, s: 25 },
    { name: "Telstar Picotee",      hex: "#f4a8c0", h: 25, s: 25 },
    { name: "Ideal Select Whitefire", hex: "#f5f5f5", h: 22, s: 25 },
  ],
  "Bidens ferulifolia": [
    { name: "Goldilocks Rocks",     hex: "#f5c020", h: 35, s: 60 },
    { name: "Solaire Compact Yellow", hex: "#f5d020", h: 30, s: 40 },
    { name: "Solaire Yellow",       hex: "#f5d020", h: 30, s: 50 },
    { name: "Beedance Painted Red", hex: "#d8404a", h: 30, s: 50 },
    { name: "Hawaiian Flare",       hex: "#f08020", h: 35, s: 60 },
    { name: "Pretty in Pink",       hex: "#f0a0c0", h: 30, s: 50 },
  ],
  "Sutera cordata": [
    { name: "Snowtopia",            hex: "#f5f5f5", h: 15, s: 50 },
    { name: "Bluetopia",            hex: "#7a8fc8", h: 15, s: 50 },
    { name: "Scopia Gulliver White", hex: "#f5f5f5", h: 20, s: 60 },
    { name: "Scopia Double Lavender", hex: "#c8a8dc", h: 20, s: 60 },
    { name: "Snowstorm Giant Snowflake", hex: "#f5f5f5", h: 15, s: 80 },
    { name: "Calypso Jumbo White",  hex: "#f5f5f5", h: 18, s: 70 },
  ],
  "Coleus scutellarioides": [
    { name: "Wizard Velvet Red",    hex: "#7a1a2a", h: 40, s: 35 },
    { name: "Wizard Pineapple",     hex: "#c8d050", h: 40, s: 35 },
    { name: "Wizard Mix",           hex: "#9c2a3a", h: 40, s: 35 },
    { name: "Kong Rose",            hex: "#e87aa0", h: 60, s: 50 },
    { name: "Kong Mosaic",          hex: "#c8404a", h: 60, s: 50 },
    { name: "ColorBlaze Royal Glissade", hex: "#7a3a9c", h: 50, s: 40 },
    { name: "Black Dragon",         hex: "#3a1a2a", h: 45, s: 35 },
    { name: "Stained Glassworks Big Red Judy", hex: "#a01828", h: 50, s: 40 },
  ],
};

// ── Pipeline ─────────────────────────────────────────────────────────────────

const data  = JSON.parse(readFileSync(LIBRARY, "utf-8"));
const items = data.items;
const existingIds = new Set(items.map(p => p.id));

function buildParentStub(latin, info) {
  return {
    id: slugify(latin),
    name: info.common,
    latin,
    type: info.type,
    family: info.family,
    heightCm: info.height,
    spreadCm: info.spread,
    colorHex: info.hex,
    bloomMonths: info.bloomMonths,
    sowIndoorMonths: info.sowIndoorMonths ?? [],
    sowDirectMonths: info.sowDirectMonths ?? [],
    transplantMonths: info.transplantMonths ?? [],
    harvestMonths: [],
    preferredSoil: info.preferredSoil,
    preferredSunlight: info.preferredSunlight,
    preferredAcidity: info.preferredAcidity,
    preferredWetness: info.preferredWetness,
    growersTips: info.tips.join("\n"),
    germinationRequirements: "",
    companions: [],
    access: info.freeTier ? "free" : "pro",
    description: `Classic UK bedding plant. ${info.tips[0]}`,
  };
}

let addedParents = 0;
let addedCultivars = 0;
let skipped = 0;

for (const [parentLatin, info] of Object.entries(BEDDING_PARENTS)) {
  // Add or reuse the parent row.
  let parent = items.find(p => p.latin === parentLatin);
  if (!parent) {
    parent = buildParentStub(parentLatin, info);
    if (!existingIds.has(parent.id)) {
      items.push(parent);
      existingIds.add(parent.id);
      addedParents++;
    }
  } else {
    // Existing parent — overlay our curated bedding fields so the cultivars
    // inherit a usable record (the SPARQL-discovered parent often lacks
    // growersTips / sowing data).
    parent.type = info.type;
    parent.colorHex = info.hex;
    parent.heightCm = info.height;
    parent.spreadCm = info.spread;
    parent.bloomMonths = info.bloomMonths;
    parent.sowIndoorMonths = info.sowIndoorMonths ?? [];
    parent.sowDirectMonths = info.sowDirectMonths ?? [];
    parent.transplantMonths = info.transplantMonths ?? [];
    parent.harvestMonths = [];
    parent.preferredSoil = info.preferredSoil;
    parent.preferredSunlight = info.preferredSunlight;
    parent.preferredAcidity = info.preferredAcidity;
    parent.preferredWetness = info.preferredWetness;
    parent.growersTips = info.tips.join("\n");
    parent.access = info.freeTier ? "free" : "pro";
  }

  // Then the cultivars.
  for (const cv of BEDDING_CULTIVARS[parentLatin] || []) {
    const fullLatin = `${parentLatin} '${cv.name}'`;
    const id = slugify(`${parentLatin}-${cv.name}`);
    if (existingIds.has(id)) { skipped++; continue; }
    const commonStem = info.common.split(/\s+/)[0];
    const row = {
      ...parent,
      id,
      name: `${commonStem} '${cv.name}'`,
      latin: fullLatin,
      heightCm: cv.h,
      spreadCm: cv.s,
      colorHex: cv.hex,
      description: `${info.common} cultivar — ${cv.name}.`,
      access: info.freeTier ? "free" : "pro",
    };
    delete row.imageUrl; // cultivar-specific image not available; fall back to colour swatch.
    items.push(row);
    existingIds.add(id);
    addedCultivars++;
  }
}

console.log(`Bedding parents added/updated: ${addedParents} (others overlaid in place)`);
console.log(`Bedding cultivars added:       ${addedCultivars}`);
console.log(`Cultivars skipped (existed):   ${skipped}`);

if (!dryRun) {
  data.generated = new Date().toISOString();
  data.source = (data.source ?? "") + " + bedding-plant canon";
  writeFileSync(LIBRARY, JSON.stringify(data, null, 2) + "\n");
  console.log(`✓ wrote ${LIBRARY} (${items.length} total items)`);
} else {
  console.log("\nDRY RUN — no write.");
}
