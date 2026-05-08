// Tests the human-readable text report and the summary counts.
import { describe, expect, test } from "bun:test";
import { formatReport, summarize } from "../src/report.ts";
import type { ReportEntry } from "../src/checker.ts";

const entries: ReportEntry[] = [
  { name: "left", version: "1.0.0", license: "MIT", status: "approved" },
  { name: "evil", version: "2.0.0", license: "GPL-3.0", status: "denied" },
  { name: "mystery", version: "3.0.0", license: null, status: "unknown" },
];

describe("summarize", () => {
  test("counts statuses", () => {
    expect(summarize(entries)).toEqual({ approved: 1, denied: 1, unknown: 1, total: 3 });
  });
});

describe("formatReport", () => {
  test("includes a header line, one row per dep, and a summary", () => {
    const text = formatReport(entries);
    expect(text).toContain("Dependency License Compliance Report");
    expect(text).toContain("left@1.0.0");
    expect(text).toContain("MIT");
    expect(text).toContain("APPROVED");
    expect(text).toContain("evil@2.0.0");
    expect(text).toContain("DENIED");
    expect(text).toContain("mystery@3.0.0");
    expect(text).toContain("UNKNOWN");
    expect(text).toMatch(/Summary:.*approved=1.*denied=1.*unknown=1/s);
  });

  test("renders empty input safely", () => {
    expect(formatReport([])).toContain("approved=0");
  });
});
