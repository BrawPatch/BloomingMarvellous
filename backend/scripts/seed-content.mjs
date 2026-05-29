#!/usr/bin/env node
/**
 * seed-content.mjs — uploads /home, /data and /library content to S3.
 *
 * Idempotent: re-running overwrites the same S3 keys. Safe to call on every
 * deploy. The Lambda fetches these on every /v1/home, /v1/data and
 * /v1/library request and filters items based on the caller's tier and
 * purchased packs.
 *
 * Schema (v2) — /home and /data:
 *   {
 *     "version": 2,
 *     "items": [
 *       { "id": "lavender",       "label": "Lavender — sow Mar–May", "access": "free" },
 *       { "id": "cosmos",         "label": "Cosmos — sow Mar–Apr",   "access": "pro" },
 *       { "id": "phalaenopsis",   "label": "Phalaenopsis Orchid",    "access": "pack_exotic" },
 *       { "id": "tomato-gardener","label": "Tomato — sow Mar–Apr",   "access": "pack_edible" }
 *     ]
 *   }
 *
 * Schema (v2) — /library: items[] are Plant objects whose shape MUST mirror
 * Sources/Models/Plant.swift Codable. Enum values use raw string values
 * ("loam", "sunny_always", "perennial", ...). Optional fields (heightCm,
 * colorHex, buyLink) may be omitted.
 *
 * `access` values:
 *   "free"         visible to every authenticated user
 *   "pro"          visible to tier=pro users
 *   "pack_exotic"  visible to tier=pro users with pack_exotic purchased
 *   "pack_edible"  visible to tier=pro users with pack_edible purchased
 *
 * Usage:
 *   node scripts/seed-content.mjs --env development
 *   node scripts/seed-content.mjs --env production
 *
 * Env overrides:
 *   S3_BUCKET   explicit bucket (skips terraform output lookup)
 *   AWS_REGION  defaults to us-east-1
 *   AWS_PROFILE forwarded to the SDK (use the right SSO profile per env)
 */

import { execSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";

// ── Args ─────────────────────────────────────────────────────────────────────

function parseArgs(argv) {
  const args = { env: null };
  for (let i = 2; i < argv.length; i++) {
    if (argv[i] === "--env" && argv[i + 1]) {
      args.env = argv[++i];
    }
  }
  return args;
}

const { env } = parseArgs(process.argv);
if (!env || !["development", "production"].includes(env)) {
  console.error("Usage: node scripts/seed-content.mjs --env development|production");
  process.exit(1);
}

// ── Bucket lookup: --env flag → terraform output ─────────────────────────────

const region = process.env.AWS_REGION ?? "us-east-1";

let bucket = process.env.S3_BUCKET;
if (!bucket) {
  const envDir = fileURLToPath(new URL(`../infrastructure/terraform/environments/${env}/`, import.meta.url));
  try {
    bucket = execSync("terraform output -raw s3_bucket_name", {
      cwd: envDir,
      encoding: "utf-8",
    }).trim();
  } catch (err) {
    console.error(`Could not read terraform output from ${envDir}.`);
    console.error("Set S3_BUCKET=... explicitly or run `terraform apply` first.");
    process.exit(1);
  }
}

const s3 = new S3Client({ region });

// ── Content (every tier is seeded for every environment) ─────────────────────

const HOME = {
  version: 2,
  items: [
    { id: "welcome",       label: "Welcome to Blooming Marvellous",            access: "free" },
    { id: "plan-by-month", label: "Plan your garden by bloom month",           access: "free" },
    { id: "tap-for-tips",  label: "Tap a plant to see growing tips",           access: "free" },
    { id: "sync-devices",  label: "Sync your beds across devices",             access: "free" },
    { id: "pro-companion", label: "Pro tip: pair flowers with companion herbs", access: "pro" },
    { id: "pack-exotic-teaser", label: "Exotic Pack: bring the tropics indoors", access: "pack_exotic" },
    { id: "pack-edible-teaser", label: "Edible Pack: from seed to dinner plate", access: "pack_edible" },
  ],
};

const DATA = {
  version: 2,
  items: [
    // Free tier — common UK garden flowers, beginner-friendly.
    { id: "lavender",   label: "Lavender — sow Mar–May",   access: "free" },
    { id: "sunflower",  label: "Sunflower — sow Apr–May",  access: "free" },
    { id: "cosmos",     label: "Cosmos — sow Mar–Apr",     access: "free" },
    { id: "sweet-pea",  label: "Sweet Pea — sow Oct–Mar",  access: "free" },
    { id: "marigold",   label: "Marigold — sow Mar–May",   access: "free" },
    { id: "nasturtium", label: "Nasturtium — sow Apr–May", access: "free" },

    // Pro tier — broader selection, slightly more advanced care.
    { id: "delphinium", label: "Delphinium — sow Feb–Apr", access: "pro" },
    { id: "foxglove",   label: "Foxglove — sow May–Jul",   access: "pro" },
    { id: "dahlia",     label: "Dahlia — tubers Apr–May",  access: "pro" },
    { id: "peony",      label: "Peony — plant Oct–Mar",    access: "pro" },
    { id: "hellebore",  label: "Hellebore — plant Sep–Nov", access: "pro" },
    { id: "echinacea",  label: "Echinacea — sow Mar–May",  access: "pro" },

    // Exotic pack — rare / tropical / indoor-friendly.
    { id: "phalaenopsis", label: "Phalaenopsis Orchid — indoor, year-round",  access: "pack_exotic" },
    { id: "bird-of-paradise", label: "Bird of Paradise — heated greenhouse",  access: "pack_exotic" },
    { id: "passionflower",label: "Passionflower — sheltered sunny wall",      access: "pack_exotic" },
    { id: "plumeria",     label: "Plumeria (Frangipani) — conservatory only", access: "pack_exotic" },
    { id: "hibiscus",     label: "Tropical Hibiscus — indoors UK / out Med",  access: "pack_exotic" },

    // Edible pack — kitchen-garden crops.
    { id: "tomato-gardener", label: "Tomato 'Gardener's Delight' — sow Feb–Apr", access: "pack_edible" },
    { id: "courgette",       label: "Courgette — sow Apr–May",                 access: "pack_edible" },
    { id: "runner-bean",     label: "Runner Bean — sow Apr–Jun",               access: "pack_edible" },
    { id: "basil",           label: "Basil — sow Mar–Jun",                     access: "pack_edible" },
    { id: "chilli",          label: "Chilli 'Cayenne' — sow Jan–Mar indoors",  access: "pack_edible" },
    { id: "strawberry",      label: "Strawberry — plant Sep–Apr",              access: "pack_edible" },
  ],
};

// ── Plant library (mirrors Sources/Models/Plant.swift Codable) ───────────────
//
// Keep this in sync with Sources/Models/PlantLibrary.swift. The Swift bundle
// stays as the offline fallback; this payload is what the Lambda serves
// (tier-filtered) via GET /v1/library.

const LIBRARY = {
  version: 2,
  items: [
    // ── Free tier ──
    {
      id: "lavender", name: "Lavender", latin: "Lavandula angustifolia",
      type: "perennial", heightCm: 60, colorHex: "#b8a0d8",
      bloomMonths: [6, 7, 8],
      sowIndoorMonths: [3, 4], sowDirectMonths: [4, 5],
      transplantMonths: [5, 6], harvestMonths: [7, 8],
      preferredSoil: ["loam", "sandy", "chalky"],
      preferredSunlight: ["sunny_always", "sunny_pm"],
      growersTips: "Prefers free-draining soil and full sun. Prune after flowering to keep compact.",
      germinationRequirements: "Light required. Surface-sow at 18–22°C. 14–21 days.",
      companions: ["marigold"],
      access: "free",
    },
    {
      id: "sunflower", name: "Sunflower", latin: "Helianthus annuus",
      type: "annual", heightCm: 200, colorHex: "#e8b070",
      bloomMonths: [7, 8, 9],
      sowIndoorMonths: [3, 4], sowDirectMonths: [4, 5],
      transplantMonths: [5], harvestMonths: [9, 10],
      preferredSoil: ["loam", "sandy"],
      preferredSunlight: ["sunny_always"],
      growersTips: "Deep watering once a week. Stake tall varieties.",
      germinationRequirements: "Sow 2 cm deep at 18–24°C. 7–14 days.",
      companions: ["cosmos"],
      access: "free",
    },
    {
      id: "cosmos", name: "Cosmos", latin: "Cosmos bipinnatus",
      type: "annual", heightCm: 90, colorHex: "#f0a898",
      bloomMonths: [6, 7, 8, 9, 10],
      sowIndoorMonths: [3, 4], sowDirectMonths: [4, 5],
      transplantMonths: [5, 6], harvestMonths: [],
      preferredSoil: ["loam", "sandy"],
      preferredSunlight: ["sunny_always", "sunny_pm"],
      growersTips: "Deadhead regularly for continuous bloom. Tolerates poor soil.",
      germinationRequirements: "Sow 5 mm deep at 18°C. 7–10 days.",
      companions: ["sunflower"],
      access: "free",
    },

    // ── Pro tier ──
    {
      id: "dahlia", name: "Dahlia", latin: "Dahlia variabilis",
      type: "perennial", heightCm: 120, colorHex: "#e07070",
      bloomMonths: [7, 8, 9, 10],
      sowIndoorMonths: [], sowDirectMonths: [],
      transplantMonths: [5], harvestMonths: [],
      preferredSoil: ["loam"],
      preferredSunlight: ["sunny_always"],
      growersTips: "Plant tubers Apr–May after last frost. Lift in autumn in cold areas.",
      germinationRequirements: "Tubers, not seed.",
      companions: [],
      access: "pro",
    },

    // ── Exotic pack ──
    {
      id: "phalaenopsis", name: "Phalaenopsis Orchid", latin: "Phalaenopsis spp.",
      type: "perennial", heightCm: 45, colorHex: "#c0a0d8",
      bloomMonths: [1, 2, 3, 4, 11, 12],
      sowIndoorMonths: [], sowDirectMonths: [],
      transplantMonths: [], harvestMonths: [],
      preferredSoil: ["peaty"],
      preferredSunlight: ["sunny_am"],
      growersTips: "Indoor-only. Bright indirect light. Water by soaking once a week.",
      germinationRequirements: "Bought as flowering plants — propagation needs lab conditions.",
      companions: [],
      access: "pack_exotic",
    },

    // ── Edible pack ──
    {
      id: "tomato-gardener", name: "Tomato 'Gardener's Delight'", latin: "Solanum lycopersicum",
      type: "annual", heightCm: 180, colorHex: "#e07070",
      bloomMonths: [6, 7],
      sowIndoorMonths: [2, 3], sowDirectMonths: [],
      transplantMonths: [5, 6], harvestMonths: [7, 8, 9],
      preferredSoil: ["loam"],
      preferredSunlight: ["sunny_always"],
      growersTips: "Side-shoot weekly. Feed weekly once trusses set.",
      germinationRequirements: "Sow 5 mm at 21°C. 7–14 days.",
      companions: ["basil"],
      access: "pack_edible",
    },
  ],
};

// ── Upload ───────────────────────────────────────────────────────────────────

async function put(key, payload) {
  await s3.send(new PutObjectCommand({
    Bucket:      bucket,
    Key:         key,
    Body:        JSON.stringify(payload, null, 2),
    ContentType: "application/json",
  }));
  console.log(`✓ s3://${bucket}/${key} (${payload.items.length} items)`);
}

await put("v1/home.json",    HOME);
await put("v1/data.json",    DATA);
await put("v1/library.json", LIBRARY);

console.log(`\nSeeded ${env} content. The iOS app will see filtered subsets on the next /home, /data and /library fetch.`);
