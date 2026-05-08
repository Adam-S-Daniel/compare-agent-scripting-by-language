// CLI entrypoint. Usage:
//   bun run src/cli.ts <file-or-dir> [<file-or-dir> ...] [--out summary.md]
//
// - If a directory is given, every *.xml and *.json inside it (non-recursive)
//   is treated as a separate "run" of a matrix build.
// - Each input file is parsed as one run (runId = file basename).
// - Markdown summary goes to --out, or stdout, AND to $GITHUB_STEP_SUMMARY when set.

import { readdirSync, statSync, existsSync } from "node:fs";
import { basename, join } from "node:path";
import { aggregate } from "./aggregate";
import { parseFile } from "./parser";
import { renderMarkdown } from "./markdown";
import type { RunResult } from "./types";

function expandInputs(args: string[]): string[] {
  const out: string[] = [];
  for (const a of args) {
    if (!existsSync(a)) throw new Error(`Input not found: ${a}`);
    const st = statSync(a);
    if (st.isDirectory()) {
      for (const name of readdirSync(a).sort()) {
        if (/\.(xml|json)$/i.test(name)) out.push(join(a, name));
      }
    } else {
      out.push(a);
    }
  }
  return out;
}

async function main(argv: string[]): Promise<number> {
  const args = [...argv];
  let outPath: string | undefined;
  let failOnFailures = false;
  const inputs: string[] = [];
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === "--out") {
      outPath = args[++i];
    } else if (a.startsWith("--out=")) {
      outPath = a.slice("--out=".length);
    } else if (a === "--fail-on-failures") {
      failOnFailures = true;
    } else {
      inputs.push(a);
    }
  }
  if (inputs.length === 0) {
    console.error("usage: bun run src/cli.ts <file-or-dir>... [--out summary.md]");
    return 2;
  }

  const files = expandInputs(inputs);
  if (files.length === 0) {
    throw new Error("No .xml or .json result files found in given inputs");
  }

  const runs: RunResult[] = [];
  for (const f of files) {
    const text = await Bun.file(f).text();
    runs.push({ runId: basename(f), cases: parseFile(f, text) });
  }

  const agg = aggregate(runs);
  const md = renderMarkdown(agg);

  if (outPath) await Bun.write(outPath, md);
  else console.log(md);

  // GitHub Actions: also append to the job summary file when running in CI.
  const stepSummary = process.env.GITHUB_STEP_SUMMARY;
  if (stepSummary) {
    const existing = (await Bun.file(stepSummary).exists())
      ? await Bun.file(stepSummary).text()
      : "";
    await Bun.write(stepSummary, existing + md + "\n");
  }

  // Print a single-line summary so workflow logs show exact totals (used by act assertions).
  const { passed, failed, skipped, total } = agg.totals;
  console.log(
    `AGG_SUMMARY passed=${passed} failed=${failed} skipped=${skipped} total=${total} flaky=${agg.flaky.length} runs=${agg.runs.length}`
  );

  // By default, exit 0 — the aggregator's job is to *report*, not to gate the build.
  // --fail-on-failures opts in to non-zero exit when any test failed.
  return failOnFailures && agg.totals.failed > 0 ? 1 : 0;
}

if (import.meta.main) {
  try {
    const code = await main(process.argv.slice(2));
    process.exit(code);
  } catch (e) {
    console.error(`error: ${(e as Error).message}`);
    process.exit(2);
  }
}
