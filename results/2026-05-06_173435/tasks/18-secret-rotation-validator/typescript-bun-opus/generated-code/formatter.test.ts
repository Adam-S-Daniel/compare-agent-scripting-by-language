import { describe, test, expect } from "bun:test";
import { formatJson, formatMarkdown } from "./formatter";
import { generateReport } from "./validator";
import type { ValidationConfig, RotationReport } from "./types";

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

describe("formatJson", () => {
  test("produces valid JSON with correct structure", () => {
    const report = generateReport(config);
    const json = formatJson(report);
    const parsed = JSON.parse(json);
    expect(parsed.generatedAt).toBe("2026-05-07");
    expect(parsed.warningWindowDays).toBe(14);
    expect(parsed.summary.total).toBe(4);
    expect(parsed.summary.expired).toBe(1);
    expect(parsed.summary.warning).toBe(1);
    expect(parsed.summary.ok).toBe(2);
  });

  test("JSON contains all secret details", () => {
    const report = generateReport(config);
    const parsed = JSON.parse(formatJson(report));
    const db = parsed.secrets.find((s: any) => s.name === "DB_PASSWORD");
    expect(db.urgency).toBe("expired");
    expect(db.daysSinceRotation).toBe(843);
    expect(db.daysUntilExpiry).toBe(-753);
    expect(db.expiryDate).toBe("2024-04-14");
    expect(db.requiredBy).toEqual(["api-server", "worker"]);
  });

  test("JSON is pretty-printed", () => {
    const report = generateReport(config);
    const json = formatJson(report);
    expect(json).toContain("\n");
    expect(json).toContain("  ");
  });
});

describe("formatMarkdown", () => {
  test("includes report title and metadata", () => {
    const report = generateReport(config);
    const md = formatMarkdown(report);
    expect(md).toContain("# Secret Rotation Report");
    expect(md).toContain("Generated: 2026-05-07 | Warning Window: 14 days");
  });

  test("includes summary table with correct counts", () => {
    const report = generateReport(config);
    const md = formatMarkdown(report);
    expect(md).toContain("| Expired | 1 |");
    expect(md).toContain("| Warning | 1 |");
    expect(md).toContain("| OK | 2 |");
    expect(md).toContain("| **Total** | **4** |");
  });

  test("includes expired section with days overdue", () => {
    const report = generateReport(config);
    const md = formatMarkdown(report);
    expect(md).toContain("## Expired");
    expect(md).toContain("| DB_PASSWORD | 2024-01-15 | 90 | 2024-04-14 | 753 | api-server, worker |");
  });

  test("includes warning section with days until expiry", () => {
    const report = generateReport(config);
    const md = formatMarkdown(report);
    expect(md).toContain("## Warning");
    expect(md).toContain("| JWT_SECRET | 2026-04-20 | 30 | 2026-05-20 | 13 | auth-service |");
  });

  test("includes OK section", () => {
    const report = generateReport(config);
    const md = formatMarkdown(report);
    expect(md).toContain("## OK");
    expect(md).toContain("| API_KEY | 2025-12-01 | 365 | 2026-12-01 | 208 | frontend |");
    expect(md).toContain("| SLACK_WEBHOOK | 2026-05-01 | 180 | 2026-10-28 | 174 | notification-service |");
  });

  test("omits empty urgency sections", () => {
    const report = generateReport({
      secrets: [{ name: "FRESH", lastRotated: "2026-05-06", rotationPolicyDays: 365, requiredBy: ["svc"] }],
      warningWindowDays: 14,
      referenceDate: "2026-05-07",
    });
    const md = formatMarkdown(report);
    expect(md).not.toContain("## Expired");
    expect(md).not.toContain("## Warning");
    expect(md).toContain("## OK");
  });

  test("handles empty secrets array", () => {
    const report = generateReport({ secrets: [], warningWindowDays: 14, referenceDate: "2026-05-07" });
    const md = formatMarkdown(report);
    expect(md).toContain("# Secret Rotation Report");
    expect(md).toContain("| **Total** | **0** |");
    expect(md).not.toContain("## Expired");
    expect(md).not.toContain("## Warning");
    expect(md).not.toContain("## OK");
  });
});
