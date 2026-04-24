// TDD tests for the secret rotation validator.
// Each describe block corresponds to one red/green/refactor cycle.

import { describe, expect, test } from "bun:test";
import {
  classifySecret,
  validateSecrets,
  renderReport,
  loadConfig,
  type Secret,
  type SecretStatus,
  type ValidationReport,
} from "./validator";

const REF_NOW = new Date("2026-04-19T00:00:00Z");

// ---------- Cycle 1: classifySecret ----------
describe("classifySecret", () => {
  test("returns 'ok' when the secret is well within its rotation window", () => {
    const secret: Secret = {
      name: "db-primary",
      lastRotated: "2026-04-01",
      rotationPolicyDays: 90,
      requiredBy: ["api"],
    };
    const status = classifySecret(secret, { now: REF_NOW, warningDays: 14 });
    expect(status).toBe<SecretStatus>("ok");
  });

  test("returns 'warning' when expiry falls inside the warning window", () => {
    const secret: Secret = {
      name: "stripe-api",
      lastRotated: "2026-01-25",
      rotationPolicyDays: 90,
      requiredBy: ["billing"],
    };
    // lastRotated + 90d = 2026-04-25 ; now = 2026-04-19 ; 6 days left
    const status = classifySecret(secret, { now: REF_NOW, warningDays: 14 });
    expect(status).toBe<SecretStatus>("warning");
  });

  test("returns 'expired' when the deadline has already passed", () => {
    const secret: Secret = {
      name: "legacy-jwt",
      lastRotated: "2025-01-01",
      rotationPolicyDays: 90,
      requiredBy: ["legacy"],
    };
    const status = classifySecret(secret, { now: REF_NOW, warningDays: 14 });
    expect(status).toBe<SecretStatus>("expired");
  });

  test("treats a secret expiring today (0 days left) as 'warning', not 'expired'", () => {
    const secret: Secret = {
      name: "today",
      lastRotated: "2026-01-19", // +90 = 2026-04-19 (today)
      rotationPolicyDays: 90,
      requiredBy: ["svc"],
    };
    const status = classifySecret(secret, { now: REF_NOW, warningDays: 14 });
    expect(status).toBe<SecretStatus>("warning");
  });

  test("rejects non-positive rotationPolicyDays", () => {
    const secret: Secret = {
      name: "bogus",
      lastRotated: "2026-01-01",
      rotationPolicyDays: 0,
      requiredBy: [],
    };
    expect(() => classifySecret(secret, { now: REF_NOW, warningDays: 14 })).toThrow(
      /rotationPolicyDays must be a positive integer/,
    );
  });

  test("rejects an unparseable lastRotated date", () => {
    const secret: Secret = {
      name: "bad-date",
      lastRotated: "not-a-date",
      rotationPolicyDays: 30,
      requiredBy: [],
    };
    expect(() => classifySecret(secret, { now: REF_NOW, warningDays: 14 })).toThrow(
      /invalid lastRotated/,
    );
  });
});

// ---------- Cycle 2: validateSecrets aggregates into a report ----------
describe("validateSecrets", () => {
  const fixture: Secret[] = [
    { name: "db-primary",  lastRotated: "2026-04-01", rotationPolicyDays: 90, requiredBy: ["api"] },
    { name: "stripe-api",  lastRotated: "2026-01-25", rotationPolicyDays: 90, requiredBy: ["billing"] },
    { name: "legacy-jwt",  lastRotated: "2025-01-01", rotationPolicyDays: 90, requiredBy: ["legacy"] },
    { name: "github-pat",  lastRotated: "2024-04-19", rotationPolicyDays: 180, requiredBy: ["ci", "deploy"] },
  ];

  test("groups secrets by urgency and sorts each group deterministically", () => {
    const report = validateSecrets(fixture, { now: REF_NOW, warningDays: 14 });

    expect(report.generatedAt).toBe("2026-04-19T00:00:00.000Z");
    expect(report.warningDays).toBe(14);
    expect(report.totals).toEqual({ expired: 2, warning: 1, ok: 1, total: 4 });

    // expired sorted by most-overdue first (by daysUntilExpiry ascending; most negative first)
    // github-pat is ~2 years overdue; legacy-jwt ~1 year overdue; most-overdue comes first.
    expect(report.expired.map((s) => s.name)).toEqual(["github-pat", "legacy-jwt"]);
    expect(report.warning.map((s) => s.name)).toEqual(["stripe-api"]);
    expect(report.ok.map((s) => s.name)).toEqual(["db-primary"]);
  });

  test("each reported secret has its computed deadline and daysUntilExpiry", () => {
    const report = validateSecrets(fixture, { now: REF_NOW, warningDays: 14 });
    const stripe = report.warning.find((s) => s.name === "stripe-api")!;
    expect(stripe.expiresOn).toBe("2026-04-25");
    expect(stripe.daysUntilExpiry).toBe(6);
    const legacy = report.expired.find((s) => s.name === "legacy-jwt")!;
    expect(legacy.expiresOn).toBe("2025-04-01");
    expect(legacy.daysUntilExpiry).toBe(-383);
  });

  test("rejects duplicate secret names (a common config mistake)", () => {
    const dupes: Secret[] = [
      { name: "a", lastRotated: "2026-04-01", rotationPolicyDays: 90, requiredBy: [] },
      { name: "a", lastRotated: "2026-04-01", rotationPolicyDays: 90, requiredBy: [] },
    ];
    expect(() => validateSecrets(dupes, { now: REF_NOW, warningDays: 14 })).toThrow(
      /duplicate secret name: "a"/,
    );
  });
});

// ---------- Cycle 3: output formats ----------
describe("renderReport", () => {
  const report: ValidationReport = {
    generatedAt: "2026-04-19T00:00:00.000Z",
    warningDays: 14,
    totals: { expired: 1, warning: 1, ok: 1, total: 3 },
    expired: [
      {
        name: "legacy-jwt",
        lastRotated: "2025-01-01",
        rotationPolicyDays: 90,
        requiredBy: ["legacy"],
        expiresOn: "2025-04-01",
        daysUntilExpiry: -383,
        status: "expired",
      },
    ],
    warning: [
      {
        name: "stripe-api",
        lastRotated: "2026-01-25",
        rotationPolicyDays: 90,
        requiredBy: ["billing"],
        expiresOn: "2026-04-25",
        daysUntilExpiry: 6,
        status: "warning",
      },
    ],
    ok: [
      {
        name: "db-primary",
        lastRotated: "2026-04-01",
        rotationPolicyDays: 90,
        requiredBy: ["api"],
        expiresOn: "2026-06-30",
        daysUntilExpiry: 72,
        status: "ok",
      },
    ],
  };

  test("renders JSON that round-trips through JSON.parse", () => {
    const out = renderReport(report, "json");
    expect(JSON.parse(out)).toEqual(report);
  });

  test("renders a markdown report with one table per urgency group", () => {
    const md = renderReport(report, "markdown");
    // Headline summary
    expect(md).toContain("# Secret Rotation Report");
    expect(md).toContain("Generated: 2026-04-19T00:00:00.000Z");
    expect(md).toContain("Warning window: 14 days");
    expect(md).toContain("Totals: 1 expired, 1 warning, 1 ok (3 total)");
    // Section headers in urgency order
    const expiredIdx = md.indexOf("## Expired (1)");
    const warningIdx = md.indexOf("## Warning (1)");
    const okIdx = md.indexOf("## OK (1)");
    expect(expiredIdx).toBeGreaterThan(-1);
    expect(warningIdx).toBeGreaterThan(expiredIdx);
    expect(okIdx).toBeGreaterThan(warningIdx);
    // Table header and a data row
    expect(md).toContain("| Name | Last Rotated | Policy (days) | Expires On | Days Left | Required By |");
    expect(md).toContain("| legacy-jwt | 2025-01-01 | 90 | 2025-04-01 | -383 | legacy |");
    expect(md).toContain("| stripe-api | 2026-01-25 | 90 | 2026-04-25 | 6 | billing |");
    expect(md).toContain("| db-primary | 2026-04-01 | 90 | 2026-06-30 | 72 | api |");
  });

  test("rejects an unknown format", () => {
    // @ts-expect-error — runtime check
    expect(() => renderReport(report, "xml")).toThrow(/unknown format: xml/);
  });
});

// ---------- Cycle 4: config loading ----------
describe("loadConfig", () => {
  test("parses a valid JSON config and returns the secrets array", async () => {
    const path = `${import.meta.dir}/fixtures/valid.json`;
    const secrets = await loadConfig(path);
    expect(secrets).toBeArrayOfSize(4);
    expect(secrets[0].name).toBe("db-primary");
  });

  test("throws a readable error for malformed JSON", async () => {
    const path = `${import.meta.dir}/fixtures/malformed.json`;
    await expect(loadConfig(path)).rejects.toThrow(/failed to parse config/);
  });

  test("throws a readable error when a secret is missing a required field", async () => {
    const path = `${import.meta.dir}/fixtures/missing-field.json`;
    await expect(loadConfig(path)).rejects.toThrow(/missing required field/);
  });
});
