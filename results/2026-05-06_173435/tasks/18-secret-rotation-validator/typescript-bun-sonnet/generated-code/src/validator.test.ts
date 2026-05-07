// TDD red phase: these tests are written BEFORE the implementation.
// Run: bun test src/validator.test.ts
// Expected: FAIL (validator.ts does not exist yet)

import { describe, it, expect } from "bun:test";
import { validateSecret, generateReport } from "./validator";
import type { SecretConfig } from "./types";

// Reference date for deterministic tests: 2026-05-07
const REFERENCE_DATE = new Date("2026-05-07T00:00:00.000Z");

// Fixture secrets with known day offsets from 2026-05-07:
//   EXPIRED_SECRET:  last rotated 40 days ago (2026-03-28), policy 30d → expired
//   WARNING_SECRET:  last rotated 25 days ago (2026-04-12), policy 30d, window 7d → warning (5 days left)
//   OK_SECRET:       last rotated 10 days ago (2026-04-27), policy 30d → ok (20 days left)
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

describe("validateSecret", () => {
  it("marks an expired secret with urgency=expired", () => {
    const status = validateSecret(EXPIRED_SECRET, REFERENCE_DATE, 7);
    expect(status.urgency).toBe("expired");
  });

  it("calculates correct daysSinceRotation for expired secret", () => {
    const status = validateSecret(EXPIRED_SECRET, REFERENCE_DATE, 7);
    // 2026-03-28 → 2026-05-07: 3 (Mar) + 30 (Apr) + 7 (May) = 40 days
    expect(status.daysSinceRotation).toBe(40);
  });

  it("calculates correct daysUntilExpiry for expired secret (negative = past due)", () => {
    const status = validateSecret(EXPIRED_SECRET, REFERENCE_DATE, 7);
    // policy 30d, rotated 40d ago → expired 10 days ago → -10
    expect(status.daysUntilExpiry).toBe(-10);
  });

  it("marks a secret expiring within warning window as urgency=warning", () => {
    const status = validateSecret(WARNING_SECRET, REFERENCE_DATE, 7);
    expect(status.urgency).toBe("warning");
  });

  it("calculates correct daysSinceRotation for warning secret", () => {
    const status = validateSecret(WARNING_SECRET, REFERENCE_DATE, 7);
    // 2026-04-12 → 2026-05-07: 18 (Apr) + 7 (May) = 25 days
    expect(status.daysSinceRotation).toBe(25);
  });

  it("calculates correct daysUntilExpiry for warning secret", () => {
    const status = validateSecret(WARNING_SECRET, REFERENCE_DATE, 7);
    // policy 30d, rotated 25d ago → expires in 5 days
    expect(status.daysUntilExpiry).toBe(5);
  });

  it("marks a healthy secret as urgency=ok", () => {
    const status = validateSecret(OK_SECRET, REFERENCE_DATE, 7);
    expect(status.urgency).toBe("ok");
  });

  it("calculates correct daysSinceRotation for ok secret", () => {
    const status = validateSecret(OK_SECRET, REFERENCE_DATE, 7);
    // 2026-04-27 → 2026-05-07: 3 (Apr) + 7 (May) = 10 days
    expect(status.daysSinceRotation).toBe(10);
  });

  it("calculates correct daysUntilExpiry for ok secret", () => {
    const status = validateSecret(OK_SECRET, REFERENCE_DATE, 7);
    // policy 30d, rotated 10d ago → expires in 20 days
    expect(status.daysUntilExpiry).toBe(20);
  });

  it("treats a secret at exactly the expiry boundary as expired", () => {
    // rotated exactly rotationPolicyDays ago → daysUntilExpiry = 0 → expired
    const secret: SecretConfig = {
      name: "BOUNDARY_SECRET",
      lastRotated: "2026-04-07", // 30 days before 2026-05-07
      rotationPolicyDays: 30,
      requiredBy: [],
    };
    const status = validateSecret(secret, REFERENCE_DATE, 7);
    expect(status.urgency).toBe("expired");
    expect(status.daysUntilExpiry).toBe(0);
  });

  it("uses a custom warning window correctly", () => {
    // 5 days until expiry, warning window = 3 → ok (5 > 3)
    const status = validateSecret(WARNING_SECRET, REFERENCE_DATE, 3);
    expect(status.urgency).toBe("ok");
  });

  it("returns the original secret on the status object", () => {
    const status = validateSecret(EXPIRED_SECRET, REFERENCE_DATE, 7);
    expect(status.secret).toBe(EXPIRED_SECRET);
  });
});

describe("generateReport", () => {
  const secrets = [EXPIRED_SECRET, WARNING_SECRET, OK_SECRET];

  it("groups secrets by urgency correctly", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 7);
    expect(report.expired).toHaveLength(1);
    expect(report.warning).toHaveLength(1);
    expect(report.ok).toHaveLength(1);
  });

  it("puts expired secret in the expired bucket", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 7);
    expect(report.expired[0].secret.name).toBe("EXPIRED_SECRET");
  });

  it("puts warning secret in the warning bucket", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 7);
    expect(report.warning[0].secret.name).toBe("WARNING_SECRET");
  });

  it("puts ok secret in the ok bucket", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 7);
    expect(report.ok[0].secret.name).toBe("OK_SECRET");
  });

  it("records the reference date in the report", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 7);
    expect(report.referenceDate).toBe("2026-05-07");
  });

  it("records the warningWindowDays in the report", () => {
    const report = generateReport(secrets, REFERENCE_DATE, 7);
    expect(report.warningWindowDays).toBe(7);
  });

  it("handles an empty secrets list", () => {
    const report = generateReport([], REFERENCE_DATE, 7);
    expect(report.expired).toHaveLength(0);
    expect(report.warning).toHaveLength(0);
    expect(report.ok).toHaveLength(0);
  });

  it("handles all-expired list", () => {
    const report = generateReport([EXPIRED_SECRET], REFERENCE_DATE, 7);
    expect(report.expired).toHaveLength(1);
    expect(report.warning).toHaveLength(0);
    expect(report.ok).toHaveLength(0);
  });
});
