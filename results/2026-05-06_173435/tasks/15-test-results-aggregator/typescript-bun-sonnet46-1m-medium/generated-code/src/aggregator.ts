// Test Results Aggregator
// Parses JUnit XML and JSON test result files, aggregates results across matrix
// build runs, identifies flaky tests, and generates a GitHub Actions markdown summary.

// ── Types ─────────────────────────────────────────────────────────────────────

export type TestStatus = "passed" | "failed" | "skipped";

export interface TestCase {
  name: string;
  classname?: string;
  duration: number;
  status: TestStatus;
  error?: string;
}

export interface TestSuite {
  name: string;
  duration: number;
  testCases: TestCase[];
}

export interface TestRunResult {
  source: string;
  suites: TestSuite[];
}

export interface AggregatedResult {
  totalPassed: number;
  totalFailed: number;
  totalSkipped: number;
  totalDuration: number;
  testRuns: TestRunResult[];
}

export interface FlakyTest {
  name: string;
  passCount: number;
  failCount: number;
  sources: string[];
}

// ── JUnit XML parser ──────────────────────────────────────────────────────────

// Minimal XML attribute extractor — avoids a full XML dependency.
function attr(element: string, name: string): string | undefined {
  const re = new RegExp(`${name}="([^"]*)"`);
  return re.exec(element)?.[1];
}

// Extract all <tag ...> blocks (both self-closing and with child content).
function* matchElements(xml: string, tag: string): Generator<string> {
  // Match opening tag with optional attributes
  const open = new RegExp(`<${tag}(\\s[^>]*)?>`, "gs");
  let m: RegExpExecArray | null;
  while ((m = open.exec(xml)) !== null) {
    const start = m.index;
    const selfClose = m[0].endsWith("/>");
    if (selfClose) {
      yield m[0];
      continue;
    }
    // find matching closing tag
    const closeTag = `</${tag}>`;
    const end = xml.indexOf(closeTag, start);
    if (end === -1) {
      yield m[0]; // unclosed element — return just the opening tag
    } else {
      yield xml.slice(start, end + closeTag.length);
    }
  }
}

// Pull inner text of a child element (used for failure/error message text).
function innerText(element: string, tag: string): string | undefined {
  const re = new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\/${tag}>`, "i");
  return re.exec(element)?.[1]?.trim();
}

export function parseJUnitXml(xml: string, source: string): TestRunResult {
  // Basic sanity check: must look like XML
  if (!xml.trim().startsWith("<")) {
    throw new Error(`parseJUnitXml: "${source}" does not appear to be XML`);
  }

  const suites: TestSuite[] = [];

  for (const suiteBlock of matchElements(xml, "testsuite")) {
    const suiteName = attr(suiteBlock, "name") ?? "Unknown Suite";
    const suiteDuration = parseFloat(attr(suiteBlock, "time") ?? "0") || 0;
    const testCases: TestCase[] = [];

    for (const caseBlock of matchElements(suiteBlock, "testcase")) {
      const name = attr(caseBlock, "name") ?? "Unknown Test";
      const classname = attr(caseBlock, "classname");
      const duration = parseFloat(attr(caseBlock, "time") ?? "0") || 0;

      let status: TestStatus = "passed";
      let error: string | undefined;

      if (caseBlock.includes("<failure") || caseBlock.includes("<error")) {
        status = "failed";
        // Capture the message attribute or inner text of the failure/error element
        const failureAttrMsg = attr(caseBlock, "message");
        const failureBody = innerText(caseBlock, "failure") ?? innerText(caseBlock, "error");
        error = failureAttrMsg
          ? failureAttrMsg + (failureBody ? `: ${failureBody}` : "")
          : failureBody;
      } else if (caseBlock.includes("<skipped")) {
        status = "skipped";
      }

      testCases.push({ name, classname, duration, status, error });
    }

    suites.push({ name: suiteName, duration: suiteDuration, testCases });
  }

  if (suites.length === 0) {
    throw new Error(`parseJUnitXml: no <testsuite> elements found in "${source}"`);
  }

  return { source, suites };
}

// ── JSON results parser ───────────────────────────────────────────────────────

// Supported JSON schema:
// { name, duration, suites: [{ name, tests: [{ name, status, duration, error? }] }] }

interface JsonTestCase {
  name: string;
  status: string;
  duration?: number;
  error?: string;
}

interface JsonSuite {
  name: string;
  duration?: number;
  tests: JsonTestCase[];
}

interface JsonResults {
  name: string;
  duration?: number;
  suites: JsonSuite[];
}

export function parseJsonResults(json: string, source: string): TestRunResult {
  let data: JsonResults;
  try {
    data = JSON.parse(json) as JsonResults;
  } catch (e) {
    throw new Error(`parseJsonResults: invalid JSON in "${source}": ${(e as Error).message}`);
  }

  if (!Array.isArray(data.suites)) {
    throw new Error(`parseJsonResults: "${source}" missing "suites" array`);
  }

  const suites: TestSuite[] = data.suites.map((s) => {
    const testCases: TestCase[] = (s.tests ?? []).map((t) => {
      const rawStatus = (t.status ?? "").toLowerCase();
      let status: TestStatus;
      if (rawStatus === "passed" || rawStatus === "pass") {
        status = "passed";
      } else if (rawStatus === "failed" || rawStatus === "fail" || rawStatus === "error") {
        status = "failed";
      } else {
        status = "skipped";
      }
      return {
        name: t.name ?? "Unknown",
        duration: typeof t.duration === "number" ? t.duration : 0,
        status,
        error: t.error,
      };
    });

    const suiteDuration =
      typeof s.duration === "number"
        ? s.duration
        : testCases.reduce((acc, tc) => acc + tc.duration, 0);

    return { name: s.name ?? "Unknown Suite", duration: suiteDuration, testCases };
  });

  return { source, suites };
}

// ── Aggregation ───────────────────────────────────────────────────────────────

export function aggregateResults(runs: TestRunResult[]): AggregatedResult {
  let totalPassed = 0;
  let totalFailed = 0;
  let totalSkipped = 0;
  let totalDuration = 0;

  for (const run of runs) {
    for (const suite of run.suites) {
      for (const tc of suite.testCases) {
        totalDuration += tc.duration;
        if (tc.status === "passed") totalPassed++;
        else if (tc.status === "failed") totalFailed++;
        else totalSkipped++;
      }
    }
  }

  return { totalPassed, totalFailed, totalSkipped, totalDuration, testRuns: runs };
}

// ── Flaky test detection ──────────────────────────────────────────────────────

// A test is flaky if it appears in multiple runs with at least one pass AND one failure.
export function identifyFlakyTests(agg: AggregatedResult): FlakyTest[] {
  // Map test name → { passCount, failCount, sources }
  const map = new Map<string, { passCount: number; failCount: number; sources: Set<string> }>();

  for (const run of agg.testRuns) {
    for (const suite of run.suites) {
      for (const tc of suite.testCases) {
        if (tc.status === "skipped") continue;
        const existing = map.get(tc.name) ?? { passCount: 0, failCount: 0, sources: new Set() };
        if (tc.status === "passed") existing.passCount++;
        else existing.failCount++;
        existing.sources.add(run.source);
        map.set(tc.name, existing);
      }
    }
  }

  const flaky: FlakyTest[] = [];
  for (const [name, entry] of map) {
    if (entry.passCount > 0 && entry.failCount > 0) {
      flaky.push({
        name,
        passCount: entry.passCount,
        failCount: entry.failCount,
        sources: [...entry.sources],
      });
    }
  }

  return flaky;
}

// ── Markdown summary ──────────────────────────────────────────────────────────

export function generateMarkdownSummary(
  agg: AggregatedResult,
  flaky: FlakyTest[]
): string {
  const total = agg.totalPassed + agg.totalFailed + agg.totalSkipped;
  const passRate = total > 0 ? ((agg.totalPassed / total) * 100).toFixed(1) : "0.0";
  const durationStr = agg.totalDuration.toFixed(2);

  const lines: string[] = [
    "# Test Results Summary",
    "",
    "## Totals",
    "",
    `| Metric | Value |`,
    `|--------|-------|`,
    `| Passed | ${agg.totalPassed} |`,
    `| Failed | ${agg.totalFailed} |`,
    `| Skipped | ${agg.totalSkipped} |`,
    `| Total | ${total} |`,
    `| Pass Rate | ${passRate}% |`,
    `| Duration | ${durationStr}s |`,
    "",
  ];

  // Per-run breakdown
  if (agg.testRuns.length > 0) {
    lines.push("## Runs");
    lines.push("");
    lines.push("| Source | Passed | Failed | Skipped | Duration |");
    lines.push("|--------|--------|--------|---------|----------|");
    for (const run of agg.testRuns) {
      let p = 0, f = 0, s = 0, d = 0;
      for (const suite of run.suites) {
        for (const tc of suite.testCases) {
          d += tc.duration;
          if (tc.status === "passed") p++;
          else if (tc.status === "failed") f++;
          else s++;
        }
      }
      lines.push(`| ${run.source} | ${p} | ${f} | ${s} | ${d.toFixed(2)}s |`);
    }
    lines.push("");
  }

  // Flaky tests section
  lines.push("## Flaky Tests");
  lines.push("");
  if (flaky.length === 0) {
    lines.push("No flaky tests detected.");
  } else {
    lines.push(`Found **${flaky.length}** flaky test(s):`);
    lines.push("");
    lines.push("| Test Name | Passes | Failures | Sources |");
    lines.push("|-----------|--------|----------|---------|");
    for (const f of flaky) {
      const srcs = f.sources.join(", ");
      lines.push(`| ${f.name} | ${f.passCount} | ${f.failCount} | ${srcs} |`);
    }
  }

  return lines.join("\n");
}
