// TDD red phase: tests for the report formatters.
// Run before formatter.ts exists to confirm failure first.

import { describe, it, expect } from "bun:test";
import { formatMarkdown, formatJSON } from "./formatter";
import { generateReport } from "./validator";
import type { SecretConfig } from "./types";

const REFERENCE_DATE = new Date("2026-05-07T00:00:00.000Z");

const EXPIRED_SECRET: SecretConfig = {
  name: "EXPIRED_SECRET",
  lastRotated: "2026-03-28",
  rotationPolicyDays: 30,
  requiredBy: ["api-server"],
};

const WARNING_SECRET: SecretConfig = {
  name: "WARNING_SECRET",
  lastRotated: "2026-04-12",
  rotationPolicyDays: 30,
  requiredBy: ["web-app"],
};

const OK_SECRET: SecretConfig = {
  name: "OK_SECRET",
  lastRotated: "2026-04-27",
  rotationPolicyDays: 30,
  requiredBy: ["worker"],
};

const MIXED_REPORT = generateReport(
  [EXPIRED_SECRET, WARNING_SECRET, OK_SECRET],
  REFERENCE_DATE,
  7
);

describe("formatMarkdown", () => {
  it("includes a top-level heading", () => {
    const md = formatMarkdown(MIXED_REPORT);
    expect(md).toContain("# Secret Rotation Report");
  });

  it("includes the reference date", () => {
    const md = formatMarkdown(MIXED_REPORT);
    expect(md).toContain("2026-05-07");
  });

  it("includes the warning window", () => {
    const md = formatMarkdown(MIXED_REPORT);
    expect(md).toContain("7");
  });

  it("has an Expired section with EXPIRED_SECRET", () => {
    const md = formatMarkdown(MIXED_REPORT);
    expect(md).toContain("## Expired");
    expect(md).toContain("EXPIRED_SECRET");
  });

  it("shows correct daysUntilExpiry (-10) for expired secret", () => {
    const md = formatMarkdown(MIXED_REPORT);
    expect(md).toContain("-10");
  });

  it("has a Warning section with WARNING_SECRET", () => {
    const md = formatMarkdown(MIXED_REPORT);
    expect(md).toContain("## Warning");
    expect(md).toContain("WARNING_SECRET");
  });

  it("shows correct daysUntilExpiry (5) for warning secret", () => {
    const md = formatMarkdown(MIXED_REPORT);
    expect(md).toContain("| 5 |");
  });

  it("has an OK section with OK_SECRET", () => {
    const md = formatMarkdown(MIXED_REPORT);
    expect(md).toContain("## OK");
    expect(md).toContain("OK_SECRET");
  });

  it("includes requiredBy services in the output", () => {
    const md = formatMarkdown(MIXED_REPORT);
    expect(md).toContain("api-server");
    expect(md).toContain("web-app");
    expect(md).toContain("worker");
  });

  it("includes a markdown table with pipe characters", () => {
    const md = formatMarkdown(MIXED_REPORT);
    // Table header row
    expect(md).toContain("| Secret |");
  });

  it("renders an empty section gracefully", () => {
    const allOkReport = generateReport([OK_SECRET], REFERENCE_DATE, 7);
    const md = formatMarkdown(allOkReport);
    // Expired section should still appear but show count 0
    expect(md).toContain("## Expired (0)");
    expect(md).toContain("## Warning (0)");
    expect(md).toContain("## OK (1)");
  });
});

describe("formatJSON", () => {
  it("produces valid JSON", () => {
    const json = formatJSON(MIXED_REPORT);
    expect(() => JSON.parse(json)).not.toThrow();
  });

  it("JSON contains expired secret name", () => {
    const json = formatJSON(MIXED_REPORT);
    const parsed = JSON.parse(json);
    expect(parsed.expired[0].secret.name).toBe("EXPIRED_SECRET");
  });

  it("JSON contains warning secret name", () => {
    const json = formatJSON(MIXED_REPORT);
    const parsed = JSON.parse(json);
    expect(parsed.warning[0].secret.name).toBe("WARNING_SECRET");
  });

  it("JSON contains ok secret name", () => {
    const json = formatJSON(MIXED_REPORT);
    const parsed = JSON.parse(json);
    expect(parsed.ok[0].secret.name).toBe("OK_SECRET");
  });

  it("JSON includes urgency field on each item", () => {
    const json = formatJSON(MIXED_REPORT);
    const parsed = JSON.parse(json);
    expect(parsed.expired[0].urgency).toBe("expired");
    expect(parsed.warning[0].urgency).toBe("warning");
    expect(parsed.ok[0].urgency).toBe("ok");
  });

  it("JSON includes daysUntilExpiry on each item", () => {
    const json = formatJSON(MIXED_REPORT);
    const parsed = JSON.parse(json);
    expect(parsed.expired[0].daysUntilExpiry).toBe(-10);
    expect(parsed.warning[0].daysUntilExpiry).toBe(5);
    expect(parsed.ok[0].daysUntilExpiry).toBe(20);
  });

  it("JSON includes summary counts", () => {
    const json = formatJSON(MIXED_REPORT);
    const parsed = JSON.parse(json);
    expect(parsed.summary).toBeDefined();
    expect(parsed.summary.expiredCount).toBe(1);
    expect(parsed.summary.warningCount).toBe(1);
    expect(parsed.summary.okCount).toBe(1);
  });

  it("JSON is pretty-printed with indentation", () => {
    const json = formatJSON(MIXED_REPORT);
    expect(json).toContain("\n");
    expect(json).toContain("  ");
  });
});
