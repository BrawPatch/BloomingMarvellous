#!/usr/bin/env node
/**
 * create-user.mjs — provisions a user row in DynamoDB.
 *
 * The Lambda's POST /v1/auth/login looks up users in this table by `username`
 * and verifies the provided password against the stored scrypt hash. The
 * user record carries `tier` and `purchasedPacks` (a StringSet); both are
 * snapshotted into the session at login time.
 *
 * Usage:
 *   node scripts/create-user.mjs --env development \
 *     --username alice --password "hunter2" --first-name Alice \
 *     --tier pro --pack pack_exotic --pack pack_edible
 *
 * --env is required and picks the right DynamoDB table via terraform output.
 * --tier defaults to "free". --pack can be repeated and is only honoured for
 * --tier pro. Valid pack values: pack_exotic, pack_edible.
 *
 * Env overrides:
 *   USERS_TABLE   skip terraform-output lookup
 *   AWS_REGION    defaults to us-east-1
 *   AWS_PROFILE   forwarded to the SDK (use the right SSO profile per env)
 *
 * The userId is derived deterministically from SHA-256(username) so re-running
 * the script for the same username is idempotent and yields the same numeric ID.
 */

import { execSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { createHash, randomBytes, scryptSync } from "node:crypto";
import { DynamoDBClient, PutItemCommand } from "@aws-sdk/client-dynamodb";

const KNOWN_PACKS = new Set(["pack_exotic", "pack_edible"]);

// ── Args ─────────────────────────────────────────────────────────────────────

function parseArgs(argv) {
  const args = { env: null, username: null, password: null, firstName: null, tier: "free", packs: [] };
  for (let i = 2; i < argv.length; i++) {
    const v = argv[i];
    const next = argv[i + 1];
    switch (v) {
      case "--env":        args.env = next; i++; break;
      case "--username":   args.username = next; i++; break;
      case "--password":   args.password = next; i++; break;
      case "--first-name": args.firstName = next; i++; break;
      case "--tier":       args.tier = next; i++; break;
      case "--pack":       args.packs.push(next); i++; break;
      default:             break;
    }
  }
  return args;
}

const args = parseArgs(process.argv);

if (!args.env || !["development", "production"].includes(args.env)) {
  console.error("Missing or invalid --env (development|production).");
  process.exit(1);
}
if (!args.username || !args.password || !args.firstName) {
  console.error("Usage: create-user.mjs --env <env> --username U --password P --first-name F [--tier free|pro] [--pack pack_exotic ...]");
  process.exit(1);
}
if (!["free", "pro"].includes(args.tier)) {
  console.error(`Invalid --tier: ${args.tier}. Must be "free" or "pro".`);
  process.exit(1);
}
for (const p of args.packs) {
  if (!KNOWN_PACKS.has(p)) {
    console.error(`Unknown --pack ${p}. Must be one of: ${[...KNOWN_PACKS].join(", ")}.`);
    process.exit(1);
  }
}
if (args.tier === "free" && args.packs.length > 0) {
  console.error("Refusing to attach packs to a free-tier user. Set --tier pro.");
  process.exit(1);
}

const username  = args.username.trim().toLowerCase();
const firstName = args.firstName.trim();
const packs     = [...new Set(args.packs)];

// ── Table lookup ─────────────────────────────────────────────────────────────

const region = process.env.AWS_REGION ?? "us-east-1";

let table = process.env.USERS_TABLE;
if (!table) {
  const envDir = fileURLToPath(new URL(`../infrastructure/terraform/environments/${args.env}/`, import.meta.url));
  try {
    table = execSync("terraform output -raw users_table_name", {
      cwd: envDir,
      encoding: "utf-8",
    }).trim();
  } catch {
    console.error(`Could not read terraform output from ${envDir}. Run terraform apply first, or set USERS_TABLE=...`);
    process.exit(1);
  }
}

// ── Write ────────────────────────────────────────────────────────────────────

const userId = parseInt(
  createHash("sha256").update(username, "utf8").digest("hex").slice(0, 8),
  16,
) & 0x7fffffff;

const salt = randomBytes(16).toString("hex");
const passwordHash = scryptSync(args.password, Buffer.from(salt, "hex"), 32).toString("hex");

const dynamo = new DynamoDBClient({ region });

const item = {
  username:     { S: username },
  userId:       { N: String(userId) },
  firstName:    { S: firstName },
  salt:         { S: salt },
  passwordHash: { S: passwordHash },
  tier:         { S: args.tier },
  createdAt:    { S: new Date().toISOString() },
};
if (packs.length > 0) item.purchasedPacks = { SS: packs };

await dynamo.send(new PutItemCommand({ TableName: table, Item: item }));

console.log(`✓ Created user "${username}" (userId=${userId}, tier=${args.tier}${packs.length ? `, packs=${packs.join("+")}` : ""}) in ${table}`);
console.log(`  Try: curl -X POST $API/v1/auth/login -d '{"username":"${username}","password":"…"}'`);
