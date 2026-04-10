// TDD: Tests for report formatting
// Red phase: tests written before implementation

import { describe, test, expect } from "bun:test";
import { formatReport } from "../src/report";
import type { ComplianceReport } from "../src/types";

describe("formatReport", () => {
  test("formats a report with mixed statuses", () => {
    const report: ComplianceReport = {
      entries: [
        { name: "express", version: "^4.18.0", license: "MIT", status: "approved" },
        { name: "gpl-lib", version: "^1.0.0", license: "GPL-3.0", status: "denied" },
        { name: "mystery", version: "^2.0.0", license: "WTFPL", status: "unknown" },
      ],
      summary: { total: 3, approved: 1, denied: 1, unknown: 1 },
    };

    const output = formatReport(report);

    // Should contain header
    expect(output).toContain("Dependency License Compliance Report");
    // Should contain each dependency line
    expect(output).toContain("express");
    expect(output).toContain("MIT");
    expect(output).toContain("APPROVED");
    expect(output).toContain("gpl-lib");
    expect(output).toContain("GPL-3.0");
    expect(output).toContain("DENIED");
    expect(output).toContain("mystery");
    expect(output).toContain("UNKNOWN");
    // Should contain summary
    expect(output).toContain("Total: 3");
    expect(output).toContain("Approved: 1");
    expect(output).toContain("Denied: 1");
    expect(output).toContain("Unknown: 1");
  });

  test("formats an empty report", () => {
    const report: ComplianceReport = {
      entries: [],
      summary: { total: 0, approved: 0, denied: 0, unknown: 0 },
    };
    const output = formatReport(report);
    expect(output).toContain("Total: 0");
  });
});
