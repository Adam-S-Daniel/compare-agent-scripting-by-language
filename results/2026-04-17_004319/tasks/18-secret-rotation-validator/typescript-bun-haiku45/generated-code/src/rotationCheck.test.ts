import { describe, it, expect } from "bun:test";
import { Secret, RotationStatus } from "./types";
import { checkSecretRotation, generateRotationReport } from "./rotationCheck";

describe("Secret rotation checking", () => {
  const now = new Date("2026-04-19");

  it("should detect an expired secret", () => {
    const secret: Secret = {
      name: "expired-secret",
      lastRotated: new Date("2026-01-10"),
      rotationPolicyDays: 30,
      requiredByServices: ["api"],
    };

    const status = checkSecretRotation(secret, now);
    expect(status.status).toBe("expired");
    expect(status.daysUntilExpiration).toBeLessThan(0);
  });

  it("should detect a secret in warning window", () => {
    const secret: Secret = {
      name: "warning-secret",
      lastRotated: new Date("2026-04-01"),
      rotationPolicyDays: 30,
      requiredByServices: ["api"],
    };

    const status = checkSecretRotation(secret, now, 14);
    expect(status.status).toBe("warning");
    expect(status.daysUntilExpiration).toBeGreaterThan(0);
    expect(status.daysUntilExpiration).toBeLessThanOrEqual(14);
  });

  it("should detect a secret that is OK", () => {
    const secret: Secret = {
      name: "ok-secret",
      lastRotated: new Date("2026-02-15"),
      rotationPolicyDays: 90,
      requiredByServices: ["api"],
    };

    const status = checkSecretRotation(secret, now, 14);
    expect(status.status).toBe("ok");
    expect(status.daysUntilExpiration).toBeGreaterThan(14);
  });

  it("should calculate expiration date correctly", () => {
    const secret: Secret = {
      name: "test-secret",
      lastRotated: new Date("2026-04-01"),
      rotationPolicyDays: 30,
      requiredByServices: ["api"],
    };

    const status = checkSecretRotation(secret, now);
    const expectedDate = new Date("2026-05-01");
    expect(status.expirationDate.toISOString().split("T")[0]).toBe(expectedDate.toISOString().split("T")[0]);
  });

  it("should generate a rotation report with summary", () => {
    const secrets: Secret[] = [
      {
        name: "expired",
        lastRotated: new Date("2026-01-01"),
        rotationPolicyDays: 30,
        requiredByServices: ["api"],
      },
      {
        name: "warning",
        lastRotated: new Date("2026-03-25"),
        rotationPolicyDays: 30,
        requiredByServices: ["worker"],
      },
      {
        name: "ok",
        lastRotated: new Date("2026-02-15"),
        rotationPolicyDays: 90,
        requiredByServices: ["api"],
      },
    ];

    const report = generateRotationReport(secrets, now, 14);
    expect(report.summary.expired).toBe(1);
    expect(report.summary.warning).toBe(1);
    expect(report.summary.ok).toBe(1);
    expect(report.secrets.length).toBe(3);
  });
});
