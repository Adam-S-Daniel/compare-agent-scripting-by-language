// RED phase tests for the report formatter.
// The report needs to be human-readable AND machine-greppable so a CI step
// can fail the build on a single denied dependency.
import { describe, expect, test } from "bun:test";
import { formatReport, summarize, type ReportEntry } from "../src/report.ts";

const entries: ReportEntry[] = [
  { name: "left-pad", version: "1.3.0", license: "MIT", status: "approved" },
  { name: "evil-lib", version: "2.0.0", license: "GPL-3.0", status: "denied" },
  { name: "mystery-lib", version: "0.1.0", license: null, status: "unknown" },
];

describe("formatReport", () => {
  test("contains a header and one row per dependency with status tag", () => {
    const out = formatReport(entries);
    expect(out).toContain("Dependency License Compliance Report");
    expect(out).toContain("[APPROVED] left-pad@1.3.0 -> MIT");
    expect(out).toContain("[DENIED] evil-lib@2.0.0 -> GPL-3.0");
    expect(out).toContain("[UNKNOWN] mystery-lib@0.1.0 -> (no license info)");
  });

  test("ends with a totals line", () => {
    const out = formatReport(entries);
    expect(out).toMatch(/Totals: 3 deps, 1 approved, 1 denied, 1 unknown/);
  });
});

describe("summarize", () => {
  test("counts each status bucket", () => {
    expect(summarize(entries)).toEqual({
      total: 3,
      approved: 1,
      denied: 1,
      unknown: 1,
    });
  });

  test("returns zeros for an empty report", () => {
    expect(summarize([])).toEqual({ total: 0, approved: 0, denied: 0, unknown: 0 });
  });
});
