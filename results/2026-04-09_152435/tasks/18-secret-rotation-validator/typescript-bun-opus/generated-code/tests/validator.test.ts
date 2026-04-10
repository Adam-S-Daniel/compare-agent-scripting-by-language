// TDD: Tests for the secret rotation validator.
// Written BEFORE the implementation — these should fail until validator.ts is implemented.

import { describe, expect, test } from "bun:test";
import { validateSecret, validateSecrets, generateReport } from "../src/validator";
import type { SecretConfig, RotationConfig } from "../src/types";

// Fixed reference date for deterministic tests: 2026-04-10
const NOW = new Date("2026-04-10");

describe("validateSecret", () => {
  test("marks a secret as expired when past its rotation policy", () => {
    const secret: SecretConfig = {
      name: "DB_PASSWORD",
      lastRotated: "2026-01-01", // 99 days ago from 2026-04-10
      rotationPolicyDays: 90,
      requiredBy: ["api-server", "worker"],
    };
    const result = validateSecret(secret, 14, NOW);
    expect(result.urgency).toBe("expired");
    expect(result.daysSinceRotation).toBe(99);
    expect(result.daysUntilExpiry).toBe(-9); // 90 - 99 = -9
    expect(result.name).toBe("DB_PASSWORD");
    expect(result.requiredBy).toEqual(["api-server", "worker"]);
  });

  test("marks a secret as warning when within the warning window", () => {
    const secret: SecretConfig = {
      name: "API_KEY",
      lastRotated: "2026-01-15", // 85 days ago
      rotationPolicyDays: 90,
      requiredBy: ["frontend"],
    };
    const result = validateSecret(secret, 14, NOW);
    expect(result.urgency).toBe("warning");
    expect(result.daysSinceRotation).toBe(85);
    expect(result.daysUntilExpiry).toBe(5); // 90 - 85 = 5, within 14-day window
  });

  test("marks a secret as ok when well within policy", () => {
    const secret: SecretConfig = {
      name: "JWT_SECRET",
      lastRotated: "2026-03-20", // 21 days ago
      rotationPolicyDays: 90,
      requiredBy: ["auth-service"],
    };
    const result = validateSecret(secret, 14, NOW);
    expect(result.urgency).toBe("ok");
    expect(result.daysSinceRotation).toBe(21);
    expect(result.daysUntilExpiry).toBe(69); // 90 - 21 = 69
  });

  test("marks a secret rotated exactly at policy boundary as expired", () => {
    const secret: SecretConfig = {
      name: "EXACT_BOUNDARY",
      lastRotated: "2026-01-10", // exactly 90 days ago
      rotationPolicyDays: 90,
      requiredBy: ["service-a"],
    };
    const result = validateSecret(secret, 14, NOW);
    // 90 days since rotation, 0 days until expiry — should be warning (within window)
    expect(result.urgency).toBe("warning");
    expect(result.daysUntilExpiry).toBe(0);
  });

  test("handles secret rotated today", () => {
    const secret: SecretConfig = {
      name: "FRESH_SECRET",
      lastRotated: "2026-04-10",
      rotationPolicyDays: 30,
      requiredBy: ["service-b"],
    };
    const result = validateSecret(secret, 7, NOW);
    expect(result.urgency).toBe("ok");
    expect(result.daysSinceRotation).toBe(0);
    expect(result.daysUntilExpiry).toBe(30);
  });
});

describe("validateSecrets", () => {
  test("validates multiple secrets and returns sorted by urgency", () => {
    const secrets: SecretConfig[] = [
      { name: "OK_SECRET", lastRotated: "2026-04-01", rotationPolicyDays: 90, requiredBy: ["svc1"] },
      { name: "EXPIRED_SECRET", lastRotated: "2025-12-01", rotationPolicyDays: 90, requiredBy: ["svc2"] },
      { name: "WARNING_SECRET", lastRotated: "2026-01-15", rotationPolicyDays: 90, requiredBy: ["svc3"] },
    ];
    const results = validateSecrets(secrets, 14, NOW);
    // Should be sorted: expired first, then warning, then ok
    expect(results[0].urgency).toBe("expired");
    expect(results[0].name).toBe("EXPIRED_SECRET");
    expect(results[1].urgency).toBe("warning");
    expect(results[1].name).toBe("WARNING_SECRET");
    expect(results[2].urgency).toBe("ok");
    expect(results[2].name).toBe("OK_SECRET");
  });
});

describe("generateReport", () => {
  test("generates a complete report with correct summary counts", () => {
    const config: RotationConfig = {
      warningWindowDays: 14,
      secrets: [
        { name: "EXPIRED_1", lastRotated: "2025-12-01", rotationPolicyDays: 90, requiredBy: ["a"] },
        { name: "EXPIRED_2", lastRotated: "2025-11-01", rotationPolicyDays: 90, requiredBy: ["b"] },
        { name: "WARNING_1", lastRotated: "2026-01-15", rotationPolicyDays: 90, requiredBy: ["c"] },
        { name: "OK_1", lastRotated: "2026-04-01", rotationPolicyDays: 90, requiredBy: ["d"] },
        { name: "OK_2", lastRotated: "2026-03-30", rotationPolicyDays: 90, requiredBy: ["e"] },
      ],
    };
    const report = generateReport(config, NOW);
    expect(report.summary.total).toBe(5);
    expect(report.summary.expired).toBe(2);
    expect(report.summary.warning).toBe(1);
    expect(report.summary.ok).toBe(2);
    expect(report.warningWindowDays).toBe(14);
    expect(report.secrets).toHaveLength(5);
  });

  test("handles empty secrets list", () => {
    const config: RotationConfig = { warningWindowDays: 7, secrets: [] };
    const report = generateReport(config, NOW);
    expect(report.summary.total).toBe(0);
    expect(report.summary.expired).toBe(0);
    expect(report.summary.warning).toBe(0);
    expect(report.summary.ok).toBe(0);
    expect(report.secrets).toHaveLength(0);
  });
});
