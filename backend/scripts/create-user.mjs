#!/usr/bin/env node
/**
 * create-user.mjs — provisions a user row in DynamoDB.
 *
 * The Lambda's POST /v1/auth/login looks up users in this table by `username`
 * and verifies the provided password against the stored scrypt hash.
 *
 * Usage:
 *   USERS_TABLE=blooming-marvellous-development-users \
 *   AWS_REGION=eu-west-2 \
 *   node scripts/create-user.mjs <username> <password> <firstName>
 *
 * If USERS_TABLE is omitted it is read from `terraform output -raw users_table_name`.
 *
 * The user_id is derived deterministically from SHA-256(username) so re-running
 * the script for the same username is idempotent and yields the same numeric ID.
 */

import { execSync } from "node:child_process";
import { createHash, randomBytes, scryptSync } from "node:crypto";
import { DynamoDBClient, PutItemCommand } from "@aws-sdk/client-dynamodb";

const [, , usernameArg, passwordArg, firstNameArg] = process.argv;
if (!usernameArg || !passwordArg || !firstNameArg) {
  console.error("Usage: node scripts/create-user.mjs <username> <password> <firstName>");
  process.exit(1);
}

const username  = usernameArg.trim().toLowerCase();
const firstName = firstNameArg.trim();

const region = process.env.AWS_REGION ?? "eu-west-2";

let table = process.env.USERS_TABLE;
if (!table) {
  try {
    table = execSync("terraform output -raw users_table_name", {
      cwd: new URL("../infrastructure/terraform", import.meta.url).pathname,
      encoding: "utf-8",
    }).trim();
  } catch {
    console.error("USERS_TABLE not set and terraform output unavailable. Aborting.");
    process.exit(1);
  }
}

// Derive a stable 31-bit positive int from the username so UserModel.userId
// stays a small Int (matches the Swift Int field, no overflow on iOS).
const userId = parseInt(
  createHash("sha256").update(username, "utf8").digest("hex").slice(0, 8),
  16,
) & 0x7fffffff;

const salt = randomBytes(16).toString("hex");
const passwordHash = scryptSync(passwordArg, Buffer.from(salt, "hex"), 32).toString("hex");

const dynamo = new DynamoDBClient({ region });

await dynamo.send(new PutItemCommand({
  TableName: table,
  Item: {
    username:     { S: username },
    userId:       { N: String(userId) },
    firstName:    { S: firstName },
    salt:         { S: salt },
    passwordHash: { S: passwordHash },
    createdAt:    { S: new Date().toISOString() },
  },
}));

console.log(`✓ Created user "${username}" (userId=${userId}) in ${table}`);
console.log(`  Try: curl -X POST $API/v1/auth/login -d '{"username":"${username}","password":"…"}'`);
