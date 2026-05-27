/**
 * BloomingMarvellousApp — API Lambda
 *
 * Routes (must match BloomingMarvellousApp/Sources/Config/AppConfig.swift):
 *   POST /v1/auth/login   body {username, password}
 *                         → 200 {user_id, first_name, api_token}
 *                         → 401 on bad credentials
 *   GET  /v1/home         Bearer auth → 200 [String]
 *   GET  /v1/data         Bearer auth → 200 [String]
 *
 * Security model (mirrors BMFinal):
 *   - Passwords stored as scrypt(password, salt). Raw passwords never logged.
 *   - api_token: 32 random bytes, base64url-encoded, returned to client once.
 *   - Server stores ONLY SHA-256(api_token) in the sessions table.
 *   - A DynamoDB TTL attribute auto-deletes expired sessions.
 *   - Constant-time comparisons used for credential and token checks.
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

const region = process.env.AWS_REGION_VAR ?? "eu-west-2";
const dynamo = new DynamoDBClient({ region });
const s3     = new S3Client({ region });

const BUCKET           = process.env.S3_BUCKET;
const USERS_TABLE      = process.env.USERS_TABLE;
const SESSIONS_TABLE   = process.env.SESSIONS_TABLE;
const SESSION_TTL_DAYS = parseInt(process.env.SESSION_TTL_DAYS ?? "30", 10);

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

// ── Auth: POST /v1/auth/login ────────────────────────────────────────────────
//
// Looks up the user, verifies password, issues a fresh api_token, stores
// SHA-256(api_token) in the sessions table, and returns the iOS-shaped JSON.

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

  const apiToken = randomBytes(32).toString("base64url");
  const tokenHash = sha256hex(apiToken);
  const now = new Date();
  const expiresAt = new Date(now.getTime() + SESSION_TTL_DAYS * 86400 * 1000);

  try {
    await dynamo.send(new PutItemCommand({
      TableName: SESSIONS_TABLE,
      Item: {
        tokenHash: { S: tokenHash },
        userId:    { N: String(userId) },
        firstName: { S: firstName },
        expiresAt: { S: expiresAt.toISOString() },
        createdAt: { S: now.toISOString() },
        ttl:       { N: String(Math.floor(expiresAt.getTime() / 1000)) },
      },
    }));
  } catch (err) {
    console.error("[login] session write failed:", err.message);
    return respond(503, { error: "Service temporarily unavailable" });
  }

  // Shape MUST match BloomingMarvellousApp/Sources/Models/UserModel.swift CodingKeys.
  return respond(200, {
    user_id:    userId,
    first_name: firstName,
    api_token:  apiToken,
  });
}

// ── Bearer auth for protected reads ──────────────────────────────────────────

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

  return item;
}

// ── GET /v1/home and /v1/data ────────────────────────────────────────────────
//
// Both return a JSON array of strings, sourced from S3 so content can be
// updated without redeploying Lambda. The seed-content.mjs script uploads
// default payloads to v1/home.json and v1/data.json.

async function handleStaticList(event, s3Key) {
  if (!await validateBearer(event)) {
    return respond(401, { error: "Authentication required" });
  }

  try {
    const body = await getS3Object(s3Key);
    // Validate it parses as an array of strings before returning.
    const parsed = JSON.parse(body);
    if (!Array.isArray(parsed) || !parsed.every((x) => typeof x === "string")) {
      console.error(`[${s3Key}] payload is not [String]`);
      return respond(500, { error: "Malformed content" });
    }
    return respond(200, parsed);
  } catch (err) {
    if (err.name === "NoSuchKey") {
      return respond(404, { error: "Content not found. Run scripts/seed-content.mjs." });
    }
    console.error(`[${s3Key}]`, err.message);
    return respond(503, { error: "Content temporarily unavailable" });
  }
}

// ── Router ───────────────────────────────────────────────────────────────────

export async function handler(event) {
  const method = event.requestContext?.http?.method ?? "GET";
  const path   = event.rawPath ?? "";

  if (method === "OPTIONS") return respond(204, "");

  if (path === "/v1/auth/login" && method === "POST") return handleLogin(event);
  if (path === "/v1/home"       && method === "GET")  return handleStaticList(event, "v1/home.json");
  if (path === "/v1/data"       && method === "GET")  return handleStaticList(event, "v1/data.json");

  return respond(404, { error: "Not found" });
}
