// Unit tests for validator core logic. Drives implementation TDD-style:
// classify -> generate report -> markdown/JSON formatting.
import { describe, expect, test } from "bun:test";
import {
  classifySecret,
  generateReport,
  formatMarkdown,
  formatJson,
  type Secret,
  type Report,
} from "./validator";

const NOW = new Date("2026-05-07T00:00:00Z");

const makeSecret = (overrides: Partial<Secret> = {}): Secret => ({
  name: "db-password",
  lastRotated: "2026-04-01",
  rotationPolicyDays: 30,
  requiredBy: ["api"],
  ...overrides,
});

describe("classifySecret", () => {
  test("returns 'expired' when secret age exceeds policy", () => {
    const s = makeSecret({ lastRotated: "2026-03-01", rotationPolicyDays: 30 });
    expect(classifySecret(s, NOW, 7).status).toBe("expired");
  });

  test("returns 'warning' when within warning window", () => {
    const s = makeSecret({ lastRotated: "2026-04-15", rotationPolicyDays: 30 });
    // age=22, due in 8 days -> within 14d warning window
    expect(classifySecret(s, NOW, 14).status).toBe("warning");
  });

  test("returns 'ok' when far from expiry", () => {
    const s = makeSecret({ lastRotated: "2026-05-01", rotationPolicyDays: 90 });
    expect(classifySecret(s, NOW, 7).status).toBe("ok");
  });

  test("computes daysUntilDue correctly (negative when expired)", () => {
    const s = makeSecret({ lastRotated: "2026-04-01", rotationPolicyDays: 30 });
    // age = 36 days, due was 6 days ago
    expect(classifySecret(s, NOW, 7).daysUntilDue).toBe(-6);
  });

  test("throws on invalid date", () => {
    const s = makeSecret({ lastRotated: "not-a-date" });
    expect(() => classifySecret(s, NOW, 7)).toThrow(/invalid lastRotated/i);
  });

  test("throws on non-positive rotation policy", () => {
    const s = makeSecret({ rotationPolicyDays: 0 });
    expect(() => classifySecret(s, NOW, 7)).toThrow(/rotationPolicyDays/);
  });
});

describe("generateReport", () => {
  test("groups secrets by urgency", () => {
    const secrets: Secret[] = [
      makeSecret({ name: "a", lastRotated: "2026-01-01", rotationPolicyDays: 30 }),
      makeSecret({ name: "b", lastRotated: "2026-04-15", rotationPolicyDays: 30 }),
      makeSecret({ name: "c", lastRotated: "2026-05-01", rotationPolicyDays: 365 }),
    ];
    const r: Report = generateReport(secrets, { now: NOW, warningDays: 14 });
    expect(r.expired.map((s) => s.name)).toEqual(["a"]);
    expect(r.warning.map((s) => s.name)).toEqual(["b"]);
    expect(r.ok.map((s) => s.name)).toEqual(["c"]);
    expect(r.summary).toEqual({ expired: 1, warning: 1, ok: 1, total: 3 });
  });

  test("sorts each group by daysUntilDue ascending (most urgent first)", () => {
    const secrets: Secret[] = [
      makeSecret({ name: "old", lastRotated: "2026-01-01", rotationPolicyDays: 30 }),
      makeSecret({ name: "older", lastRotated: "2025-01-01", rotationPolicyDays: 30 }),
    ];
    const r = generateReport(secrets, { now: NOW, warningDays: 0 });
    expect(r.expired.map((s) => s.name)).toEqual(["older", "old"]);
  });
});

describe("formatJson", () => {
  test("emits stable JSON shape with summary + groups", () => {
    const r = generateReport(
      [makeSecret({ name: "a", lastRotated: "2026-05-01", rotationPolicyDays: 90 })],
      { now: NOW, warningDays: 7 },
    );
    const obj = JSON.parse(formatJson(r));
    expect(obj.summary.total).toBe(1);
    expect(obj.ok[0].name).toBe("a");
    expect(obj.ok[0].status).toBe("ok");
  });
});

describe("formatMarkdown", () => {
  test("renders a section per urgency with table headers", () => {
    const r = generateReport(
      [
        makeSecret({ name: "a", lastRotated: "2026-01-01", rotationPolicyDays: 30 }),
        makeSecret({ name: "b", lastRotated: "2026-05-01", rotationPolicyDays: 90 }),
      ],
      { now: NOW, warningDays: 7 },
    );
    const md = formatMarkdown(r);
    expect(md).toContain("# Secret Rotation Report");
    expect(md).toContain("## Expired (1)");
    expect(md).toContain("## OK (1)");
    expect(md).toContain("| Name | Last Rotated | Policy (days) | Days Until Due | Required By |");
    expect(md).toContain("| a |");
    expect(md).toContain("| b |");
  });

  test("shows 'none' when a group is empty", () => {
    const r = generateReport([], { now: NOW, warningDays: 7 });
    const md = formatMarkdown(r);
    expect(md).toMatch(/## Expired \(0\)\s+_none_/);
  });
});
