// CLI integration test: shells out to `bun run src/cli.ts` so we exercise
// argument parsing, file I/O, and exit codes the same way CI will.

import { describe, expect, test, beforeAll } from "bun:test";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const CLI = join(import.meta.dir, "..", "src", "cli.ts");

const FIXTURE = [
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

let configPath: string;

beforeAll(() => {
  const dir = mkdtempSync(join(tmpdir(), "secret-rotation-"));
  configPath = join(dir, "secrets.json");
  writeFileSync(configPath, JSON.stringify(FIXTURE), "utf8");
});

function run(args: string[]) {
  return spawnSync("bun", ["run", CLI, ...args], {
    encoding: "utf8",
    env: { ...process.env, FAKE_NOW: "2026-05-07T00:00:00Z" },
  });
}

describe("cli", () => {
  test("--format json prints a parseable report and exits non-zero when expired", () => {
    const r = run([
      "--config",
      configPath,
      "--warning-window",
      "14",
      "--format",
      "json",
    ]);
    expect(r.status).toBe(2); // 2 == expired secrets present
    const parsed = JSON.parse(r.stdout);
    expect(parsed.totals).toEqual({ expired: 1, warning: 1, ok: 1 });
    expect(parsed.expired[0].name).toBe("stripe_api_key");
  });

  test("--format markdown prints the rendered report", () => {
    const r = run([
      "--config",
      configPath,
      "--warning-window",
      "14",
      "--format",
      "markdown",
    ]);
    expect(r.status).toBe(2);
    expect(r.stdout).toContain("# Secret Rotation Report");
    expect(r.stdout).toContain("| stripe_api_key | 2025-10-01 | 128 |");
  });

  test("exits 1 when only warnings exist, 0 when all OK", () => {
    const warningsOnly = run([
      "--config",
      configPath,
      "--warning-window",
      "14",
      "--format",
      "json",
      "--ignore-expired",
    ]);
    // With --ignore-expired the stripe entry is dropped, so only "warning" is left.
    expect(warningsOnly.status).toBe(1);

    const allOk = run([
      "--config",
      configPath,
      "--warning-window",
      "0",
      "--format",
      "json",
      "--ignore-expired",
      "--ignore-warning",
    ]);
    expect(allOk.status).toBe(0);
  });

  test("emits a clear error when the config file is missing", () => {
    const r = run(["--config", "/no/such/file.json", "--format", "json"]);
    expect(r.status).toBe(3);
    expect(r.stderr).toContain("config file");
  });
});
