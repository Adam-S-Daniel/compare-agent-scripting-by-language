// JUnit XML parser
// Parses JUnit XML format test results into our internal TestSuite format.
// Bun provides a built-in DOM parser via the global DOMParser.

import type { TestSuite, TestCase } from "../types";

/**
 * Parse JUnit XML content into an array of TestSuite objects.
 * @param xml - Raw XML string content
 * @param matrixKey - Optional label for which matrix job this came from
 */
export function parseJUnitXml(xml: string, matrixKey?: string): TestSuite[] {
  // Use Bun's built-in HTML parser (which handles XML)
  // We parse manually via string operations to avoid needing external XML libs
  const suites: TestSuite[] = [];

  // Validate that this looks like XML
  const trimmed = xml.trim();
  if (!trimmed.startsWith("<")) {
    throw new Error(`Invalid XML: content does not start with '<'. Got: ${trimmed.substring(0, 20)}`);
  }

  // Extract all <testsuite> elements (use lookahead to avoid matching <testsuites>)
  const testsuitePattern = /<testsuite(?=[^a-zA-Z])([^>]*?)>([\s\S]*?)<\/testsuite>/g;
  let suiteMatch: RegExpExecArray | null;

  while ((suiteMatch = testsuitePattern.exec(xml)) !== null) {
    const attrs = suiteMatch[1];
    const inner = suiteMatch[2];

    const suite: TestSuite = {
      name: extractAttr(attrs, "name") ?? "unknown",
      tests: parseInt(extractAttr(attrs, "tests") ?? "0", 10),
      failures: parseInt(extractAttr(attrs, "failures") ?? "0", 10),
      errors: parseInt(extractAttr(attrs, "errors") ?? "0", 10),
      skipped: parseInt(extractAttr(attrs, "skipped") ?? "0", 10),
      duration: parseFloat(extractAttr(attrs, "time") ?? "0"),
      testCases: [],
      matrixKey,
    };

    // Parse all <testcase> elements within this suite
    suite.testCases = parseTestCases(inner);

    suites.push(suite);
  }

  // If we found no suites at all, check if it's a malformed document
  if (suites.length === 0) {
    // Check if there's at least some XML structure; if not, it's invalid
    if (!/<[a-zA-Z]/.test(xml)) {
      throw new Error(`Invalid XML: no valid XML elements found`);
    }
    // Could be a valid XML with no testsuites — return empty array
  }

  return suites;
}

/** Parse all testcase elements from the inner content of a testsuite */
function parseTestCases(inner: string): TestCase[] {
  const cases: TestCase[] = [];
  const testcasePattern = /<testcase([^>]*?)(\/>|>([\s\S]*?)<\/testcase>)/g;
  let caseMatch: RegExpExecArray | null;

  while ((caseMatch = testcasePattern.exec(inner)) !== null) {
    const attrs = caseMatch[1];
    const selfClose = caseMatch[2] === "/>";
    const innerContent = selfClose ? "" : (caseMatch[3] ?? "");

    const tc: TestCase = {
      name: extractAttr(attrs, "name") ?? "unknown",
      className: extractAttr(attrs, "classname") ?? "unknown",
      duration: parseFloat(extractAttr(attrs, "time") ?? "0"),
      status: "passed",
    };

    // Check for failure element
    const failureMatch = /<failure([^>]*)>([\s\S]*?)<\/failure>/.exec(innerContent);
    if (failureMatch) {
      tc.status = "failed";
      tc.errorMessage = extractAttr(failureMatch[1], "message") ?? undefined;
      tc.errorType = extractAttr(failureMatch[1], "type") ?? undefined;
    }

    // Check for error element (treated same as failure)
    const errorMatch = /<error([^>]*)>([\s\S]*?)<\/error>/.exec(innerContent);
    if (errorMatch) {
      tc.status = "failed";
      tc.errorMessage = extractAttr(errorMatch[1], "message") ?? undefined;
      tc.errorType = extractAttr(errorMatch[1], "type") ?? undefined;
    }

    // Check for skipped element
    if (/<skipped\s*\/>|<skipped>/.test(innerContent)) {
      tc.status = "skipped";
    }

    cases.push(tc);
  }

  return cases;
}

/**
 * Extract an XML attribute value from an attributes string.
 * Handles both single and double quoted values.
 */
function extractAttr(attrs: string, name: string): string | null {
  // Match: name="value" or name='value'
  const pattern = new RegExp(`${name}=["']([^"']*)["']`);
  const match = pattern.exec(attrs);
  return match ? match[1] : null;
}
