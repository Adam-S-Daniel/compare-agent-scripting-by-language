// Parser module: converts JUnit XML and JSON test result files into TestSuite objects.
// Written to make the parser tests pass (TDD green phase).

import type { TestCase, TestSuite } from "./types";

/**
 * Parse JUnit XML content into TestSuite objects.
 * Handles both <testsuites> and bare <testsuite> root elements.
 */
export function parseJUnit(content: string, file: string = ""): TestSuite[] {
  const suites: TestSuite[] = [];

  // Match all <testsuite ...>...</testsuite> blocks
  const suiteRegex = /<testsuite\s([^>]*)>([\s\S]*?)<\/testsuite>/g;
  let suiteMatch: RegExpExecArray | null;

  while ((suiteMatch = suiteRegex.exec(content)) !== null) {
    const attrs = parseXmlAttributes(suiteMatch[1]);
    const suiteBody = suiteMatch[2];

    const testCases = parseTestCases(suiteBody);
    const passed = testCases.filter((tc) => tc.status === "passed").length;
    const failed = testCases.filter((tc) => tc.status === "failed").length;
    const skipped = testCases.filter((tc) => tc.status === "skipped").length;

    suites.push({
      name: attrs.name ?? "Unknown",
      file,
      tests: parseInt(attrs.tests ?? "0", 10),
      passed,
      failed,
      skipped,
      duration: parseFloat(attrs.time ?? "0"),
      testCases,
    });
  }

  return suites;
}

/**
 * Parse JSON content into TestSuite objects.
 * Accepts a single suite object or an array of suite objects.
 *
 * Expected schema:
 *   { name: string, duration: number, tests: Array<{ name, status, duration, errorMessage? }> }
 */
export function parseJSON(content: string, file: string = ""): TestSuite[] {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const data: any = JSON.parse(content);
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const rawSuites: any[] = Array.isArray(data) ? data : [data];

  return rawSuites.map((raw) => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const testCases: TestCase[] = (raw.tests ?? []).map((tc: any) => ({
      name: String(tc.name ?? "Unknown"),
      classname: String(tc.classname ?? raw.name ?? ""),
      status: tc.status as "passed" | "failed" | "skipped",
      duration: Number(tc.duration ?? 0),
      errorMessage: tc.errorMessage as string | undefined,
    }));

    const passed = testCases.filter((tc) => tc.status === "passed").length;
    const failed = testCases.filter((tc) => tc.status === "failed").length;
    const skipped = testCases.filter((tc) => tc.status === "skipped").length;

    return {
      name: String(raw.name ?? "Unknown"),
      file,
      tests: testCases.length,
      passed,
      failed,
      skipped,
      duration: Number(raw.duration ?? 0),
      testCases,
    };
  });
}

/**
 * Dispatch to the appropriate parser based on the file extension.
 * Throws a meaningful error for unsupported formats.
 */
export function parseFile(content: string, file: string): TestSuite[] {
  if (file.endsWith(".xml")) {
    return parseJUnit(content, file);
  }
  if (file.endsWith(".json")) {
    return parseJSON(content, file);
  }
  throw new Error(`Unsupported file format: ${file}. Expected .xml or .json`);
}

// --- Helpers ---

/** Extract key="value" pairs from an XML attribute string */
function parseXmlAttributes(attrStr: string): Record<string, string> {
  const attrs: Record<string, string> = {};
  const re = /(\w+)="([^"]*)"/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(attrStr)) !== null) {
    attrs[m[1]] = m[2];
  }
  return attrs;
}

/** Parse all <testcase> elements from a testsuite body */
function parseTestCases(body: string): TestCase[] {
  const testCases: TestCase[] = [];

  // Match self-closing <testcase .../> and element-form <testcase ...>...</testcase>
  const re = /<testcase\s([^>]*?)(?:\/>|>([\s\S]*?)<\/testcase>)/g;
  let m: RegExpExecArray | null;

  while ((m = re.exec(body)) !== null) {
    const attrs = parseXmlAttributes(m[1]);
    const inner = m[2] ?? "";

    let status: "passed" | "failed" | "skipped" = "passed";
    let errorMessage: string | undefined;

    if (/<failure[\s>]/.test(inner) || /<error[\s>]/.test(inner)) {
      status = "failed";
      // Extract message attribute from <failure message="..."> if present
      const msgMatch = inner.match(/<(?:failure|error)[^>]*\smessage="([^"]*)"/);
      errorMessage = msgMatch ? msgMatch[1] : "Test failed";
    } else if (/<skipped/.test(inner)) {
      status = "skipped";
    }

    testCases.push({
      name: attrs.name ?? "Unknown",
      classname: attrs.classname ?? "",
      status,
      duration: parseFloat(attrs.time ?? "0"),
      errorMessage,
    });
  }

  return testCases;
}
