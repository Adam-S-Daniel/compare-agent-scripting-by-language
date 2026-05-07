import type { TestCase, TestStatus } from "./types";

// Tiny, dependency-free JUnit XML reader. Pulls out <testcase> elements with
// their classname/name/time and inspects whether each contains <failure>,
// <error>, or <skipped> children. Good enough for the common JUnit dialect
// emitted by Jest, pytest, gotestsum, JUnit5, etc.
export function parseJUnitXml(xml: string): TestCase[] {
  if (!/<testsuite[\s>]/.test(xml)) {
    throw new Error("Malformed JUnit XML: no <testsuite> element found");
  }

  const cases: TestCase[] = [];
  // Match the opening <testsuite ...> we are currently "inside" so we can fall
  // back to its name if a <testcase> omits classname.
  const testsuiteRe = /<testsuite\b([^>]*)>([\s\S]*?)<\/testsuite>/g;
  let suiteMatch: RegExpExecArray | null;
  while ((suiteMatch = testsuiteRe.exec(xml)) !== null) {
    const suiteAttrs = suiteMatch[1];
    const suiteBody = suiteMatch[2];
    const suiteName = attr(suiteAttrs, "name") ?? "unknown";

    // Self-closing <testcase ... /> and the open/close form. Handle both.
    const caseRe = /<testcase\b([^>]*?)(?:\/>|>([\s\S]*?)<\/testcase>)/g;
    let caseMatch: RegExpExecArray | null;
    while ((caseMatch = caseRe.exec(suiteBody)) !== null) {
      const attrs = caseMatch[1];
      const body = caseMatch[2] ?? "";
      const name = attr(attrs, "name") ?? "unknown";
      const suite = attr(attrs, "classname") ?? suiteName;
      const time = parseFloat(attr(attrs, "time") ?? "0");
      const durationMs = Math.round(time * 1000);

      let status: TestStatus = "passed";
      let message: string | undefined;
      const failure = /<(failure|error)\b([^>]*?)(?:\/>|>([\s\S]*?)<\/\1>)/.exec(body);
      const skipped = /<skipped\b/.test(body);
      if (failure) {
        status = "failed";
        message = attr(failure[2], "message") ?? (failure[3]?.trim() || undefined);
      } else if (skipped) {
        status = "skipped";
      }

      const tc: TestCase = { suite, name, status, durationMs };
      if (message) tc.message = message;
      cases.push(tc);
    }
  }
  return cases;
}

function attr(attrs: string | undefined, key: string): string | undefined {
  if (!attrs) return undefined;
  const re = new RegExp(`\\b${key}="([^"]*)"`);
  const m = re.exec(attrs);
  return m?.[1];
}

// JSON format we consume:
//   { "suite": "Name", "tests": [ { "name", "status", "durationMs", "message"? } ] }
// We accept both single-suite and multi-suite shapes.
export function parseJsonResults(text: string): TestCase[] {
  let data: unknown;
  try {
    data = JSON.parse(text);
  } catch (e) {
    throw new Error(`Invalid JSON test report: ${(e as Error).message}`);
  }
  const suites = Array.isArray(data) ? data : [data];
  const out: TestCase[] = [];
  for (const s of suites) {
    if (!s || typeof s !== "object") {
      throw new Error("JSON report must be an object or array of suites");
    }
    const suite = (s as { suite?: string }).suite ?? "unknown";
    const tests = (s as { tests?: unknown }).tests;
    if (!Array.isArray(tests)) {
      throw new Error(`JSON suite "${suite}" missing tests array`);
    }
    for (const t of tests) {
      const obj = t as Partial<TestCase>;
      if (!obj.name || !obj.status) {
        throw new Error(`JSON test missing name/status in suite ${suite}`);
      }
      const tc: TestCase = {
        suite,
        name: obj.name,
        status: obj.status as TestStatus,
        durationMs: obj.durationMs ?? 0,
      };
      if (obj.message) tc.message = obj.message;
      out.push(tc);
    }
  }
  return out;
}

export function parseFile(path: string, contents: string): TestCase[] {
  const lower = path.toLowerCase();
  if (lower.endsWith(".xml")) return parseJUnitXml(contents);
  if (lower.endsWith(".json")) return parseJsonResults(contents);
  throw new Error(`Unsupported test result extension: ${path}`);
}
