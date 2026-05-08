// TDD test suite for the secret rotation validator.
// All tests use a fixed "now" so results are deterministic across machines.

import { describe, expect, test } from "bun:test";
import {
  classifySecret,
  generateReport,
  formatJson,
  formatMarkdown,
  parseSecrets,
  type Secret,
  type Urgency,
} from "./validator.ts";

const NOW = new Date("2026-05-08T00:00:00Z");

const sampleSecrets: Secret[] = [
  {
    name: "db-password",
    lastRotated: "2025-01-01",
    rotationDays: 90,
    services: ["api", "worker"],
  },
  {
    name: "api-token",
    lastRotated: "2026-04-01",
    rotationDays: 30,
    services: ["api"],
  },
  {
    name: "stripe-key",
    lastRotated: "2026-05-01",
    rotationDays: 90,
    services: ["billing"],
  },
];

describe("classifySecret", () => {
  test("expired when past rotation deadline", () => {
    const result = classifySecret(sampleSecrets[0]!, NOW, 7);
    expect(result.urgency).toBe<Urgency>("expired");
    expect(result.daysUntilDue).toBeLessThan(0);
  });

  test("warning when due within window", () => {
    // last rotated 2026-04-01, 30 day policy => due 2026-05-01, already 7 days past => expired
    // Use a custom secret to test warning bucket precisely.
    const s: Secret = {
      name: "warn-key",
      lastRotated: "2026-04-15",
      rotationDays: 30,
      services: ["x"],
    };
    // due: 2026-05-15, now is 2026-05-08 => 7 days remaining, warning window 7 => warning
    const result = classifySecret(s, NOW, 7);
    expect(result.urgency).toBe<Urgency>("warning");
    expect(result.daysUntilDue).toBe(7);
  });

  test("ok when far from expiry", () => {
    const result = classifySecret(sampleSecrets[2]!, NOW, 7);
    expect(result.urgency).toBe<Urgency>("ok");
  });
});

describe("parseSecrets", () => {
  test("parses valid JSON config", () => {
    const json = JSON.stringify({ secrets: sampleSecrets });
    expect(parseSecrets(json)).toEqual(sampleSecrets);
  });

  test("throws helpful error on bad JSON", () => {
    expect(() => parseSecrets("{not json")).toThrow(/parse/i);
  });

  test("throws when a secret is missing required fields", () => {
    const bad = JSON.stringify({ secrets: [{ name: "x" }] });
    expect(() => parseSecrets(bad)).toThrow(/lastRotated|rotationDays/);
  });
});

describe("generateReport", () => {
  test("groups by urgency and counts", () => {
    const report = generateReport(sampleSecrets, NOW, 7);
    // db-password is most overdue, api-token also expired (due 2026-05-01).
    expect(report.expired.map((r) => r.secret.name)).toEqual([
      "db-password",
      "api-token",
    ]);
    expect(report.ok.map((r) => r.secret.name)).toEqual(["stripe-key"]);
    expect(report.summary.total).toBe(3);
    expect(report.summary.expired).toBe(2);
  });
});

describe("formatJson", () => {
  test("emits stable JSON with summary", () => {
    const report = generateReport(sampleSecrets, NOW, 7);
    const out = formatJson(report);
    const parsed = JSON.parse(out);
    expect(parsed.summary.total).toBe(3);
    expect(Array.isArray(parsed.expired)).toBe(true);
  });
});

describe("formatMarkdown", () => {
  test("renders an expired section with a markdown table", () => {
    const report = generateReport(sampleSecrets, NOW, 7);
    const md = formatMarkdown(report);
    expect(md).toContain("# Secret Rotation Report");
    expect(md).toContain("## Expired");
    expect(md).toContain("| Secret | Last Rotated | Days Overdue | Services |");
    expect(md).toContain("db-password");
  });

  test("includes ok section even when empty list says none", () => {
    const onlyOk: Secret[] = [sampleSecrets[2]!];
    const report = generateReport(onlyOk, NOW, 7);
    const md = formatMarkdown(report);
    expect(md).toContain("## OK");
    expect(md).toContain("stripe-key");
  });
});
