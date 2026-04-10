/**
 * Tests for the Secret Rotation Validator core logic.
 * TDD approach: these tests were written FIRST, before the implementation.
 * All date calculations use a fixed TODAY constant for deterministic results.
 */
import { describe, test, expect } from "bun:test";
import { processSecret, generateReport } from "../src/validator";
import type { SecretConfig } from "../src/types";

// Fixed reference date for deterministic tests (2026-04-10)
const TODAY = "2026-04-10";
const WARNING_DAYS = 14;

// Test fixtures designed upfront with known expected outputs for TODAY=2026-04-10:
//   PROD_DB_PASSWORD: expired on 2026-01-31, daysUntilExpiry=-69  → urgency=expired
//   API_KEY:          expires on 2026-04-11, daysUntilExpiry=1     → urgency=warning
//   JWT_SECRET:       expires on 2026-07-04, daysUntilExpiry=85    → urgency=ok
const fixtures: SecretConfig[] = [
  {
    name: "PROD_DB_PASSWORD",
    lastRotated: "2026-01-01",
    rotationPolicyDays: 30,
    requiredBy: ["auth-service", "api-gateway"],
  },
  {
    name: "API_KEY",
    lastRotated: "2026-03-28",
    rotationPolicyDays: 14,
    requiredBy: ["payment-service"],
  },
  {
    name: "JWT_SECRET",
    lastRotated: "2026-04-05",
    rotationPolicyDays: 90,
    requiredBy: ["auth-service"],
  },
];

describe("processSecret", () => {
  test("identifies expired secret correctly", () => {
    // 2026-01-01 + 30 days = 2026-01-31; 2026-04-10 - 2026-01-31 = 69 days overdue
    const status = processSecret(fixtures[0], TODAY, WARNING_DAYS);
    expect(status.name).toBe("PROD_DB_PASSWORD");
    expect(status.expiryDate).toBe("2026-01-31");
    expect(status.daysUntilExpiry).toBe(-69);
    expect(status.urgency).toBe("expired");
    expect(status.requiredBy).toEqual(["auth-service", "api-gateway"]);
  });

  test("identifies warning secret correctly", () => {
    // 2026-03-28 + 14 days = 2026-04-11; 1 day remaining < 14-day warning window
    const status = processSecret(fixtures[1], TODAY, WARNING_DAYS);
    expect(status.name).toBe("API_KEY");
    expect(status.expiryDate).toBe("2026-04-11");
    expect(status.daysUntilExpiry).toBe(1);
    expect(status.urgency).toBe("warning");
  });

  test("identifies ok secret correctly", () => {
    // 2026-04-05 + 90 days = 2026-07-04; 85 days remaining >= 14-day warning window
    const status = processSecret(fixtures[2], TODAY, WARNING_DAYS);
    expect(status.name).toBe("JWT_SECRET");
    expect(status.expiryDate).toBe("2026-07-04");
    expect(status.daysUntilExpiry).toBe(85);
    expect(status.urgency).toBe("ok");
  });

  test("secret expiring today has 0 days remaining and is warning", () => {
    // 2026-03-11 + 30 = 2026-04-10 (today); 0 < 14 → warning
    const secret: SecretConfig = {
      name: "EXPIRING_TODAY",
      lastRotated: "2026-03-11",
      rotationPolicyDays: 30,
      requiredBy: ["some-service"],
    };
    const status = processSecret(secret, TODAY, WARNING_DAYS);
    expect(status.daysUntilExpiry).toBe(0);
    expect(status.urgency).toBe("warning");
  });

  test("secret expired yesterday has -1 days and is expired", () => {
    // 2026-03-10 + 30 = 2026-04-09 (yesterday); daysUntilExpiry=-1 → expired
    const secret: SecretConfig = {
      name: "EXPIRED_YESTERDAY",
      lastRotated: "2026-03-10",
      rotationPolicyDays: 30,
      requiredBy: [],
    };
    const status = processSecret(secret, TODAY, WARNING_DAYS);
    expect(status.daysUntilExpiry).toBe(-1);
    expect(status.urgency).toBe("expired");
  });

  test("secret expiring exactly at warning boundary is ok", () => {
    // 2026-03-27 + 14 = 2026-04-10... wait, that's today with daysUntil=0
    // Let's use: lastRotated=2026-03-13, policy=28 → expiry=2026-04-10+14=...
    // Actually: expiry = lastRotated + policy. Days until = expiry - today.
    // For daysUntilExpiry = warningWindowDays (14): expiry = 2026-04-24
    // lastRotated = 2026-04-24 - 30 = 2026-03-25, policy=30
    const secret: SecretConfig = {
      name: "AT_BOUNDARY",
      lastRotated: "2026-03-25",
      rotationPolicyDays: 30,
      requiredBy: [],
    };
    // 2026-03-25 + 30 = 2026-04-24; 2026-04-24 - 2026-04-10 = 14 days
    const status = processSecret(secret, TODAY, WARNING_DAYS);
    expect(status.daysUntilExpiry).toBe(14);
    expect(status.urgency).toBe("ok"); // 14 is NOT < 14, so ok
  });
});

describe("generateReport", () => {
  test("groups secrets by urgency correctly", () => {
    const report = generateReport(fixtures, TODAY, WARNING_DAYS);
    expect(report.expired).toHaveLength(1);
    expect(report.warning).toHaveLength(1);
    expect(report.ok).toHaveLength(1);
    expect(report.expired[0].name).toBe("PROD_DB_PASSWORD");
    expect(report.warning[0].name).toBe("API_KEY");
    expect(report.ok[0].name).toBe("JWT_SECRET");
  });

  test("summary counts match group lengths", () => {
    const report = generateReport(fixtures, TODAY, WARNING_DAYS);
    expect(report.summary.expired).toBe(1);
    expect(report.summary.warning).toBe(1);
    expect(report.summary.ok).toBe(1);
  });

  test("report metadata contains correct values", () => {
    const report = generateReport(fixtures, TODAY, WARNING_DAYS);
    expect(report.generatedAt).toBe(TODAY);
    expect(report.warningWindowDays).toBe(WARNING_DAYS);
  });

  test("handles empty secrets list gracefully", () => {
    const report = generateReport([], TODAY, WARNING_DAYS);
    expect(report.expired).toHaveLength(0);
    expect(report.warning).toHaveLength(0);
    expect(report.ok).toHaveLength(0);
    expect(report.summary).toEqual({ expired: 0, warning: 0, ok: 0 });
  });

  test("respects custom warning window", () => {
    // With 0-day window: only negative days are expired; 1+ days = ok
    const report = generateReport(fixtures, TODAY, 0);
    expect(report.expired).toHaveLength(1);
    expect(report.warning).toHaveLength(0);
    expect(report.ok).toHaveLength(2);
  });

  test("all secrets expired with very large warning window", () => {
    // With 365-day warning window: everything expiring within a year is warning or expired
    const report = generateReport(fixtures, TODAY, 365);
    // PROD_DB_PASSWORD: -69 → expired; API_KEY: 1 → warning; JWT_SECRET: 85 → warning
    expect(report.expired).toHaveLength(1);
    expect(report.warning).toHaveLength(2); // API_KEY and JWT_SECRET both < 365
    expect(report.ok).toHaveLength(0);
  });
});
