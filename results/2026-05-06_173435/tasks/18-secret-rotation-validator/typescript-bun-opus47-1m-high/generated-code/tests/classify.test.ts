// Red-step TDD: classification of secrets by rotation status.
// A secret is "expired" if more days have passed since lastRotated than its
// rotationPolicyDays; "warning" if it will expire within `warningWindowDays`;
// otherwise "ok".

import { describe, expect, test } from "bun:test";
import { classifySecrets, type Secret } from "../src/classify.ts";

const REFERENCE_NOW = new Date("2026-05-07T00:00:00Z");

const fixture: Secret[] = [
  {
    name: "stripe_api_key",
    lastRotated: "2025-10-01",
    rotationPolicyDays: 90,
    requiredBy: ["billing-svc", "checkout-svc"],
  },
  {
    name: "datadog_api_key",
    lastRotated: "2026-02-20",
    rotationPolicyDays: 90,
    requiredBy: ["observability"],
  },
  {
    name: "sendgrid_api_key",
    lastRotated: "2026-04-15",
    rotationPolicyDays: 60,
    requiredBy: ["notifications"],
  },
];

describe("classifySecrets", () => {
  test("buckets each secret into expired/warning/ok using the warning window", () => {
    const report = classifySecrets(fixture, {
      warningWindowDays: 14,
      now: REFERENCE_NOW,
    });

    expect(report.totals).toEqual({ expired: 1, warning: 1, ok: 1 });

    const expiredNames = report.expired.map((s) => s.name);
    const warningNames = report.warning.map((s) => s.name);
    const okNames = report.ok.map((s) => s.name);
    expect(expiredNames).toEqual(["stripe_api_key"]);
    expect(warningNames).toEqual(["datadog_api_key"]);
    expect(okNames).toEqual(["sendgrid_api_key"]);

    // stripe was rotated 2025-10-01, policy 90 days -> due 2025-12-30,
    // now 2026-05-07 -> 128 days past expiry.
    const stripe = report.expired[0]!;
    expect(stripe.daysUntilExpiry).toBe(-128);
    expect(stripe.status).toBe("expired");

    // datadog was rotated 2026-02-20, policy 90 days -> due 2026-05-21,
    // 14 days from now (2026-05-07) is 2026-05-21 -> 14 days remaining.
    const dd = report.warning[0]!;
    expect(dd.daysUntilExpiry).toBe(14);
    expect(dd.status).toBe("warning");
  });

  test("orders expired secrets by most-overdue first, warnings by soonest", () => {
    const secrets: Secret[] = [
      { name: "a", lastRotated: "2026-01-01", rotationPolicyDays: 30, requiredBy: ["x"] },
      { name: "b", lastRotated: "2025-06-01", rotationPolicyDays: 30, requiredBy: ["x"] },
      { name: "c", lastRotated: "2026-04-20", rotationPolicyDays: 30, requiredBy: ["x"] },
      { name: "d", lastRotated: "2026-04-25", rotationPolicyDays: 30, requiredBy: ["x"] },
    ];
    const report = classifySecrets(secrets, {
      warningWindowDays: 30,
      now: REFERENCE_NOW,
    });
    expect(report.expired.map((s) => s.name)).toEqual(["b", "a"]);
    expect(report.warning.map((s) => s.name)).toEqual(["c", "d"]);
  });

  test("rejects malformed input with a meaningful error", () => {
    expect(() =>
      classifySecrets(
        // @ts-expect-error - intentionally bad shape to verify validation
        [{ name: "broken", lastRotated: "not-a-date", rotationPolicyDays: 30 }],
        { warningWindowDays: 7, now: REFERENCE_NOW },
      ),
    ).toThrow(/lastRotated/);

    expect(() =>
      classifySecrets(
        [{ name: "bad", lastRotated: "2026-01-01", rotationPolicyDays: -5, requiredBy: [] }],
        { warningWindowDays: 7, now: REFERENCE_NOW },
      ),
    ).toThrow(/rotationPolicyDays/);
  });
});
