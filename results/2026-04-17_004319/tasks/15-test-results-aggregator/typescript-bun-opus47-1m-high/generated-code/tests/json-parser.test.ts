// TDD: tests for the JSON parser. The format we support is a pragmatic shape
// used by many test tools (jest-style / mocha-style): either a top-level object
// with a `testResults` array of suites, OR a top-level `suites` array, each
// containing a `tests` array with a `status` field.
import { describe, test, expect } from "bun:test";
import { parseJsonReport } from "../src/json-parser";

describe("parseJsonReport", () => {
  test("parses the canonical suites/tests shape", () => {
    const json = JSON.stringify({
      suites: [
        {
          name: "suite-a",
          tests: [
            { classname: "X", name: "ok", status: "passed", duration: 0.1 },
            {
              classname: "X",
              name: "bad",
              status: "failed",
              duration: 0.2,
              failureMessage: "oops",
            },
            { classname: "X", name: "later", status: "skipped", duration: 0 },
          ],
        },
      ],
    });
    const res = parseJsonReport(json);
    expect(res.suites).toHaveLength(1);
    expect(res.suites[0].tests.map((t) => t.status)).toEqual([
      "passed",
      "failed",
      "skipped",
    ]);
    expect(res.suites[0].tests[1].failureMessage).toBe("oops");
  });

  test("parses a jest-like shape with testResults", () => {
    const json = JSON.stringify({
      testResults: [
        {
          name: "a.test.ts",
          assertionResults: [
            { fullName: "ok", status: "passed", duration: 100 },
            { fullName: "bad", status: "failed", duration: 50, failureMessages: ["bang"] },
          ],
        },
      ],
    });
    const res = parseJsonReport(json);
    expect(res.suites).toHaveLength(1);
    expect(res.suites[0].name).toBe("a.test.ts");
    expect(res.suites[0].tests[0].status).toBe("passed");
    // jest reports duration in ms; parser should convert to seconds.
    expect(res.suites[0].tests[0].duration).toBeCloseTo(0.1, 5);
    expect(res.suites[0].tests[1].failureMessage).toBe("bang");
  });

  test("throws on non-JSON input", () => {
    expect(() => parseJsonReport("not json")).toThrow(/JSON/);
  });

  test("throws on JSON that doesn't match either shape", () => {
    expect(() => parseJsonReport(JSON.stringify({ foo: 1 }))).toThrow(/shape/i);
  });
});
