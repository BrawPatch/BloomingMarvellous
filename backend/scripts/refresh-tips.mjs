#!/usr/bin/env node
/**
 * refresh-tips.mjs — refills the `growersTips` field on every plant in
 * backend/data/library.json using the Gemini Flash API, in parallel
 * batches so a 9 K-plant library completes in minutes rather than hours.
 *
 * Reuses backend/data/tips-cache.json so re-runs are free except for
 * brand-new taxa, and persists the cache every batch so a mid-run
 * crash never loses the in-flight tips.
 *
 * Usage:
 *   GEMINI_API_KEY=... node scripts/refresh-tips.mjs                # only new plants
 *   GEMINI_API_KEY=... node scripts/refresh-tips.mjs --all          # re-call even cached
 *   GEMINI_API_KEY=... node scripts/refresh-tips.mjs --limit 100    # smoke test
 *
 * Resolves the Gemini key from (in order): env var GEMINI_API_KEY,
 * GOOGLE_API_KEY, then the gitignored API_Keys/GeminiKey.txt at the
 * repo root. (S3 fallback omitted to keep this script dependency-free.)
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

// ── Args ─────────────────────────────────────────────────────────────

const args = {
  all:   process.argv.includes("--all"),
  limit: (() => {
    const ix = process.argv.indexOf("--limit");
    return ix >= 0 ? parseInt(process.argv[ix + 1], 10) : null;
  })(),
};

// ── Paths ────────────────────────────────────────────────────────────

const LIBRARY = fileURLToPath(new URL("../data/library.json", import.meta.url));
const CACHE   = fileURLToPath(new URL("../data/tips-cache.json", import.meta.url));
const LOCAL_KEY_PATH = fileURLToPath(new URL("../../API_Keys/GeminiKey.txt", import.meta.url));

// ── Key resolution ──────────────────────────────────────────────────

function resolveKey() {
  const fromEnv = (process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY || "").trim();
  if (fromEnv) return fromEnv;
  if (existsSync(LOCAL_KEY_PATH)) {
    const text = readFileSync(LOCAL_KEY_PATH, "utf-8").trim();
    if (text) return text;
  }
  return null;
}

const GEMINI_KEY = resolveKey();
if (!GEMINI_KEY) {
  console.error("No Gemini API key found — set GEMINI_API_KEY or drop one at API_Keys/GeminiKey.txt");
  process.exit(1);
}
const GEMINI_MODEL = process.env.GEMINI_MODEL || "gemini-flash-latest";

// ── Tips cache ──────────────────────────────────────────────────────

function loadCache() {
  if (!existsSync(CACHE)) return {};
  try { return JSON.parse(readFileSync(CACHE, "utf-8")); } catch { return {}; }
}

function saveCache(cache) {
  mkdirSync(path.dirname(CACHE), { recursive: true });
  writeFileSync(CACHE, JSON.stringify(cache, null, 2) + "\n");
}

// ── Gemini per-plant call ───────────────────────────────────────────

async function geminiTipsFor({ name, latin, type, familyLabel }) {
  const prompt = [
    `Give me the FIVE most useful practical UK gardening tips specific to`,
    `${name} (Latin name: ${latin}; family: ${familyLabel ?? "unknown"};`,
    `growth habit: ${type ?? "unknown"}).`,
    `Rules:`,
    `- Output exactly five lines, one tip per line, with no numbering, no markdown,`,
    `  no bold, no leading dash or bullet.`,
    `- Each line must be 100 characters or less.`,
    `- Each tip must be specific and actionable (planting depth, watering pattern,`,
    `  pest watch, pruning timing, soil prep, companion plants, cultivar-specific`,
    `  quirks). Avoid generic gardening clichés that apply to anything.`,
    `- Focus on UK-relevant climate and the typical home gardener.`,
    `- Friendly, conversational tone — like a chat with a gardening friend.`,
  ].join(" ");

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_KEY}`;
  const body = {
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: {
      temperature: 0.6,
      thinkingConfig: { thinkingBudget: 0 },
      maxOutputTokens: 400,
    },
  };
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 20_000);
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      signal: ctrl.signal,
    });
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      throw new Error(`HTTP ${res.status} ${text.slice(0, 120)}`);
    }
    const data = await res.json();
    const txt = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    return cleanTips(txt);
  } finally {
    clearTimeout(timer);
  }
}

function cleanTips(text) {
  const lines = text.split(/\r?\n/)
    .map(l => l.replace(/^[\s\d\.\-•\*]+/, "").trim())
    .filter(l => l.length > 0 && l.length <= 200);
  return lines.slice(0, 5).join("\n");
}

// ── Main ────────────────────────────────────────────────────────────

const data = JSON.parse(readFileSync(LIBRARY, "utf-8"));
let items = data.items;
if (args.limit) items = items.slice(0, args.limit);

const cache = loadCache();
const BATCH = 8;
let calls = 0, cacheHits = 0, failures = 0;
const startedAt = Date.now();

console.log(`→ Refreshing tips for ${items.length} plants (batch ${BATCH}, model ${GEMINI_MODEL})…`);
console.log(`  ${args.all ? "Forcing fresh calls for every plant" : "Reusing cached tips where available"}`);

for (let i = 0; i < items.length; i += BATCH) {
  const slice = items.slice(i, i + BATCH);
  const results = await Promise.allSettled(slice.map(async p => {
    const cached = cache[p.id];
    if (cached && !args.all) {
      p.growersTips = cached;
      return { kind: "cache" };
    }
    try {
      const tips = await geminiTipsFor({
        name: p.name,
        latin: p.latin,
        type: p.type,
        familyLabel: p.family ?? null,
      });
      if (tips) {
        p.growersTips = tips;
        cache[p.id] = tips;
        return { kind: "call" };
      }
      return { kind: "empty" };
    } catch (err) {
      return { kind: "fail", error: err.message };
    }
  }));

  for (const r of results) {
    if (r.status !== "fulfilled") { failures++; continue; }
    if (r.value.kind === "cache") cacheHits++;
    else if (r.value.kind === "call") calls++;
    else failures++;
  }

  if ((i + BATCH) % 80 < BATCH) {
    const done = Math.min(i + BATCH, items.length);
    const elapsed = (Date.now() - startedAt) / 1000;
    const rate = done / Math.max(1, elapsed);
    console.log(`  ${done}/${items.length}  live ${calls} cached ${cacheHits} fails ${failures}  (${rate.toFixed(1)}/s)`);
  }
  // Persist cache every 4 batches so a crash doesn't waste API spend.
  if (i % (BATCH * 4) === 0) saveCache(cache);
}

saveCache(cache);

if (!args.limit) {
  data.generated = new Date().toISOString();
  writeFileSync(LIBRARY, JSON.stringify(data, null, 2) + "\n");
}
const total = (Date.now() - startedAt) / 1000;
console.log(`\n✓ Done in ${total.toFixed(1)}s  ·  live ${calls}  cached ${cacheHits}  failures ${failures}`);
