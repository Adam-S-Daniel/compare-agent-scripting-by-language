/**
 * Secret Rotation Validator Tests
 *
 * TDD approach: tests are written FIRST, then the implementation makes them pass.
 * Each test group covers a specific piece of functionality.
 */

import { describe, it, expect, beforeEach } from "bun:test";
import {
  classifySecret,
  analyzeSecrets,
  generateReport,
  formatAsMarkdown,
  formatAsJson,
} from "../src/rotation-validator";
import type {
  SecretConfig,
  SecretStatus,
  RotationReport,
  OutputFormat,
} from "../src/types";

// ─── Test Fixtures ────────────────────────────────────────────────────────────

/** Reference date for all tests: 2026-04-09 */
const REFERENCE_DATE = new Date("2026-04-09T00:00:00Z");

/** Fixture: an expired secret (last rotated 100 days ago, policy is 90 days) */
const EXPIRED_SECRET: SecretConfig = {
  name: "DB_PASSWORD",
  lastRotated: new Date("2026-01-29T00:00:00Z"), // 70 days before ref — exceeds 60-day policy
  rotationPolicyDays: 60,
  requiredBy: ["api-service", "worker"],
};

/** Fixture: a secret expiring soon (within 14-day warning window)
 *  lastRotated = 2026-01-19, policy = 80 days → expires 2026-04-09 + 10 days = 2026-04-19
 *  Wait: Jan 19 + 80 = Apr 9 exactly → 0 days left. Let's use Jan 26 + 80 = Apr 16 → 7 days left.
 *  Jan 26 + 80 days: Jan has 31, so Jan 26 + 5 = Jan 31 → +75 more = Apr 16. ✓
 */
const WARNING_SECRET: SecretConfig = {
  name: "API_KEY",
  lastRotated: new Date("2026-01-26T00:00:00Z"), // policy=80 days → expires 2026-04-16 → 7 days left
  rotationPolicyDays: 80,
  requiredBy: ["frontend"],
};

/** Fixture: a healthy secret (plenty of time left) */
const OK_SECRET: SecretConfig = {
  name: "JWT_SECRET",
  lastRotated: new Date("2026-03-10T00:00:00Z"), // 30 days before ref, 180-day policy → 150 days left
  rotationPolicyDays: 180,
  requiredBy: ["auth-service"],
};

// ─── Tests: classifySecret ────────────────────────────────────────────────────

describe("classifySecret", () => {
  it("classifies a secret as EXPIRED when past its rotation deadline", () => {
    const status = classifySecret(EXPIRED_SECRET, REFERENCE_DATE, 14);
    expect(status.urgency).toBe("expired");
  });

  it("classifies a secret as WARNING when within the warning window", () => {
    const status = classifySecret(WARNING_SECRET, REFERENCE_DATE, 14);
    expect(status.urgency).toBe("warning");
  });

  it("classifies a secret as OK when well within rotation policy", () => {
    const status = classifySecret(OK_SECRET, REFERENCE_DATE, 14);
    expect(status.urgency).toBe("ok");
  });

  it("includes the correct daysUntilExpiry (negative for expired)", () => {
    const status = classifySecret(EXPIRED_SECRET, REFERENCE_DATE, 14);
    // lastRotated = Jan 29, policy = 60 days → expires Mar 29. Ref = Apr 9 → 11 days past expiry
    expect(status.daysUntilExpiry).toBeLessThan(0);
  });

  it("includes correct daysUntilExpiry for ok secrets", () => {
    const status = classifySecret(OK_SECRET, REFERENCE_DATE, 14);
    // lastRotated = Mar 10, policy = 180 → expires Sep 6. Ref = Apr 9 → ~150 days
    expect(status.daysUntilExpiry).toBeGreaterThan(14);
  });

  it("includes the secret's name in the status", () => {
    const status = classifySecret(EXPIRED_SECRET, REFERENCE_DATE, 14);
    expect(status.name).toBe("DB_PASSWORD");
  });

  it("includes requiredBy in the status", () => {
    const status = classifySecret(EXPIRED_SECRET, REFERENCE_DATE, 14);
    expect(status.requiredBy).toEqual(["api-service", "worker"]);
  });

  it("handles zero warning window (only expired/ok)", () => {
    // With 0-day warning, a secret expiring in 5 days should be OK not WARNING
    const status = classifySecret(WARNING_SECRET, REFERENCE_DATE, 0);
    expect(status.urgency).toBe("ok");
  });
});

// ─── Tests: analyzeSecrets ────────────────────────────────────────────────────

describe("analyzeSecrets", () => {
  const secrets: SecretConfig[] = [EXPIRED_SECRET, WARNING_SECRET, OK_SECRET];

  it("returns a list of SecretStatus objects for all secrets", () => {
    const results = analyzeSecrets(secrets, REFERENCE_DATE, 14);
    expect(results).toHaveLength(3);
  });

  it("correctly identifies expired secrets", () => {
    const results = analyzeSecrets(secrets, REFERENCE_DATE, 14);
    const expired = results.filter((s) => s.urgency === "expired");
    expect(expired).toHaveLength(1);
    expect(expired[0].name).toBe("DB_PASSWORD");
  });

  it("correctly identifies warning secrets", () => {
    const results = analyzeSecrets(secrets, REFERENCE_DATE, 14);
    const warnings = results.filter((s) => s.urgency === "warning");
    expect(warnings).toHaveLength(1);
    expect(warnings[0].name).toBe("API_KEY");
  });

  it("correctly identifies ok secrets", () => {
    const results = analyzeSecrets(secrets, REFERENCE_DATE, 14);
    const ok = results.filter((s) => s.urgency === "ok");
    expect(ok).toHaveLength(1);
    expect(ok[0].name).toBe("JWT_SECRET");
  });

  it("handles an empty list gracefully", () => {
    const results = analyzeSecrets([], REFERENCE_DATE, 14);
    expect(results).toHaveLength(0);
  });
});

// ─── Tests: generateReport ───────────────────────────────────────────────────

describe("generateReport", () => {
  const secrets: SecretConfig[] = [EXPIRED_SECRET, WARNING_SECRET, OK_SECRET];

  it("produces a RotationReport with grouped results", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 14);
    expect(report).toHaveProperty("expired");
    expect(report).toHaveProperty("warning");
    expect(report).toHaveProperty("ok");
  });

  it("groups expired secrets correctly", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 14);
    expect(report.expired).toHaveLength(1);
    expect(report.expired[0].name).toBe("DB_PASSWORD");
  });

  it("groups warning secrets correctly", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 14);
    expect(report.warning).toHaveLength(1);
    expect(report.warning[0].name).toBe("API_KEY");
  });

  it("groups ok secrets correctly", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 14);
    expect(report.ok).toHaveLength(1);
    expect(report.ok[0].name).toBe("JWT_SECRET");
  });

  it("includes summary counts", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 14);
    expect(report.summary.totalSecrets).toBe(3);
    expect(report.summary.expiredCount).toBe(1);
    expect(report.summary.warningCount).toBe(1);
    expect(report.summary.okCount).toBe(1);
  });

  it("includes the reference date in the report", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 14);
    expect(report.generatedAt).toEqual(REFERENCE_DATE);
  });
});

// ─── Tests: formatAsMarkdown ─────────────────────────────────────────────────

describe("formatAsMarkdown", () => {
  const secrets: SecretConfig[] = [EXPIRED_SECRET, WARNING_SECRET, OK_SECRET];

  it("outputs a markdown string", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 14);
    const md = formatAsMarkdown(report);
    expect(typeof md).toBe("string");
  });

  it("contains a table header row", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 14);
    const md = formatAsMarkdown(report);
    expect(md).toContain("| Name |");
    expect(md).toContain("| Status |");
  });

  it("contains all secret names", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 14);
    const md = formatAsMarkdown(report);
    expect(md).toContain("DB_PASSWORD");
    expect(md).toContain("API_KEY");
    expect(md).toContain("JWT_SECRET");
  });

  it("contains urgency labels", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 14);
    const md = formatAsMarkdown(report);
    expect(md).toContain("EXPIRED");
    expect(md).toContain("WARNING");
    expect(md).toContain("OK");
  });

  it("contains a summary section", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 14);
    const md = formatAsMarkdown(report);
    expect(md).toContain("Summary");
    expect(md).toContain("Total");
  });
});

// ─── Tests: formatAsJson ─────────────────────────────────────────────────────

describe("formatAsJson", () => {
  const secrets: SecretConfig[] = [EXPIRED_SECRET, WARNING_SECRET, OK_SECRET];

  it("outputs valid JSON", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 14);
    const json = formatAsJson(report);
    expect(() => JSON.parse(json)).not.toThrow();
  });

  it("JSON contains expired, warning, ok arrays", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 14);
    const parsed = JSON.parse(formatAsJson(report));
    expect(parsed).toHaveProperty("expired");
    expect(parsed).toHaveProperty("warning");
    expect(parsed).toHaveProperty("ok");
  });

  it("JSON contains the correct secret names in each group", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 14);
    const parsed = JSON.parse(formatAsJson(report));
    expect(parsed.expired[0].name).toBe("DB_PASSWORD");
    expect(parsed.warning[0].name).toBe("API_KEY");
    expect(parsed.ok[0].name).toBe("JWT_SECRET");
  });

  it("JSON contains summary with correct counts", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 14);
    const parsed = JSON.parse(formatAsJson(report));
    expect(parsed.summary.totalSecrets).toBe(3);
    expect(parsed.summary.expiredCount).toBe(1);
    expect(parsed.summary.warningCount).toBe(1);
    expect(parsed.summary.okCount).toBe(1);
  });
});
