// Test suite for the test results aggregator using Bun's built-in test runner.
// TDD approach: tests are written first, then implementation follows.
import { describe, it, expect } from "bun:test";
import {
  parseJUnitXml,
  parseJsonResults,
  aggregateResults,
  identifyFlakyTests,
  generateMarkdownSummary,
} from "./aggregator";
import type {
  TestRunResult,
  AggregatedResult,
  TestCase,
} from "./aggregator";

// ── Fixture strings ───────────────────────────────────────────────────────────

const JUNIT_XML_BASIC = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="matrix-linux" time="2.5" tests="4" failures="1" errors="0" skipped="1">
  <testsuite name="Auth Tests" tests="4" failures="1" errors="0" skipped="1" time="2.5">
    <testcase name="login succeeds" classname="auth.login" time="0.5"/>
    <testcase name="login fails with bad creds" classname="auth.login" time="0.3">
      <failure message="Expected 401, got 200">Assertion error at line 42</failure>
    </testcase>
    <testcase name="logout" classname="auth.logout" time="0.2">
      <skipped/>
    </testcase>
    <testcase name="token refresh" classname="auth.token" time="1.5"/>
  </testsuite>
</testsuites>`;

const JUNIT_XML_PASSING = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="matrix-windows" time="1.8" tests="2" failures="0" errors="0" skipped="0">
  <testsuite name="Auth Tests" tests="2" failures="0" errors="0" skipped="0" time="1.8">
    <testcase name="login succeeds" classname="auth.login" time="0.9"/>
    <testcase name="login fails with bad creds" classname="auth.login" time="0.9"/>
  </testsuite>
</testsuites>`;

const JSON_RESULTS_BASIC = JSON.stringify({
  name: "Unit Tests",
  duration: 3.2,
  suites: [
    {
      name: "API Tests",
      tests: [
        { name: "GET /users returns list", status: "passed", duration: 0.4 },
        { name: "POST /users creates user", status: "failed", duration: 0.6, error: "Expected 201, got 500" },
        { name: "DELETE /users/:id", status: "skipped", duration: 0 },
      ],
    },
  ],
});

// ── parseJUnitXml ─────────────────────────────────────────────────────────────

describe("parseJUnitXml", () => {
  it("parses a valid JUnit XML string and returns a TestRunResult", () => {
    const result = parseJUnitXml(JUNIT_XML_BASIC, "linux.xml");
    expect(result.source).toBe("linux.xml");
    expect(result.suites).toHaveLength(1);
    expect(result.suites[0].name).toBe("Auth Tests");
    expect(result.suites[0].testCases).toHaveLength(4);
  });

  it("correctly classifies passed/failed/skipped test cases", () => {
    const result = parseJUnitXml(JUNIT_XML_BASIC, "linux.xml");
    const cases = result.suites[0].testCases;
    const statuses = cases.map((c) => c.status);
    expect(statuses).toEqual(["passed", "failed", "skipped", "passed"]);
  });

  it("captures failure message for failed tests", () => {
    const result = parseJUnitXml(JUNIT_XML_BASIC, "linux.xml");
    const failed = result.suites[0].testCases.find((c) => c.status === "failed");
    expect(failed?.error).toContain("Expected 401");
  });

  it("parses duration from testcase time attribute", () => {
    const result = parseJUnitXml(JUNIT_XML_BASIC, "linux.xml");
    expect(result.suites[0].testCases[0].duration).toBeCloseTo(0.5);
  });

  it("throws a meaningful error on invalid XML", () => {
    expect(() => parseJUnitXml("not xml at all", "bad.xml")).toThrow();
  });
});

// ── parseJsonResults ──────────────────────────────────────────────────────────

describe("parseJsonResults", () => {
  it("parses a valid JSON string and returns a TestRunResult", () => {
    const result = parseJsonResults(JSON_RESULTS_BASIC, "unit.json");
    expect(result.source).toBe("unit.json");
    expect(result.suites).toHaveLength(1);
    expect(result.suites[0].name).toBe("API Tests");
    expect(result.suites[0].testCases).toHaveLength(3);
  });

  it("maps passed/failed/skipped statuses correctly", () => {
    const result = parseJsonResults(JSON_RESULTS_BASIC, "unit.json");
    const statuses = result.suites[0].testCases.map((c) => c.status);
    expect(statuses).toContain("passed");
    expect(statuses).toContain("failed");
    expect(statuses).toContain("skipped");
  });

  it("captures error message for failed tests", () => {
    const result = parseJsonResults(JSON_RESULTS_BASIC, "unit.json");
    const failed = result.suites[0].testCases.find((c) => c.status === "failed");
    expect(failed?.error).toContain("Expected 201");
  });

  it("throws a meaningful error on invalid JSON", () => {
    expect(() => parseJsonResults("{not json}", "bad.json")).toThrow();
  });
});

// ── aggregateResults ──────────────────────────────────────────────────────────

describe("aggregateResults", () => {
  it("counts totals across multiple runs", () => {
    const run1 = parseJUnitXml(JUNIT_XML_BASIC, "linux.xml");
    const run2 = parseJsonResults(JSON_RESULTS_BASIC, "unit.json");
    const agg = aggregateResults([run1, run2]);

    // linux.xml: 2 passed, 1 failed, 1 skipped
    // unit.json: 1 passed, 1 failed, 1 skipped
    expect(agg.totalPassed).toBe(3);
    expect(agg.totalFailed).toBe(2);
    expect(agg.totalSkipped).toBe(2);
  });

  it("sums duration across all runs", () => {
    const run1 = parseJUnitXml(JUNIT_XML_BASIC, "linux.xml");
    const agg = aggregateResults([run1]);
    // testcases: 0.5 + 0.3 + 0.2 + 1.5 = 2.5
    expect(agg.totalDuration).toBeCloseTo(2.5);
  });

  it("returns empty aggregation for zero runs", () => {
    const agg = aggregateResults([]);
    expect(agg.totalPassed).toBe(0);
    expect(agg.totalFailed).toBe(0);
    expect(agg.totalSkipped).toBe(0);
    expect(agg.totalDuration).toBe(0);
  });
});

// ── identifyFlakyTests ────────────────────────────────────────────────────────

describe("identifyFlakyTests", () => {
  it("identifies tests that pass in one run and fail in another", () => {
    const run1 = parseJUnitXml(JUNIT_XML_BASIC, "linux.xml");       // "login fails with bad creds" → failed
    const run2 = parseJUnitXml(JUNIT_XML_PASSING, "windows.xml");  // "login fails with bad creds" → passed
    const agg = aggregateResults([run1, run2]);
    const flaky = identifyFlakyTests(agg);
    const flakyNames = flaky.map((f) => f.name);
    expect(flakyNames).toContain("login fails with bad creds");
  });

  it("does not flag tests that consistently pass", () => {
    const run1 = parseJUnitXml(JUNIT_XML_BASIC, "linux.xml");
    const run2 = parseJUnitXml(JUNIT_XML_PASSING, "windows.xml");
    const agg = aggregateResults([run1, run2]);
    const flaky = identifyFlakyTests(agg);
    const flakyNames = flaky.map((f) => f.name);
    expect(flakyNames).not.toContain("login succeeds");
  });

  it("records which sources the flaky test appeared in", () => {
    const run1 = parseJUnitXml(JUNIT_XML_BASIC, "linux.xml");
    const run2 = parseJUnitXml(JUNIT_XML_PASSING, "windows.xml");
    const agg = aggregateResults([run1, run2]);
    const flaky = identifyFlakyTests(agg);
    const entry = flaky.find((f) => f.name === "login fails with bad creds");
    expect(entry?.sources).toContain("linux.xml");
    expect(entry?.sources).toContain("windows.xml");
  });

  it("returns empty array when no flaky tests exist", () => {
    const run1 = parseJUnitXml(JUNIT_XML_PASSING, "windows.xml");
    const agg = aggregateResults([run1]);
    const flaky = identifyFlakyTests(agg);
    expect(flaky).toHaveLength(0);
  });
});

// ── generateMarkdownSummary ───────────────────────────────────────────────────

describe("generateMarkdownSummary", () => {
  it("includes a heading and the totals", () => {
    const run1 = parseJUnitXml(JUNIT_XML_BASIC, "linux.xml");
    const agg = aggregateResults([run1]);
    const flaky = identifyFlakyTests(agg);
    const md = generateMarkdownSummary(agg, flaky);

    expect(md).toContain("# Test Results");
    expect(md).toContain("Passed");
    expect(md).toContain("Failed");
    expect(md).toContain("Skipped");
  });

  it("lists flaky tests when present", () => {
    const run1 = parseJUnitXml(JUNIT_XML_BASIC, "linux.xml");
    const run2 = parseJUnitXml(JUNIT_XML_PASSING, "windows.xml");
    const agg = aggregateResults([run1, run2]);
    const flaky = identifyFlakyTests(agg);
    const md = generateMarkdownSummary(agg, flaky);

    expect(md).toContain("Flaky");
    expect(md).toContain("login fails with bad creds");
  });

  it("shows 'No flaky tests' when none detected", () => {
    const run1 = parseJUnitXml(JUNIT_XML_PASSING, "windows.xml");
    const agg = aggregateResults([run1]);
    const flaky = identifyFlakyTests(agg);
    const md = generateMarkdownSummary(agg, flaky);
    expect(md).toContain("No flaky tests");
  });

  it("includes per-run source names", () => {
    const run1 = parseJUnitXml(JUNIT_XML_BASIC, "linux.xml");
    const agg = aggregateResults([run1]);
    const flaky = identifyFlakyTests(agg);
    const md = generateMarkdownSummary(agg, flaky);
    expect(md).toContain("linux.xml");
  });
});
