import { describe, test, expect } from "bun:test";
import { validateSecret, generateReport } from "./validator";
import type { SecretConfig, ValidationConfig } from "./types";

const refDate = new Date("2026-05-07T00:00:00Z");

describe("validateSecret", () => {
  test("classifies expired secret correctly", () => {
    const secret: SecretConfig = {
      name: "DB_PASSWORD",
      lastRotated: "2024-01-15",
      rotationPolicyDays: 90,
      requiredBy: ["api-server", "worker"],
    };
    const result = validateSecret(secret, refDate, 14);
    expect(result.urgency).toBe("expired");
    expect(result.daysUntilExpiry).toBe(-753);
    expect(result.expiryDate).toBe("2024-04-14");
    expect(result.daysSinceRotation).toBe(843);
  });

  test("classifies warning secret correctly", () => {
    const secret: SecretConfig = {
      name: "JWT_SECRET",
      lastRotated: "2026-04-20",
      rotationPolicyDays: 30,
      requiredBy: ["auth-service"],
    };
    const result = validateSecret(secret, refDate, 14);
    expect(result.urgency).toBe("warning");
    expect(result.daysUntilExpiry).toBe(13);
    expect(result.expiryDate).toBe("2026-05-20");
    expect(result.daysSinceRotation).toBe(17);
  });

  test("classifies ok secret correctly", () => {
    const secret: SecretConfig = {
      name: "API_KEY",
      lastRotated: "2025-12-01",
      rotationPolicyDays: 365,
      requiredBy: ["frontend"],
    };
    const result = validateSecret(secret, refDate, 14);
    expect(result.urgency).toBe("ok");
    expect(result.daysUntilExpiry).toBe(208);
    expect(result.expiryDate).toBe("2026-12-01");
    expect(result.daysSinceRotation).toBe(157);
  });

  test("classifies ok secret with long policy", () => {
    const secret: SecretConfig = {
      name: "SLACK_WEBHOOK",
      lastRotated: "2026-05-01",
      rotationPolicyDays: 180,
      requiredBy: ["notification-service"],
    };
    const result = validateSecret(secret, refDate, 14);
    expect(result.urgency).toBe("ok");
    expect(result.daysUntilExpiry).toBe(174);
    expect(result.expiryDate).toBe("2026-10-28");
    expect(result.daysSinceRotation).toBe(6);
  });

  test("secret expiring exactly on warning boundary is warning", () => {
    const secret: SecretConfig = {
      name: "BOUNDARY",
      lastRotated: "2026-04-23",
      rotationPolicyDays: 28,
      requiredBy: ["svc"],
    };
    // expires on 2026-05-21, 14 days from 2026-05-07
    const result = validateSecret(secret, refDate, 14);
    expect(result.urgency).toBe("warning");
    expect(result.daysUntilExpiry).toBe(14);
  });

  test("secret expiring exactly today (0 days) is warning", () => {
    const secret: SecretConfig = {
      name: "TODAY",
      lastRotated: "2026-04-07",
      rotationPolicyDays: 30,
      requiredBy: ["svc"],
    };
    // expires on 2026-05-07, 0 days until expiry
    const result = validateSecret(secret, refDate, 14);
    expect(result.urgency).toBe("warning");
    expect(result.daysUntilExpiry).toBe(0);
  });

  test("zero warning window means only expired or ok", () => {
    const secret: SecretConfig = {
      name: "TIGHT",
      lastRotated: "2026-05-06",
      rotationPolicyDays: 2,
      requiredBy: ["svc"],
    };
    // expires 2026-05-08, 1 day from ref. warningWindow=0, so only daysUntilExpiry<=0 is warning
    const result = validateSecret(secret, refDate, 0);
    expect(result.urgency).toBe("ok");
    expect(result.daysUntilExpiry).toBe(1);
  });

  test("throws on invalid date", () => {
    const secret: SecretConfig = {
      name: "BAD_DATE",
      lastRotated: "not-a-date",
      rotationPolicyDays: 30,
      requiredBy: [],
    };
    expect(() => validateSecret(secret, refDate, 14)).toThrow("Invalid lastRotated date");
  });

  test("throws on empty name", () => {
    const secret: SecretConfig = {
      name: "",
      lastRotated: "2026-01-01",
      rotationPolicyDays: 30,
      requiredBy: [],
    };
    expect(() => validateSecret(secret, refDate, 14)).toThrow("Secret name cannot be empty");
  });

  test("throws on non-positive rotation policy", () => {
    const secret: SecretConfig = {
      name: "ZERO_POLICY",
      lastRotated: "2026-01-01",
      rotationPolicyDays: 0,
      requiredBy: [],
    };
    expect(() => validateSecret(secret, refDate, 14)).toThrow("must be positive");
  });
});

describe("generateReport", () => {
  const config: ValidationConfig = {
    secrets: [
      { name: "DB_PASSWORD", lastRotated: "2024-01-15", rotationPolicyDays: 90, requiredBy: ["api-server", "worker"] },
      { name: "API_KEY", lastRotated: "2025-12-01", rotationPolicyDays: 365, requiredBy: ["frontend"] },
      { name: "JWT_SECRET", lastRotated: "2026-04-20", rotationPolicyDays: 30, requiredBy: ["auth-service"] },
      { name: "SLACK_WEBHOOK", lastRotated: "2026-05-01", rotationPolicyDays: 180, requiredBy: ["notification-service"] },
    ],
    warningWindowDays: 14,
    referenceDate: "2026-05-07",
  };

  test("generates correct summary counts", () => {
    const report = generateReport(config);
    expect(report.summary.total).toBe(4);
    expect(report.summary.expired).toBe(1);
    expect(report.summary.warning).toBe(1);
    expect(report.summary.ok).toBe(2);
  });

  test("sorts secrets by urgency then name", () => {
    const report = generateReport(config);
    expect(report.secrets[0].name).toBe("DB_PASSWORD");
    expect(report.secrets[0].urgency).toBe("expired");
    expect(report.secrets[1].name).toBe("JWT_SECRET");
    expect(report.secrets[1].urgency).toBe("warning");
    expect(report.secrets[2].name).toBe("API_KEY");
    expect(report.secrets[2].urgency).toBe("ok");
    expect(report.secrets[3].name).toBe("SLACK_WEBHOOK");
    expect(report.secrets[3].urgency).toBe("ok");
  });

  test("sets generatedAt and warningWindowDays", () => {
    const report = generateReport(config);
    expect(report.generatedAt).toBe("2026-05-07");
    expect(report.warningWindowDays).toBe(14);
  });

  test("throws on missing secrets array", () => {
    expect(() => generateReport({ secrets: null as any, warningWindowDays: 14 })).toThrow(
      'must include a "secrets" array'
    );
  });

  test("throws on negative warning window", () => {
    expect(() => generateReport({ secrets: [], warningWindowDays: -1 })).toThrow(
      "non-negative"
    );
  });

  test("throws on invalid reference date", () => {
    expect(() =>
      generateReport({ secrets: [], warningWindowDays: 14, referenceDate: "bad" })
    ).toThrow("Invalid referenceDate");
  });

  test("handles empty secrets array", () => {
    const report = generateReport({ secrets: [], warningWindowDays: 14, referenceDate: "2026-05-07" });
    expect(report.summary.total).toBe(0);
    expect(report.summary.expired).toBe(0);
    expect(report.secrets).toHaveLength(0);
  });
});
