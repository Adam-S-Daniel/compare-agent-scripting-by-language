// Parsers for test result files.
//
// We deliberately avoid an XML-parser dependency so the script runs
// self-contained in CI. JUnit XML is a stable, well-known shape — a small
// regex-driven extractor is enough for typical reporter output (Vitest, Jest,
// Mocha-junit-reporter, pytest, etc.). For anything pathological we surface a
// clear error rather than silently truncating.
import type { TestCase, TestRun, TestStatus, TestSuite } from "./types.ts";

/** Decode the small set of XML entities we expect in attribute / text values. */
function decodeXmlEntities(value: string): string {
  return value
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, "&");
}

/** Pull a single attribute out of a JUnit element's opening tag. */
function getAttr(tagOpen: string, attr: string): string | undefined {
  const match = tagOpen.match(new RegExp(`\\b${attr}\\s*=\\s*"([^"]*)"`));
  return match ? decodeXmlEntities(match[1]!) : undefined;
}

/** Inspect the body of a <testcase>...</testcase> to determine its status. */
function classifyCase(
  body: string,
): { status: TestStatus; message?: string } {
  // <failure ... /> or <error ... /> — both count as a hard failure.
  const failureMatch = body.match(/<(failure|error)\b([^>]*?)(\/>|>([\s\S]*?)<\/\1>)/);
  if (failureMatch) {
    const attrs = failureMatch[2] ?? "";
    const message = getAttr(`<x ${attrs}>`, "message");
    return message ? { status: "failed", message } : { status: "failed" };
  }
  if (/<skipped\b[^>]*?(\/>|>[\s\S]*?<\/skipped>)/.test(body)) {
    return { status: "skipped" };
  }
  return { status: "passed" };
}

/** Parse a JUnit XML payload into a single TestRun. */
export function parseJUnitXml(xml: string, source: string): TestRun {
  if (typeof xml !== "string" || xml.trim() === "") {
    throw new Error(`parseJUnitXml: empty XML payload from ${source}`);
  }

  const suites: TestSuite[] = [];
  // Match <testsuite ...>...</testsuite>. JUnit allows a top-level <testsuites>
  // wrapper or a single <testsuite> root — this regex handles both.
  const suiteRe = /<testsuite\b([^>]*)>([\s\S]*?)<\/testsuite>/g;
  let suiteMatch: RegExpExecArray | null;
  while ((suiteMatch = suiteRe.exec(xml)) !== null) {
    const openAttrs = suiteMatch[1] ?? "";
    const suiteBody = suiteMatch[2] ?? "";
    const suiteName = getAttr(`<x ${openAttrs}>`, "name") ?? "default";

    const cases: TestCase[] = [];
    const caseRe =
      /<testcase\b([^>]*?)(\/>|>([\s\S]*?)<\/testcase>)/g;
    let caseMatch: RegExpExecArray | null;
    while ((caseMatch = caseRe.exec(suiteBody)) !== null) {
      const caseAttrs = caseMatch[1] ?? "";
      const isSelfClosing = caseMatch[2] === "/>";
      const caseBody = isSelfClosing ? "" : (caseMatch[3] ?? "");
      const synthetic = `<x ${caseAttrs}>`;
      const name = getAttr(synthetic, "name") ?? "<unnamed>";
      const classname = getAttr(synthetic, "classname") ?? suiteName;
      const time = parseFloat(getAttr(synthetic, "time") ?? "0");
      const { status, message } = classifyCase(caseBody);
      const tc: TestCase = {
        classname,
        name,
        status,
        duration: Number.isFinite(time) ? time : 0,
      };
      if (message !== undefined) tc.message = message;
      cases.push(tc);
    }
    suites.push({ name: suiteName, cases });
  }

  if (suites.length === 0) {
    throw new Error(
      `parseJUnitXml: no <testsuite> elements found in ${source}`,
    );
  }

  return { source, suites };
}

const VALID_STATUSES: ReadonlySet<TestStatus> = new Set([
  "passed",
  "failed",
  "skipped",
]);

interface RawJsonCase {
  classname?: string;
  name: string;
  status: string;
  duration?: number;
  time?: number;
  message?: string;
}

interface RawJsonSuite {
  name: string;
  tests: RawJsonCase[];
}

interface RawJsonRun {
  suites: RawJsonSuite[];
}

/**
 * Parse a JSON results payload. Accepts the simple {suites:[{tests:[...]}]}
 * shape we produce as a fixture; that is also a reasonable lowest-common-
 * denominator form that other reporters can map onto.
 */
export function parseJsonResults(text: string, source: string): TestRun {
  let raw: RawJsonRun;
  try {
    raw = JSON.parse(text) as RawJsonRun;
  } catch (err) {
    const detail = err instanceof Error ? err.message : String(err);
    throw new Error(`parseJsonResults: failed to parse JSON from ${source}: ${detail}`);
  }
  if (!raw || !Array.isArray(raw.suites)) {
    throw new Error(
      `parseJsonResults: expected an object with a "suites" array in ${source}`,
    );
  }
  const suites: TestSuite[] = raw.suites.map((rs) => {
    const cases: TestCase[] = (rs.tests ?? []).map((rc) => {
      if (!VALID_STATUSES.has(rc.status as TestStatus)) {
        throw new Error(
          `parseJsonResults: unknown status "${rc.status}" for ${rs.name}.${rc.name} in ${source}`,
        );
      }
      const tc: TestCase = {
        classname: rc.classname ?? rs.name,
        name: rc.name,
        status: rc.status as TestStatus,
        duration: typeof rc.duration === "number"
          ? rc.duration
          : typeof rc.time === "number"
          ? rc.time
          : 0,
      };
      if (rc.message) tc.message = rc.message;
      return tc;
    });
    return { name: rs.name, cases };
  });
  return { source, suites };
}
