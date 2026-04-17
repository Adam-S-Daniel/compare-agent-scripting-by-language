// Test result aggregator: parses JUnit XML and JSON test result files,
// aggregates across multiple runs, detects flaky tests, and emits markdown.

export type TestStatus = "passed" | "failed" | "skipped";

export interface TestCase {
  suite: string;
  classname: string;
  name: string;
  status: TestStatus;
  time: number;
  message?: string;
}

export interface TestRun {
  source: string;
  cases: TestCase[];
}

export interface Totals {
  total: number;
  passed: number;
  failed: number;
  skipped: number;
  duration: number;
}

export interface FlakyTest {
  id: string;
  statuses: TestStatus[];
}

export interface Aggregate {
  runs: TestRun[];
  totals: Totals;
  flaky: FlakyTest[];
}

// Parse JUnit XML. Uses a small hand-written parser — keeps zero deps for Bun.
export function parseJUnitXml(xml: string, source = "xml"): TestRun {
  const cases: TestCase[] = [];
  const suiteRegex = /<testsuite\b([^>]*)>([\s\S]*?)<\/testsuite>/g;
  let sMatch: RegExpExecArray | null;
  while ((sMatch = suiteRegex.exec(xml)) !== null) {
    const suiteAttrs = parseAttrs(sMatch[1]);
    const suiteName = suiteAttrs["name"] ?? "unknown";
    const body = sMatch[2];
    // Match <testcase .../> or <testcase ...>...</testcase>
    const caseRegex =
      /<testcase\b([^>]*?)(?:\/>|>([\s\S]*?)<\/testcase>)/g;
    let cMatch: RegExpExecArray | null;
    while ((cMatch = caseRegex.exec(body)) !== null) {
      const attrs = parseAttrs(cMatch[1]);
      const inner = cMatch[2] ?? "";
      let status: TestStatus = "passed";
      let message: string | undefined;
      if (/<failure\b/.test(inner) || /<error\b/.test(inner)) {
        status = "failed";
        const m = /<(?:failure|error)\b([^>]*)/.exec(inner);
        if (m) message = parseAttrs(m[1])["message"];
      } else if (/<skipped\b/.test(inner)) {
        status = "skipped";
      }
      cases.push({
        suite: suiteName,
        classname: attrs["classname"] ?? suiteName,
        name: attrs["name"] ?? "unnamed",
        status,
        time: Number(attrs["time"] ?? "0"),
        message,
      });
    }
  }
  if (cases.length === 0 && !/<testsuite/.test(xml)) {
    throw new Error(`Invalid JUnit XML from '${source}': no <testsuite> found`);
  }
  return { source, cases };
}

function parseAttrs(s: string): Record<string, string> {
  const out: Record<string, string> = {};
  const re = /(\w[\w:-]*)\s*=\s*"([^"]*)"/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(s)) !== null) out[m[1]] = m[2];
  return out;
}

interface JsonSuite {
  name: string;
  tests: Array<{
    name: string;
    classname?: string;
    status: TestStatus;
    time?: number;
    message?: string;
  }>;
}
interface JsonReport {
  suites: JsonSuite[];
}

export function parseJsonReport(text: string, source = "json"): TestRun {
  let parsed: JsonReport;
  try {
    parsed = JSON.parse(text);
  } catch (e) {
    throw new Error(`Invalid JSON from '${source}': ${(e as Error).message}`);
  }
  if (!parsed || !Array.isArray(parsed.suites)) {
    throw new Error(`Invalid JSON from '${source}': missing 'suites' array`);
  }
  const cases: TestCase[] = [];
  for (const suite of parsed.suites) {
    for (const t of suite.tests ?? []) {
      if (!["passed", "failed", "skipped"].includes(t.status)) {
        throw new Error(
          `Invalid status '${t.status}' for ${suite.name}.${t.name} in '${source}'`,
        );
      }
      cases.push({
        suite: suite.name,
        classname: t.classname ?? suite.name,
        name: t.name,
        status: t.status,
        time: t.time ?? 0,
        message: t.message,
      });
    }
  }
  return { source, cases };
}

// Auto-detect by extension or content.
export async function parseFile(path: string): Promise<TestRun> {
  const file = Bun.file(path);
  if (!(await file.exists())) {
    throw new Error(`Test result file not found: ${path}`);
  }
  const text = await file.text();
  const lower = path.toLowerCase();
  if (lower.endsWith(".xml")) return parseJUnitXml(text, path);
  if (lower.endsWith(".json")) return parseJsonReport(text, path);
  // Fallback: sniff content.
  if (text.trimStart().startsWith("<")) return parseJUnitXml(text, path);
  return parseJsonReport(text, path);
}

export function computeTotals(runs: TestRun[]): Totals {
  const t: Totals = { total: 0, passed: 0, failed: 0, skipped: 0, duration: 0 };
  for (const run of runs) {
    for (const c of run.cases) {
      t.total++;
      t[c.status]++;
      t.duration += c.time;
    }
  }
  // Round duration to 2 decimals to avoid float noise in output.
  t.duration = Math.round(t.duration * 100) / 100;
  return t;
}

// Flaky = a test (classname.name) that both passed and failed across runs.
export function findFlaky(runs: TestRun[]): FlakyTest[] {
  const map = new Map<string, TestStatus[]>();
  for (const run of runs) {
    for (const c of run.cases) {
      const id = `${c.classname}.${c.name}`;
      const arr = map.get(id) ?? [];
      arr.push(c.status);
      map.set(id, arr);
    }
  }
  const flaky: FlakyTest[] = [];
  for (const [id, statuses] of map) {
    if (statuses.includes("passed") && statuses.includes("failed")) {
      flaky.push({ id, statuses });
    }
  }
  flaky.sort((a, b) => a.id.localeCompare(b.id));
  return flaky;
}

export function aggregate(runs: TestRun[]): Aggregate {
  return { runs, totals: computeTotals(runs), flaky: findFlaky(runs) };
}

export function renderMarkdown(agg: Aggregate): string {
  const { totals, flaky, runs } = agg;
  const passRate =
    totals.total === 0
      ? "0.0"
      : ((totals.passed / totals.total) * 100).toFixed(1);
  const status = totals.failed === 0 ? "✅ PASS" : "❌ FAIL";
  const lines: string[] = [];
  lines.push(`# Test Results ${status}`);
  lines.push("");
  lines.push(`**Runs aggregated:** ${runs.length}`);
  lines.push("");
  lines.push("## Totals");
  lines.push("");
  lines.push("| Metric | Value |");
  lines.push("| --- | --- |");
  lines.push(`| Total | ${totals.total} |`);
  lines.push(`| Passed | ${totals.passed} |`);
  lines.push(`| Failed | ${totals.failed} |`);
  lines.push(`| Skipped | ${totals.skipped} |`);
  lines.push(`| Duration | ${totals.duration.toFixed(2)}s |`);
  lines.push(`| Pass rate | ${passRate}% |`);
  lines.push("");
  lines.push("## Flaky Tests");
  lines.push("");
  if (flaky.length === 0) {
    lines.push("_No flaky tests detected._");
  } else {
    lines.push("| Test | Results |");
    lines.push("| --- | --- |");
    for (const f of flaky) {
      lines.push(`| ${f.id} | ${f.statuses.join(", ")} |`);
    }
  }
  lines.push("");
  return lines.join("\n");
}

export async function main(argv: string[]): Promise<number> {
  const files = argv.filter((a) => !a.startsWith("--"));
  if (files.length === 0) {
    console.error("Usage: bun run src/aggregator.ts <file1> [file2...]");
    return 2;
  }
  const runs: TestRun[] = [];
  for (const f of files) runs.push(await parseFile(f));
  const agg = aggregate(runs);
  const md = renderMarkdown(agg);
  const outPath = process.env.GITHUB_STEP_SUMMARY;
  if (outPath) await Bun.write(outPath, md);
  console.log(md);
  return agg.totals.failed > 0 ? 1 : 0;
}

if (import.meta.main) {
  const code = await main(Bun.argv.slice(2));
  process.exit(code);
}
