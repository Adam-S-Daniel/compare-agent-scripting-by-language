// Tests for the secret rotation validator.
// Red/green TDD: these are written before the implementation is complete.
import { describe, test, expect } from "bun:test";
import {
  classifySecret,
  validateSecrets,
  type Secret,
} from "../src/validator.ts";
import { renderJson, renderMarkdown } from "../src/report.ts";

const NOW = new Date("2026-04-20T00:00:00Z");

function daysAgo(n: number): string {
  const d = new Date(NOW.getTime() - n * 86400 * 1000);
  return d.toISOString().slice(0, 10);
}

describe("classifySecret", () => {
  test("ok when rotated recently within policy", () => {
    const s: Secret = {
      name: "API_KEY",
      lastRotated: daysAgo(10),
      rotationPolicyDays: 90,
      requiredBy: ["web"],
    };
    const r = classifySecret(s, NOW, 14);
    expect(r.status).toBe("ok");
    expect(r.daysUntilDue).toBe(80);
  });

  test("warning when inside the warning window", () => {
    const s: Secret = {
      name: "DB_PASS",
      lastRotated: daysAgo(80),
      rotationPolicyDays: 90,
      requiredBy: ["api"],
    };
    const r = classifySecret(s, NOW, 14);
    expect(r.status).toBe("warning");
    expect(r.daysUntilDue).toBe(10);
  });

  test("expired when past rotation deadline", () => {
    const s: Secret = {
      name: "OLD",
      lastRotated: daysAgo(120),
      rotationPolicyDays: 90,
      requiredBy: ["batch"],
    };
    const r = classifySecret(s, NOW, 14);
    expect(r.status).toBe("expired");
    expect(r.daysUntilDue).toBe(-30);
  });

  test("throws on invalid lastRotated date", () => {
    const bad = {
      name: "BAD",
      lastRotated: "not-a-date",
      rotationPolicyDays: 30,
      requiredBy: [],
    } as Secret;
    expect(() => classifySecret(bad, NOW, 7)).toThrow(/invalid date/i);
  });

  test("throws on non-positive rotation policy", () => {
    const bad: Secret = {
      name: "BAD",
      lastRotated: daysAgo(1),
      rotationPolicyDays: 0,
      requiredBy: [],
    };
    expect(() => classifySecret(bad, NOW, 7)).toThrow(/rotationPolicyDays/);
  });
});

describe("validateSecrets", () => {
  const secrets: Secret[] = [
    { name: "A", lastRotated: daysAgo(5), rotationPolicyDays: 90, requiredBy: ["web"] },
    { name: "B", lastRotated: daysAgo(85), rotationPolicyDays: 90, requiredBy: ["api"] },
    { name: "C", lastRotated: daysAgo(200), rotationPolicyDays: 90, requiredBy: ["batch"] },
  ];

  test("groups secrets by urgency", () => {
    const report = validateSecrets(secrets, { now: NOW, warningDays: 14 });
    expect(report.expired.map((s) => s.name)).toEqual(["C"]);
    expect(report.warning.map((s) => s.name)).toEqual(["B"]);
    expect(report.ok.map((s) => s.name)).toEqual(["A"]);
    expect(report.summary.total).toBe(3);
    expect(report.summary.expired).toBe(1);
  });

  test("expired sorted most-overdue first", () => {
    const input: Secret[] = [
      { name: "mild", lastRotated: daysAgo(95), rotationPolicyDays: 90, requiredBy: [] },
      { name: "severe", lastRotated: daysAgo(300), rotationPolicyDays: 90, requiredBy: [] },
    ];
    const report = validateSecrets(input, { now: NOW, warningDays: 7 });
    expect(report.expired.map((s) => s.name)).toEqual(["severe", "mild"]);
  });
});

describe("renderJson", () => {
  test("produces stable JSON containing grouped results and summary", () => {
    const report = validateSecrets(
      [
        { name: "A", lastRotated: daysAgo(5), rotationPolicyDays: 30, requiredBy: ["x"] },
      ],
      { now: NOW, warningDays: 7 },
    );
    const out = renderJson(report);
    const parsed = JSON.parse(out);
    expect(parsed.summary.total).toBe(1);
    expect(parsed.ok[0].name).toBe("A");
    expect(parsed.ok[0].status).toBe("ok");
  });
});

describe("renderMarkdown", () => {
  test("emits markdown table with grouping headers", () => {
    const report = validateSecrets(
      [
        { name: "A", lastRotated: daysAgo(5), rotationPolicyDays: 90, requiredBy: ["web"] },
        { name: "B", lastRotated: daysAgo(85), rotationPolicyDays: 90, requiredBy: ["api"] },
        { name: "C", lastRotated: daysAgo(200), rotationPolicyDays: 90, requiredBy: ["batch"] },
      ],
      { now: NOW, warningDays: 14 },
    );
    const md = renderMarkdown(report);
    expect(md).toContain("# Secret Rotation Report");
    expect(md).toContain("## Expired");
    expect(md).toContain("## Warning");
    expect(md).toContain("## OK");
    expect(md).toContain("| Name | Last Rotated | Policy (days) | Days Until Due | Required By |");
    expect(md).toContain("| C |");
    expect(md).toContain("| B |");
    expect(md).toContain("| A |");
    // summary line
    expect(md).toMatch(/Total:\s*3/);
    expect(md).toMatch(/Expired:\s*1/);
  });

  test("shows empty-section placeholder when nothing is expired", () => {
    const report = validateSecrets(
      [{ name: "A", lastRotated: daysAgo(1), rotationPolicyDays: 30, requiredBy: [] }],
      { now: NOW, warningDays: 7 },
    );
    const md = renderMarkdown(report);
    expect(md).toContain("## Expired");
    expect(md).toContain("_none_");
  });
});
