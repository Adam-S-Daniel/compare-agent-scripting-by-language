#!/usr/bin/env bun
// CLI entry point. Usage: bun run src/cli.ts <file1> [file2 ...] [--out path]
// Writes the markdown summary to stdout (and to GITHUB_STEP_SUMMARY in CI).
import { aggregate, loadFile, renderMarkdown } from "./aggregator";
import { appendFileSync, writeFileSync, statSync, readdirSync } from "node:fs";
import { join } from "node:path";

function expandArgs(args: string[]): string[] {
  // Allow passing a directory; we'll recursively pick up *.xml / *.json.
  const files: string[] = [];
  for (const a of args) {
    let st;
    try {
      st = statSync(a);
    } catch {
      throw new Error(`Path does not exist: ${a}`);
    }
    if (st.isDirectory()) {
      for (const entry of readdirSync(a)) {
        if (entry.endsWith(".xml") || entry.endsWith(".json")) {
          files.push(join(a, entry));
        }
      }
    } else {
      files.push(a);
    }
  }
  return files;
}

function main(argv: string[]): number {
  const args = argv.slice(2);
  if (args.length === 0 || args.includes("--help") || args.includes("-h")) {
    console.error(
      "Usage: bun run src/cli.ts <file_or_dir>... [--out <markdown_path>]",
    );
    return 64;
  }
  let outPath: string | undefined;
  const positional: string[] = [];
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--out") {
      outPath = args[++i];
    } else {
      positional.push(args[i]);
    }
  }

  const files = expandArgs(positional);
  if (files.length === 0) {
    throw new Error("No test result files found");
  }

  const runs = files.map((f) => loadFile(f));
  const agg = aggregate(runs);
  const md = renderMarkdown(agg);

  process.stdout.write(md + "\n");

  if (outPath) writeFileSync(outPath, md);

  // GitHub Actions job summary integration.
  const stepSummary = process.env.GITHUB_STEP_SUMMARY;
  if (stepSummary) appendFileSync(stepSummary, md + "\n");

  // A short, parseable status line for CI assertions.
  console.log(
    `\n::AGG:: passed=${agg.totals.passed} failed=${agg.totals.failed} skipped=${agg.totals.skipped} flaky=${agg.flaky.length} runs=${agg.runs}`,
  );

  // Exit non-zero only if explicitly asked (we want the workflow to keep
  // going so the summary can be published even on failure).
  return 0;
}

try {
  process.exit(main(process.argv));
} catch (e) {
  console.error(`Error: ${(e as Error).message}`);
  process.exit(1);
}
