// Red-step TDD: rendering reports as markdown and JSON.

import { describe, expect, test } from "bun:test";
import { classifySecrets, type Secret } from "../src/classify.ts";
import { formatJson, formatMarkdown } from "../src/format.ts";

const NOW = new Date("2026-05-07T00:00:00Z");

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

describe("formatMarkdown", () => {
  test("emits a section per urgency bucket with required-by services", () => {
    const report = classifySecrets(fixture, { warningWindowDays: 14, now: NOW });
    const md = formatMarkdown(report);

    expect(md).toContain("# Secret Rotation Report");
    expect(md).toContain("Warning window: 14 days");
    expect(md).toContain("**Expired:** 1");
    expect(md).toContain("**Warning:** 1");
    expect(md).toContain("**OK:** 1");

    // Markdown table header for expired section
    expect(md).toContain("## Expired (1)");
    expect(md).toContain("| Secret | Last Rotated | Days Overdue | Required By |");
    expect(md).toContain("| stripe_api_key | 2025-10-01 | 128 | billing-svc, checkout-svc |");

    expect(md).toContain("## Warning (1)");
    expect(md).toContain("| Secret | Last Rotated | Days Until Expiry | Required By |");
    expect(md).toContain("| datadog_api_key | 2026-02-20 | 14 | observability |");

    expect(md).toContain("## OK (1)");
    // sendgrid rotated 2026-04-15, policy 60 days -> expires 2026-06-14 -> 38 days remaining.
    expect(md).toContain("| sendgrid_api_key | 2026-04-15 | 38 | notifications |");
  });

  test("renders an empty-state line when a bucket has no entries", () => {
    const allOk: Secret[] = [
      { name: "fresh", lastRotated: "2026-05-01", rotationPolicyDays: 365, requiredBy: ["svc"] },
    ];
    const md = formatMarkdown(
      classifySecrets(allOk, { warningWindowDays: 7, now: NOW }),
    );
    expect(md).toContain("## Expired (0)\n\n_No secrets in this bucket._");
    expect(md).toContain("## Warning (0)\n\n_No secrets in this bucket._");
    expect(md).toContain("## OK (1)");
  });
});

describe("formatJson", () => {
  test("produces stable, parseable JSON containing totals and groups", () => {
    const report = classifySecrets(fixture, { warningWindowDays: 14, now: NOW });
    const json = formatJson(report);
    const parsed = JSON.parse(json);

    expect(parsed.totals).toEqual({ expired: 1, warning: 1, ok: 1 });
    expect(parsed.warningWindowDays).toBe(14);
    expect(parsed.expired[0].name).toBe("stripe_api_key");
    expect(parsed.expired[0].status).toBe("expired");
    expect(parsed.expired[0].daysUntilExpiry).toBe(-128);
    expect(parsed.warning[0].name).toBe("datadog_api_key");
    expect(parsed.ok[0].name).toBe("sendgrid_api_key");

    // Pretty-printed (newlines + indentation) so it diffs cleanly in CI.
    expect(json).toContain("\n");
    expect(json).toContain('  "totals"');
  });
});
