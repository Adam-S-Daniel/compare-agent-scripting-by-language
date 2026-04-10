/**
 * Tests for the output formatters (Markdown table and JSON).
 * Written before the implementation (TDD RED phase).
 * Uses a pre-built mock report to test formatting independently of validator logic.
 */
import { describe, test, expect } from "bun:test";
import { formatMarkdown, formatJSON } from "../src/formatter";
import type { RotationReport } from "../src/types";

// Pre-built mock report matching the known test fixture output for 2026-04-10
const mockReport: RotationReport = {
  generatedAt: "2026-04-10",
  warningWindowDays: 14,
  summary: { expired: 1, warning: 1, ok: 1 },
  expired: [
    {
      name: "PROD_DB_PASSWORD",
      lastRotated: "2026-01-01",
      rotationPolicyDays: 30,
      requiredBy: ["auth-service", "api-gateway"],
      expiryDate: "2026-01-31",
      daysUntilExpiry: -69,
      urgency: "expired",
    },
  ],
  warning: [
    {
      name: "API_KEY",
      lastRotated: "2026-03-28",
      rotationPolicyDays: 14,
      requiredBy: ["payment-service"],
      expiryDate: "2026-04-11",
      daysUntilExpiry: 1,
      urgency: "warning",
    },
  ],
  ok: [
    {
      name: "JWT_SECRET",
      lastRotated: "2026-04-05",
      rotationPolicyDays: 90,
      requiredBy: ["auth-service"],
      expiryDate: "2026-07-04",
      daysUntilExpiry: 85,
      urgency: "ok",
    },
  ],
};

const emptyReport: RotationReport = {
  generatedAt: "2026-04-10",
  warningWindowDays: 14,
  summary: { expired: 0, warning: 0, ok: 0 },
  expired: [],
  warning: [],
  ok: [],
};

describe("formatMarkdown", () => {
  test("includes report title", () => {
    expect(formatMarkdown(mockReport)).toContain("# Secret Rotation Report");
  });

  test("includes generated date", () => {
    expect(formatMarkdown(mockReport)).toContain("2026-04-10");
  });

  test("includes warning window", () => {
    expect(formatMarkdown(mockReport)).toContain("14 days");
  });

  test("shows summary section with correct counts", () => {
    const output = formatMarkdown(mockReport);
    expect(output).toContain("Expired: 1");
    expect(output).toContain("Warning: 1");
    expect(output).toContain("OK: 1");
  });

  test("shows EXPIRED section with correct count", () => {
    const output = formatMarkdown(mockReport);
    expect(output).toContain("## EXPIRED (1)");
    expect(output).toContain("PROD_DB_PASSWORD");
    expect(output).toContain("69 overdue");
    expect(output).toContain("2026-01-31");
  });

  test("shows WARNING section with correct count", () => {
    const output = formatMarkdown(mockReport);
    expect(output).toContain("## WARNING (1)");
    expect(output).toContain("API_KEY");
    expect(output).toContain("1 remaining");
    expect(output).toContain("2026-04-11");
  });

  test("shows OK section with correct count", () => {
    const output = formatMarkdown(mockReport);
    expect(output).toContain("## OK (1)");
    expect(output).toContain("JWT_SECRET");
    expect(output).toContain("85 remaining");
    expect(output).toContain("2026-07-04");
  });

  test("includes required-by services in table", () => {
    const output = formatMarkdown(mockReport);
    expect(output).toContain("auth-service");
    expect(output).toContain("api-gateway");
    expect(output).toContain("payment-service");
  });

  test("handles empty report gracefully", () => {
    const output = formatMarkdown(emptyReport);
    expect(output).toContain("## EXPIRED (0)");
    expect(output).toContain("## WARNING (0)");
    expect(output).toContain("## OK (0)");
    expect(output).toContain("_None_");
  });

  test("includes table header row", () => {
    const output = formatMarkdown(mockReport);
    expect(output).toContain("| Secret |");
    expect(output).toContain("| Last Rotated |");
    expect(output).toContain("| Required By |");
  });
});

describe("formatJSON", () => {
  test("produces valid parseable JSON", () => {
    const output = formatJSON(mockReport);
    expect(() => JSON.parse(output)).not.toThrow();
  });

  test("includes all three urgency groups", () => {
    const parsed = JSON.parse(formatJSON(mockReport));
    expect(parsed.expired).toHaveLength(1);
    expect(parsed.warning).toHaveLength(1);
    expect(parsed.ok).toHaveLength(1);
  });

  test("places secrets in correct urgency groups", () => {
    const parsed = JSON.parse(formatJSON(mockReport));
    expect(parsed.expired[0].name).toBe("PROD_DB_PASSWORD");
    expect(parsed.warning[0].name).toBe("API_KEY");
    expect(parsed.ok[0].name).toBe("JWT_SECRET");
  });

  test("summary object has correct counts", () => {
    const parsed = JSON.parse(formatJSON(mockReport));
    expect(parsed.summary).toEqual({ expired: 1, warning: 1, ok: 1 });
  });

  test("each secret has urgency field", () => {
    const parsed = JSON.parse(formatJSON(mockReport));
    expect(parsed.expired[0].urgency).toBe("expired");
    expect(parsed.warning[0].urgency).toBe("warning");
    expect(parsed.ok[0].urgency).toBe("ok");
  });

  test("each secret includes daysUntilExpiry with exact values", () => {
    const parsed = JSON.parse(formatJSON(mockReport));
    expect(parsed.expired[0].daysUntilExpiry).toBe(-69);
    expect(parsed.warning[0].daysUntilExpiry).toBe(1);
    expect(parsed.ok[0].daysUntilExpiry).toBe(85);
  });

  test("each secret includes expiryDate", () => {
    const parsed = JSON.parse(formatJSON(mockReport));
    expect(parsed.expired[0].expiryDate).toBe("2026-01-31");
    expect(parsed.warning[0].expiryDate).toBe("2026-04-11");
    expect(parsed.ok[0].expiryDate).toBe("2026-07-04");
  });

  test("includes generatedAt and warningWindowDays", () => {
    const parsed = JSON.parse(formatJSON(mockReport));
    expect(parsed.generatedAt).toBe("2026-04-10");
    expect(parsed.warningWindowDays).toBe(14);
  });

  test("handles empty report", () => {
    const parsed = JSON.parse(formatJSON(emptyReport));
    expect(parsed.expired).toHaveLength(0);
    expect(parsed.warning).toHaveLength(0);
    expect(parsed.ok).toHaveLength(0);
  });
});
