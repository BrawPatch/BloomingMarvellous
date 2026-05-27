#!/usr/bin/env node
/**
 * seed-content.mjs — uploads default /home and /data payloads to S3.
 *
 * The Lambda fetches these objects on every GET /v1/home and GET /v1/data
 * request, so editing the JSON and re-running this script is enough to
 * update what the app sees — no Lambda redeploy needed.
 *
 * Usage:
 *   S3_BUCKET=blooming-marvellous-development-content \
 *   AWS_REGION=eu-west-2 \
 *   node scripts/seed-content.mjs
 *
 * If S3_BUCKET is omitted it is read from `terraform output -raw s3_bucket_name`.
 */

import { execSync } from "node:child_process";
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";

const region = process.env.AWS_REGION ?? "eu-west-2";

let bucket = process.env.S3_BUCKET;
if (!bucket) {
  try {
    bucket = execSync("terraform output -raw s3_bucket_name", {
      cwd: new URL("../infrastructure/terraform", import.meta.url).pathname,
      encoding: "utf-8",
    }).trim();
  } catch {
    console.error("S3_BUCKET not set and terraform output unavailable. Aborting.");
    process.exit(1);
  }
}

const s3 = new S3Client({ region });

const HOME = [
  "Welcome to Blooming Marvellous",
  "Plan your garden by bloom month",
  "Tap a plant to see growing tips",
  "Sync your beds across devices",
];

const DATA = [
  "Lavender — sow Mar–May",
  "Sunflower — sow Apr–May",
  "Cosmos — sow Mar–Apr",
  "Sweet Pea — sow Oct–Mar",
  "Marigold — sow Mar–May",
];

async function put(key, payload) {
  await s3.send(new PutObjectCommand({
    Bucket:      bucket,
    Key:         key,
    Body:        JSON.stringify(payload, null, 2),
    ContentType: "application/json",
  }));
  console.log(`✓ s3://${bucket}/${key} (${payload.length} items)`);
}

await put("v1/home.json", HOME);
await put("v1/data.json", DATA);

console.log("\nDone. The iOS app will see these on the next /home and /data fetch.");
