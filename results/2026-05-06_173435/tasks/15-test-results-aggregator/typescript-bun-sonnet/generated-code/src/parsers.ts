// Parsers for JUnit XML and JSON test result formats
// XML parsing uses a lightweight built-in approach to avoid external dependencies

import type { ParsedRun, TestCase, TestSuite, TestStatus } from "./types";

// --- Simple JUnit XML parser (no external dependencies) ---

interface XmlElement {
  tag: string;
  attrs: Record<string, string>;
  children: XmlElement[];
  text: string;
}

function parseXml(xml: string): XmlElement {
  // Strip XML declaration and comments
  const clean = xml
    .replace(/<\?xml[^>]*\?>/g, "")
    .replace(/<!--[\s\S]*?-->/g, "")
    .trim();

  let pos = 0;

  function parseElement(): XmlElement {
    skipWhitespace();
    if (pos >= clean.length || clean[pos] !== "<") {
      throw new Error(`Expected '<' at position ${pos}`);
    }
    pos++; // consume '<'
    const tag = readName();
    const attrs = readAttrs();

    skipWhitespace();
    if (pos >= clean.length) throw new Error("Unexpected end of XML");

    // Self-closing tag
    if (clean[pos] === "/") {
      if (clean[pos + 1] !== ">") throw new Error(`Expected '>' at ${pos}`);
      pos += 2;
      return { tag, attrs, children: [], text: "" };
    }

    if (clean[pos] !== ">") throw new Error(`Expected '>' at ${pos}`);
    pos++; // consume '>'

    const children: XmlElement[] = [];
    let text = "";

    while (pos < clean.length) {
      skipWhitespace();
      if (pos >= clean.length) break;
      if (clean[pos] === "<") {
        if (clean[pos + 1] === "/") {
          // Closing tag
          pos += 2;
          const closingTag = readName();
          if (closingTag !== tag) {
            throw new Error(`Mismatched tags: </${closingTag}> closes <${tag}>`);
          }
          skipWhitespace();
          if (clean[pos] !== ">") throw new Error(`Expected '>' after </${closingTag}>`);
          pos++;
          break;
        } else {
          children.push(parseElement());
        }
      } else {
        // Text content
        const start = pos;
        while (pos < clean.length && clean[pos] !== "<") pos++;
        text += clean.slice(start, pos).trim();
      }
    }

    return { tag, attrs, children, text };
  }

  function readName(): string {
    let name = "";
    while (pos < clean.length && /[\w:.-]/.test(clean[pos])) {
      name += clean[pos++];
    }
    if (!name) throw new Error(`Expected element name at position ${pos}`);
    return name;
  }

  function readAttrs(): Record<string, string> {
    const attrs: Record<string, string> = {};
    while (pos < clean.length && clean[pos] !== ">" && clean[pos] !== "/") {
      skipWhitespace();
      if (clean[pos] === ">" || clean[pos] === "/") break;
      const name = readName();
      if (!name) break;
      skipWhitespace();
      if (clean[pos] !== "=") {
        attrs[name] = "";
        continue;
      }
      pos++; // consume '='
      skipWhitespace();
      const quote = clean[pos];
      if (quote !== '"' && quote !== "'") throw new Error(`Expected quote at ${pos}`);
      pos++;
      let val = "";
      while (pos < clean.length && clean[pos] !== quote) val += clean[pos++];
      pos++; // consume closing quote
      attrs[name] = decodeXmlEntities(val);
    }
    return attrs;
  }

  function skipWhitespace(): void {
    while (pos < clean.length && /\s/.test(clean[pos])) pos++;
  }

  return parseElement();
}

function decodeXmlEntities(s: string): string {
  return s
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'");
}

export function parseJUnitXml(xmlContent: string, runId: string): ParsedRun {
  let root: XmlElement;
  try {
    root = parseXml(xmlContent.trim());
  } catch (err) {
    throw new Error(`Failed to parse JUnit XML for run "${runId}": ${String(err)}`);
  }

  // Support both <testsuites> root and a bare <testsuite> as root
  const suiteElements: XmlElement[] =
    root.tag === "testsuites"
      ? root.children.filter((c) => c.tag === "testsuite")
      : [root];

  const suites: TestSuite[] = suiteElements.map((suiteEl) => {
    const suiteName = suiteEl.attrs.name ?? "unknown";
    const testCaseEls = suiteEl.children.filter((c) => c.tag === "testcase");

    const tests: TestCase[] = testCaseEls.map((tcEl) => {
      const name = tcEl.attrs.name ?? "unknown";
      const classname = tcEl.attrs.classname;
      const duration = parseFloat(tcEl.attrs.time ?? "0") || 0;

      const failureEl = tcEl.children.find((c) => c.tag === "failure");
      const errorEl = tcEl.children.find((c) => c.tag === "error");
      const skippedEl = tcEl.children.find((c) => c.tag === "skipped");

      let status: TestStatus = "passed";
      let failureMessage: string | undefined;

      if (failureEl) {
        status = "failed";
        failureMessage = failureEl.attrs.message;
      } else if (errorEl) {
        status = "error";
        failureMessage = errorEl.attrs.message;
      } else if (skippedEl) {
        status = "skipped";
      }

      return { name, classname, duration, status, failureMessage };
    });

    return { name: suiteName, runId, tests };
  });

  return { runId, suites };
}

// --- JSON Parser ---

interface JsonTestCase {
  name: string;
  status: string;
  duration: number;
  classname?: string;
  failureMessage?: string;
}

interface JsonTestSuite {
  name: string;
  tests: JsonTestCase[];
}

interface JsonResultFile {
  runId?: string;
  testSuites?: JsonTestSuite[];
}

export function parseJsonResults(jsonContent: string, runId: string): ParsedRun {
  let data: JsonResultFile;

  try {
    data = JSON.parse(jsonContent) as JsonResultFile;
  } catch (err) {
    throw new Error(`Failed to parse JSON results for run "${runId}": ${String(err)}`);
  }

  if (!data.testSuites) {
    throw new Error(
      `Invalid JSON result file for run "${runId}": missing "testSuites" array`
    );
  }

  const effectiveRunId = data.runId ?? runId;

  const suites: TestSuite[] = data.testSuites.map((suiteData) => {
    const tests: TestCase[] = suiteData.tests.map((tc) => {
      const status = normalizeStatus(tc.status);
      return {
        name: tc.name,
        classname: tc.classname,
        duration: tc.duration ?? 0,
        status,
        failureMessage: tc.failureMessage,
      };
    });
    return { name: suiteData.name, runId: effectiveRunId, tests };
  });

  return { runId: effectiveRunId, suites };
}

function normalizeStatus(s: string): TestStatus {
  switch (s.toLowerCase()) {
    case "passed":
    case "pass":
      return "passed";
    case "failed":
    case "fail":
      return "failed";
    case "skipped":
    case "skip":
      return "skipped";
    case "error":
      return "error";
    default:
      return "passed";
  }
}
