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
import { readFileSync, existsSync } from "node:fs";
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

// ── Plant library ────────────────────────────────────────────────────────────
//
// Loaded from backend/data/library.json (committed; refreshed by
// `node scripts/ingest-plants.mjs`). Falls back to an inline minimal seed
// so a fresh checkout / first deploy still produces a usable /v1/library
// without first running ingest. Schema mirrors Sources/Models/Plant.swift.

const LIBRARY_FILE = fileURLToPath(new URL("../data/library.json", import.meta.url));

const INLINE_LIBRARY_FALLBACK = {
  version: 2,
  items: [
    {
      id: "lavender", name: "Lavender", latin: "Lavandula angustifolia",
      type: "perennial", heightCm: 60, colorHex: "#b8a0d8",
      bloomMonths: [6, 7, 8],
      sowIndoorMonths: [3, 4], sowDirectMonths: [4, 5],
      transplantMonths: [5, 6], harvestMonths: [7, 8],
      preferredSoil: ["loam", "sandy", "chalky"],
      preferredSunlight: ["sunny_always", "sunny_pm"],
      growersTips: "Free-draining soil and full sun. Prune after flowering.",
      germinationRequirements: "Light required. Surface-sow at 18–22°C. 14–21 days.",
      companions: ["marigold"], access: "free",
    },
    {
      id: "sunflower", name: "Sunflower", latin: "Helianthus annuus",
      type: "annual", heightCm: 200, colorHex: "#e8b070",
      bloomMonths: [7, 8, 9],
      sowIndoorMonths: [3, 4], sowDirectMonths: [4, 5],
      transplantMonths: [5], harvestMonths: [9, 10],
      preferredSoil: ["loam", "sandy"],
      preferredSunlight: ["sunny_always"],
      growersTips: "Deep water weekly. Stake tall varieties.",
      germinationRequirements: "Sow 2 cm deep at 18–24°C. 7–14 days.",
      companions: ["cosmos"], access: "free",
    },
    {
      id: "cosmos", name: "Cosmos", latin: "Cosmos bipinnatus",
      type: "annual", heightCm: 90, colorHex: "#f0a898",
      bloomMonths: [6, 7, 8, 9, 10],
      sowIndoorMonths: [3, 4], sowDirectMonths: [4, 5],
      transplantMonths: [5, 6], harvestMonths: [],
      preferredSoil: ["loam", "sandy"],
      preferredSunlight: ["sunny_always", "sunny_pm"],
      growersTips: "Deadhead for continuous bloom.",
      germinationRequirements: "Sow 5 mm deep at 18°C. 7–10 days.",
      companions: ["sunflower"], access: "free",
    },
  ],
};

function loadLibrary() {
  if (existsSync(LIBRARY_FILE)) {
    try {
      const parsed = JSON.parse(readFileSync(LIBRARY_FILE, "utf-8"));
      if (parsed?.version === 2 && Array.isArray(parsed.items) && parsed.items.length > 0) {
        console.log(`✓ Loaded library from ${LIBRARY_FILE} (${parsed.items.length} items)`);
        return parsed;
      }
      console.warn(`⚠️ ${LIBRARY_FILE} is malformed — falling back to inline seed.`);
    } catch (err) {
      console.warn(`⚠️ Failed to parse ${LIBRARY_FILE}: ${err.message} — falling back to inline seed.`);
    }
  } else {
    console.warn(`⚠️ ${LIBRARY_FILE} not found — using inline seed (run scripts/ingest-plants.mjs to populate).`);
  }
  return INLINE_LIBRARY_FALLBACK;
}

const LIBRARY = loadLibrary();

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
