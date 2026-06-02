#!/usr/bin/env node
/**
 * add-cultivars.mjs — appends hand-authored cultivar rows to
 * backend/data/library.json so the picker has named varieties to choose
 * from, not just botanical species.
 *
 * Each cultivar inherits its parent species' editorial data (image,
 * preferred soil/sunlight/etc.) and overrides only the cultivar-specific
 * tweaks (height, spread, colour). Output rows match the v2 LIBRARY
 * shape produced by ingest-plants.mjs so the iOS Plant Codable still
 * decodes cleanly.
 *
 * Idempotent: re-running skips any cultivar id already present in the
 * library.
 *
 * Usage:
 *   node scripts/add-cultivars.mjs            # writes in place
 *   node scripts/add-cultivars.mjs --dry-run
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

// Cultivar definitions grouped by parent species (Latin binomial).
// Each entry: cultivar name (single quotes), colourHex, heightCm,
// spreadCm, optional notes string appended to the description.
//
// Sources: RHS Award of Garden Merit lists, common UK garden cultivar
// rosters, and well-known kitchen-garden varieties.

const CULTIVARS = {
  // ── Ornamental perennials & shrubs ─────────────────────────────────
  "Lavandula angustifolia": [
    { name: "Hidcote",       hex: "#7a5d9c", h: 45, s: 50, note: "Compact dark-purple lavender; classic edging." },
    { name: "Munstead",      hex: "#9c80c2", h: 45, s: 55, note: "Soft-blue early-flowering lavender." },
    { name: "Loddon Pink",   hex: "#e8b8c8", h: 50, s: 55, note: "Soft pink spires." },
    { name: "Alba",          hex: "#f5f5f5", h: 55, s: 55, note: "Pure white lavender." },
    { name: "Imperial Gem",  hex: "#5e4a82", h: 50, s: 55, note: "Deep violet; long flowering." },
  ],
  "Rosa": [
    { name: "Gertrude Jekyll",  hex: "#e87bb0", h: 150, s: 110, note: "David Austin English rose; richly fragrant pink." },
    { name: "Graham Thomas",    hex: "#f4d76b", h: 150, s: 130, note: "Apricot-yellow English rose." },
    { name: "Munstead Wood",    hex: "#8a2a3a", h: 100, s: 90,  note: "Deep velvety crimson." },
    { name: "Iceberg",          hex: "#f5f5f5", h: 120, s: 100, note: "Reliable white floribunda." },
    { name: "Mister Lincoln",   hex: "#9c1f24", h: 150, s: 110, note: "Dark red hybrid tea, strong scent." },
    { name: "Peace",            hex: "#f5e6a8", h: 140, s: 110, note: "Classic yellow-pink hybrid tea." },
    { name: "Queen Elizabeth",  hex: "#f0a8c8", h: 180, s: 120, note: "Tall pink grandiflora." },
    { name: "The Pilgrim",      hex: "#f4d76b", h: 140, s: 120, note: "Soft yellow English rose, very floriferous." },
  ],
  "Salvia nemorosa": [
    { name: "Caradonna",   hex: "#5a3a8a", h: 60,  s: 45, note: "Dark-stemmed violet spires." },
    { name: "Mainacht",    hex: "#3e2e7a", h: 55,  s: 45, note: "Indigo flowers, early." },
    { name: "Amethyst",    hex: "#a06fc8", h: 60,  s: 45, note: "Light purple, long flowering." },
    { name: "Schwellenburg", hex: "#d68fc8", h: 55, s: 45, note: "Bright pink." },
  ],
  "Hosta": [
    { name: "Frances Williams", hex: "#9bc28a", h: 60, s: 90, note: "Blue-green leaves with gold margin." },
    { name: "Sum and Substance", hex: "#c2c25a", h: 75, s: 120, note: "Huge chartreuse leaves." },
    { name: "Halcyon",          hex: "#7a9bc2", h: 40, s: 70,  note: "Blue-leaved compact hosta." },
    { name: "Patriot",          hex: "#5a8a4d", h: 50, s: 80,  note: "Dark-green with white margin." },
    { name: "June",             hex: "#9bc25a", h: 40, s: 80,  note: "Blue-edged gold heart." },
  ],
  "Hydrangea macrophylla": [
    { name: "Annabelle",          hex: "#f0f0f0", h: 120, s: 150, note: "Huge white mophead." },
    { name: "Endless Summer",     hex: "#8aaae0", h: 100, s: 120, note: "Reblooming blue/pink." },
    { name: "Nikko Blue",         hex: "#5a8aca", h: 150, s: 150, note: "Classic blue mophead in acid soil." },
    { name: "Pia",                hex: "#d65a91", h: 60,  s: 80,  note: "Dwarf pink mophead." },
  ],
  "Helleborus orientalis": [
    { name: "Double Ellen Red",   hex: "#7a2a3a", h: 45, s: 50, note: "Double dark-red blooms." },
    { name: "Pretty Ellen Pink",  hex: "#e8a0c0", h: 45, s: 50, note: "Double soft pink." },
    { name: "Anna's Red",         hex: "#a02a4a", h: 40, s: 45, note: "Marbled foliage, wine-red blooms." },
  ],
  "Echinacea purpurea": [
    { name: "Magnus",         hex: "#c25a7a", h: 90,  s: 50, note: "Reliable purple coneflower." },
    { name: "White Swan",     hex: "#f5f5f5", h: 80,  s: 50, note: "Crisp white coneflower." },
    { name: "Cheyenne Spirit", hex: "#e8a04a", h: 70,  s: 50, note: "Mixed warm shades, seed-grown." },
    { name: "Green Envy",     hex: "#9bc28a", h: 90,  s: 50, note: "Unusual green-petalled cultivar." },
  ],
  "Geranium": [
    { name: "Rozanne",         hex: "#5a7bc8", h: 50, s: 90, note: "Long-blooming violet-blue cranesbill." },
    { name: "Johnson's Blue",  hex: "#7a9bc2", h: 40, s: 60, note: "Classic mid-blue hardy geranium." },
    { name: "Ann Folkard",     hex: "#a02a8a", h: 50, s: 90, note: "Magenta with gold foliage." },
  ],
  "Clematis": [
    { name: "Nelly Moser",      hex: "#e0a0c0", h: 300, s: 100, note: "Pale pink with darker bar." },
    { name: "Jackmanii",        hex: "#5a2a8a", h: 350, s: 100, note: "Deep velvety purple, vigorous." },
    { name: "The President",    hex: "#5a4a9c", h: 300, s: 100, note: "Rich purple, free-flowering." },
    { name: "Niobe",            hex: "#7a1a2a", h: 300, s: 100, note: "Deep ruby red." },
    { name: "Princess Diana",   hex: "#d65a91", h: 300, s: 100, note: "Tulip-shaped pink, late season." },
  ],
  "Achillea millefolium": [
    { name: "Cerise Queen",  hex: "#d65a91", h: 70, s: 60, note: "Bright cerise pink." },
    { name: "Paprika",       hex: "#d65a3a", h: 70, s: 60, note: "Brick-red yarrow, fading to peach." },
    { name: "Moonshine",     hex: "#f5e070", h: 60, s: 60, note: "Soft yellow with silvery leaves." },
  ],
  "Hemerocallis": [
    { name: "Stella de Oro",   hex: "#f5d04a", h: 40, s: 50, note: "Compact reblooming yellow daylily." },
    { name: "Pardon Me",       hex: "#a01a2a", h: 50, s: 50, note: "Compact crimson daylily, evening fragrance." },
    { name: "Happy Returns",   hex: "#f5e070", h: 45, s: 50, note: "Bright lemon-yellow reblooming." },
  ],
  "Camellia japonica": [
    { name: "Adolphe Audusson",   hex: "#a02a4a", h: 300, s: 200, note: "Semi-double red, classic mid-season." },
    { name: "Bob Hope",           hex: "#5a1a2a", h: 250, s: 180, note: "Deep red double, late." },
    { name: "Pink Perfection",    hex: "#e8a0c0", h: 350, s: 200, note: "Formal double pink." },
  ],
  "Rhododendron": [
    { name: "Cunningham's White", hex: "#f5f5f5", h: 200, s: 200, note: "Reliable hardy white." },
    { name: "Nova Zembla",        hex: "#a01a2a", h: 250, s: 220, note: "Deep red, very hardy." },
    { name: "Cynthia",            hex: "#d65a91", h: 350, s: 300, note: "Classic rose-pink rhododendron." },
  ],
  "Buxus sempervirens": [
    { name: "Suffruticosa", hex: "#5a7a4a", h: 60,  s: 60, note: "Dwarf box for low edging." },
    { name: "Elegantissima", hex: "#9bc28a", h: 100, s: 100, note: "Variegated cream margins." },
  ],
  "Acer palmatum": [
    { name: "Bloodgood",       hex: "#7a1a2a", h: 400, s: 300, note: "Deep red-purple Japanese maple." },
    { name: "Dissectum Atropurpureum", hex: "#5a1a3a", h: 200, s: 250, note: "Cut-leaved purple weeping form." },
    { name: "Sango-kaku",      hex: "#d65a3a", h: 400, s: 300, note: "Coral-bark maple, red winter twigs." },
  ],
  "Wisteria sinensis": [
    { name: "Prolific",  hex: "#8a6fbc", h: 800, s: 800, note: "Free-flowering lilac-blue Chinese wisteria." },
    { name: "Alba",      hex: "#f5f5f5", h: 800, s: 800, note: "White Chinese wisteria." },
  ],
  "Magnolia grandiflora": [
    { name: "Exmouth",     hex: "#f5f0d0", h: 800, s: 500, note: "Hardy English-grown evergreen magnolia." },
    { name: "Goliath",     hex: "#f5f5f0", h: 700, s: 500, note: "Huge waxy white blooms." },
  ],
  "Sempervivum tectorum": [
    { name: "Atropurpureum", hex: "#7a3a4a", h: 8, s: 15, note: "Burgundy houseleek." },
    { name: "Silverine",     hex: "#bcbcbc", h: 8, s: 15, note: "Silver-grey rosettes." },
    { name: "Royal Ruby",    hex: "#9c1a3a", h: 8, s: 15, note: "Deep ruby rosettes." },
  ],
  "Sedum spectabile": [
    { name: "Autumn Joy",     hex: "#c25a7a", h: 50, s: 50, note: "Pink-to-rust autumn flowers." },
    { name: "Brilliant",      hex: "#d65a91", h: 45, s: 50, note: "Bright rose-pink heads." },
  ],
  "Saxifraga": [
    { name: "Tumbling Waters", hex: "#f5f5f5", h: 30, s: 30, note: "Cascading white rockery saxifrage." },
    { name: "Peter Pan",       hex: "#c25a7a", h: 8,  s: 15, note: "Compact pink mossy saxifrage." },
  ],
  "Primula vulgaris": [
    { name: "Wanda",         hex: "#7a2a8a", h: 12, s: 20, note: "Deep purple primrose." },
    { name: "Belarina",      hex: "#e8a0c0", h: 15, s: 20, note: "Double-flowered primrose series." },
  ],
  "Dianthus": [
    { name: "Doris",         hex: "#e89bc8", h: 35, s: 30, note: "Salmon-pink pink with darker eye." },
    { name: "Mrs Sinkins",   hex: "#f5f5f5", h: 30, s: 30, note: "Fragrant white pink." },
  ],

  // ── Fruit-bearing genera (priority for the Fruit pack) ─────────────
  "Malus domestica": [
    { name: "Bramley's Seedling", hex: "#9bc25a", h: 500, s: 500, note: "Classic cooking apple, sharp and tart." },
    { name: "Cox's Orange Pippin", hex: "#d65a3a", h: 400, s: 400, note: "Aromatic dessert apple, late September." },
    { name: "Egremont Russet",    hex: "#a06f4a", h: 400, s: 400, note: "Nutty russet dessert apple." },
    { name: "Discovery",          hex: "#d65a3a", h: 400, s: 400, note: "Crisp early dessert apple." },
    { name: "Gala",               hex: "#e8a04a", h: 400, s: 400, note: "Sweet red-striped dessert apple." },
    { name: "Granny Smith",       hex: "#9bc25a", h: 400, s: 400, note: "Crisp green eating + cooking apple." },
    { name: "Worcester Pearmain", hex: "#d65a3a", h: 400, s: 400, note: "Strawberry-scented red apple." },
    { name: "Russet",             hex: "#a06f4a", h: 400, s: 400, note: "Rough-skinned heritage dessert apple." },
    { name: "James Grieve",       hex: "#d6a04a", h: 400, s: 400, note: "Dual-purpose dessert/cooking apple." },
    { name: "Howgate Wonder",     hex: "#9bc25a", h: 450, s: 450, note: "Heavy cropping cooking apple." },
  ],
  "Pyrus communis": [
    { name: "Conference",   hex: "#7aaa5a", h: 500, s: 350, note: "Reliable self-fertile pear." },
    { name: "Doyenné du Comice", hex: "#9bc25a", h: 500, s: 350, note: "Buttery flesh, finest dessert pear." },
    { name: "Williams' Bon Chrétien", hex: "#bcb24a", h: 500, s: 350, note: "Classic Bartlett pear." },
    { name: "Beurré Hardy", hex: "#a08a4a", h: 500, s: 350, note: "Russet pear, melting flesh." },
    { name: "Concorde",     hex: "#9bc25a", h: 400, s: 300, note: "Conference × Comice; compact heavy cropper." },
  ],
  "Prunus avium": [
    { name: "Stella",        hex: "#7a1a2a", h: 500, s: 400, note: "Self-fertile dark sweet cherry." },
    { name: "Sunburst",      hex: "#9c1a3a", h: 500, s: 400, note: "Self-fertile large dark red cherry." },
    { name: "Sweetheart",    hex: "#a01a2a", h: 500, s: 400, note: "Late-cropping self-fertile cherry." },
  ],
  "Prunus domestica": [
    { name: "Victoria",     hex: "#d65a91", h: 400, s: 350, note: "Self-fertile dessert/cooking plum." },
    { name: "Marjorie's Seedling", hex: "#5a1a3a", h: 400, s: 350, note: "Late-cropping dark cooking plum." },
    { name: "Czar",         hex: "#5a1a3a", h: 350, s: 300, note: "Hardy cooking plum, very reliable." },
  ],
  "Prunus persica": [
    { name: "Peregrine",     hex: "#d68f6a", h: 400, s: 350, note: "Hardy white-fleshed peach for UK walls." },
    { name: "Rochester",     hex: "#e8a04a", h: 400, s: 350, note: "Yellow-fleshed reliable peach." },
  ],
  "Fragaria × ananassa": [
    { name: "Cambridge Favourite", hex: "#d6202a", h: 20, s: 30, note: "Reliable mid-season strawberry." },
    { name: "Honeoye",       hex: "#d6202a", h: 20, s: 30, note: "Early heavy-cropping strawberry." },
    { name: "Florence",      hex: "#d6202a", h: 20, s: 30, note: "Late-season strawberry, disease resistant." },
    { name: "Mara des Bois",  hex: "#d6202a", h: 20, s: 30, note: "Wild-strawberry-flavoured everbearer." },
    { name: "Symphony",      hex: "#d6202a", h: 20, s: 30, note: "Late summer strawberry, large fruits." },
    { name: "Pegasus",       hex: "#d6202a", h: 20, s: 30, note: "Mid-season strawberry, resistant to mildew." },
  ],
  "Rubus idaeus": [
    { name: "Glen Ample",    hex: "#d6202a", h: 180, s: 60, note: "Heavy summer-fruiting raspberry, spine-free." },
    { name: "Autumn Bliss",  hex: "#d6202a", h: 150, s: 60, note: "Autumn-fruiting raspberry, fruits on new canes." },
    { name: "Polka",         hex: "#d6202a", h: 150, s: 60, note: "Heavy autumn primocane raspberry." },
    { name: "Tulameen",      hex: "#d6202a", h: 180, s: 60, note: "Large-fruited summer raspberry, sweet flavour." },
  ],
  "Rubus fruticosus": [
    { name: "Loch Ness",     hex: "#1a1a3a", h: 200, s: 120, note: "Thornless heavy-cropping blackberry." },
    { name: "Oregon Thornless", hex: "#1a1a3a", h: 250, s: 150, note: "Parsley-leaved thornless blackberry." },
    { name: "Black Butte",   hex: "#1a1a3a", h: 200, s: 120, note: "Huge berries, early ripening." },
  ],
  "Ribes nigrum": [
    { name: "Ben Sarek",     hex: "#1a1a3a", h: 100, s: 100, note: "Compact blackcurrant for small gardens." },
    { name: "Ben Hope",      hex: "#1a1a3a", h: 150, s: 120, note: "Heavy-cropping blackcurrant, aphid resistant." },
    { name: "Ben Lomond",    hex: "#1a1a3a", h: 150, s: 120, note: "Reliable mid-season blackcurrant." },
  ],
  "Ribes rubrum": [
    { name: "Jonkheer van Tets", hex: "#d6202a", h: 150, s: 120, note: "Heavy early-cropping redcurrant." },
    { name: "Red Lake",         hex: "#d6202a", h: 150, s: 120, note: "Mid-season redcurrant, long sprigs." },
    { name: "White Versailles", hex: "#f5e6a8", h: 150, s: 120, note: "Translucent white-currant." },
  ],
  "Ribes uva-crispa": [
    { name: "Invicta",          hex: "#9bc25a", h: 120, s: 120, note: "Mildew-resistant gooseberry." },
    { name: "Hinnonmaki Red",   hex: "#a01a2a", h: 120, s: 120, note: "Dessert gooseberry, dark red when ripe." },
    { name: "Whinham's Industry", hex: "#a01a2a", h: 120, s: 120, note: "Heritage red gooseberry, heavy cropper." },
  ],
  "Vaccinium corymbosum": [
    { name: "Bluecrop",      hex: "#3a5a8a", h: 150, s: 120, note: "Reliable mid-season blueberry." },
    { name: "Duke",          hex: "#3a5a8a", h: 120, s: 100, note: "Early blueberry, big sweet berries." },
    { name: "Chandler",      hex: "#3a5a8a", h: 150, s: 120, note: "Late-summer blueberry, huge berries." },
    { name: "Patriot",       hex: "#3a5a8a", h: 150, s: 120, note: "Hardy blueberry, attractive autumn colour." },
  ],
  "Vitis vinifera": [
    { name: "Black Hamburgh", hex: "#3a1a3a", h: 600, s: 400, note: "Classic glasshouse black dessert grape." },
    { name: "Müller-Thurgau", hex: "#9bc28a", h: 500, s: 400, note: "Reliable white grape for UK outdoors." },
    { name: "Phoenix",        hex: "#9bc28a", h: 500, s: 400, note: "Disease-resistant white wine grape." },
    { name: "Regent",         hex: "#3a1a3a", h: 500, s: 400, note: "Hardy red wine grape." },
  ],

  // ── Kitchen-garden vegetables & herbs ──────────────────────────────
  "Solanum lycopersicum": [
    { name: "Gardener's Delight", hex: "#d6202a", h: 200, s: 60, note: "Reliable cordon cherry tomato." },
    { name: "Sungold",          hex: "#f5b04a", h: 200, s: 60, note: "Orange cherry tomato, super sweet." },
    { name: "Black Russian",    hex: "#3a1a3a", h: 200, s: 60, note: "Dark-fruited heirloom beefsteak." },
    { name: "San Marzano",      hex: "#d6202a", h: 200, s: 60, note: "Italian plum tomato, ideal for sauce." },
    { name: "Moneymaker",       hex: "#d6202a", h: 200, s: 60, note: "Heavy-cropping greenhouse classic." },
    { name: "Tigerella",        hex: "#d6504a", h: 200, s: 60, note: "Striped red-and-yellow heirloom." },
    { name: "Brandywine",       hex: "#a01a2a", h: 200, s: 60, note: "Pink heirloom beefsteak, rich flavour." },
  ],
  "Capsicum annuum": [
    { name: "Bell Boy",      hex: "#d6202a", h: 80, s: 50, note: "Heavy-cropping bell pepper." },
    { name: "Sweet Banana",  hex: "#f5d04a", h: 80, s: 50, note: "Long yellow sweet pepper." },
    { name: "Hungarian Hot Wax", hex: "#f5b04a", h: 80, s: 50, note: "Mild-to-hot yellow pepper." },
    { name: "Cayenne",       hex: "#d6202a", h: 80, s: 50, note: "Slim red chilli pepper, dries well." },
    { name: "Jalapeño",      hex: "#3a7a3a", h: 80, s: 50, note: "Classic Mexican mid-hot chilli." },
  ],
  "Lactuca sativa": [
    { name: "Little Gem",    hex: "#7aaa5a", h: 20, s: 20, note: "Compact sweet cos lettuce." },
    { name: "Tom Thumb",     hex: "#9bc28a", h: 15, s: 20, note: "Tiny butterhead, fast." },
    { name: "Lollo Rosso",   hex: "#a01a3a", h: 25, s: 25, note: "Loose-leaf red frilly lettuce." },
    { name: "Salad Bowl",    hex: "#7aaa5a", h: 25, s: 30, note: "Cut-and-come-again loose-leaf." },
    { name: "Webb's Wonderful", hex: "#9bc28a", h: 30, s: 30, note: "Reliable crisp head lettuce." },
  ],
  "Brassica oleracea": [
    { name: "Calabrese",       hex: "#7aaa5a", h: 80, s: 50, note: "Sprouting broccoli with central head." },
    { name: "Purple Sprouting", hex: "#5a3a8a", h: 100, s: 60, note: "Hardy purple-sprouting broccoli." },
    { name: "Cavolo Nero",     hex: "#3a5a3a", h: 80, s: 60, note: "Tuscan black kale." },
    { name: "Red Drumhead",    hex: "#7a3a8a", h: 50, s: 60, note: "Compact red cabbage." },
  ],
  "Daucus carota": [
    { name: "Nantes 2",      hex: "#d65a3a", h: 30, s: 5, note: "Sweet sweet stump-rooted carrot." },
    { name: "Autumn King",   hex: "#d65a3a", h: 30, s: 5, note: "Heavy long-rooted maincrop." },
    { name: "Purple Haze",   hex: "#5a2a8a", h: 30, s: 5, note: "Purple-skinned heritage carrot." },
    { name: "Paris Market",  hex: "#d65a3a", h: 15, s: 5, note: "Round baby carrot, ideal for shallow soil." },
  ],
  "Ocimum basilicum": [
    { name: "Sweet Genovese", hex: "#5a8a4d", h: 30, s: 25, note: "Classic Italian basil for pesto." },
    { name: "Purple Ruffles", hex: "#3a1a4a", h: 30, s: 25, note: "Crinkled purple-leaved basil." },
    { name: "Thai",           hex: "#5a8a4d", h: 35, s: 25, note: "Aniseed-scented basil for Asian cooking." },
    { name: "Greek",          hex: "#5a8a4d", h: 20, s: 20, note: "Tight-leaved compact basil." },
  ],
  "Thymus vulgaris": [
    { name: "Silver Posie",  hex: "#7a8a4d", h: 25, s: 30, note: "Silver-variegated culinary thyme." },
    { name: "Lemon",         hex: "#7a8a4d", h: 25, s: 30, note: "Lemon-scented thyme." },
    { name: "Provence",      hex: "#7a8a4d", h: 30, s: 35, note: "French culinary thyme." },
  ],
  "Mentha": [
    { name: "Spearmint",     hex: "#7aaa5a", h: 40, s: 60, note: "Classic mint for sauce." },
    { name: "Peppermint",    hex: "#5a8a4d", h: 40, s: 60, note: "Sharper mint for tea." },
    { name: "Chocolate",     hex: "#5a4a3a", h: 40, s: 60, note: "Chocolate-scented mint." },
    { name: "Apple",         hex: "#7aaa5a", h: 40, s: 60, note: "Soft apple-scented mint." },
  ],
};

// Hand-authored stub parents — used when the Wikidata ingest didn't
// return a record for the parent species. The stub seeds enough fields
// that retag-packs.mjs can still slot the row into the right pack.

const PARENT_STUBS = {
  "Lavandula angustifolia": { common: "Lavender", type: "perennial", family: "Lamiaceae", access: "free" },
  "Rosa": { common: "Rose", type: "shrub", family: "Rosaceae", access: "pack_rockery" },
  "Salvia nemorosa": { common: "Wood Sage", type: "perennial", family: "Lamiaceae", access: "pro" },
  "Achillea millefolium": { common: "Yarrow", type: "perennial", family: "Asteraceae", access: "pro" },
  "Hemerocallis": { common: "Daylily", type: "perennial", family: "Asphodelaceae", access: "pro" },
  "Rhododendron": { common: "Rhododendron", type: "shrub", family: "Ericaceae", access: "pack_rockery" },
  "Acer palmatum": { common: "Japanese Maple", type: "shrub", family: "Sapindaceae", access: "pack_rockery" },
  "Wisteria sinensis": { common: "Chinese Wisteria", type: "perennial", family: "Fabaceae", access: "pro" },
  "Sempervivum tectorum": { common: "Houseleek", type: "perennial", family: "Crassulaceae", access: "pack_rockery" },
  "Sedum spectabile": { common: "Showy Stonecrop", type: "perennial", family: "Crassulaceae", access: "pack_rockery" },
  "Saxifraga": { common: "Saxifrage", type: "perennial", family: "Saxifragaceae", access: "pack_rockery" },
  "Primula vulgaris": { common: "Primrose", type: "perennial", family: "Primulaceae", access: "free" },
  "Pyrus communis": { common: "Pear", type: "shrub", family: "Rosaceae", access: "pack_fruit" },
  "Prunus avium": { common: "Sweet Cherry", type: "shrub", family: "Rosaceae", access: "pack_fruit" },
  "Prunus domestica": { common: "Plum", type: "shrub", family: "Rosaceae", access: "pack_fruit" },
  "Prunus persica": { common: "Peach", type: "shrub", family: "Rosaceae", access: "pack_fruit" },
  "Rubus idaeus": { common: "Raspberry", type: "shrub", family: "Rosaceae", access: "pack_fruit" },
  "Rubus fruticosus": { common: "Blackberry", type: "shrub", family: "Rosaceae", access: "pack_fruit" },
  "Ribes nigrum": { common: "Blackcurrant", type: "shrub", family: "Grossulariaceae", access: "pack_fruit" },
  "Ribes rubrum": { common: "Redcurrant", type: "shrub", family: "Grossulariaceae", access: "pack_fruit" },
  "Ribes uva-crispa": { common: "Gooseberry", type: "shrub", family: "Grossulariaceae", access: "pack_fruit" },
  "Vaccinium corymbosum": { common: "Highbush Blueberry", type: "shrub", family: "Ericaceae", access: "pack_fruit" },
  "Vitis vinifera": { common: "Grape Vine", type: "perennial", family: "Vitaceae", access: "pack_fruit" },
  "Lactuca sativa": { common: "Lettuce", type: "vegetable", family: "Asteraceae", access: "pack_edible" },
  "Ocimum basilicum": { common: "Basil", type: "herb", family: "Lamiaceae", access: "pack_edible" },
  "Thymus vulgaris": { common: "Thyme", type: "herb", family: "Lamiaceae", access: "pack_edible" },
  "Mentha": { common: "Mint", type: "herb", family: "Lamiaceae", access: "pack_edible" },
  "Capsicum annuum": { common: "Pepper", type: "vegetable", family: "Solanaceae", access: "pack_edible" },
  "Daucus carota": { common: "Carrot", type: "vegetable", family: "Apiaceae", access: "pack_edible" },
  "Camellia japonica": { common: "Camellia", type: "shrub", family: "Theaceae", access: "pack_rockery" },
  "Buxus sempervirens": { common: "Box", type: "shrub", family: "Buxaceae", access: "pack_rockery" },
  "Magnolia grandiflora": { common: "Bull Bay", type: "shrub", family: "Magnoliaceae", access: "pack_rockery" },
  "Hydrangea macrophylla": { common: "Hydrangea", type: "shrub", family: "Hydrangeaceae", access: "pack_rockery" },
};

function stubParent(latin, info, sample) {
  // Use the first cultivar entry as a default for fields we couldn't
  // hand-author (most importantly the editorial colourHex).
  return {
    id: slugify(latin),
    name: info.common,
    latin,
    type: info.type,
    heightCm: sample.h,
    spreadCm: sample.s,
    colorHex: sample.hex,
    bloomMonths: [],
    sowIndoorMonths: [], sowDirectMonths: [],
    transplantMonths: [], harvestMonths: [],
    preferredSoil: [], preferredSunlight: [],
    growersTips: "",
    germinationRequirements: "",
    companions: [],
    access: info.access,
    family: info.family,
    description: `Reference parent species for the ${info.common} cultivars.`,
  };
}

// MARK: - Load library + parent lookup

const data = JSON.parse(readFileSync(LIBRARY, "utf-8"));
const items = data.items;

// Index parent species by Latin binomial AND by genus (first token).
const byLatin = new Map();
const byGenus = new Map();
for (const p of items) {
  byLatin.set(p.latin, p);
  const genus = p.latin.split(/\s+/)[0];
  if (!byGenus.has(genus)) byGenus.set(genus, p);
}

const existingIds = new Set(items.map(p => p.id));
let added = 0, skipped = 0;
const skippedParents = new Set();

for (const [parentLatin, cultivars] of Object.entries(CULTIVARS)) {
  // Try to find a parent species by exact Latin first, then by genus.
  let parent = byLatin.get(parentLatin);
  if (!parent) {
    const genus = parentLatin.split(/\s+/)[0];
    parent = byGenus.get(genus);
  }
  if (!parent && PARENT_STUBS[parentLatin]) {
    parent = stubParent(parentLatin, PARENT_STUBS[parentLatin], cultivars[0]);
    if (!existingIds.has(parent.id)) {
      items.push(parent);
      existingIds.add(parent.id);
      added++;
    }
    byLatin.set(parentLatin, parent);
    const g = parentLatin.split(/\s+/)[0];
    if (!byGenus.has(g)) byGenus.set(g, parent);
  }
  if (!parent) {
    skippedParents.add(parentLatin);
    continue;
  }

  for (const cv of cultivars) {
    const fullLatin = `${parentLatin} '${cv.name}'`;
    const id = slugify(`${parentLatin}-${cv.name}`);
    if (existingIds.has(id)) { skipped++; continue; }

    const commonStem = parent.name.split(/[ ,]/)[0];
    const row = {
      ...parent,
      id,
      name: `${commonStem} '${cv.name}'`,
      latin: fullLatin,
      heightCm: cv.h,
      spreadCm: cv.s,
      colorHex: cv.hex,
      description: cv.note,
      // Cultivars inherit the parent's access tag; retag-packs.mjs will
      // still apply genus / type rules over the top.
      access: parent.access,
    };
    // Drop the imageUrl rather than mis-attribute the species photo to
    // a named cultivar that may look different.
    delete row.imageUrl;
    items.push(row);
    existingIds.add(id);
    added++;
  }
}

console.log(`Cultivars added: ${added}  skipped (already present): ${skipped}`);
if (skippedParents.size) {
  console.log(`Parents not found in library, skipped: ${[...skippedParents].join(", ")}`);
}

if (!dryRun) {
  data.generated = new Date().toISOString();
  writeFileSync(LIBRARY, JSON.stringify(data, null, 2) + "\n");
  console.log(`✓ wrote ${LIBRARY} (${items.length} total items)`);
}
