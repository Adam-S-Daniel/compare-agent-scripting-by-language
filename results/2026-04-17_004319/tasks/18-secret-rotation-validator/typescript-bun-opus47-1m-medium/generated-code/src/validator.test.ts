// Unit tests for the secret rotation validator.
// Red/green TDD: each test was written failing first, then made to pass.
import { describe, expect, test } from "bun:test";
import {
  classify,
  generateReport,
  formatMarkdown,
  formatJson,
  loadConfig,
  type Secret,
} from "./validator";

const REF_NOW = new Date("2026-04-17T00:00:00Z");

describe("classify", () => {
  test("returns 'expired' when age exceeds rotation policy", () => {
    const s: Secret = {
      name: "db-prod",
      lastRotated: "2025-01-01",
      rotationPolicyDays: 90,
      requiredBy: ["api"],
    };
    expect(classify(s, REF_NOW, 7).status).toBe("expired");
  });

  test("returns 'warning' when within configurable warning window", () => {
    // last rotated 85 days ago, policy 90d, warning 7d -> 5 days until expiry -> warning
    const lastRotated = new Date(REF_NOW);
    lastRotated.setUTCDate(lastRotated.getUTCDate() - 85);
    const s: Secret = {
      name: "api-key",
      lastRotated: lastRotated.toISOString().slice(0, 10),
      rotationPolicyDays: 90,
      requiredBy: ["ingest"],
    };
    expect(classify(s, REF_NOW, 7).status).toBe("warning");
  });

  test("returns 'ok' when comfortably within policy", () => {
    const s: Secret = {
      name: "fresh",
      lastRotated: "2026-04-10",
      rotationPolicyDays: 90,
      requiredBy: ["svc"],
    };
    expect(classify(s, REF_NOW, 7).status).toBe("ok");
  });

  test("boundary: exactly at rotation policy counts as expired", () => {
    const lastRotated = new Date(REF_NOW);
    lastRotated.setUTCDate(lastRotated.getUTCDate() - 90);
    const s: Secret = {
      name: "boundary",
      lastRotated: lastRotated.toISOString().slice(0, 10),
      rotationPolicyDays: 90,
      requiredBy: ["x"],
    };
    expect(classify(s, REF_NOW, 7).status).toBe("expired");
  });
});

describe("generateReport", () => {
  const secrets: Secret[] = [
    { name: "old", lastRotated: "2020-01-01", rotationPolicyDays: 90, requiredBy: ["a"] },
    { name: "soon", lastRotated: subtract(REF_NOW, 85), rotationPolicyDays: 90, requiredBy: ["b"] },
    { name: "ok", lastRotated: "2026-04-16", rotationPolicyDays: 90, requiredBy: ["c"] },
  ];

  test("groups secrets by urgency bucket", () => {
    const r = generateReport(secrets, REF_NOW, 7);
    expect(r.expired.map((e) => e.name)).toEqual(["old"]);
    expect(r.warning.map((e) => e.name)).toEqual(["soon"]);
    expect(r.ok.map((e) => e.name)).toEqual(["ok"]);
  });

  test("sorts expired by most overdue first", () => {
    const s = [
      { name: "a", lastRotated: "2020-01-01", rotationPolicyDays: 30, requiredBy: [] },
      { name: "b", lastRotated: "2010-01-01", rotationPolicyDays: 30, requiredBy: [] },
    ];
    const r = generateReport(s, REF_NOW, 7);
    expect(r.expired.map((e) => e.name)).toEqual(["b", "a"]);
  });
});

describe("formatJson", () => {
  test("emits valid JSON with all three buckets and counts", () => {
    const r = generateReport(
      [{ name: "old", lastRotated: "2020-01-01", rotationPolicyDays: 90, requiredBy: ["a"] }],
      REF_NOW,
      7,
    );
    const out = formatJson(r);
    const parsed = JSON.parse(out);
    expect(parsed.counts).toEqual({ expired: 1, warning: 0, ok: 0 });
    expect(parsed.expired[0].name).toBe("old");
  });
});

describe("formatMarkdown", () => {
  test("renders grouped tables with headers per urgency", () => {
    const r = generateReport(
      [
        { name: "old", lastRotated: "2020-01-01", rotationPolicyDays: 90, requiredBy: ["api"] },
        { name: "ok", lastRotated: "2026-04-16", rotationPolicyDays: 90, requiredBy: ["svc"] },
      ],
      REF_NOW,
      7,
    );
    const md = formatMarkdown(r);
    expect(md).toContain("# Secret Rotation Report");
    expect(md).toContain("## Expired (1)");
    expect(md).toContain("## Warning (0)");
    expect(md).toContain("## OK (1)");
    expect(md).toContain("| old |");
    expect(md).toContain("| ok |");
  });
});

describe("loadConfig", () => {
  test("rejects config with missing required fields", () => {
    expect(() => loadConfig(JSON.stringify([{ name: "x" }]))).toThrow(/lastRotated/);
  });

  test("rejects non-array root", () => {
    expect(() => loadConfig(JSON.stringify({}))).toThrow(/array/);
  });

  test("accepts a valid config", () => {
    const json = JSON.stringify([
      { name: "x", lastRotated: "2026-01-01", rotationPolicyDays: 30, requiredBy: ["svc"] },
    ]);
    const out = loadConfig(json);
    expect(out[0].name).toBe("x");
  });
});

function subtract(from: Date, days: number): string {
  const d = new Date(from);
  d.setUTCDate(d.getUTCDate() - days);
  return d.toISOString().slice(0, 10);
}
