#!/usr/bin/env node
/**
 * add-fruit-cultivars.mjs — bulk-append named fruit cultivars to
 * backend/data/library.json so the Fruit Pack hits its 500-plant
 * minimum. Re-uses the same parent stubs / inheritance pattern from
 * add-cultivars.mjs; idempotent on the `id` field.
 *
 * Each line is `[cultivar name, colorHex, heightCm, spreadCm, note]`.
 *
 * Usage:
 *   node scripts/add-fruit-cultivars.mjs
 *   node scripts/add-fruit-cultivars.mjs --dry-run
 */

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const LIBRARY = fileURLToPath(new URL("../data/library.json", import.meta.url));
const dryRun = process.argv.includes("--dry-run");

function slugify(s) {
  return s.toLowerCase()
          .replace(/['']/g, "")
          .replace(/[^a-z0-9]+/g, "-")
          .replace(/^-+|-+$/g, "");
}

// Parent stub map (used when the parent species isn't in the library).
const PARENT_STUBS = {
  "Malus domestica":      { common: "Apple",        type: "shrub",     family: "Rosaceae" },
  "Pyrus communis":       { common: "Pear",         type: "shrub",     family: "Rosaceae" },
  "Prunus domestica":     { common: "Plum",         type: "shrub",     family: "Rosaceae" },
  "Prunus avium":         { common: "Sweet Cherry", type: "shrub",     family: "Rosaceae" },
  "Prunus cerasus":       { common: "Sour Cherry",  type: "shrub",     family: "Rosaceae" },
  "Prunus persica":       { common: "Peach",        type: "shrub",     family: "Rosaceae" },
  "Prunus armeniaca":     { common: "Apricot",      type: "shrub",     family: "Rosaceae" },
  "Prunus insititia":     { common: "Damson",       type: "shrub",     family: "Rosaceae" },
  "Cydonia oblonga":      { common: "Quince",       type: "shrub",     family: "Rosaceae" },
  "Mespilus germanica":   { common: "Medlar",       type: "shrub",     family: "Rosaceae" },
  "Fragaria × ananassa":  { common: "Strawberry",   type: "perennial", family: "Rosaceae" },
  "Rubus idaeus":         { common: "Raspberry",    type: "shrub",     family: "Rosaceae" },
  "Rubus fruticosus":     { common: "Blackberry",   type: "shrub",     family: "Rosaceae" },
  "Ribes nigrum":         { common: "Blackcurrant", type: "shrub",     family: "Grossulariaceae" },
  "Ribes rubrum":         { common: "Redcurrant",   type: "shrub",     family: "Grossulariaceae" },
  "Ribes uva-crispa":     { common: "Gooseberry",   type: "shrub",     family: "Grossulariaceae" },
  "Vaccinium corymbosum": { common: "Highbush Blueberry", type: "shrub", family: "Ericaceae" },
  "Vaccinium macrocarpon":{ common: "Cranberry",    type: "shrub",     family: "Ericaceae" },
  "Vaccinium vitis-idaea":{ common: "Lingonberry",  type: "shrub",     family: "Ericaceae" },
  "Vitis vinifera":       { common: "Grape Vine",   type: "perennial", family: "Vitaceae" },
  "Ficus carica":         { common: "Fig",          type: "shrub",     family: "Moraceae" },
  "Morus nigra":          { common: "Black Mulberry", type: "shrub",   family: "Moraceae" },
  "Morus alba":           { common: "White Mulberry", type: "shrub",   family: "Moraceae" },
  "Hippophae rhamnoides": { common: "Sea Buckthorn", type: "shrub",    family: "Elaeagnaceae" },
  "Sambucus nigra":       { common: "Elder",        type: "shrub",     family: "Adoxaceae" },
  "Aronia melanocarpa":   { common: "Chokeberry",   type: "shrub",     family: "Rosaceae" },
  "Amelanchier lamarckii":{ common: "Snowy Mespilus", type: "shrub",   family: "Rosaceae" },
  "Lonicera caerulea":    { common: "Honeyberry",   type: "shrub",     family: "Caprifoliaceae" },
  "Actinidia deliciosa":  { common: "Kiwi",         type: "perennial", family: "Actinidiaceae" },
  "Diospyros kaki":       { common: "Persimmon",    type: "shrub",     family: "Ebenaceae" },
  "Punica granatum":      { common: "Pomegranate",  type: "shrub",     family: "Lythraceae" },
  "Citrus limon":         { common: "Lemon",        type: "shrub",     family: "Rutaceae" },
  "Citrus sinensis":      { common: "Orange",       type: "shrub",     family: "Rutaceae" },
  "Citrus aurantiifolia": { common: "Lime",         type: "shrub",     family: "Rutaceae" },
};

// ── Cultivar dataset (~400 entries) ───────────────────────────────────
// Format: [name, hex, h, s, note]

const C = {
  "Malus domestica": [
    // UK heritage + RHS AGM classics
    ["Beauty of Bath",        "#d65a3a", 400, 400, "Very early eating apple, soft and aromatic."],
    ["Blenheim Orange",       "#d6a04a", 500, 500, "Old dual-purpose apple, nutty flavour."],
    ["Charles Ross",          "#d65a3a", 400, 400, "Large dual-purpose dessert apple."],
    ["Crispin (Mutsu)",       "#c2c25a", 400, 400, "Large green dessert apple, sweet and juicy."],
    ["Empire",                "#a01a2a", 400, 400, "Dark-red small dessert apple, crisp."],
    ["Fiesta",                "#d65a3a", 400, 400, "Cox-style sweet dessert apple."],
    ["Fuji",                  "#e8a04a", 400, 400, "Sweet crisp dessert apple, stores well."],
    ["Golden Delicious",      "#e8d04a", 400, 400, "Yellow dessert apple, very productive."],
    ["Honeycrisp",            "#d65a3a", 400, 400, "Crunchy sweet dessert apple, modern favourite."],
    ["Jonagold",              "#d65a3a", 400, 400, "Jonathan × Golden Delicious; sharp-sweet dessert."],
    ["Katy",                  "#d6202a", 400, 400, "Bright-red eating apple, early-mid season."],
    ["Kidd's Orange Red",     "#d65a3a", 400, 400, "Heritage NZ apple, Cox-like flavour."],
    ["Laxton's Superb",       "#d65a3a", 400, 400, "Late dessert apple, sweet and aromatic."],
    ["McIntosh",              "#a01a2a", 400, 400, "Tender Canadian dessert apple."],
    ["Pink Lady",             "#e89bc8", 400, 400, "Crisp pink-skinned modern dessert apple."],
    ["Pixie",                 "#d6a04a", 400, 400, "Late RHS AGM dessert apple, very firm."],
    ["Red Falstaff",          "#d6202a", 400, 400, "Reliable dessert apple, heavy cropper."],
    ["Spartan",               "#7a1a2a", 400, 400, "Dark-skinned dessert apple, sweet."],
    ["Sturmer Pippin",        "#c2c25a", 400, 400, "Very late dessert apple, sharp until stored."],
    ["Tydeman's Late Orange", "#d65a3a", 400, 400, "Long-keeping late dessert apple."],
    ["Annie Elizabeth",       "#9bc25a", 450, 450, "Heritage Leicestershire cooker, late." ],
    ["Arthur Turner",         "#9bc25a", 400, 400, "Large yellow cooker, early."],
    ["Ashmead's Kernel",      "#a06f4a", 400, 400, "Heritage russet dessert apple."],
    ["Belle de Boskoop",      "#a01a2a", 450, 450, "Heritage Dutch cooker, sharp."],
    ["Braeburn",              "#d65a3a", 400, 400, "Crisp NZ dessert apple, late."],
    ["Bountiful",              "#9bc25a", 400, 400, "Modern dessert/cooker, very heavy cropper."],
    ["Chivers Delight",       "#d65a3a", 400, 400, "Cambridgeshire heritage dessert apple."],
    ["D'Arcy Spice",          "#a06f4a", 400, 400, "Heritage Essex russet, spicy."],
    ["Devonshire Quarrenden", "#a01a2a", 400, 400, "Heritage SW England dessert apple."],
    ["Edward VII",            "#9bc25a", 400, 400, "Late cooking apple, stores well."],
    ["Ellison's Orange",      "#d65a3a", 400, 400, "Heritage dessert apple, aniseed flavour."],
    ["Falstaff",              "#d6202a", 400, 400, "Heavy-cropping dessert apple."],
    ["Greensleeves",          "#c2c25a", 400, 400, "Modern self-fertile dessert apple."],
    ["Grenadier",             "#9bc25a", 400, 400, "Early cooker, very reliable."],
    ["Idared",                "#d6202a", 400, 400, "Bright-red dessert apple, stores well."],
    ["Jupiter",               "#d65a3a", 400, 400, "Cox-style dessert apple, modern."],
    ["Keswick Codlin",        "#9bc25a", 400, 400, "Cumbrian heritage cooker."],
    ["Kingston Black",        "#7a1a2a", 400, 400, "Cider apple, classic vintage variety."],
    ["Lane's Prince Albert",  "#9bc25a", 400, 400, "Heritage cooker, late."],
    ["Lord Derby",            "#9bc25a", 450, 450, "Heritage cooker, large fruit."],
    ["Newton Wonder",         "#d65a3a", 450, 450, "Dual-purpose heritage apple."],
    ["Norfolk Beauty",        "#9bc25a", 400, 400, "Heritage Norfolk cooker."],
    ["Orleans Reinette",      "#d6a04a", 400, 400, "Heritage French dessert apple."],
    ["Peasgood Nonsuch",      "#9bc25a", 450, 450, "Heritage cooker, large fruit."],
    ["Pitmaston Pineapple",   "#d6a04a", 400, 400, "Tiny heritage russet, pineapple flavour."],
    ["Reverend W Wilks",      "#9bc25a", 400, 400, "Heritage cooker, early."],
    ["Ribston Pippin",        "#d65a3a", 400, 400, "Heritage Yorkshire dessert apple."],
    ["Rosemary Russet",       "#a06f4a", 400, 400, "Heritage russet, late."],
    ["Sturmer Russet",        "#a06f4a", 400, 400, "Very late dessert russet."],
    ["Sunset",                "#d65a3a", 400, 400, "Cox-style dessert apple, smaller tree."],
    ["Suntan",                "#d65a3a", 400, 400, "RHS AGM dessert apple, late."],
    ["Tom Putt",              "#d6202a", 400, 400, "Heritage SW England cider/cooker."],
    ["Wagener",               "#d6202a", 400, 400, "Heritage US dessert apple."],
    ["Winston",               "#d65a3a", 400, 400, "Cox-style dessert apple, late."],
    ["Yorkshire Greening",    "#9bc25a", 450, 450, "Heritage Yorkshire cooker."],
  ],
  "Pyrus communis": [
    ["Onward",                "#9bc25a", 500, 350, "Self-fertile dessert pear, mid-season."],
    ["Glou Morceau",          "#9bc25a", 500, 350, "Late buttery dessert pear."],
    ["Beth",                  "#9bc25a", 400, 300, "Compact self-fertile early pear."],
    ["Beurré Bosc",           "#a06f4a", 500, 350, "Russet skin, melting flesh, late."],
    ["Beurré Superfin",       "#a08a4a", 500, 350, "Russet dessert pear, mid-season."],
    ["Black Worcester",       "#3a5a3a", 500, 350, "Heritage cooking pear, dark green."],
    ["Catillac",              "#9bc25a", 500, 350, "Large heritage cooker, long-keeping."],
    ["Clapp's Favourite",     "#9bc25a", 500, 350, "Early dessert pear, USA heritage."],
    ["Doyenne d'Hiver",       "#9bc25a", 500, 350, "Very late dessert pear, keeps until March."],
    ["Fertility",             "#9bc25a", 400, 300, "Heritage UK pear, reliable cropper."],
    ["Joséphine de Malines",  "#9bc25a", 500, 350, "Late dessert pear, sweet."],
    ["Louise Bonne of Jersey","#d6a04a", 500, 350, "Heritage dessert pear, red-flushed."],
    ["Marguerite Marillat",   "#a06f4a", 500, 350, "Large russet dessert pear."],
    ["Olivier de Serres",     "#a06f4a", 500, 350, "Very late russet dessert pear."],
    ["Packham's Triumph",     "#9bc25a", 500, 350, "Australian dessert pear, juicy."],
    ["Red Bartlett",          "#d6202a", 500, 350, "Red-skinned mutation of Williams."],
    ["Seckel",                "#a06f4a", 400, 300, "Tiny dessert pear, very sweet."],
    ["Thompson's",            "#9bc25a", 500, 350, "Heritage Yorkshire dessert pear."],
    ["Vicar of Wakefield",    "#9bc25a", 500, 350, "Long heritage cooking pear."],
    ["Improved Fertility",    "#9bc25a", 400, 300, "Improved Fertility, heavier cropper."],
  ],
  "Prunus domestica": [
    ["Cambridge Gage",        "#c2c25a", 400, 350, "Yellow-green dessert gage, sweet."],
    ["Greengage",             "#c2c25a", 400, 350, "Classic heritage green dessert gage."],
    ["Old Greengage",         "#c2c25a", 400, 350, "Original heritage greengage form."],
    ["Avalon",                "#7a1a2a", 400, 350, "Modern dark dessert plum, large fruit."],
    ["Blue Tit",              "#5a1a3a", 400, 300, "Small self-fertile blue plum."],
    ["Denniston's Superb",    "#c2c25a", 400, 350, "Self-fertile yellow gage, heavy cropper."],
    ["Early Laxton",          "#7a1a2a", 400, 300, "Early sweet dessert plum."],
    ["Excalibur",             "#7a1a2a", 400, 350, "Modern self-fertile dessert plum."],
    ["Kirke's Blue",          "#5a1a3a", 400, 350, "Heritage dessert plum, dark blue."],
    ["Mirabelle",             "#d6a04a", 400, 350, "French dessert mirabelle plum."],
    ["Opal",                  "#a01a3a", 400, 350, "Early Swedish dessert plum."],
    ["Pershore",              "#d6a04a", 400, 350, "Heritage Worcestershire cooker."],
    ["Reine Claude de Bavay", "#c2c25a", 400, 350, "Late Belgian gage, sweet."],
    ["Rivers's Early Prolific","#5a1a3a", 400, 350, "Heritage early-cropping blue plum."],
    ["Sanctus Hubertus",      "#5a1a3a", 400, 350, "Heritage dessert plum."],
    ["Stanley",               "#5a1a3a", 400, 350, "Heritage dessert plum from USA."],
    ["Warwickshire Drooper",  "#d6a04a", 400, 350, "Heritage UK cooking plum."],
    ["Yellow Pershore",       "#d6a04a", 400, 350, "Cooking variant of Pershore."],
    ["Jefferson",             "#c2c25a", 400, 350, "Heritage gage-style dessert plum."],
    ["President",             "#5a1a3a", 400, 350, "Heritage purple dessert plum, late."],
  ],
  "Prunus insititia": [
    ["Merryweather",          "#3a1a3a", 400, 300, "Sweet damson, large fruits."],
    ["Shropshire Prune",      "#3a1a3a", 400, 300, "Heritage damson for cooking."],
    ["Farleigh",              "#3a1a3a", 400, 300, "Heritage Kentish damson."],
    ["Bradley's King",        "#3a1a3a", 400, 300, "Heritage damson, very sweet."],
    ["Prune Damson",          "#3a1a3a", 400, 300, "Traditional cooking damson."],
    ["Westmorland",           "#3a1a3a", 400, 300, "Westmorland heritage damson."],
  ],
  "Prunus avium": [
    ["Morello",               "#5a1a2a", 400, 350, "Sour cherry, ideal for cooking."],
    ["Lapins",                "#9c1a3a", 500, 400, "Self-fertile dark sweet cherry."],
    ["Black Tartarian",       "#3a1a2a", 500, 400, "Heritage dark sweet cherry."],
    ["Celeste",               "#9c1a3a", 400, 350, "Compact self-fertile cherry, small garden."],
    ["Early Rivers",          "#3a1a2a", 500, 400, "Heritage very early black cherry."],
    ["Florence",              "#d6a04a", 500, 400, "Heritage yellow-red dessert cherry."],
    ["Governor Wood",         "#d6a04a", 500, 400, "Heritage yellow cherry."],
    ["Kentish Red",           "#a01a2a", 500, 400, "Heritage Kentish sour cherry."],
    ["Kordia",                "#7a1a2a", 500, 400, "Czech dessert cherry, very large."],
    ["Merchant",              "#7a1a2a", 500, 400, "Self-fertile mid-season dark cherry."],
    ["Merton Glory",          "#d6a04a", 500, 400, "Heritage white-fleshed dessert cherry."],
    ["Napoleon",              "#d6a04a", 500, 400, "Heritage white-yellow cherry."],
    ["Penny",                 "#9c1a3a", 500, 400, "Late dark sweet cherry."],
    ["Regina",                "#7a1a2a", 500, 400, "German late dessert cherry."],
    ["Skeena",                "#3a1a2a", 500, 400, "Modern dark sweet cherry, crack-resistant."],
    ["Summit",                "#7a1a2a", 500, 400, "Mid-season dessert cherry."],
    ["Sylvia",                "#9c1a3a", 400, 300, "Compact self-fertile dessert cherry."],
    ["Bigarreau Napoléon",    "#d6a04a", 500, 400, "Heritage yellow-blushed dessert cherry."],
  ],
  "Prunus persica": [
    ["Avalon Pride",          "#e8a04a", 400, 350, "Leaf-curl-resistant peach for UK."],
    ["Bonanza",               "#d68f6a", 300, 250, "Dwarf patio peach, pink flowers."],
    ["Early Rivers",          "#e8a04a", 400, 350, "Heritage early yellow peach."],
    ["Hale's Early",          "#e8a04a", 400, 350, "Heritage early peach for UK walls."],
    ["Lord Napier",           "#d68f6a", 400, 350, "Heritage nectarine for UK."],
    ["Nectared",              "#d68f6a", 400, 350, "Modern UK nectarine selection."],
    ["Pineapple",             "#d68f6a", 400, 350, "Heritage tropical-flavoured nectarine."],
    ["Saturne",               "#e8a04a", 400, 350, "Doughnut-shaped flat peach."],
    ["White Glory",           "#f5e6a8", 400, 350, "Heritage white-fleshed nectarine."],
    ["Garden Lady",           "#d68f6a", 200, 200, "Patio peach, very compact."],
  ],
  "Prunus armeniaca": [
    ["Moorpark",              "#d68f3a", 400, 350, "Heritage UK apricot, late."],
    ["Tomcot",                "#d68f3a", 400, 350, "Modern UK apricot, early."],
    ["Tilton",                "#d68f3a", 400, 350, "Heritage US apricot, hardy."],
    ["Goldcot",               "#d68f3a", 400, 350, "Hardy heritage apricot."],
    ["Petit Muscat",          "#d68f3a", 350, 300, "Small heritage musky apricot."],
    ["Royal",                 "#d68f3a", 400, 350, "Heritage French apricot."],
    ["Wilson Delicious",      "#d68f3a", 400, 350, "Heritage UK apricot, sweet."],
    ["Flavorcot",             "#d68f3a", 400, 350, "Modern UK apricot, large fruit."],
  ],
  "Cydonia oblonga": [
    ["Champion",              "#e8d04a", 400, 350, "Pear-shaped heritage quince."],
    ["Meech's Prolific",      "#e8d04a", 400, 350, "Heritage US quince, large fruit."],
    ["Portugal",              "#e8d04a", 400, 350, "Heritage Portuguese quince."],
    ["Serbian Gold",          "#e8d04a", 400, 350, "Serbian heritage quince, golden."],
    ["Vranja",                "#e8d04a", 400, 350, "Yugoslav heritage quince, large."],
  ],
  "Mespilus germanica": [
    ["Bredase Reus",          "#a06f4a", 400, 400, "Large heritage Dutch medlar."],
    ["Iranian",               "#a06f4a", 400, 400, "Iranian heritage medlar."],
    ["Nottingham",            "#a06f4a", 400, 400, "Heritage English medlar."],
    ["Royal",                 "#a06f4a", 400, 400, "Heritage medlar, large fruits."],
  ],
  "Fragaria × ananassa": [
    ["Elsanta",               "#d6202a", 25, 30, "Dutch maincrop strawberry, large red fruits."],
    ["Sonata",                "#d6202a", 25, 30, "Dutch mid-season strawberry."],
    ["Marshmello",            "#d6202a", 25, 30, "Heavy-cropping late strawberry."],
    ["Pandora",               "#d6202a", 25, 30, "Late strawberry, large fruits."],
    ["Rhapsody",              "#d6202a", 25, 30, "Late summer strawberry."],
    ["Royal Sovereign",       "#d6202a", 25, 30, "Heritage British strawberry, prized."],
    ["Fenella",               "#d6202a", 25, 30, "Disease-resistant mid-season strawberry."],
    ["Vibrant",               "#d6202a", 25, 30, "Very early strawberry."],
    ["Christine",             "#d6202a", 25, 30, "Early strawberry, sweet flavour."],
    ["Gariguette",            "#d6202a", 25, 30, "French heritage gourmet strawberry."],
    ["Korona",                "#d6202a", 25, 30, "Dutch mid-season strawberry."],
    ["Manille",               "#d6202a", 25, 30, "Heavy-cropping strawberry."],
    ["Maxim",                 "#d6202a", 25, 30, "Very large fruited maincrop."],
    ["Sweetheart",            "#d6202a", 25, 30, "Compact strawberry for hanging baskets."],
    ["Albion",                "#d6202a", 25, 30, "Day-neutral everbearer."],
    ["Cambridge Late Pine",   "#d6202a", 25, 30, "Heritage Cambridge strawberry."],
    ["Cambridge Vigour",      "#d6202a", 25, 30, "Heritage Cambridge strawberry, sweet."],
    ["Loran",                 "#d6202a", 25, 30, "Mid-season strawberry, vigorous."],
    ["Ostara",                "#d6202a", 25, 30, "Perpetual strawberry, all-summer."],
    ["Tarda Vicoda",          "#d6202a", 25, 30, "Italian heritage strawberry."],
    ["Eve's Delight",         "#d6202a", 25, 30, "Heavy-cropping June strawberry."],
    ["Hapil",                 "#d6202a", 25, 30, "Belgian midseason strawberry."],
    ["Aromel",                "#d6202a", 25, 30, "Perpetual fragrant strawberry."],
    ["Mae",                   "#d6202a", 25, 30, "Modern early strawberry."],
    ["Malling Pearl",         "#d6202a", 25, 30, "UK breeding strawberry, sweet."],
  ],
  "Rubus idaeus": [
    ["Glen Magna",            "#d6202a", 200, 60, "Modern summer raspberry, large fruit."],
    ["Glen Coe",              "#5a1a3a", 200, 60, "Purple raspberry, very sweet."],
    ["Joan J",                "#d6202a", 150, 60, "Spine-free autumn raspberry."],
    ["Malling Jewel",         "#d6202a", 180, 60, "Heritage UK summer raspberry."],
    ["Octavia",               "#d6202a", 200, 60, "Late summer raspberry, very large."],
    ["Glen Lyon",             "#d6202a", 180, 60, "Heavy-cropping summer raspberry."],
    ["Glen Moy",              "#d6202a", 200, 60, "Early summer raspberry, large fruit."],
    ["Glen Prosen",           "#d6202a", 180, 60, "Spine-free summer raspberry."],
    ["Heritage",              "#d6202a", 180, 60, "Autumn primocane raspberry."],
    ["Leo",                   "#d6202a", 180, 60, "Late summer raspberry, large firm fruit."],
    ["Malling Promise",       "#d6202a", 180, 60, "Heritage early summer raspberry."],
    ["Sceptre",               "#d6202a", 200, 60, "Modern primocane autumn raspberry."],
    ["Tadmor",                "#d6202a", 180, 60, "Modern raspberry, very tasty."],
    ["Terri Louise",          "#d6202a", 180, 60, "Modern autumn raspberry."],
    ["Valentina",             "#e89bc8", 180, 60, "Apricot-coloured raspberry."],
    ["Zeva",                  "#d6202a", 180, 60, "Swiss autumn raspberry."],
    ["Erika",                 "#d6202a", 180, 60, "Italian primocane raspberry."],
    ["All Gold",              "#f5d04a", 180, 60, "Yellow-fruited autumn raspberry."],
    ["Anne",                  "#f5d04a", 180, 60, "Yellow-fruited primocane raspberry."],
    ["Cascade Delight",       "#d6202a", 180, 60, "Modern US summer raspberry."],
  ],
  "Rubus fruticosus": [
    ["Helen",                 "#1a1a3a", 200, 120, "Spine-free early blackberry."],
    ["Loch Tay",              "#1a1a3a", 200, 120, "Modern UK blackberry, sweet."],
    ["Marion",                "#1a1a3a", 250, 150, "Heritage US blackberry."],
    ["Veronique",             "#1a1a3a", 200, 120, "Late blackberry, large fruit."],
    ["Reuben",                "#1a1a3a", 180, 100, "Compact thornless blackberry."],
    ["Triple Crown",          "#1a1a3a", 200, 120, "Heavy-cropping thornless blackberry."],
    ["Apache",                "#1a1a3a", 200, 120, "Thornless erect blackberry."],
    ["Asterina",              "#1a1a3a", 200, 120, "Modern blackberry, large fruit."],
    ["Chester",               "#1a1a3a", 200, 120, "Spine-free heavy cropper."],
    ["Karaka Black",          "#1a1a3a", 200, 120, "NZ blackberry, very large fruit."],
    ["Loch Maree",            "#1a1a3a", 200, 120, "Heritage Scottish blackberry."],
    ["Navaho",                "#1a1a3a", 200, 120, "Erect spine-free blackberry."],
    ["Ouachita",              "#1a1a3a", 200, 120, "Erect thornless blackberry."],
    ["Prime Ark",             "#1a1a3a", 200, 120, "Primocane blackberry, autumn-fruiting."],
  ],
  "Ribes nigrum": [
    ["Big Ben",               "#1a1a3a", 150, 120, "Modern blackcurrant, large berries."],
    ["Ben Connan",             "#1a1a3a", 100, 100, "Compact blackcurrant, early."],
    ["Ben More",              "#1a1a3a", 150, 120, "Late blackcurrant, heavy cropper."],
    ["Ben Tirran",            "#1a1a3a", 150, 120, "Very late blackcurrant, frost-tolerant."],
    ["Bona",                  "#1a1a3a", 150, 120, "Polish blackcurrant, modern."],
    ["Boskoop Giant",         "#1a1a3a", 150, 120, "Heritage Dutch blackcurrant."],
    ["Goliath",               "#1a1a3a", 150, 120, "Heritage Russian blackcurrant."],
    ["Jet",                   "#1a1a3a", 150, 120, "Heritage UK blackcurrant."],
    ["Laxton's Giant",        "#1a1a3a", 150, 120, "Heritage UK blackcurrant, large fruit."],
    ["Tihope",                "#1a1a3a", 150, 120, "NZ blackcurrant cultivar."],
    ["Titania",               "#1a1a3a", 150, 120, "Swedish blackcurrant, disease resistant."],
  ],
  "Ribes rubrum": [
    ["Junifer",               "#d6202a", 150, 120, "Early redcurrant, large fruit."],
    ["Laxton's No 1",         "#d6202a", 150, 120, "Heritage UK redcurrant."],
    ["Red Glory",             "#d6202a", 150, 120, "Modern redcurrant."],
    ["Red Start",             "#d6202a", 150, 120, "Late redcurrant."],
    ["Rolan",                 "#d6202a", 150, 120, "Dutch redcurrant."],
    ["Rondom",                "#d6202a", 150, 120, "Dutch heritage redcurrant."],
    ["Rovada",                "#d6202a", 150, 120, "Late Dutch redcurrant, very heavy cropper."],
    ["Stanza",                "#d6202a", 150, 120, "Heritage redcurrant, mid-late."],
    ["Witte Hollander",       "#f5e6a8", 150, 120, "White Dutch heritage currant."],
    ["Werdavia",              "#f5e6a8", 150, 120, "White currant heritage cultivar."],
    ["Pearl",                 "#f5e6a8", 150, 120, "Translucent white-currant."],
    ["White Grape",           "#f5e6a8", 150, 120, "Heritage white currant."],
    ["White Pearl",           "#f5e6a8", 150, 120, "Modern white currant."],
    ["White Dutch",           "#f5e6a8", 150, 120, "Old Dutch heritage white currant."],
    ["White Imperial",        "#f5e6a8", 150, 120, "Heritage US white currant."],
  ],
  "Ribes uva-crispa": [
    ["Achilles",              "#a01a2a", 120, 120, "Heritage red gooseberry."],
    ["Captivator",            "#d6202a", 120, 120, "Spine-free heritage gooseberry."],
    ["Careless",              "#9bc25a", 120, 120, "Heritage cooking gooseberry."],
    ["Crown Bob",             "#d6202a", 120, 120, "Heritage UK gooseberry."],
    ["Dan's Mistake",         "#d6202a", 120, 120, "Heritage gooseberry, large fruit."],
    ["Early Sulphur",         "#e8d04a", 120, 120, "Heritage yellow gooseberry."],
    ["Greenfinch",            "#9bc25a", 120, 120, "Modern green gooseberry."],
    ["Hinnonmaki Yellow",     "#e8d04a", 120, 120, "Finnish yellow gooseberry."],
    ["Hinnonmaki Green",      "#9bc25a", 120, 120, "Finnish green gooseberry."],
    ["Howard's Lancer",       "#9bc25a", 120, 120, "Heritage gooseberry."],
    ["Jubilee",               "#a01a2a", 120, 120, "Modern red gooseberry."],
    ["Keepsake",              "#9bc25a", 120, 120, "Heritage gooseberry, long picking."],
    ["Lancashire Lad",        "#a01a2a", 120, 120, "Heritage Lancashire red gooseberry."],
    ["Langley Gage",          "#9bc25a", 120, 120, "Heritage gooseberry, very sweet."],
    ["Leveller",              "#e8d04a", 120, 120, "Heritage yellow gooseberry, large fruit."],
    ["London",                "#a01a2a", 120, 120, "Heritage UK gooseberry, large dark fruit."],
    ["Lord Derby",            "#a01a2a", 120, 120, "Heritage red dessert gooseberry."],
    ["May Duke",              "#a01a2a", 120, 120, "Heritage early gooseberry."],
    ["Pax",                   "#a01a2a", 120, 120, "Modern spine-free gooseberry."],
    ["Rokula",                "#a01a2a", 120, 120, "Modern red dessert gooseberry."],
    ["Whitesmith",            "#9bc25a", 120, 120, "Heritage cooking gooseberry."],
    ["Yellow Champagne",      "#e8d04a", 120, 120, "Heritage yellow dessert gooseberry."],
    ["Hero of the Nile",      "#9bc25a", 120, 120, "Heritage UK gooseberry."],
    ["Surprise",              "#a01a2a", 120, 120, "Heritage UK gooseberry, dark fruit."],
  ],
  "Vaccinium corymbosum": [
    ["Brigitta",              "#3a5a8a", 150, 120, "Late summer blueberry, large fruit."],
    ["Bluetta",                "#3a5a8a", 80, 100, "Compact early blueberry."],
    ["Concord",               "#3a5a8a", 150, 120, "Mid-season blueberry, very hardy."],
    ["Coville",               "#3a5a8a", 180, 150, "Vigorous late blueberry."],
    ["Earliblue",             "#3a5a8a", 180, 150, "Very early blueberry."],
    ["Elliot",                "#3a5a8a", 150, 120, "Very late blueberry, firm berries."],
    ["Goldtraube",            "#3a5a8a", 180, 150, "German blueberry, abundant."],
    ["Herbert",               "#3a5a8a", 180, 150, "Late mid-season blueberry, large berry."],
    ["Jersey",                "#3a5a8a", 180, 150, "Heritage US blueberry, hardy."],
    ["Northland",             "#3a5a8a", 100, 100, "Compact half-high blueberry."],
    ["Ozark Blue",            "#3a5a8a", 180, 150, "Modern blueberry, very long picking."],
    ["Pioneer",               "#3a5a8a", 180, 150, "Heritage US blueberry."],
    ["Reka",                  "#3a5a8a", 180, 150, "NZ blueberry, very vigorous."],
    ["Sunshine Blue",         "#3a5a8a", 100, 100, "Compact patio blueberry, semi-evergreen."],
    ["Top Hat",               "#3a5a8a", 60, 60, "Dwarf patio blueberry."],
    ["Toro",                  "#3a5a8a", 180, 150, "Modern blueberry, very large berries."],
    ["Spartan",               "#3a5a8a", 180, 150, "Early blueberry, large fruit."],
    ["Berkeley",              "#3a5a8a", 180, 150, "Heritage US blueberry."],
    ["Aurora",                "#3a5a8a", 180, 150, "Modern very late blueberry."],
    ["Draper",                "#3a5a8a", 180, 150, "Modern blueberry, firm fruit."],
  ],
  "Vitis vinifera": [
    ["Boskoop Glory",         "#3a1a3a", 600, 400, "Dutch outdoor black grape, reliable."],
    ["Brant",                 "#3a1a3a", 600, 400, "Hardy outdoor red grape, autumn colour."],
    ["Cabernet Sauvignon",    "#3a1a3a", 600, 400, "Classic wine grape, late."],
    ["Chardonnay",            "#9bc28a", 600, 400, "Classic white wine grape."],
    ["Concord",               "#3a1a3a", 600, 400, "Heritage US grape, juicy."],
    ["Dornfelder",            "#3a1a3a", 600, 400, "German red wine grape, hardy."],
    ["Madeleine Angevine",    "#9bc28a", 600, 400, "Hardy outdoor white wine grape."],
    ["Madeleine Sylvaner",    "#9bc28a", 600, 400, "Early outdoor wine grape."],
    ["Orion",                 "#9bc28a", 600, 400, "Modern outdoor white wine grape."],
    ["Ortega",                "#9bc28a", 600, 400, "German white wine grape, sweet."],
    ["Pinot Noir",            "#3a1a3a", 600, 400, "Classic red wine grape."],
    ["Pinot Meunier",         "#3a1a3a", 600, 400, "Champagne grape."],
    ["Reichensteiner",        "#9bc28a", 600, 400, "Modern white grape, hardy."],
    ["Riesling",              "#9bc28a", 600, 400, "Classic German white wine grape."],
    ["Rondo",                 "#3a1a3a", 600, 400, "Modern outdoor red wine grape."],
    ["Schönburger",           "#9bc28a", 600, 400, "Modern outdoor white wine grape."],
    ["Seyval Blanc",          "#9bc28a", 600, 400, "Hybrid white wine grape, hardy."],
    ["Sieger",                "#9bc28a", 600, 400, "German outdoor white wine grape."],
    ["Solaris",               "#9bc28a", 600, 400, "Very early disease-resistant white grape."],
    ["Triomphe",              "#3a1a3a", 600, 400, "Hardy outdoor black grape."],
    ["Vroege van der Laan",   "#9bc28a", 600, 400, "Dutch outdoor white grape."],
    ["Cascade",               "#3a1a3a", 600, 400, "Hardy outdoor red grape."],
    ["Lakemont",              "#9bc28a", 600, 400, "Seedless outdoor white grape."],
    ["New York Muscat",       "#3a1a3a", 600, 400, "Muscat-flavoured outdoor grape."],
    ["Suffolk Red",           "#a01a3a", 600, 400, "Seedless outdoor red grape."],
  ],
  "Ficus carica": [
    ["Brown Turkey",          "#5a3a3a", 300, 300, "Reliable hardy UK fig, brown skin."],
    ["Brunswick",             "#5a3a3a", 300, 300, "Heritage UK fig, hardy."],
    ["White Marseilles",      "#9bc25a", 300, 300, "Heritage white fig, very sweet."],
    ["Black Mission",         "#1a1a1a", 300, 300, "Californian heritage black fig."],
    ["Adriatic",              "#9bc25a", 300, 300, "Heritage Italian fig."],
    ["Celeste",               "#5a3a3a", 300, 300, "US heritage fig, cold-hardy."],
    ["Chicago Hardy",         "#5a3a3a", 300, 300, "Very cold-hardy fig, brown fruit."],
    ["Desert King",           "#9bc25a", 300, 300, "Heritage green fig."],
    ["Ischia",                "#9bc25a", 300, 300, "Italian heritage fig, sweet."],
    ["Kadota",                "#9bc25a", 300, 300, "California heritage white fig."],
    ["Negronne",              "#3a1a3a", 300, 300, "French heritage dark fig."],
    ["Panaché",               "#a06f3a", 300, 300, "Striped fig, unusual."],
    ["Petite Negra",          "#3a1a3a", 250, 250, "Compact black fig, container."],
    ["Texas Everbearing",     "#5a3a3a", 300, 300, "Long picking US fig."],
    ["Violette de Bordeaux",  "#3a1a3a", 300, 300, "Compact French heritage fig."],
  ],
  "Morus nigra": [
    ["Chelsea",               "#5a1a2a", 600, 500, "Heritage UK black mulberry."],
    ["Charlotte Russe",       "#a01a2a", 200, 150, "Compact patio mulberry, fruits on new wood."],
    ["King James",            "#5a1a2a", 600, 500, "Heritage English black mulberry."],
    ["Persian",               "#5a1a2a", 600, 500, "Heritage Persian black mulberry."],
  ],
  "Morus alba": [
    ["Pendula",               "#f5e6a8", 400, 400, "Weeping white mulberry."],
    ["Issai",                 "#5a1a2a", 200, 150, "Compact white mulberry, dark fruits."],
    ["Pakistan",              "#5a1a2a", 600, 500, "Very long fruit, heritage Pakistani."],
  ],
  "Hippophae rhamnoides": [
    ["Leikora",               "#e8a04a", 300, 300, "Female sea buckthorn, large berries."],
    ["Pollmix",               "#7aaa5a", 300, 300, "Male sea buckthorn for pollination."],
    ["Friesdorfer Orange",    "#e8a04a", 300, 300, "German sea buckthorn cultivar."],
    ["Frugana",               "#e8a04a", 300, 300, "Heavy-cropping female sea buckthorn."],
    ["Hergo",                 "#e8a04a", 300, 300, "Heritage German sea buckthorn."],
  ],
  "Sambucus nigra": [
    ["Black Beauty",          "#1a1a1a", 300, 300, "Dark-foliaged ornamental elder."],
    ["Black Lace",            "#1a1a1a", 300, 300, "Cut-leaved black-foliaged elder."],
    ["Madonna",               "#9bc25a", 300, 300, "Cream-variegated elder."],
    ["Variegata",             "#9bc25a", 300, 300, "Variegated elder, white margin."],
    ["Aurea",                 "#e8d04a", 300, 300, "Golden-leaved elder."],
    ["Aurea-marginata",       "#e8d04a", 300, 300, "Gold-edged elder."],
    ["Albo-variegata",        "#9bc25a", 300, 300, "White-edged elder."],
    ["Black Tower",           "#1a1a1a", 300, 200, "Columnar dark-foliaged elder."],
  ],
  "Aronia melanocarpa": [
    ["Brilliant",             "#1a1a1a", 200, 200, "Brilliant autumn colour chokeberry."],
    ["Viking",                "#1a1a1a", 200, 200, "Heavy-cropping chokeberry."],
    ["Nero",                  "#1a1a1a", 200, 200, "Compact chokeberry, large berries."],
    ["Hugin",                 "#1a1a1a", 150, 200, "Compact chokeberry."],
    ["Aron",                  "#1a1a1a", 200, 200, "Heritage chokeberry."],
  ],
  "Vaccinium macrocarpon": [
    ["Pilgrim",               "#d6202a", 30, 60, "Heritage US cranberry."],
    ["Stevens",               "#d6202a", 30, 60, "Modern heavy-cropping cranberry."],
    ["Howes",                 "#d6202a", 30, 60, "Heritage US cranberry."],
    ["Early Black",           "#5a1a2a", 30, 60, "Heritage early cranberry."],
  ],
  "Vaccinium vitis-idaea": [
    ["Koralle",               "#a01a2a", 30, 40, "Compact lingonberry."],
    ["Red Pearl",             "#a01a2a", 30, 40, "Pearl-shaped lingonberry."],
    ["Erntedank",             "#a01a2a", 30, 40, "German lingonberry."],
    ["Sussi",                 "#a01a2a", 30, 40, "Swedish lingonberry."],
  ],
  "Lonicera caerulea": [
    ["Aurora",                "#3a5a8a", 200, 150, "Modern honeyberry, sweet large fruit."],
    ["Borealis",              "#3a5a8a", 200, 150, "Modern honeyberry, large oval fruit."],
    ["Cinderella",            "#3a5a8a", 200, 150, "Modern honeyberry, very sweet."],
    ["Honeybee",              "#3a5a8a", 200, 150, "Modern pollinator honeyberry."],
    ["Indigo Gem",            "#3a5a8a", 200, 150, "Canadian honeyberry."],
    ["Wojtek",                "#3a5a8a", 200, 150, "Polish honeyberry."],
    ["Maistar",               "#3a5a8a", 200, 150, "Czech honeyberry, very early."],
  ],
  "Actinidia deliciosa": [
    ["Hayward",               "#9bc28a", 500, 400, "Classic kiwi cultivar, large fruit."],
    ["Bruno",                 "#9bc28a", 500, 400, "Long fruit heritage kiwi."],
    ["Jenny",                 "#9bc28a", 400, 300, "Self-fertile kiwi for small gardens."],
    ["Jensen",                "#9bc28a", 500, 400, "Modern kiwi cultivar."],
    ["Solissimo",             "#9bc28a", 400, 300, "Self-fertile dwarf kiwi."],
  ],
  "Diospyros kaki": [
    ["Hachiya",               "#e8a04a", 500, 400, "Astringent classic Japanese persimmon."],
    ["Fuyu",                  "#e8a04a", 500, 400, "Non-astringent eating persimmon."],
    ["Jiro",                  "#e8a04a", 500, 400, "Compact non-astringent persimmon."],
    ["Sharon",                "#e8a04a", 500, 400, "Modern Israeli persimmon."],
    ["Saijo",                 "#e8a04a", 500, 400, "Japanese heritage persimmon, very sweet."],
  ],
  "Punica granatum": [
    ["Wonderful",             "#a01a2a", 400, 400, "Classic heritage pomegranate."],
    ["Eversweet",             "#d6202a", 400, 400, "Sweet pomegranate."],
    ["Sweet",                 "#a01a2a", 400, 400, "Heritage sweet pomegranate."],
    ["Granada",               "#a01a2a", 400, 400, "Spanish pomegranate."],
    ["Russian Red",           "#a01a2a", 400, 400, "Cold-hardy Russian heritage cultivar."],
    ["Mollar de Elche",       "#a01a2a", 400, 400, "Spanish heritage soft-seeded pomegranate."],
    ["Ariana",                "#a01a2a", 400, 400, "Modern hardy pomegranate."],
  ],
  "Citrus limon": [
    ["Eureka",                "#e8d04a", 300, 200, "Classic eating/cooking lemon."],
    ["Lisbon",                "#e8d04a", 300, 200, "Heritage hardy lemon."],
    ["Meyer",                 "#e8d04a", 250, 200, "Hybrid sweet lemon, compact." ],
    ["Verna",                 "#e8d04a", 300, 200, "Spanish heritage lemon."],
    ["Variegated Pink",       "#e8d04a", 250, 200, "Striped lemon with pink flesh."],
  ],
  "Citrus sinensis": [
    ["Washington Navel",      "#e89bc8", 300, 250, "Classic seedless dessert orange."],
    ["Valencia",              "#e8a04a", 300, 250, "Heritage juice orange."],
    ["Blood",                 "#a01a2a", 300, 250, "Sicilian heritage blood orange."],
    ["Cara Cara",             "#e89bc8", 300, 250, "Pink-fleshed navel orange."],
    ["Salustiana",            "#e8a04a", 300, 250, "Spanish heritage juice orange."],
  ],
  "Citrus aurantiifolia": [
    ["Persian",               "#9bc25a", 300, 200, "Classic large green lime."],
    ["Key",                   "#9bc25a", 300, 200, "Small aromatic key lime."],
    ["Bearss",                "#9bc25a", 300, 200, "Seedless heritage lime."],
    ["Kaffir",                "#9bc25a", 300, 200, "Aromatic leaves used in Thai cooking."],
  ],
};

function stubParent(latin, info, sample) {
  return {
    id: slugify(latin),
    name: info.common,
    latin,
    type: info.type,
    heightCm: sample[2], spreadCm: sample[3], colorHex: sample[1],
    bloomMonths: [], sowIndoorMonths: [], sowDirectMonths: [],
    transplantMonths: [], harvestMonths: [],
    preferredSoil: [], preferredSunlight: [],
    growersTips: "", germinationRequirements: "",
    companions: [], access: "pack_fruit", family: info.family,
    description: `Reference parent species for the ${info.common} cultivars.`,
  };
}

// MARK: - Apply

const data = JSON.parse(readFileSync(LIBRARY, "utf-8"));
const items = data.items;
const byLatin = new Map();
const byGenus = new Map();
for (const p of items) {
  byLatin.set(p.latin, p);
  const g = p.latin.split(/\s+/)[0];
  if (!byGenus.has(g)) byGenus.set(g, p);
}
const existingIds = new Set(items.map(p => p.id));
let added = 0, skipped = 0;

for (const [parentLatin, cultivars] of Object.entries(C)) {
  let parent = byLatin.get(parentLatin);
  if (!parent) {
    const g = parentLatin.split(/\s+/)[0];
    parent = byGenus.get(g);
  }
  if (!parent && PARENT_STUBS[parentLatin]) {
    parent = stubParent(parentLatin, PARENT_STUBS[parentLatin], cultivars[0]);
    if (!existingIds.has(parent.id)) {
      items.push(parent); existingIds.add(parent.id); added++;
    }
    byLatin.set(parentLatin, parent);
    const g = parentLatin.split(/\s+/)[0];
    if (!byGenus.has(g)) byGenus.set(g, parent);
  }
  if (!parent) { skipped += cultivars.length; continue; }

  const commonStem = parent.name.split(/[ ,]/)[0];
  for (const [cvName, hex, h, s, note] of cultivars) {
    const fullLatin = `${parentLatin} '${cvName}'`;
    const id = slugify(`${parentLatin}-${cvName}`);
    if (existingIds.has(id)) { skipped++; continue; }
    const row = {
      ...parent,
      id,
      name: `${commonStem} '${cvName}'`,
      latin: fullLatin,
      heightCm: h, spreadCm: s, colorHex: hex,
      description: note,
      // Force the new cultivars into pack_fruit regardless of the
      // parent's tag; retag-packs will keep them there because the
      // genus rules also map to fruit.
      access: "pack_fruit",
    };
    delete row.imageUrl;
    items.push(row);
    existingIds.add(id);
    added++;
  }
}

console.log(`Fruit cultivars added: ${added}  skipped: ${skipped}`);

if (!dryRun) {
  data.generated = new Date().toISOString();
  writeFileSync(LIBRARY, JSON.stringify(data, null, 2) + "\n");
  console.log(`✓ wrote ${LIBRARY} (${items.length} total items)`);
}
