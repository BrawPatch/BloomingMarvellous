/**
 * BloomingMarvellousApp — API Lambda
 *
 * Routes (must match BloomingMarvellousApp/Sources/Config/AppConfig.swift):
 *   POST /v1/auth/login   body {username, password}
 *                         → 200 {user_id, first_name, api_token, tier, purchased_packs}
 *                         → 401 on bad credentials
 *   GET  /v1/home         Bearer auth → 200 [String]  (filtered by tier + packs)
 *   GET  /v1/data         Bearer auth → 200 [String]  (filtered by tier + packs)
 *   GET  /v1/library      Bearer auth → 200 [Plant]   (filtered by tier + packs)
 *                         Payload mirrors Sources/Models/Plant.swift Codable.
 *
 * Tier model:
 *   - users table: { username, userId, firstName, passwordHash, salt,
 *                    tier ("free"|"pro"), purchasedPacks (StringSet), createdAt }
 *   - sessions table snapshots tier + purchasedPacks at login time so reads
 *     don't need a second DynamoDB lookup. A purchase made mid-session is
 *     visible after the next login. (Acceptable for V1.)
 *
 * S3 content schema (v2):
 *   { version: 2, items: [ { id, label, access }, ... ] }
 *   access ∈ "free" | "pro" | "pack_exotic" | "pack_edible"
 *
 * Filter rules (server side):
 *   free → access==="free"
 *   pro  → access==="free" || access==="pro" || purchasedPacks.includes(access)
 *
 * Security model (unchanged from previous version):
 *   - Passwords stored as scrypt(password, salt). Raw passwords never logged.
 *   - api_token: 32 random bytes, base64url-encoded, returned to client once.
 *   - Server stores ONLY SHA-256(api_token) in the sessions table.
 *   - DynamoDB TTL auto-deletes expired sessions.
 *   - Constant-time comparisons for credential and token checks.
 */

import {
  DynamoDBClient,
  GetItemCommand,
  PutItemCommand,
} from "@aws-sdk/client-dynamodb";
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import {
  createHash,
  randomBytes,
  scryptSync,
  timingSafeEqual,
} from "node:crypto";

const region = process.env.AWS_REGION_VAR ?? "us-east-1";
const dynamo = new DynamoDBClient({ region });
const s3     = new S3Client({ region });

const BUCKET           = process.env.S3_BUCKET;
const USERS_TABLE      = process.env.USERS_TABLE;
const SESSIONS_TABLE   = process.env.SESSIONS_TABLE;
const SESSION_TTL_DAYS = parseInt(process.env.SESSION_TTL_DAYS ?? "30", 10);

const KNOWN_PACKS = new Set(["pack_exotic", "pack_edible"]);

const SECURITY_HEADERS = {
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains; preload",
  "X-Content-Type-Options":    "nosniff",
  "X-Frame-Options":           "DENY",
  "Cache-Control":             "no-store",
  "Content-Type":              "application/json",
};

// ── Helpers ──────────────────────────────────────────────────────────────────

function respond(statusCode, body, extraHeaders = {}) {
  return {
    statusCode,
    headers: { ...SECURITY_HEADERS, ...extraHeaders },
    body: typeof body === "string" ? body : JSON.stringify(body),
  };
}

function sha256hex(input) {
  return createHash("sha256").update(input, "utf8").digest("hex");
}

async function getS3Object(key) {
  const res = await s3.send(new GetObjectCommand({ Bucket: BUCKET, Key: key }));
  const chunks = [];
  for await (const chunk of res.Body) chunks.push(chunk);
  return Buffer.concat(chunks).toString("utf-8");
}

function constantTimeEqualHex(a, b) {
  if (typeof a !== "string" || typeof b !== "string") return false;
  if (a.length !== b.length) return false;
  return timingSafeEqual(Buffer.from(a, "hex"), Buffer.from(b, "hex"));
}

function verifyScryptPassword(plain, saltHex, expectedHashHex) {
  const derived = scryptSync(plain, Buffer.from(saltHex, "hex"), 32).toString("hex");
  return constantTimeEqualHex(derived, expectedHashHex);
}

// Normalise a DynamoDB StringSet attribute (`.SS`) or absence into a JS array.
function readStringSet(attr) {
  if (!attr) return [];
  if (Array.isArray(attr.SS)) return attr.SS;
  return [];
}

// Filter items[] based on the caller's tier and purchased packs.
function filterByEntitlements(items, tier, purchasedPacks) {
  const packs = new Set(purchasedPacks);
  return items.filter((item) => {
    switch (item.access) {
      case "free":
        return true;
      case "pro":
        return tier === "pro";
      default:
        // pack_* — must be pro AND own that specific pack.
        return tier === "pro" && KNOWN_PACKS.has(item.access) && packs.has(item.access);
    }
  });
}

// ── Auth: POST /v1/auth/login ────────────────────────────────────────────────
//
// Looks up the user, verifies password, issues a fresh api_token, stores
// SHA-256(api_token) + tier + packs in the sessions table, returns iOS JSON.

async function handleLogin(event) {
  let body;
  try {
    body = JSON.parse(event.body ?? "{}");
  } catch {
    return respond(400, { error: "Invalid JSON body" });
  }

  const username = typeof body.username === "string" ? body.username.trim().toLowerCase() : "";
  const password = typeof body.password === "string" ? body.password : "";

  if (!username || !password) {
    return respond(400, { error: "username and password are required" });
  }

  let user;
  try {
    const result = await dynamo.send(new GetItemCommand({
      TableName: USERS_TABLE,
      Key:       { username: { S: username } },
    }));
    user = result.Item;
  } catch (err) {
    console.error("[login] users lookup failed:", err.message);
    return respond(503, { error: "Service temporarily unavailable" });
  }

  // Same response for "unknown user" and "wrong password" to avoid user enumeration.
  if (!user || !verifyScryptPassword(password, user.salt?.S, user.passwordHash?.S)) {
    return respond(401, { error: "Invalid credentials" });
  }

  const userId    = parseInt(user.userId?.N ?? "0", 10);
  const firstName = user.firstName?.S ?? "";
  const tier      = user.tier?.S === "pro" ? "pro" : "free";
  const purchasedPacks = readStringSet(user.purchasedPacks)
    .filter((p) => KNOWN_PACKS.has(p));

  const apiToken  = randomBytes(32).toString("base64url");
  const tokenHash = sha256hex(apiToken);
  const now       = new Date();
  const expiresAt = new Date(now.getTime() + SESSION_TTL_DAYS * 86400 * 1000);

  const sessionItem = {
    tokenHash: { S: tokenHash },
    userId:    { N: String(userId) },
    firstName: { S: firstName },
    tier:      { S: tier },
    expiresAt: { S: expiresAt.toISOString() },
    createdAt: { S: now.toISOString() },
    ttl:       { N: String(Math.floor(expiresAt.getTime() / 1000)) },
  };
  // DynamoDB rejects empty StringSets — only attach the field if non-empty.
  if (purchasedPacks.length > 0) {
    sessionItem.purchasedPacks = { SS: purchasedPacks };
  }

  try {
    await dynamo.send(new PutItemCommand({
      TableName: SESSIONS_TABLE,
      Item:      sessionItem,
    }));
  } catch (err) {
    console.error("[login] session write failed:", err.message);
    return respond(503, { error: "Service temporarily unavailable" });
  }

  // Shape MUST match BloomingMarvellousApp/Sources/Models/UserModel.swift CodingKeys.
  return respond(200, {
    user_id:         userId,
    first_name:      firstName,
    api_token:       apiToken,
    tier:            tier,
    purchased_packs: purchasedPacks,
  });
}

// ── Bearer auth → returns the session record (or null) ───────────────────────

async function validateBearer(event) {
  const header = event.headers?.authorization ?? event.headers?.Authorization ?? "";
  if (!header.startsWith("Bearer ")) return null;

  const token = header.slice(7).trim();
  if (token.length < 32) return null;

  const tokenHash = sha256hex(token);

  let item;
  try {
    const result = await dynamo.send(new GetItemCommand({
      TableName: SESSIONS_TABLE,
      Key:       { tokenHash: { S: tokenHash } },
    }));
    item = result.Item;
  } catch (err) {
    console.error("[auth] session lookup failed:", err.message);
    return null;
  }

  if (!item) return null;
  const expires = new Date(item.expiresAt?.S ?? 0);
  if (Number.isNaN(expires.getTime()) || expires < new Date()) return null;

  return {
    userId:         parseInt(item.userId?.N ?? "0", 10),
    firstName:      item.firstName?.S ?? "",
    tier:           item.tier?.S === "pro" ? "pro" : "free",
    purchasedPacks: readStringSet(item.purchasedPacks),
  };
}

// ── GET /v1/home and /v1/data ────────────────────────────────────────────────
//
// Fetches a v2 content object from S3 ({version, items[]}), filters items by
// the caller's entitlements, and returns the projected `[String]` of labels
// to preserve the existing iOS contract.

async function handleStaticList(event, s3Key) {
  const session = await validateBearer(event);
  if (!session) return respond(401, { error: "Authentication required" });

  let raw;
  try {
    raw = await getS3Object(s3Key);
  } catch (err) {
    if (err.name === "NoSuchKey") {
      return respond(404, { error: "Content not found. Run scripts/seed-content.mjs." });
    }
    console.error(`[${s3Key}]`, err.message);
    return respond(503, { error: "Content temporarily unavailable" });
  }

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    console.error(`[${s3Key}] payload is not JSON`);
    return respond(500, { error: "Malformed content" });
  }

  // Accept the v2 schema only — fail loudly on legacy payloads so we don't
  // silently leak un-tiered content.
  if (parsed?.version !== 2 || !Array.isArray(parsed.items)) {
    console.error(`[${s3Key}] schema mismatch (expected v2 {items[]})`);
    return respond(500, { error: "Malformed content" });
  }

  const filtered = filterByEntitlements(parsed.items, session.tier, session.purchasedPacks);
  return respond(200, filtered.map((item) => item.label));
}

// ── GET /v1/library ──────────────────────────────────────────────────────────
//
// Returns the full Plant payload (not just labels) so the iOS Plant Picker
// can render hero photos, tips, buy links, etc. Same v2 envelope as /home
// and /data — { version: 2, items: [Plant, ...] } — and the same tier filter.

async function handleLibrary(event) {
  const session = await validateBearer(event);
  if (!session) return respond(401, { error: "Authentication required" });

  let raw;
  try {
    raw = await getS3Object("v1/library.json");
  } catch (err) {
    if (err.name === "NoSuchKey") {
      return respond(404, { error: "Library not found. Run scripts/seed-content.mjs." });
    }
    console.error("[library]", err.message);
    return respond(503, { error: "Library temporarily unavailable" });
  }

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    console.error("[library] payload is not JSON");
    return respond(500, { error: "Malformed library" });
  }

  if (parsed?.version !== 2 || !Array.isArray(parsed.items)) {
    console.error("[library] schema mismatch (expected v2 {items[]})");
    return respond(500, { error: "Malformed library" });
  }

  const filtered = filterByEntitlements(parsed.items, session.tier, session.purchasedPacks);
  return respond(200, filtered);
}

// ── Router ───────────────────────────────────────────────────────────────────

export async function handler(event) {
  const method = event.requestContext?.http?.method ?? "GET";
  const path   = event.rawPath ?? "";

  if (method === "OPTIONS") return respond(204, "");

  if (path === "/v1/auth/login" && method === "POST") return handleLogin(event);
  if (path === "/v1/home"       && method === "GET")  return handleStaticList(event, "v1/home.json");
  if (path === "/v1/data"       && method === "GET")  return handleStaticList(event, "v1/data.json");
  if (path === "/v1/library"    && method === "GET")  return handleLibrary(event);

  return respond(404, { error: "Not found" });
}
