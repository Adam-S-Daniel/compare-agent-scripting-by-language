// JUnit XML parser - handles both <testsuites> and <testsuite> root elements
import { XMLParser } from "fast-xml-parser";
import type { ParsedResult, TestSuite, TestCase } from "../types";

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "@_",
  // Always return arrays for these elements so we handle single-item suites
  isArray: (tagName: string) =>
    tagName === "testsuite" || tagName === "testcase",
});

export function parseJUnit(content: string, runId: string): ParsedResult {
  const raw = parser.parse(content);

  // Handle both <testsuites> wrapper and bare <testsuite> root
  let suitesData: unknown[] = [];
  if (raw.testsuites?.testsuite) {
    const ts = raw.testsuites.testsuite;
    suitesData = Array.isArray(ts) ? ts : [ts];
  } else if (raw.testsuite) {
    const ts = raw.testsuite;
    suitesData = Array.isArray(ts) ? ts : [ts];
  }

  const suites: TestSuite[] = suitesData.map((suite: unknown) => {
    const s = suite as Record<string, unknown>;
    const rawCases = (s["testcase"] as unknown[]) ?? [];
    const testcases: unknown[] = Array.isArray(rawCases) ? rawCases : [rawCases];

    const tests: TestCase[] = testcases.map((tc: unknown) => {
      const t = tc as Record<string, unknown>;
      let status: "passed" | "failed" | "skipped" = "passed";
      let error: string | undefined;

      if (t["failure"] !== undefined || t["error"] !== undefined) {
        status = "failed";
        const f = t["failure"] ?? t["error"];
        if (typeof f === "string") {
          error = f;
        } else if (f && typeof f === "object") {
          const fo = f as Record<string, unknown>;
          error = String(fo["@_message"] ?? fo["#text"] ?? "");
        }
      } else if (t["skipped"] !== undefined) {
        status = "skipped";
      }

      return {
        name: String(t["@_name"] ?? "Unknown"),
        suiteName: String(s["@_name"] ?? "Unknown"),
        status,
        duration: parseFloat(String(t["@_time"] ?? "0")),
        error,
      };
    });

    return {
      name: String(s["@_name"] ?? "Unknown"),
      tests,
      duration: parseFloat(String(s["@_time"] ?? "0")),
    };
  });

  return { runId, format: "junit", suites };
}
