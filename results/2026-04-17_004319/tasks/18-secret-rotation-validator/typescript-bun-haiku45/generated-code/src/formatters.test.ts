import { describe, it, expect } from "bun:test";
import { Secret, RotationReport } from "./types";
import { formatMarkdown, formatJSON } from "./formatters";

describe("Output formatters", () => {
  const report: RotationReport = {
    generated: new Date("2026-04-19"),
    summary: {
      expired: 1,
      warning: 1,
      ok: 1,
    },
    secrets: [
      {
        secret: {
          name: "db-password",
          lastRotated: new Date("2026-01-01"),
          rotationPolicyDays: 30,
          requiredByServices: ["api", "worker"],
        },
        status: "expired",
        daysUntilExpiration: -78,
        expirationDate: new Date("2026-01-31"),
      },
      {
        secret: {
          name: "api-key",
          lastRotated: new Date("2026-03-25"),
          rotationPolicyDays: 30,
          requiredByServices: ["external-service"],
        },
        status: "warning",
        daysUntilExpiration: 5,
        expirationDate: new Date("2026-04-24"),
      },
      {
        secret: {
          name: "jwt-secret",
          lastRotated: new Date("2026-02-15"),
          rotationPolicyDays: 90,
          requiredByServices: ["auth-server"],
        },
        status: "ok",
        daysUntilExpiration: 26,
        expirationDate: new Date("2026-05-16"),
      },
    ],
  };

  it("should format report as markdown table", () => {
    const markdown = formatMarkdown(report);

    expect(markdown).toContain("Secret Rotation Report");
    expect(markdown).toContain("db-password");
    expect(markdown).toContain("expired");
    expect(markdown).toContain("api-key");
    expect(markdown).toContain("warning");
    expect(markdown).toContain("jwt-secret");
    expect(markdown).toContain("ok");
  });

  it("should include summary in markdown", () => {
    const markdown = formatMarkdown(report);
    expect(markdown).toContain("Summary");
    expect(markdown).toContain("Expired: 1");
    expect(markdown).toContain("Warning: 1");
    expect(markdown).toContain("OK: 1");
  });

  it("should format report as JSON", () => {
    const json = formatJSON(report);
    const parsed = JSON.parse(json);

    expect(parsed.summary).toEqual({
      expired: 1,
      warning: 1,
      ok: 1,
    });
    expect(parsed.secrets).toHaveLength(3);
    expect(parsed.secrets[0].secret.name).toBe("db-password");
    expect(parsed.secrets[0].status).toBe("expired");
  });

  it("should include generation timestamp in JSON", () => {
    const json = formatJSON(report);
    const parsed = JSON.parse(json);
    expect(parsed.generated).toBeDefined();
  });
});
