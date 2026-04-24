// Test-result aggregator: parses JUnit XML + JSON, aggregates across runs,
// finds flaky tests, and renders a GitHub Actions markdown summary.
//
// Design notes:
// - No XML/JSON-schema library dependencies; we use small regex-based parsers
//   scoped to the subsets we care about so the script runs on a vanilla Bun install.
// - All parsing functions accept a `source` label so errors can point back to
//   the offending file path even though parsers themselves are string-based.

export type Status = "passed" | "failed" | "skipped";

export interface TestCase {
  name: string;
  status: Status;
  duration: number; // seconds
}

export interface TestRun {
  source: string;
  duration: number; // seconds
  tests: TestCase[];
}

export interface Totals {
  passed: number;
  failed: number;
  skipped: number;
  total: number;
  duration: number;
}

export interface FlakyEntry {
  name: string;
  passCount: number;
  failCount: number;
}

export interface Aggregate {
  totals: Totals;
  runs: TestRun[];
  flaky: FlakyEntry[];
}

// --- JUnit XML parsing -----------------------------------------------------

// Minimal, tolerant JUnit parser. Pulls <testcase ...>...</testcase> blocks
// plus self-closing variants, and inspects each block for <failure>/<error>/<skipped>.
export function parseJUnit(xml: string, source: string): TestRun {
  if (!/<testsuite[\s>]|<testsuites[\s>]/i.test(xml)) {
    throw new Error(`${source}: does not look like JUnit XML`);
  }

  const tests: TestCase[] = [];
  // Match testcase blocks (self-closing or with body).
  const re = /<testcase\b([^>]*?)(?:\/>|>([\s\S]*?)<\/testcase\s*>)/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(xml)) !== null) {
    const attrs = m[1] ?? "";
    const body = m[2] ?? "";
    const name = attr(attrs, "name") ?? "unknown";
    const classname = attr(attrs, "classname");
    const time = Number(attr(attrs, "time") ?? "0") || 0;
    let status: Status = "passed";
    if (/<failure\b|<error\b/i.test(body)) status = "failed";
    else if (/<skipped\b/i.test(body)) status = "skipped";
    tests.push({
      name: classname ? `${classname}.${name}` : name,
      status,
      duration: time,
    });
  }

  // Sum <testsuite time="..."> attrs for the run total; fall back to case sum.
  let duration = 0;
  const suiteRe = /<testsuite\b([^>]*)>/g;
  let s: RegExpExecArray | null;
  while ((s = suiteRe.exec(xml)) !== null) {
    const t = Number(attr(s[1] ?? "", "time") ?? "");
    if (!Number.isNaN(t)) duration += t;
  }
  if (!duration) duration = tests.reduce((a, t) => a + t.duration, 0);

  return { source, duration, tests };
}

function attr(attrs: string, key: string): string | undefined {
  const m = attrs.match(new RegExp(`\\b${key}\\s*=\\s*"([^"]*)"`, "i"));
  return m ? m[1] : undefined;
}

// --- JSON parsing ----------------------------------------------------------

// Expected shape: { suite?, duration?, tests: [{ name, status, duration }] }
// `status` may be "passed"/"pass"/"ok" etc.; normalize to our Status union.
export function parseJSON(text: string, source: string): TestRun {
  let data: unknown;
  try {
    data = JSON.parse(text);
  } catch (err) {
    throw new Error(`${source}: invalid JSON: ${(err as Error).message}`);
  }
  const obj = data as {
    duration?: number;
    tests?: Array<{ name?: string; status?: string; duration?: number }>;
  };
  if (!obj || !Array.isArray(obj.tests)) {
    throw new Error(`${source}: expected { tests: [...] }`);
  }
  const tests: TestCase[] = obj.tests.map((t, i) => ({
    name: t.name ?? `test-${i}`,
    status: normalizeStatus(t.status),
    duration: Number(t.duration) || 0,
  }));
  const duration =
    Number(obj.duration) || tests.reduce((a, t) => a + t.duration, 0);
  return { source, duration, tests };
}

function normalizeStatus(s: string | undefined): Status {
  const v = (s ?? "").toLowerCase();
  if (v === "pass" || v === "passed" || v === "ok" || v === "success") return "passed";
  if (v === "skip" || v === "skipped" || v === "pending") return "skipped";
  return "failed";
}

// --- File dispatch ---------------------------------------------------------

export async function parseResultFile(path: string): Promise<TestRun> {
  const lower = path.toLowerCase();
  if (!lower.endsWith(".xml") && !lower.endsWith(".json")) {
    throw new Error(`unsupported extension: ${path}`);
  }
  const text = await Bun.file(path).text();
  if (lower.endsWith(".xml")) return parseJUnit(text, path);
  return parseJSON(text, path);
}

// --- Aggregation -----------------------------------------------------------

export function aggregate(runs: TestRun[]): Aggregate {
  const totals: Totals = { passed: 0, failed: 0, skipped: 0, total: 0, duration: 0 };
  for (const run of runs) {
    totals.duration += run.duration;
    for (const t of run.tests) {
      totals[t.status] += 1;
      totals.total += 1;
    }
  }
  return { totals, runs, flaky: findFlaky(runs) };
}

export function findFlaky(runs: TestRun[]): FlakyEntry[] {
  const counts = new Map<string, { pass: number; fail: number }>();
  for (const run of runs) {
    for (const t of run.tests) {
      if (t.status === "skipped") continue;
      const prev = counts.get(t.name) ?? { pass: 0, fail: 0 };
      if (t.status === "passed") prev.pass++;
      else prev.fail++;
      counts.set(t.name, prev);
    }
  }
  const out: FlakyEntry[] = [];
  for (const [name, c] of counts) {
    if (c.pass > 0 && c.fail > 0) {
      out.push({ name, passCount: c.pass, failCount: c.fail });
    }
  }
  out.sort((a, b) => a.name.localeCompare(b.name));
  return out;
}

// --- Markdown rendering ----------------------------------------------------

export function renderMarkdown(agg: Aggregate): string {
  const { totals, runs, flaky } = agg;
  const status = totals.failed > 0 ? "FAILED" : "PASSED";
  const lines: string[] = [];
  lines.push(`# Test Results: ${status}`);
  lines.push("");
  lines.push("## Totals");
  lines.push("");
  lines.push("| Metric | Count |");
  lines.push("| --- | --- |");
  lines.push(`| Passed | ${totals.passed} |`);
  lines.push(`| Failed | ${totals.failed} |`);
  lines.push(`| Skipped | ${totals.skipped} |`);
  lines.push(`| Total | ${totals.total} |`);
  lines.push(`| Duration | ${totals.duration.toFixed(2)}s |`);
  lines.push("");
  lines.push("## Runs");
  lines.push("");
  lines.push("| Source | Passed | Failed | Skipped | Duration |");
  lines.push("| --- | --- | --- | --- | --- |");
  for (const run of runs) {
    const p = run.tests.filter((t) => t.status === "passed").length;
    const f = run.tests.filter((t) => t.status === "failed").length;
    const s = run.tests.filter((t) => t.status === "skipped").length;
    lines.push(
      `| ${run.source} | ${p} | ${f} | ${s} | ${run.duration.toFixed(2)}s |`,
    );
  }
  lines.push("");
  lines.push("## Flaky Tests");
  lines.push("");
  if (flaky.length === 0) {
    lines.push("_None detected._");
  } else {
    lines.push("| Test | Passes | Failures |");
    lines.push("| --- | --- | --- |");
    for (const fl of flaky) {
      lines.push(`| ${fl.name} | ${fl.passCount} | ${fl.failCount} |`);
    }
  }
  lines.push("");
  return lines.join("\n");
}
