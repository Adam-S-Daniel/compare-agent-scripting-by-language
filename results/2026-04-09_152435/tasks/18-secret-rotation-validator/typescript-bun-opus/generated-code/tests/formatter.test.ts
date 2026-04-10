// TDD: Tests for output formatters.
// Written BEFORE the implementation — these should fail until formatter.ts exists.

import { describe, expect, test } from "bun:test";
import { formatAsJson, formatAsMarkdown } from "../src/formatter";
import type { RotationReport } from "../src/types";

const SAMPLE_REPORT: RotationReport = {
  generatedAt: "2026-04-10T00:00:00.000Z",
  warningWindowDays: 14,
  secrets: [
    {
      name: "DB_PASSWORD",
      urgency: "expired",
      daysSinceRotation: 99,
      daysUntilExpiry: -9,
      rotationPolicyDays: 90,
      requiredBy: ["api-server", "worker"],
      lastRotated: "2026-01-01",
    },
    {
      name: "API_KEY",
      urgency: "warning",
      daysSinceRotation: 85,
      daysUntilExpiry: 5,
      rotationPolicyDays: 90,
      requiredBy: ["frontend"],
      lastRotated: "2026-01-15",
    },
    {
      name: "JWT_SECRET",
      urgency: "ok",
      daysSinceRotation: 21,
      daysUntilExpiry: 69,
      rotationPolicyDays: 90,
      requiredBy: ["auth-service"],
      lastRotated: "2026-03-20",
    },
  ],
  summary: { total: 3, expired: 1, warning: 1, ok: 1 },
};

describe("formatAsJson", () => {
  test("returns valid JSON matching the report structure", () => {
    const output = formatAsJson(SAMPLE_REPORT);
    const parsed = JSON.parse(output);
    expect(parsed.summary.total).toBe(3);
    expect(parsed.summary.expired).toBe(1);
    expect(parsed.summary.warning).toBe(1);
    expect(parsed.summary.ok).toBe(1);
    expect(parsed.secrets).toHaveLength(3);
    expect(parsed.secrets[0].name).toBe("DB_PASSWORD");
  });
});

describe("formatAsMarkdown", () => {
  test("contains the markdown table header", () => {
    const output = formatAsMarkdown(SAMPLE_REPORT);
    expect(output).toContain("| Name | Urgency | Days Since Rotation | Days Until Expiry | Policy (days) | Required By |");
  });

  test("contains all secret names in the table", () => {
    const output = formatAsMarkdown(SAMPLE_REPORT);
    expect(output).toContain("DB_PASSWORD");
    expect(output).toContain("API_KEY");
    expect(output).toContain("JWT_SECRET");
  });

  test("contains summary section with correct counts", () => {
    const output = formatAsMarkdown(SAMPLE_REPORT);
    expect(output).toContain("Total: 3");
    expect(output).toContain("Expired: 1");
    expect(output).toContain("Warning: 1");
    expect(output).toContain("OK: 1");
  });

  test("handles empty report", () => {
    const emptyReport: RotationReport = {
      generatedAt: "2026-04-10T00:00:00.000Z",
      warningWindowDays: 7,
      secrets: [],
      summary: { total: 0, expired: 0, warning: 0, ok: 0 },
    };
    const output = formatAsMarkdown(emptyReport);
    expect(output).toContain("Total: 0");
    // Table header should still appear
    expect(output).toContain("| Name |");
  });
});
