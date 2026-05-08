import { describe, it, expect, beforeAll, afterAll } from "bun:test";
import * as fs from "fs";
import * as path from "path";
import { spawnSync } from "bun";

// Test fixtures for CLI testing
const testDir = ".test-fixtures";

describe("CLI", () => {
  beforeAll(() => {
    if (fs.existsSync(testDir)) {
      fs.rmSync(testDir, { recursive: true, force: true });
    }
    fs.mkdirSync(testDir, { recursive: true });
  });

  afterAll(() => {
    if (fs.existsSync(testDir)) {
      fs.rmSync(testDir, { recursive: true, force: true });
    }
  });

  it("should read secrets from a JSON configuration file and output markdown", () => {
    const configPath = path.join(testDir, "config.json");
    const config = {
      secrets: [
        {
          name: "db-password",
          lastRotated: "2026-03-22",
          rotationPolicyDays: 30,
          requiredBy: ["api-service", "web-app"],
        },
        {
          name: "api-key",
          lastRotated: "2026-04-26",
          rotationPolicyDays: 30,
          requiredBy: ["auth-service"],
        },
      ],
      warningWindowDays: 7,
      outputFormat: "markdown",
      referenceDate: "2026-05-06",
    };

    fs.writeFileSync(configPath, JSON.stringify(config, null, 2));

    const result = spawnSync([
      "bun",
      "run",
      "cli.ts",
      configPath,
      "markdown",
    ]);

    expect(result.success).toBe(false); // Exits with error due to expired secret
    const output = result.stdout?.toString() || "";
    expect(output).toContain("## 🔴 Expired Secrets");
    expect(output).toContain("db-password");
  });

  it("should output JSON format when requested", () => {
    const configPath = path.join(testDir, "config-json.json");
    const config = {
      secrets: [
        {
          name: "test-secret",
          lastRotated: "2026-04-26",
          rotationPolicyDays: 30,
          requiredBy: ["service"],
        },
      ],
      warningWindowDays: 7,
      outputFormat: "json",
      referenceDate: "2026-05-06",
    };

    fs.writeFileSync(configPath, JSON.stringify(config, null, 2));

    const result = spawnSync([
      "bun",
      "run",
      "cli.ts",
      configPath,
      "json",
    ]);

    expect(result.success).toBe(true);
    const output = result.stdout?.toString() || "";
    const parsed = JSON.parse(output);
    expect(parsed.ok).toBeDefined();
    expect(parsed.ok[0].name).toBe("test-secret");
  });

  it("should exit with error code when secrets are expired", () => {
    const configPath = path.join(testDir, "config-expired.json");
    const config = {
      secrets: [
        {
          name: "expired-secret",
          lastRotated: "2026-03-22",
          rotationPolicyDays: 30,
          requiredBy: ["service"],
        },
      ],
      warningWindowDays: 7,
      outputFormat: "markdown",
      referenceDate: "2026-05-06",
    };

    fs.writeFileSync(configPath, JSON.stringify(config, null, 2));

    const result = spawnSync([
      "bun",
      "run",
      "cli.ts",
      configPath,
      "markdown",
    ]);

    expect(result.success).toBe(false);
    expect(result.exitCode).toBe(1);
  });

  it("should handle missing configuration file gracefully", () => {
    const result = spawnSync([
      "bun",
      "run",
      "cli.ts",
      path.join(testDir, "nonexistent.json"),
    ]);

    expect(result.success).toBe(false);
    const output = result.stderr?.toString() || "";
    expect(output).toContain("not found");
  });
});
