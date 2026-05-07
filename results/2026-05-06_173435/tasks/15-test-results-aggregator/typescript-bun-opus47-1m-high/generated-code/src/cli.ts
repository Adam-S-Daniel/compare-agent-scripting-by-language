// CLI entry point. Walks an input directory, parses every recognised result
// file, aggregates them, writes a markdown summary, and exits non-zero if any
// test failed.
//
// Designed to slot into a GitHub Actions step:
//   bun run src/cli.ts --input ./test-results --summary $GITHUB_STEP_SUMMARY
//
// We export `runCli` so unit tests can drive it without spawning a subprocess.

import { readdirSync, readFileSync, statSync, writeFileSync, existsSync } from "node:fs";
import { extname, join } from "node:path";
import { aggregate } from "./aggregator.ts";
import { renderMarkdown } from "./markdown.ts";
import { parseJUnitXml, parseJsonResults } from "./parsers.ts";
import type { AggregatedResults, TestSuite } from "./types.ts";

export interface CliOptions {
  inputDir: string;
  summaryPath: string;
}

export interface CliResult {
  exitCode: number;
  results: AggregatedResults;
}

function walk(dir: string): string[] {
  const entries = readdirSync(dir);
  const out: string[] = [];
  for (const e of entries) {
    const full = join(dir, e);
    const st = statSync(full);
    if (st.isDirectory()) {
      out.push(...walk(full));
    } else {
      out.push(full);
    }
  }
  return out;
}

function parseFile(path: string): TestSuite[] {
  const ext = extname(path).toLowerCase();
  const content = readFileSync(path, "utf8");
  if (ext === ".xml") return parseJUnitXml(content, path);
  if (ext === ".json") return parseJsonResults(content, path);
  return [];
}

export function runCli(opts: CliOptions): CliResult {
  if (!existsSync(opts.inputDir)) {
    throw new Error(`input directory does not exist: ${opts.inputDir}`);
  }
  const files = walk(opts.inputDir).filter((f) => {
    const ext = extname(f).toLowerCase();
    return ext === ".xml" || ext === ".json";
  });

  const allSuites: TestSuite[] = [];
  for (const f of files) {
    allSuites.push(...parseFile(f));
  }

  const results = aggregate(allSuites);
  const md = renderMarkdown(results);
  writeFileSync(opts.summaryPath, md, "utf8");

  return {
    exitCode: results.failed > 0 ? 1 : 0,
    results,
  };
}

// Run when invoked directly via `bun run src/cli.ts`.
// Bun sets `import.meta.main` to true for the entry module.
if (import.meta.main) {
  const args = process.argv.slice(2);
  let inputDir = "./test-results";
  let summaryPath = process.env.GITHUB_STEP_SUMMARY ?? "./summary.md";
  // --no-fail keeps the process exit at 0 even when tests failed. Useful in
  // CI when the aggregator is purely informational and another step decides
  // policy (e.g. block PR vs. just annotate).
  let noFail = false;

  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === "--input" || a === "-i") {
      inputDir = args[++i];
    } else if (a === "--summary" || a === "-s") {
      summaryPath = args[++i];
    } else if (a === "--no-fail") {
      noFail = true;
    } else if (a === "--help" || a === "-h") {
      console.log(
        "usage: bun run src/cli.ts --input <dir> [--summary <path>] [--no-fail]\n" +
          "  --input    directory containing JUnit .xml or .json result files\n" +
          "  --summary  output markdown path (defaults to $GITHUB_STEP_SUMMARY or ./summary.md)\n" +
          "  --no-fail  exit 0 even when failures are present",
      );
      process.exit(0);
    } else {
      console.error(`unknown argument: ${a}`);
      process.exit(2);
    }
  }

  try {
    const r = runCli({ inputDir, summaryPath });
    // Machine-parseable summary on a single line — the act-based harness
    // greps for these exact tokens, so the format is part of the contract.
    console.log(
      `RESULTS files=${r.results.fileCount} total=${r.results.totalTests} ` +
        `passed=${r.results.passed} failed=${r.results.failed} ` +
        `skipped=${r.results.skipped} flaky=${r.results.flaky.length} ` +
        `duration=${r.results.totalDuration.toFixed(2)}s`,
    );
    if (r.results.flaky.length > 0) {
      const names = r.results.flaky
        .map((f) => (f.classname ? `${f.classname}::${f.name}` : f.name))
        .join(",");
      console.log(`FLAKY ${names}`);
    }
    process.exit(noFail ? 0 : r.exitCode);
  } catch (err) {
    console.error(`error: ${(err as Error).message}`);
    process.exit(2);
  }
}
