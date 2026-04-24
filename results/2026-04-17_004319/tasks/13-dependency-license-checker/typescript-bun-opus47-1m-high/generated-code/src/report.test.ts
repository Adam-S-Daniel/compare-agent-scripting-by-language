import { describe, expect, test } from "bun:test";
import { generateReport, summarise, type ComplianceRecord } from "./report";

const records: ComplianceRecord[] = [
  { name: "lodash", version: "4.17.21", license: "MIT", status: "approved" },
  { name: "bad-pkg", version: "1.0.0", license: "GPL-3.0", status: "denied" },
  { name: "weird-pkg", version: "1.0.0", license: "WTFPL", status: "unknown" },
  { name: "mystery-pkg", version: "1.0.0", license: null, status: "unknown" },
];

describe("summarise", () => {
  test("counts records by status", () => {
    expect(summarise(records)).toEqual({
      approved: 1,
      denied: 1,
      unknown: 2,
      total: 4,
    });
  });

  test("returns zero counts for an empty list", () => {
    expect(summarise([])).toEqual({ approved: 0, denied: 0, unknown: 0, total: 0 });
  });
});

describe("generateReport", () => {
  test("produces a markdown report with a header, counts, and a row per dependency", () => {
    const text = generateReport(records);
    expect(text).toContain("# Dependency License Compliance Report");
    expect(text).toContain("Total dependencies: 4");
    expect(text).toContain("Approved: 1");
    expect(text).toContain("Denied: 1");
    expect(text).toContain("Unknown: 2");
    // One row per dependency, with name, version, licence, status.
    expect(text).toContain("| lodash | 4.17.21 | MIT | approved |");
    expect(text).toContain("| bad-pkg | 1.0.0 | GPL-3.0 | denied |");
    expect(text).toContain("| weird-pkg | 1.0.0 | WTFPL | unknown |");
    // Null licences render as the literal string "UNKNOWN".
    expect(text).toContain("| mystery-pkg | 1.0.0 | UNKNOWN | unknown |");
  });

  test("renders an empty report when no dependencies are given", () => {
    const text = generateReport([]);
    expect(text).toContain("Total dependencies: 0");
    expect(text).toContain("No dependencies found.");
  });
});
