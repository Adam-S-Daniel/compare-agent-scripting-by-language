// Tiny dependency-free JUnit XML parser.
// We intentionally avoid a full XML parser: JUnit reports use a very small
// subset of XML, and the scope here is test-result ingestion (not arbitrary XML).
// The parser walks a linear token stream of start/end/self-closing tags and
// captures the inner text between <failure>, <error>, etc. open/close tags.
import type { ParsedReport, TestCase, TestSuite, TestStatus } from "./types";

interface Tag {
  name: string;
  attrs: Record<string, string>;
  selfClosing: boolean;
  closing: boolean;
  raw: string;
  start: number;
  end: number;
}

function parseAttrs(raw: string): Record<string, string> {
  const attrs: Record<string, string> = {};
  // Match `key="value"` or `key='value'`.
  const re = /([A-Za-z_:][\w:.-]*)\s*=\s*"([^"]*)"|([A-Za-z_:][\w:.-]*)\s*=\s*'([^']*)'/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(raw)) !== null) {
    const key = m[1] ?? m[3];
    const val = m[2] ?? m[4] ?? "";
    attrs[key] = decodeXmlEntities(val);
  }
  return attrs;
}

function decodeXmlEntities(s: string): string {
  return s
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(parseInt(n, 10)))
    .replace(/&amp;/g, "&");
}

function tokenize(xml: string): Tag[] {
  const tags: Tag[] = [];
  // Strip XML prolog, comments, and CDATA simply.
  const cleaned = xml
    .replace(/<\?[\s\S]*?\?>/g, "")
    .replace(/<!--[\s\S]*?-->/g, "");
  const tagRe = /<\/?([A-Za-z_][\w-]*)\b([^>]*?)(\/)?>/g;
  let m: RegExpExecArray | null;
  while ((m = tagRe.exec(cleaned)) !== null) {
    const full = m[0];
    const name = m[1];
    const attrRaw = m[2] || "";
    const closing = full.startsWith("</");
    const selfClosing = Boolean(m[3]);
    tags.push({
      name,
      attrs: closing ? {} : parseAttrs(attrRaw),
      selfClosing,
      closing,
      raw: cleaned,
      start: m.index,
      end: tagRe.lastIndex,
    });
  }
  return tags;
}

function innerText(raw: string, openEnd: number, closeStart: number): string {
  const slice = raw.slice(openEnd, closeStart);
  return decodeXmlEntities(slice.trim());
}

export function parseJUnitXml(xml: string): ParsedReport {
  if (!xml || !xml.includes("<")) {
    throw new Error("JUnit parse error: input is not XML");
  }
  const tags = tokenize(xml);
  if (tags.length === 0) {
    throw new Error("JUnit parse error: no tags found");
  }
  const hasSuite = tags.some((t) => !t.closing && t.name === "testsuite");
  if (!hasSuite) {
    throw new Error("JUnit parse error: no <testsuite> element found");
  }

  const suites: TestSuite[] = [];

  // Walk tags; when we hit a <testsuite>, consume until its close tag,
  // collecting testcases and their child nested markers.
  for (let i = 0; i < tags.length; i++) {
    const t = tags[i];
    if (t.closing || t.name !== "testsuite") continue;
    const suiteName = t.attrs.name ?? "unknown";
    const tests: TestCase[] = [];

    // Find matching </testsuite>.
    let depth = t.selfClosing ? 0 : 1;
    let j = i + 1;
    for (; j < tags.length && depth > 0; j++) {
      const u = tags[j];
      if (u.name !== "testsuite") continue;
      if (u.closing) depth--;
      else if (!u.selfClosing) depth++;
    }
    const suiteEndIdx = j - 1;

    // Iterate testcases inside.
    for (let k = i + 1; k < suiteEndIdx; k++) {
      const c = tags[k];
      if (c.closing || c.name !== "testcase") continue;
      const tc: TestCase = {
        classname: c.attrs.classname ?? "",
        name: c.attrs.name ?? "",
        status: "passed",
        duration: parseFloat(c.attrs.time ?? "0") || 0,
      };

      if (!c.selfClosing) {
        // Find matching </testcase> and look at child tags for status markers.
        let d = 1;
        let m = k + 1;
        for (; m < suiteEndIdx && d > 0; m++) {
          const u = tags[m];
          if (u.name !== "testcase") {
            // Check status-affecting tags at top level of the testcase.
            if (!u.closing && (u.name === "failure" || u.name === "error" || u.name === "skipped")) {
              const status: TestStatus = u.name === "skipped" ? "skipped" : "failed";
              tc.status = status;
              if (u.attrs.message) tc.failureMessage = u.attrs.message;
              // If not self-closing, try to grab inner text as fallback message.
              if (!u.selfClosing && !tc.failureMessage) {
                // Find matching close of this tag (simple — same name, depth 1).
                let dd = 1;
                let n = m + 1;
                for (; n < suiteEndIdx && dd > 0; n++) {
                  const uu = tags[n];
                  if (uu.name !== u.name) continue;
                  if (uu.closing) dd--;
                  else if (!uu.selfClosing) dd++;
                }
                if (n <= suiteEndIdx) {
                  const closeTag = tags[n - 1];
                  tc.failureMessage = innerText(u.raw, u.end, closeTag.start) || undefined;
                }
              }
            }
            continue;
          }
          if (u.closing) d--;
          else if (!u.selfClosing) d++;
        }
        k = m - 1;
      }

      tests.push(tc);
    }

    suites.push({ name: suiteName, tests });
    i = suiteEndIdx;
  }

  return { suites };
}
