// Red-green TDD: compliance report generator.
// Given a list of ComplianceEntry values, build a report with
// summary counts and render it in two formats:
//   - JSON: machine-readable for the CI step to parse assertions
//   - text: one line per dependency + a summary footer

import { describe, test, expect } from "bun:test";
import { buildReport, renderText, renderJson } from "../src/reporter.ts";
import type { ComplianceEntry } from "../src/types.ts";

const entries: ComplianceEntry[] = [
  { name: "lodash", version: "4.17.21", license: "MIT", status: "approved" },
  { name: "bad-lib", version: "1.0.0", license: "GPL-3.0", status: "denied" },
  { name: "mystery", version: "0.1.0", license: null, status: "unknown" },
  { name: "chalk", version: "5.3.0", license: "MIT", status: "approved" },
];

describe("buildReport", () => {
  test("produces correct summary counts", () => {
    const report = buildReport(entries);
    expect(report.summary).toEqual({
      approved: 2,
      denied: 1,
      unknown: 1,
      total: 4,
    });
  });

  test("preserves the given entries verbatim in order", () => {
    const report = buildReport(entries);
    expect(report.entries).toEqual(entries);
  });

  test("handles an empty input", () => {
    const report = buildReport([]);
    expect(report.summary).toEqual({ approved: 0, denied: 0, unknown: 0, total: 0 });
    expect(report.entries).toEqual([]);
  });
});

describe("renderText", () => {
  test("writes one line per entry plus a summary footer", () => {
    const text = renderText(buildReport(entries));
    expect(text).toContain("lodash@4.17.21 MIT approved");
    expect(text).toContain("bad-lib@1.0.0 GPL-3.0 denied");
    expect(text).toContain("mystery@0.1.0 UNKNOWN unknown");
    expect(text).toContain("Total: 4 | Approved: 2 | Denied: 1 | Unknown: 1");
  });
});

describe("renderJson", () => {
  test("round-trips through JSON.parse preserving structure", () => {
    const report = buildReport(entries);
    const parsed = JSON.parse(renderJson(report));
    expect(parsed).toEqual(report);
  });
});
