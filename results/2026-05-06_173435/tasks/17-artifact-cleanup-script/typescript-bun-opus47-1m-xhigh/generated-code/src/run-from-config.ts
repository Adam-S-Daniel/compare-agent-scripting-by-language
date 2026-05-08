#!/usr/bin/env bun
// Workflow-friendly wrapper: reads a JSON config file and invokes the CLI
// with the corresponding args. Lets the GitHub Actions workflow stay free of
// any bash arg-construction logic — the test harness only needs to swap
// fixture files between act runs, not edit the workflow.

import { readFileSync } from "node:fs";
import { main } from "./cli";

interface RunConfig {
  input: string;
  now?: string;
  maxAgeDays?: number;
  maxTotalSizeBytes?: number;
  keepLatestN?: number;
  dryRun?: boolean;
}

function parseConfig(path: string): RunConfig {
  const raw = readFileSync(path, "utf8");
  const parsed = JSON.parse(raw) as unknown;
  if (typeof parsed !== "object" || parsed === null) {
    throw new Error(`Config at ${path} is not an object`);
  }
  const cfg = parsed as Record<string, unknown>;
  if (typeof cfg.input !== "string") {
    throw new Error(`Config at ${path} requires a string 'input' field`);
  }
  return {
    input: cfg.input,
    now: typeof cfg.now === "string" ? cfg.now : undefined,
    maxAgeDays:
      typeof cfg.maxAgeDays === "number" ? cfg.maxAgeDays : undefined,
    maxTotalSizeBytes:
      typeof cfg.maxTotalSizeBytes === "number"
        ? cfg.maxTotalSizeBytes
        : undefined,
    keepLatestN:
      typeof cfg.keepLatestN === "number" ? cfg.keepLatestN : undefined,
    dryRun: cfg.dryRun === true,
  };
}

function buildArgs(cfg: RunConfig): string[] {
  const args: string[] = ["--input", cfg.input];
  if (cfg.now) args.push("--now", cfg.now);
  if (cfg.maxAgeDays !== undefined) {
    args.push("--max-age-days", String(cfg.maxAgeDays));
  }
  if (cfg.maxTotalSizeBytes !== undefined) {
    args.push("--max-total-size-bytes", String(cfg.maxTotalSizeBytes));
  }
  if (cfg.keepLatestN !== undefined) {
    args.push("--keep-latest-n", String(cfg.keepLatestN));
  }
  if (cfg.dryRun) args.push("--dry-run");
  return args;
}

const configPath = process.argv[2] ?? "fixtures/cleanup.config.json";

let cfg: RunConfig;
try {
  cfg = parseConfig(configPath);
} catch (err) {
  const msg = err instanceof Error ? err.message : String(err);
  console.error(`error: cannot load config: ${msg}`);
  process.exit(1);
}

const exit = await main(buildArgs(cfg));
process.exit(exit);
