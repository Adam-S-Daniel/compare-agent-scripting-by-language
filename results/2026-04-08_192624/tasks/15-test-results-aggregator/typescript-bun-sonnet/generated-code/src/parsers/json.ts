// JSON test result parser
// Parses our custom JSON format into internal TestSuite representation.

import type { TestSuite, TestCase, JsonTestResult } from "../types";

/**
 * Parse a JSON test result object into a TestSuite.
 * @param input - Parsed JSON object matching the JsonTestResult schema
 */
export function parseJsonResult(input: JsonTestResult): TestSuite {
  // Validate basic structure
  if (!input || typeof input !== "object") {
    throw new Error("Invalid JSON test result: expected an object");
  }
  if (!input.suiteName) {
    throw new Error("Invalid JSON test result: missing required field 'suiteName'");
  }
  if (!Array.isArray(input.results)) {
    throw new Error("Invalid JSON test result: missing required field 'results' (must be array)");
  }

  const testCases: TestCase[] = input.results.map((r) => {
    const tc: TestCase = {
      name: r.name,
      className: r.className,
      duration: r.duration,
      status: r.status,
    };

    // Map error info for failed tests
    if (r.status === "failed" && r.error) {
      tc.errorType = r.error.type;
      tc.errorMessage = r.error.message;
    }

    return tc;
  });

  // Compute totals by counting test statuses
  const failures = testCases.filter((t) => t.status === "failed").length;
  const skipped = testCases.filter((t) => t.status === "skipped").length;
  const totalDuration = testCases.reduce((sum, t) => sum + t.duration, 0);

  return {
    name: input.suiteName,
    tests: testCases.length,
    failures,
    errors: 0, // JSON format doesn't distinguish errors from failures
    skipped,
    duration: totalDuration,
    testCases,
    matrixKey: input.matrixKey,
  };
}
