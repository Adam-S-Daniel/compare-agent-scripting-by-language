// Parsers for JUnit XML and JSON test result formats.
//
// We deliberately use a small handwritten regex-based JUnit reader instead of
// pulling in an XML dependency. JUnit XML is shallow (testsuite/testcase/
// failure/skipped) so a 50-line scanner is more honest than a full parser
// that reads more semantics into the document than we use.
//
// The JSON parser uses runtime checks at the boundary — once data is past
// `parseJsonResults` it conforms to `TestSuite[]`, so callers don't need
// to validate again.

import type { TestCase, TestStatus, TestSuite } from "./types.ts";

const ALLOWED_STATUSES: ReadonlySet<TestStatus> = new Set([
  "passed",
  "failed",
  "skipped",
]);

// Pull attributes out of the opening tag. Tolerates single or double quotes.
function readAttrs(openTag: string): Record<string, string> {
  const out: Record<string, string> = {};
  const re = /([\w:-]+)\s*=\s*("([^"]*)"|'([^']*)')/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(openTag)) !== null) {
    out[m[1]] = m[3] ?? m[4] ?? "";
  }
  return out;
}

function decodeXmlEntities(s: string): string {
  return s
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, "&");
}

interface RawTag {
  name: string;
  attrs: Record<string, string>;
  body: string; // inner text between open and close tags (empty for self-closed)
}

// Find every occurrence of a tag at any depth and return its open-tag attrs
// plus inner text. Handles `<x ... />` (self-closed) and `<x ...>...</x>`.
function findTags(xml: string, tagName: string): RawTag[] {
  // Match the open tag. Note: we use `[^>]*` (greedy) and then check the
  // last char of the captured attribute string to decide self-closed.
  // A lazy quantifier can absorb the trailing `/` and silently drop it.
  const open = new RegExp(`<${tagName}\\b([^>]*)>`, "g");
  const out: RawTag[] = [];
  let m: RegExpExecArray | null;
  while ((m = open.exec(xml)) !== null) {
    let attrSrc = m[1];
    const selfClosed = attrSrc.endsWith("/");
    if (selfClosed) attrSrc = attrSrc.slice(0, -1);
    const attrs = readAttrs(attrSrc);
    let body = "";
    if (!selfClosed) {
      // Locate the matching closing tag, accounting for possible nesting of
      // the same tag name. JUnit doesn't nest testcases inside testcases,
      // but we still walk depth so we don't over-eat on a re-used name.
      const closeRe = new RegExp(`<(/)?${tagName}\\b([^>]*)>`, "g");
      closeRe.lastIndex = open.lastIndex;
      let depth = 1;
      let bodyEnd = -1;
      let cm: RegExpExecArray | null;
      while ((cm = closeRe.exec(xml)) !== null) {
        const isClose = cm[1] === "/";
        const isSelf = cm[2].endsWith("/");
        if (isClose) {
          depth--;
          if (depth === 0) {
            bodyEnd = cm.index;
            open.lastIndex = closeRe.lastIndex;
            break;
          }
        } else if (!isSelf) {
          depth++;
        }
      }
      if (bodyEnd === -1) {
        throw new Error(`unclosed <${tagName}> tag`);
      }
      const bodyStart = m.index + m[0].length;
      body = xml.slice(bodyStart, bodyEnd);
    }
    out.push({ name: tagName, attrs, body });
  }
  return out;
}

function classifyCase(body: string, attrs: Record<string, string>): {
  status: TestStatus;
  failureMessage?: string;
} {
  // <skipped/> wins regardless of order — a skipped test never ran.
  if (/<skipped\b/.test(body)) return { status: "skipped" };

  const failureMatch =
    body.match(/<failure\b([^>]*?)(?:\/>|>([\s\S]*?)<\/failure>)/) ??
    body.match(/<error\b([^>]*?)(?:\/>|>([\s\S]*?)<\/error>)/);
  if (failureMatch) {
    const failAttrs = readAttrs(failureMatch[1]);
    const inner = decodeXmlEntities((failureMatch[2] ?? "").trim());
    const message = failAttrs.message ?? "";
    const combined = [message, inner].filter(Boolean).join(": ");
    return {
      status: "failed",
      failureMessage: combined || "(no failure message)",
    };
  }
  // status="failed" attribute is rare but valid.
  if (attrs.status === "failed" || attrs.status === "error") {
    return { status: "failed", failureMessage: "(no failure message)" };
  }
  return { status: "passed" };
}

export function parseJUnitXml(xml: string, source: string): TestSuite[] {
  // Cheap sanity check: a JUnit document must contain at least one
  // <testsuite> tag. Anything else is malformed input.
  if (!/<testsuite\b/.test(xml)) {
    throw new Error(`failed to parse JUnit XML in ${source}: no <testsuite> element`);
  }
  try {
    const suites = findTags(xml, "testsuite");
    return suites.map((s) => {
      const cases = findTags(s.body, "testcase").map<TestCase>((tc) => {
        const { status, failureMessage } = classifyCase(tc.body, tc.attrs);
        const duration = Number(tc.attrs.time ?? "0") || 0;
        return {
          name: tc.attrs.name ?? "(unnamed)",
          classname: tc.attrs.classname,
          status,
          duration,
          ...(failureMessage !== undefined ? { failureMessage } : {}),
        };
      });
      return { name: s.attrs.name ?? "(unnamed)", source, cases };
    });
  } catch (err) {
    throw new Error(
      `failed to parse JUnit XML in ${source}: ${(err as Error).message}`,
    );
  }
}

interface JsonTest {
  name: string;
  classname?: string;
  status: string;
  duration?: number;
  message?: string;
}

interface JsonSuite {
  suite: string;
  tests: JsonTest[];
}

function isObject(x: unknown): x is Record<string, unknown> {
  return typeof x === "object" && x !== null && !Array.isArray(x);
}

function coerceSuite(raw: unknown, source: string): TestSuite {
  if (!isObject(raw)) {
    throw new Error("expected a suite object");
  }
  const suiteName = typeof raw.suite === "string" ? raw.suite : "(unnamed)";
  if (!Array.isArray(raw.tests)) {
    throw new Error(`suite "${suiteName}" missing tests[] array`);
  }
  const cases = raw.tests.map<TestCase>((t, i) => {
    if (!isObject(t)) throw new Error(`test #${i} is not an object`);
    const status = String(t.status);
    if (!ALLOWED_STATUSES.has(status as TestStatus)) {
      throw new Error(
        `test "${t.name}" has unknown status "${status}" (expected passed|failed|skipped)`,
      );
    }
    const tc: TestCase = {
      name: typeof t.name === "string" ? t.name : `(test #${i})`,
      classname: typeof t.classname === "string" ? t.classname : undefined,
      status: status as TestStatus,
      duration: typeof t.duration === "number" ? t.duration : 0,
    };
    if (status === "failed" && typeof t.message === "string") {
      tc.failureMessage = t.message;
    }
    return tc;
  });
  return { name: suiteName, source, cases };
}

export function parseJsonResults(raw: string, source: string): TestSuite[] {
  let data: unknown;
  try {
    data = JSON.parse(raw);
  } catch (err) {
    throw new Error(
      `failed to parse JSON in ${source}: ${(err as Error).message}`,
    );
  }
  try {
    const suites = Array.isArray(data) ? data : [data];
    return suites.map((s) => coerceSuite(s, source));
  } catch (err) {
    throw new Error(
      `invalid JSON test results in ${source}: ${(err as Error).message}`,
    );
  }
}
