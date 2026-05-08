// Test-results aggregator core.
//
// Pure functions only — file IO is isolated in `loadFile` / the CLI so the
// parsing + aggregation logic stays trivially testable.
import { readFileSync } from "node:fs";
import { extname } from "node:path";

export type Status = "passed" | "failed" | "skipped";

export interface TestCase {
  suite: string;
  name: string;
  status: Status;
  duration: number; // seconds
  message?: string;
}

export interface TestRun {
  source: string;
  tests: TestCase[];
}

export interface Totals {
  passed: number;
  failed: number;
  skipped: number;
  total: number;
  duration: number;
}

export interface FlakyTest {
  suite: string;
  name: string;
  passed: number;
  failed: number;
  sources: string[];
}

export interface SuiteSummary {
  suite: string;
  passed: number;
  failed: number;
  skipped: number;
  duration: number;
}

export interface Aggregated {
  totals: Totals;
  flaky: FlakyTest[];
  suites: SuiteSummary[];
  failures: { suite: string; name: string; source: string; message?: string }[];
  runs: number;
}

// --- JUnit XML parser ----------------------------------------------------
//
// We deliberately avoid pulling in a heavy XML library. JUnit XML is a
// well-known, shallow shape; a focused regex-based extractor handles every
// JUnit dialect we care about (Jest, pytest, surefire, gotestsum, ...).
export function parseJUnitXml(xml: string, source: string): TestRun {
  if (!/<testsuites?\b/i.test(xml)) {
    throw new Error(`Not a JUnit XML document: ${source}`);
  }
  const tests: TestCase[] = [];
  // Match each <testsuite ...> block so we can attribute classname fallback.
  const suiteRe =
    /<testsuite\b([^>]*)>([\s\S]*?)<\/testsuite>|<testsuite\b([^/]*)\/>/gi;
  let suiteMatch: RegExpExecArray | null;
  while ((suiteMatch = suiteRe.exec(xml)) !== null) {
    const attrs = suiteMatch[1] ?? suiteMatch[3] ?? "";
    const body = suiteMatch[2] ?? "";
    const suiteName = attr(attrs, "name") ?? "default";
    const caseRe =
      /<testcase\b([^>]*?)\/>|<testcase\b([^>]*)>([\s\S]*?)<\/testcase>/gi;
    let caseMatch: RegExpExecArray | null;
    while ((caseMatch = caseRe.exec(body)) !== null) {
      const cAttrs = caseMatch[1] ?? caseMatch[2] ?? "";
      const cBody = caseMatch[3] ?? "";
      const name = attr(cAttrs, "name") ?? "(unnamed)";
      const classname = attr(cAttrs, "classname") ?? suiteName;
      const time = parseFloat(attr(cAttrs, "time") ?? "0") || 0;
      let status: Status = "passed";
      let message: string | undefined;
      if (/<failure\b/i.test(cBody) || /<error\b/i.test(cBody)) {
        status = "failed";
        message = attr(cBody.match(/<(?:failure|error)\b([^>]*)/i)?.[1] ?? "", "message");
      } else if (/<skipped\b/i.test(cBody)) {
        status = "skipped";
      }
      tests.push({ suite: classname, name, status, duration: time, message });
    }
  }
  return { source, tests };
}

function attr(attrs: string, key: string): string | undefined {
  const m = new RegExp(`\\b${key}\\s*=\\s*"([^"]*)"`, "i").exec(attrs);
  return m?.[1];
}

// --- JSON parser ---------------------------------------------------------
//
// Internal/portable JSON shape: { tests: [{ suite, name, status, duration }] }.
// This is intentionally minimal — tools that want to feed us output transform
// it to this shape rather than us trying to support every framework's JSON.
export function parseJsonResults(text: string, source: string): TestRun {
  let data: unknown;
  try {
    data = JSON.parse(text);
  } catch (e) {
    throw new Error(`Invalid JSON in ${source}: ${(e as Error).message}`);
  }
  if (
    typeof data !== "object" ||
    data === null ||
    !Array.isArray((data as { tests?: unknown }).tests)
  ) {
    throw new Error(`Expected a 'tests' array in ${source}`);
  }
  const tests: TestCase[] = (data as { tests: unknown[] }).tests.map((raw, i) => {
    const t = raw as Partial<TestCase>;
    if (!t.name || !t.status) {
      throw new Error(
        `Invalid test entry at index ${i} in ${source}: missing name or status`,
      );
    }
    if (!["passed", "failed", "skipped"].includes(t.status)) {
      throw new Error(`Invalid status '${t.status}' in ${source}`);
    }
    return {
      suite: t.suite ?? "default",
      name: t.name,
      status: t.status as Status,
      duration: typeof t.duration === "number" ? t.duration : 0,
      message: t.message,
    };
  });
  return { source, tests };
}

// Auto-detect format by extension; fallback by sniffing the first non-blank char.
export function loadFile(path: string): TestRun {
  const text = readFileSync(path, "utf8");
  const ext = extname(path).toLowerCase();
  if (ext === ".xml") return parseJUnitXml(text, path);
  if (ext === ".json") return parseJsonResults(text, path);
  const firstChar = text.trim()[0];
  if (firstChar === "<") return parseJUnitXml(text, path);
  if (firstChar === "{" || firstChar === "[") return parseJsonResults(text, path);
  throw new Error(`Cannot detect format for ${path}`);
}

// --- Aggregation ---------------------------------------------------------
export function aggregate(runs: TestRun[]): Aggregated {
  const totals: Totals = {
    passed: 0,
    failed: 0,
    skipped: 0,
    total: 0,
    duration: 0,
  };
  // Per-test history for flakiness detection.
  const history = new Map<
    string,
    { suite: string; name: string; passed: number; failed: number; sources: string[] }
  >();
  const suiteMap = new Map<string, SuiteSummary>();
  const failures: Aggregated["failures"] = [];

  for (const run of runs) {
    for (const t of run.tests) {
      totals.total++;
      totals[t.status]++;
      totals.duration += t.duration;

      const suiteSummary =
        suiteMap.get(t.suite) ??
        { suite: t.suite, passed: 0, failed: 0, skipped: 0, duration: 0 };
      suiteSummary[t.status]++;
      suiteSummary.duration += t.duration;
      suiteMap.set(t.suite, suiteSummary);

      const key = `${t.suite}::${t.name}`;
      const h =
        history.get(key) ??
        { suite: t.suite, name: t.name, passed: 0, failed: 0, sources: [] as string[] };
      if (t.status === "passed") h.passed++;
      else if (t.status === "failed") {
        h.failed++;
        failures.push({
          suite: t.suite,
          name: t.name,
          source: run.source,
          message: t.message,
        });
      }
      h.sources.push(run.source);
      history.set(key, h);
    }
  }

  // A test is flaky if it both passed and failed at least once.
  const flaky: FlakyTest[] = [];
  for (const h of history.values()) {
    if (h.passed > 0 && h.failed > 0) flaky.push(h);
  }

  // Round duration to avoid float crud.
  totals.duration = round(totals.duration);
  const suites = [...suiteMap.values()]
    .map((s) => ({ ...s, duration: round(s.duration) }))
    .sort((a, b) => a.suite.localeCompare(b.suite));

  return { totals, flaky, suites, failures, runs: runs.length };
}

function round(n: number): number {
  return Math.round(n * 1000) / 1000;
}

// --- Markdown rendering --------------------------------------------------
export function renderMarkdown(agg: Aggregated): string {
  const { totals, flaky, suites, failures, runs } = agg;
  const lines: string[] = [];
  lines.push("# Test Results");
  lines.push("");
  lines.push(`Aggregated across **${runs}** run(s).`);
  lines.push("");
  lines.push("## Totals");
  lines.push("");
  lines.push("| Passed | Failed | Skipped | Total | Duration (s) |");
  lines.push("|-------:|-------:|--------:|------:|-------------:|");
  lines.push(
    `| ${totals.passed} | ${totals.failed} | ${totals.skipped} | ${totals.total} | ${totals.duration.toFixed(2)} |`,
  );
  lines.push("");

  if (totals.failed === 0 && flaky.length === 0) {
    lines.push(`All ${totals.passed} tests passed cleanly.`);
    lines.push("");
  }

  lines.push("## By suite");
  lines.push("");
  lines.push("| Suite | Passed | Failed | Skipped | Duration (s) |");
  lines.push("|-------|-------:|-------:|--------:|-------------:|");
  for (const s of suites) {
    lines.push(
      `| ${s.suite} | ${s.passed} | ${s.failed} | ${s.skipped} | ${s.duration.toFixed(2)} |`,
    );
  }
  lines.push("");

  lines.push("## Flaky tests");
  lines.push("");
  if (flaky.length === 0) {
    lines.push("_None detected._");
  } else {
    lines.push("| Suite | Test | Passed | Failed |");
    lines.push("|-------|------|-------:|-------:|");
    for (const f of flaky) {
      lines.push(`| ${f.suite} | ${f.name} | ${f.passed} | ${f.failed} |`);
    }
  }
  lines.push("");

  if (failures.length > 0) {
    lines.push("## Failures");
    lines.push("");
    for (const f of failures) {
      lines.push(`- **${f.suite} / ${f.name}** (from \`${f.source}\`)${f.message ? `: ${f.message}` : ""}`);
    }
    lines.push("");
  }
  return lines.join("\n");
}
