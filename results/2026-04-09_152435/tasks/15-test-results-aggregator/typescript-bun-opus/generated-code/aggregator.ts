/**
 * Test Results Aggregator
 *
 * Parses JUnit XML and JSON test result files, aggregates across multiple
 * matrix runs, detects flaky tests, and generates a GitHub Actions markdown summary.
 */

import { readFileSync, readdirSync } from "fs";
import { join, extname } from "path";

// ── Types ──────────────────────────────────────────────────────────────────

/** A single test case result */
export interface TestResult {
  classname: string;
  name: string;
  status: "passed" | "failed" | "skipped";
  duration: number; // seconds
  error?: string;
}

/** A test suite containing multiple test cases */
export interface TestSuite {
  name: string;
  tests: TestResult[];
}

/** Parsed output from a single result file */
export interface ParsedFile {
  source: string; // filename
  suites: TestSuite[];
}

/** Aggregated totals across all files */
export interface AggregatedTotals {
  passed: number;
  failed: number;
  skipped: number;
  total: number;
  duration: number; // total seconds
}

/** A test identified as flaky (passed in some runs, failed in others) */
export interface FlakyTest {
  classname: string;
  name: string;
  passCount: number;
  failCount: number;
}

// ── XML Parsing ────────────────────────────────────────────────────────────

/**
 * Minimal XML parser for JUnit format. Extracts testcase elements with
 * their attributes and child elements (failure, skipped).
 * No external dependencies — uses regex-based extraction.
 */
export function parseJUnitXML(xml: string, source: string): ParsedFile {
  const suites: TestSuite[] = [];

  // Match each <testsuite> block
  const suiteRegex = /<testsuite\s+([^>]*)>([\s\S]*?)<\/testsuite>/g;
  let suiteMatch: RegExpExecArray | null;

  while ((suiteMatch = suiteRegex.exec(xml)) !== null) {
    const suiteAttrs = suiteMatch[1];
    const suiteBody = suiteMatch[2];
    const suiteName = extractAttr(suiteAttrs, "name") || "Unknown";

    const tests: TestResult[] = [];

    // Match each <testcase> — can be self-closing or have children
    const tcRegex = /<testcase\s+([^>]*?)(?:\/>|>([\s\S]*?)<\/testcase>)/g;
    let tcMatch: RegExpExecArray | null;

    while ((tcMatch = tcRegex.exec(suiteBody)) !== null) {
      const attrs = tcMatch[1];
      const body = tcMatch[2] || "";

      const classname = extractAttr(attrs, "classname") || suiteName;
      const name = extractAttr(attrs, "name") || "unknown";
      const duration = parseFloat(extractAttr(attrs, "time") || "0");

      let status: "passed" | "failed" | "skipped" = "passed";
      let error: string | undefined;

      if (/<failure\s/.test(body) || /<failure>/.test(body)) {
        status = "failed";
        error = extractAttr(body, "message") || "Test failed";
      } else if (/<skipped/.test(body)) {
        status = "skipped";
      }

      tests.push({ classname, name, status, duration, error });
    }

    suites.push({ name: suiteName, tests });
  }

  return { source, suites };
}

/** Extract an XML attribute value by name */
function extractAttr(text: string, attr: string): string | undefined {
  // Word boundary ensures "name" doesn't match inside "classname"
  const re = new RegExp(`(?:^|\\s)${attr}="([^"]*)"`, "i");
  const m = re.exec(text);
  return m ? m[1] : undefined;
}

// ── JSON Parsing ───────────────────────────────────────────────────────────

/** Expected shape of JSON test result files */
interface JsonTestFile {
  testSuites: Array<{
    name: string;
    tests: Array<{
      name: string;
      classname: string;
      status: string;
      duration: number;
      error?: string;
    }>;
  }>;
}

export function parseJSONResults(json: string, source: string): ParsedFile {
  const data: JsonTestFile = JSON.parse(json);

  if (!data.testSuites || !Array.isArray(data.testSuites)) {
    throw new Error(`Invalid JSON test results in ${source}: missing testSuites array`);
  }

  const suites: TestSuite[] = data.testSuites.map((s) => ({
    name: s.name,
    tests: s.tests.map((t) => ({
      classname: t.classname,
      name: t.name,
      status: normalizeStatus(t.status),
      duration: t.duration,
      error: t.error,
    })),
  }));

  return { source, suites };
}

function normalizeStatus(s: string): "passed" | "failed" | "skipped" {
  const lower = s.toLowerCase();
  if (lower === "passed" || lower === "pass") return "passed";
  if (lower === "failed" || lower === "fail" || lower === "error") return "failed";
  if (lower === "skipped" || lower === "skip") return "skipped";
  throw new Error(`Unknown test status: ${s}`);
}

// ── File Loading ───────────────────────────────────────────────────────────

/** Parse a single file based on its extension */
export function parseFile(filePath: string): ParsedFile {
  const content = readFileSync(filePath, "utf-8");
  const ext = extname(filePath).toLowerCase();
  const source = filePath.split("/").pop() || filePath;

  if (ext === ".xml") {
    return parseJUnitXML(content, source);
  } else if (ext === ".json") {
    return parseJSONResults(content, source);
  } else {
    throw new Error(`Unsupported file format: ${ext} (${filePath})`);
  }
}

/** Load all test result files from a directory */
export function loadDirectory(dir: string): ParsedFile[] {
  const files = readdirSync(dir).filter(
    (f) => f.endsWith(".xml") || f.endsWith(".json")
  );

  if (files.length === 0) {
    throw new Error(`No test result files found in ${dir}`);
  }

  return files.map((f) => parseFile(join(dir, f)));
}

// ── Aggregation ────────────────────────────────────────────────────────────

/** Compute totals across all parsed files */
export function aggregateTotals(files: ParsedFile[]): AggregatedTotals {
  let passed = 0;
  let failed = 0;
  let skipped = 0;
  let duration = 0;

  for (const file of files) {
    for (const suite of file.suites) {
      for (const test of suite.tests) {
        if (test.status === "passed") passed++;
        else if (test.status === "failed") failed++;
        else if (test.status === "skipped") skipped++;
        duration += test.duration;
      }
    }
  }

  return { passed, failed, skipped, total: passed + failed + skipped, duration };
}

// ── Flaky Detection ────────────────────────────────────────────────────────

/**
 * Identify flaky tests: tests that appear in multiple files and have
 * different outcomes (passed in some, failed in others).
 */
export function detectFlakyTests(files: ParsedFile[]): FlakyTest[] {
  // Key: "classname::name"
  const outcomes = new Map<string, { pass: number; fail: number }>();

  for (const file of files) {
    for (const suite of file.suites) {
      for (const test of suite.tests) {
        if (test.status === "skipped") continue;
        const key = `${test.classname}::${test.name}`;
        const entry = outcomes.get(key) || { pass: 0, fail: 0 };
        if (test.status === "passed") entry.pass++;
        else if (test.status === "failed") entry.fail++;
        outcomes.set(key, entry);
      }
    }
  }

  const flaky: FlakyTest[] = [];
  for (const [key, counts] of outcomes) {
    if (counts.pass > 0 && counts.fail > 0) {
      const [classname, name] = key.split("::");
      flaky.push({
        classname,
        name,
        passCount: counts.pass,
        failCount: counts.fail,
      });
    }
  }

  return flaky.sort((a, b) => `${a.classname}::${a.name}`.localeCompare(`${b.classname}::${b.name}`));
}

// ── Markdown Summary ───────────────────────────────────────────────────────

/** Generate a GitHub Actions-compatible markdown summary */
export function generateMarkdownSummary(
  files: ParsedFile[],
  totals: AggregatedTotals,
  flaky: FlakyTest[]
): string {
  const lines: string[] = [];

  // Header
  lines.push("# Test Results Summary");
  lines.push("");

  // Status badge
  const statusIcon = totals.failed > 0 ? "FAIL" : "PASS";
  lines.push(`**Status:** ${statusIcon}`);
  lines.push("");

  // Totals table
  lines.push("## Totals");
  lines.push("");
  lines.push("| Metric | Value |");
  lines.push("|--------|-------|");
  lines.push(`| Total tests | ${totals.total} |`);
  lines.push(`| Passed | ${totals.passed} |`);
  lines.push(`| Failed | ${totals.failed} |`);
  lines.push(`| Skipped | ${totals.skipped} |`);
  lines.push(`| Duration | ${totals.duration.toFixed(2)}s |`);
  lines.push("");

  // Per-file breakdown
  lines.push("## Per-File Breakdown");
  lines.push("");
  lines.push("| File | Passed | Failed | Skipped | Duration |");
  lines.push("|------|--------|--------|---------|----------|");
  for (const file of files) {
    const ft = aggregateTotals([file]);
    lines.push(
      `| ${file.source} | ${ft.passed} | ${ft.failed} | ${ft.skipped} | ${ft.duration.toFixed(2)}s |`
    );
  }
  lines.push("");

  // Failed tests
  const allFailed: Array<{ classname: string; name: string; error: string; source: string }> = [];
  for (const file of files) {
    for (const suite of file.suites) {
      for (const test of suite.tests) {
        if (test.status === "failed") {
          allFailed.push({
            classname: test.classname,
            name: test.name,
            error: test.error || "No error message",
            source: file.source,
          });
        }
      }
    }
  }

  if (allFailed.length > 0) {
    lines.push("## Failed Tests");
    lines.push("");
    lines.push("| Test | Error | Source |");
    lines.push("|------|-------|--------|");
    for (const f of allFailed) {
      lines.push(`| ${f.classname} > ${f.name} | ${f.error} | ${f.source} |`);
    }
    lines.push("");
  }

  // Flaky tests
  if (flaky.length > 0) {
    lines.push("## Flaky Tests");
    lines.push("");
    lines.push("| Test | Passed | Failed | Flake Rate |");
    lines.push("|------|--------|--------|------------|");
    for (const f of flaky) {
      const total = f.passCount + f.failCount;
      const rate = ((f.failCount / total) * 100).toFixed(0);
      lines.push(
        `| ${f.classname} > ${f.name} | ${f.passCount} | ${f.failCount} | ${rate}% |`
      );
    }
    lines.push("");
  }

  return lines.join("\n");
}

// ── CLI Entry Point ────────────────────────────────────────────────────────

/** Main function: parse directory, aggregate, output markdown */
export function main(dir: string): string {
  const files = loadDirectory(dir);
  const totals = aggregateTotals(files);
  const flaky = detectFlakyTests(files);
  const markdown = generateMarkdownSummary(files, totals, flaky);
  return markdown;
}

// Run from CLI: bun run aggregator.ts <dir>
if (import.meta.main) {
  const dir = process.argv[2];
  if (!dir) {
    console.error("Usage: bun run aggregator.ts <fixtures-dir>");
    process.exit(1);
  }
  const result = main(dir);
  console.log(result);
}
