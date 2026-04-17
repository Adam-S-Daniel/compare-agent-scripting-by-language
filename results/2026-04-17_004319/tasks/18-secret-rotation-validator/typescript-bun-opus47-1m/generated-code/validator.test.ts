// Unit tests for the secret rotation validator.
// Approach: small, incremental red/green steps. Each describe block
// corresponds to one unit of behaviour implemented in validator.ts.

import { describe, expect, test } from "bun:test";
import {
  classifySecret,
  validateSecrets,
  renderJson,
  renderMarkdown,
  parseConfig,
  type Secret,
  type SecretStatus,
  type ValidationReport,
} from "./validator.ts";

const REF = new Date("2026-04-17T00:00:00Z");

describe("classifySecret", () => {
  test("returns 'ok' when secret is well within its rotation window", () => {
    const secret: Secret = {
      name: "db-password",
      lastRotated: "2026-04-10",
      rotationDays: 90,
      requiredBy: ["api"],
    };
    const result = classifySecret(secret, REF, 14);
    expect(result.status).toBe<SecretStatus>("ok");
    expect(result.daysUntilRotation).toBe(83);
  });

  test("returns 'warning' when inside warning window but not yet expired", () => {
    const secret: Secret = {
      name: "stripe-key",
      lastRotated: "2026-01-20",
      rotationDays: 90,
      requiredBy: ["billing"],
    };
    // 2026-01-20 + 90 days = 2026-04-20; 3 days away with REF = 2026-04-17.
    const result = classifySecret(secret, REF, 14);
    expect(result.status).toBe<SecretStatus>("warning");
    expect(result.daysUntilRotation).toBe(3);
  });

  test("returns 'expired' when past rotation deadline", () => {
    const secret: Secret = {
      name: "legacy-token",
      lastRotated: "2025-11-01",
      rotationDays: 90,
      requiredBy: ["cron"],
    };
    const result = classifySecret(secret, REF, 14);
    expect(result.status).toBe<SecretStatus>("expired");
    // 2025-11-01 + 90d = 2026-01-30, so 77 days overdue.
    expect(result.daysUntilRotation).toBe(-77);
  });

  test("treats exactly 0 days remaining as warning (boundary)", () => {
    const secret: Secret = {
      name: "expiring-today",
      lastRotated: "2026-01-17",
      rotationDays: 90,
      requiredBy: ["app"],
    };
    const result = classifySecret(secret, REF, 14);
    expect(result.status).toBe<SecretStatus>("warning");
    expect(result.daysUntilRotation).toBe(0);
  });
});

describe("validateSecrets", () => {
  const secrets: Secret[] = [
    {
      name: "expired-key",
      lastRotated: "2025-10-01",
      rotationDays: 60,
      requiredBy: ["svc-a"],
    },
    {
      name: "warn-key",
      lastRotated: "2026-01-20",
      rotationDays: 90,
      requiredBy: ["svc-b"],
    },
    {
      name: "ok-key",
      lastRotated: "2026-04-10",
      rotationDays: 90,
      requiredBy: ["svc-c"],
    },
  ];

  test("groups secrets by urgency bucket", () => {
    const report = validateSecrets(secrets, { referenceDate: REF, warningDays: 14 });
    expect(report.expired.map((c) => c.secret.name)).toEqual(["expired-key"]);
    expect(report.warning.map((c) => c.secret.name)).toEqual(["warn-key"]);
    expect(report.ok.map((c) => c.secret.name)).toEqual(["ok-key"]);
  });

  test("sorts expired most-overdue-first and warning soonest-first", () => {
    const many: Secret[] = [
      { name: "a", lastRotated: "2026-01-17", rotationDays: 90, requiredBy: [] }, // 0d
      { name: "b", lastRotated: "2026-01-23", rotationDays: 90, requiredBy: [] }, // 6d
      { name: "c", lastRotated: "2025-10-01", rotationDays: 60, requiredBy: [] }, // very overdue
      { name: "d", lastRotated: "2025-11-01", rotationDays: 60, requiredBy: [] }, // less overdue
    ];
    const report = validateSecrets(many, { referenceDate: REF, warningDays: 14 });
    expect(report.expired.map((c) => c.secret.name)).toEqual(["c", "d"]);
    expect(report.warning.map((c) => c.secret.name)).toEqual(["a", "b"]);
  });

  test("records summary counts", () => {
    const report = validateSecrets(secrets, { referenceDate: REF, warningDays: 14 });
    expect(report.summary).toEqual({ expired: 1, warning: 1, ok: 1, total: 3 });
  });
});

describe("parseConfig", () => {
  test("parses a valid config object", () => {
    const config = parseConfig({
      secrets: [
        {
          name: "k1",
          lastRotated: "2026-04-10",
          rotationDays: 90,
          requiredBy: ["api"],
        },
      ],
    });
    expect(config).toHaveLength(1);
    expect(config[0]!.name).toBe("k1");
  });

  test("throws a helpful error when required fields are missing", () => {
    expect(() => parseConfig({ secrets: [{ name: "bad" }] })).toThrow(
      /lastRotated/,
    );
  });

  test("throws when rotationDays is not a positive integer", () => {
    expect(() =>
      parseConfig({
        secrets: [
          {
            name: "bad",
            lastRotated: "2026-01-01",
            rotationDays: 0,
            requiredBy: [],
          },
        ],
      }),
    ).toThrow(/rotationDays/);
  });

  test("throws when lastRotated is not a valid date", () => {
    expect(() =>
      parseConfig({
        secrets: [
          {
            name: "bad",
            lastRotated: "not-a-date",
            rotationDays: 30,
            requiredBy: [],
          },
        ],
      }),
    ).toThrow(/lastRotated/);
  });

  test("throws when secrets is not an array", () => {
    expect(() => parseConfig({ secrets: "nope" })).toThrow(/array/i);
  });
});

describe("renderJson", () => {
  test("produces a stable JSON string with summary + buckets", () => {
    const report: ValidationReport = {
      expired: [
        {
          secret: {
            name: "expired-key",
            lastRotated: "2025-10-01",
            rotationDays: 60,
            requiredBy: ["svc-a"],
          },
          status: "expired",
          daysUntilRotation: -138,
          dueDate: "2025-11-30",
        },
      ],
      warning: [],
      ok: [],
      summary: { expired: 1, warning: 0, ok: 0, total: 1 },
    };
    const json = renderJson(report);
    const parsed = JSON.parse(json);
    expect(parsed.summary.expired).toBe(1);
    expect(parsed.expired[0].secret.name).toBe("expired-key");
    expect(parsed.expired[0].status).toBe("expired");
  });
});

describe("renderMarkdown", () => {
  const report: ValidationReport = {
    expired: [
      {
        secret: {
          name: "expired-key",
          lastRotated: "2025-10-01",
          rotationDays: 60,
          requiredBy: ["svc-a"],
        },
        status: "expired",
        daysUntilRotation: -138,
        dueDate: "2025-11-30",
      },
    ],
    warning: [
      {
        secret: {
          name: "warn-key",
          lastRotated: "2026-01-20",
          rotationDays: 90,
          requiredBy: ["svc-b", "svc-c"],
        },
        status: "warning",
        daysUntilRotation: 3,
        dueDate: "2026-04-20",
      },
    ],
    ok: [
      {
        secret: {
          name: "ok-key",
          lastRotated: "2026-04-10",
          rotationDays: 90,
          requiredBy: ["svc-d"],
        },
        status: "ok",
        daysUntilRotation: 83,
        dueDate: "2026-07-09",
      },
    ],
    summary: { expired: 1, warning: 1, ok: 1, total: 3 },
  };

  test("includes a summary line", () => {
    const md = renderMarkdown(report);
    expect(md).toContain("# Secret Rotation Report");
    expect(md).toMatch(/Expired:\s*1/);
    expect(md).toMatch(/Warning:\s*1/);
    expect(md).toMatch(/OK:\s*1/);
    expect(md).toMatch(/Total:\s*3/);
  });

  test("renders one markdown table per urgency group with expected columns", () => {
    const md = renderMarkdown(report);
    expect(md).toContain("## Expired");
    expect(md).toContain("## Warning");
    expect(md).toContain("## OK");
    // Header and separator line for a markdown table.
    expect(md).toContain("| Name | Last Rotated | Due Date | Days | Required By |");
    expect(md).toContain("|---|---|---|---|---|");
    expect(md).toContain("| expired-key | 2025-10-01 | 2025-11-30 | -138 | svc-a |");
    expect(md).toContain("| warn-key | 2026-01-20 | 2026-04-20 | 3 | svc-b, svc-c |");
  });

  test("renders an explicit '(none)' marker for empty groups", () => {
    const empty: ValidationReport = {
      expired: [],
      warning: [],
      ok: [],
      summary: { expired: 0, warning: 0, ok: 0, total: 0 },
    };
    const md = renderMarkdown(empty);
    expect(md).toContain("_(none)_");
  });
});
