#!/usr/bin/env bun
// CLI: `bun run cli.ts <fixtures-dir> [output.md]`
// Reads every *.xml/*.json in the given directory (non-recursive), aggregates,
// and writes the markdown summary to stdout + the output path (or $GITHUB_STEP_SUMMARY).

import { readdir } from "node:fs/promises";
import { join } from "node:path";
import { aggregate, parseResultFile, renderMarkdown } from "./aggregator";

async function main(): Promise<number> {
  const args = Bun.argv.slice(2);
  if (args.length < 1) {
    console.error("usage: bun run cli.ts <fixtures-dir> [output.md]");
    return 2;
  }
  const dir = args[0];
  const outPath = args[1] ?? process.env.GITHUB_STEP_SUMMARY ?? "";

  const entries = await readdir(dir);
  const files = entries
    .filter((f) => f.endsWith(".xml") || f.endsWith(".json"))
    .map((f) => join(dir, f))
    .sort();

  if (files.length === 0) {
    console.error(`no .xml or .json fixtures found in ${dir}`);
    return 1;
  }

  const runs = [];
  for (const f of files) {
    runs.push(await parseResultFile(f));
  }
  const agg = aggregate(runs);
  const md = renderMarkdown(agg);

  console.log(md);
  // Stable key=value lines parsed by the act harness.
  console.log(`AGG_PASSED=${agg.totals.passed}`);
  console.log(`AGG_FAILED=${agg.totals.failed}`);
  console.log(`AGG_SKIPPED=${agg.totals.skipped}`);
  console.log(`AGG_TOTAL=${agg.totals.total}`);
  console.log(`AGG_FLAKY=${agg.flaky.length}`);
  console.log(`AGG_FLAKY_NAMES=${agg.flaky.map((f) => f.name).join(",")}`);

  if (outPath) {
    await Bun.write(outPath, md);
  }
  // Exit 0 even on test failures — the aggregator reports status; CI gating is caller's choice.
  return 0;
}

process.exit(await main());
