// TDD red/green cycle:
// 1. Write failing test → 2. Write minimum code → 3. Refactor → repeat
import { test, expect, describe } from "bun:test";
import { identifySecretStatus, generateReport } from "../src/validator";
import { formatAsMarkdown, formatAsJSON } from "../src/formatter";
import type { Secret, ValidatorConfig } from "../src/types";

// Reference date for all tests: 2026-04-19
const REF = new Date("2026-04-19T00:00:00Z");

// ─── Fixtures ────────────────────────────────────────────────────────────────
// DB_PASSWORD: 100 days since rotation, 90-day policy → EXPIRED (10 days overdue)
const expiredSecret: Secret = {
  name: "DB_PASSWORD",
  lastRotated: new Date("2026-01-09T00:00:00Z"),
  rotationPolicyDays: 90,
  requiredBy: ["api-service", "worker-service"],
};

// API_KEY: 84 days since rotation, 90-day policy → WARNING (6 days left, within 7-day window)
const warningSecret: Secret = {
  name: "API_KEY",
  lastRotated: new Date("2026-01-25T00:00:00Z"),
  rotationPolicyDays: 90,
  requiredBy: ["frontend-service"],
};

// JWT_SECRET: 30 days since rotation, 90-day policy → OK (60 days left)
const okSecret: Secret = {
  name: "JWT_SECRET",
  lastRotated: new Date("2026-03-20T00:00:00Z"),
  rotationPolicyDays: 90,
  requiredBy: ["auth-service"],
};

// OAUTH_TOKEN: 49 days since rotation, 30-day policy → EXPIRED (19 days overdue)
const anotherExpiredSecret: Secret = {
  name: "OAUTH_TOKEN",
  lastRotated: new Date("2026-03-01T00:00:00Z"),
  rotationPolicyDays: 30,
  requiredBy: ["oauth-service"],
};

// ─── identifySecretStatus ─────────────────────────────────────────────────────
describe("identifySecretStatus", () => {
  test("marks expired secret correctly", () => {
    const result = identifySecretStatus(expiredSecret, REF, 7);
    expect(result.status).toBe("expired");
    expect(result.daysSinceRotation).toBe(100);
    expect(result.daysUntilExpiry).toBe(-10); // negative means overdue
    expect(result.secret).toBe(expiredSecret);
  });

  test("marks warning secret correctly", () => {
    const result = identifySecretStatus(warningSecret, REF, 7);
    expect(result.status).toBe("warning");
    expect(result.daysSinceRotation).toBe(84);
    expect(result.daysUntilExpiry).toBe(6);
  });

  test("marks ok secret correctly", () => {
    const result = identifySecretStatus(okSecret, REF, 7);
    expect(result.status).toBe("ok");
    expect(result.daysSinceRotation).toBe(30);
    expect(result.daysUntilExpiry).toBe(60);
  });

  test("boundary: exactly at expiry (0 days left) is warning", () => {
    const atExpiry: Secret = {
      name: "AT_EXPIRY",
      lastRotated: new Date("2026-01-19T00:00:00Z"), // exactly 90 days before ref
      rotationPolicyDays: 90,
      requiredBy: ["svc"],
    };
    const result = identifySecretStatus(atExpiry, REF, 7);
    expect(result.status).toBe("warning");
    expect(result.daysUntilExpiry).toBe(0);
  });

  test("boundary: exactly at warning threshold is still warning", () => {
    // 7 days left, warningWindow=7 → warning
    const atWindow: Secret = {
      name: "AT_WINDOW",
      lastRotated: new Date("2026-01-13T00:00:00Z"), // 96 days before ref → 90-96 = -6 wait...
      // Let me compute: ref=Apr19, 83 days before = Jan25+1? No.
      // 90-7=83 days since rotation → lastRotated = REF - 83days
      // REF=Apr19. 83 days before:
      // Apr: 19 days → remaining 83-19=64 into March backwards
      // Mar: 31 days → remaining 64-31=33 into Feb backwards
      // Feb: 28 days → remaining 33-28=5 into Jan backwards
      // Jan: 31-5=26 → Jan 26? Let me just use a computed date
      lastRotated: new Date(REF.getTime() - 83 * 86400000),
      rotationPolicyDays: 90,
      requiredBy: ["svc"],
    };
    const result = identifySecretStatus(atWindow, REF, 7);
    expect(result.status).toBe("warning");
    expect(result.daysUntilExpiry).toBe(7);
  });

  test("boundary: 8 days left is ok when window=7", () => {
    const justOk: Secret = {
      name: "JUST_OK",
      lastRotated: new Date(REF.getTime() - 82 * 86400000),
      rotationPolicyDays: 90,
      requiredBy: ["svc"],
    };
    const result = identifySecretStatus(justOk, REF, 7);
    expect(result.status).toBe("ok");
    expect(result.daysUntilExpiry).toBe(8);
  });

  test("configurable warning window: 14 days makes warning-range wider", () => {
    // okSecret has 60 days left → still ok even with 14-day window
    const result = identifySecretStatus(okSecret, REF, 14);
    expect(result.status).toBe("ok");
    // warningSecret has 6 days left → also warning with 14-day window
    const r2 = identifySecretStatus(warningSecret, REF, 14);
    expect(r2.status).toBe("warning");
  });
});

// ─── generateReport ────────────────────────────────────────────────────────────
describe("generateReport", () => {
  const mixedSecrets = [expiredSecret, warningSecret, okSecret, anotherExpiredSecret];
  const config: ValidatorConfig = { warningWindowDays: 7, referenceDate: REF };

  test("groups secrets by status", () => {
    const report = generateReport(mixedSecrets, config);
    expect(report.expired.length).toBe(2);
    expect(report.warning.length).toBe(1);
    expect(report.ok.length).toBe(1);
  });

  test("summary counts match groups", () => {
    const report = generateReport(mixedSecrets, config);
    expect(report.summary.expired).toBe(2);
    expect(report.summary.warning).toBe(1);
    expect(report.summary.ok).toBe(1);
  });

  test("generatedAt is referenceDate when provided", () => {
    const report = generateReport(mixedSecrets, config);
    expect(report.generatedAt).toEqual(REF);
  });

  test("uses current date when referenceDate omitted", () => {
    const before = Date.now();
    const report = generateReport([], { warningWindowDays: 7 });
    const after = Date.now();
    expect(report.generatedAt.getTime()).toBeGreaterThanOrEqual(before);
    expect(report.generatedAt.getTime()).toBeLessThanOrEqual(after);
  });

  test("all-ok scenario: no expired or warning", () => {
    const allOk = [
      { name: "A", lastRotated: new Date(REF.getTime() - 18 * 86400000), rotationPolicyDays: 90, requiredBy: ["s1"] },
      { name: "B", lastRotated: new Date(REF.getTime() - 9 * 86400000), rotationPolicyDays: 90, requiredBy: ["s2"] },
      { name: "C", lastRotated: new Date(REF.getTime() - 4 * 86400000), rotationPolicyDays: 30, requiredBy: ["s3"] },
    ];
    const report = generateReport(allOk, { warningWindowDays: 7, referenceDate: REF });
    expect(report.summary.expired).toBe(0);
    expect(report.summary.warning).toBe(0);
    expect(report.summary.ok).toBe(3);
  });
});

// ─── formatAsMarkdown ─────────────────────────────────────────────────────────
describe("formatAsMarkdown", () => {
  const config: ValidatorConfig = { warningWindowDays: 7, referenceDate: REF };
  const report = generateReport([expiredSecret, warningSecret, okSecret], config);

  test("contains report header", () => {
    const md = formatAsMarkdown(report);
    expect(md).toContain("Secret Rotation Report");
  });

  test("contains section headers with counts", () => {
    const md = formatAsMarkdown(report);
    expect(md).toContain("EXPIRED (1)");
    expect(md).toContain("WARNING (1)");
    expect(md).toContain("OK (1)");
  });

  test("contains secret names", () => {
    const md = formatAsMarkdown(report);
    expect(md).toContain("DB_PASSWORD");
    expect(md).toContain("API_KEY");
    expect(md).toContain("JWT_SECRET");
  });

  test("contains required-by services", () => {
    const md = formatAsMarkdown(report);
    expect(md).toContain("api-service");
    expect(md).toContain("worker-service");
  });

  test("contains markdown table delimiters", () => {
    const md = formatAsMarkdown(report);
    expect(md).toContain("|");
    expect(md).toContain("---");
  });
});

// ─── formatAsJSON ─────────────────────────────────────────────────────────────
describe("formatAsJSON", () => {
  const config: ValidatorConfig = { warningWindowDays: 7, referenceDate: REF };
  const report = generateReport([expiredSecret, warningSecret, okSecret], config);

  test("valid JSON", () => {
    const json = formatAsJSON(report);
    expect(() => JSON.parse(json)).not.toThrow();
  });

  test("summary field present", () => {
    const data = JSON.parse(formatAsJSON(report));
    expect(data.summary).toBeDefined();
    expect(data.summary.expired).toBe(1);
    expect(data.summary.warning).toBe(1);
    expect(data.summary.ok).toBe(1);
  });

  test("expired array contains secret name", () => {
    const data = JSON.parse(formatAsJSON(report));
    expect(data.expired[0].name).toBe("DB_PASSWORD");
  });

  test("generatedAt is ISO date string", () => {
    const data = JSON.parse(formatAsJSON(report));
    expect(data.generatedAt).toMatch(/^\d{4}-\d{2}-\d{2}/);
  });
});
