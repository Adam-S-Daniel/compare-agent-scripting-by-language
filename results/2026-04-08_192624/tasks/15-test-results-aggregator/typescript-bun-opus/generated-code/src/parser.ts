// Parser module: reads JUnit XML and JSON test result files into a common format

import { readFileSync } from "fs";
import type { TestResult, TestStatus, JsonTestFile } from "./types";

/**
 * Parse a JUnit XML file into TestResult array.
 * Handles the standard JUnit XML schema with testsuites/testsuite/testcase elements.
 */
export function parseJUnitXml(filePath: string): TestResult[] {
  const content = readFileSync(filePath, "utf-8");
  return parseJUnitXmlString(content);
}

/** Parse JUnit XML from a string (for testability without file I/O) */
export function parseJUnitXmlString(xml: string): TestResult[] {
  const results: TestResult[] = [];

  // Extract each testsuite block
  const suiteRegex = /<testsuite\s+([^>]*)>([\s\S]*?)<\/testsuite>/g;
  let suiteMatch: RegExpExecArray | null;

  while ((suiteMatch = suiteRegex.exec(xml)) !== null) {
    const suiteAttrs = suiteMatch[1];
    const suiteBody = suiteMatch[2];
    const suiteName = extractAttr(suiteAttrs, "name") || "unknown";

    // Extract each testcase
    const caseRegex = /<testcase\s+([^>]*?)(?:\/>|>([\s\S]*?)<\/testcase>)/g;
    let caseMatch: RegExpExecArray | null;

    while ((caseMatch = caseRegex.exec(suiteBody)) !== null) {
      const caseAttrs = caseMatch[1];
      const caseBody = caseMatch[2] || "";
      const name = extractAttr(caseAttrs, "name") || "unknown";
      const duration = parseFloat(extractAttr(caseAttrs, "time") || "0");

      // Determine status from child elements
      let status: TestStatus = "passed";
      let message: string | undefined;

      if (/<failure[\s>]/i.test(caseBody)) {
        status = "failed";
        const msgMatch = caseBody.match(/<failure\s+message="([^"]*)"[^>]*>/);
        message = msgMatch ? msgMatch[1] : "Test failed";
      } else if (/<skipped[\s/>]/i.test(caseBody)) {
        status = "skipped";
      }

      results.push({ name, suite: suiteName, status, duration, message });
    }
  }

  if (results.length === 0) {
    throw new Error(`No test cases found in JUnit XML`);
  }

  return results;
}

/**
 * Parse a JSON test result file into TestResult array.
 * Expects the JsonTestFile format with testSuites[].tests[].
 */
export function parseJsonResults(filePath: string): TestResult[] {
  const content = readFileSync(filePath, "utf-8");
  return parseJsonResultsString(content);
}

/** Parse JSON results from a string */
export function parseJsonResultsString(json: string): TestResult[] {
  let data: JsonTestFile;
  try {
    data = JSON.parse(json) as JsonTestFile;
  } catch (e) {
    throw new Error(`Invalid JSON test result file: ${(e as Error).message}`);
  }

  if (!data.testSuites || !Array.isArray(data.testSuites)) {
    throw new Error("JSON test file missing 'testSuites' array");
  }

  const results: TestResult[] = [];
  for (const suite of data.testSuites) {
    for (const test of suite.tests) {
      results.push({
        name: test.name,
        suite: suite.name,
        status: test.status,
        duration: test.duration,
        message: test.message,
      });
    }
  }
  return results;
}

/**
 * Auto-detect file format and parse accordingly.
 * Supports .xml (JUnit) and .json formats.
 */
export function parseFile(filePath: string): TestResult[] {
  if (filePath.endsWith(".xml")) {
    return parseJUnitXml(filePath);
  } else if (filePath.endsWith(".json")) {
    return parseJsonResults(filePath);
  } else {
    throw new Error(`Unsupported file format: ${filePath}. Expected .xml or .json`);
  }
}

/** Helper to extract an XML attribute value by name */
function extractAttr(attrs: string, name: string): string | null {
  const match = attrs.match(new RegExp(`${name}="([^"]*)"`));
  return match ? match[1] : null;
}
