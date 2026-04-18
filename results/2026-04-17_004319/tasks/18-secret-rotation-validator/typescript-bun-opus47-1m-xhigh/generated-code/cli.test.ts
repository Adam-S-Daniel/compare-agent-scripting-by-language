// End-to-end CLI tests. We shell out to `bun run cli.ts` against temp fixtures
// and check that:
//   - the rendered output is correct for both formats
//   - exit code is 1 when any secret is expired
//   - exit code is 2 when warnings exist but nothing is expired
//   - exit code is 0 when everything is ok
//   - bad config produces a clear error on stderr

import { afterAll, describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const SCRIPT = new URL("./cli.ts", import.meta.url).pathname;
const tmpRoot = mkdtempSync(join(tmpdir(), "srv-cli-"));

afterAll(() => {
  rmSync(tmpRoot, { recursive: true, force: true });
});

function writeConfig(name: string, obj: unknown): string {
  const p = join(tmpRoot, `${name}.json`);
  writeFileSync(p, JSON.stringify(obj, null, 2));
  return p;
}

async function runCli(
  args: string[],
): Promise<{ code: number; stdout: string; stderr: string }> {
  const proc = Bun.spawn(["bun", "run", SCRIPT, ...args], {
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  const code = await proc.exited;
  return { code, stdout, stderr };
}

const REF = "2026-04-17";

describe("cli", () => {
  test("--format json outputs a parseable report and exits 1 when anything is expired", async () => {
    const cfg = writeConfig("mixed", {
      secrets: [
        {
          name: "expired-key",
          lastRotated: "2025-10-01",
          rotationDays: 60,
          requiredBy: ["svc-a"],
        },
        {
          name: "ok-key",
          lastRotated: "2026-04-10",
          rotationDays: 90,
          requiredBy: ["svc-b"],
        },
      ],
    });
    const result = await runCli([
      "--config",
      cfg,
      "--format",
      "json",
      "--warning-days",
      "14",
      "--reference-date",
      REF,
    ]);
    expect(result.code).toBe(1);
    const parsed = JSON.parse(result.stdout);
    expect(parsed.summary.expired).toBe(1);
    expect(parsed.summary.ok).toBe(1);
    expect(parsed.expired[0].secret.name).toBe("expired-key");
  });

  test("--format markdown renders a table and exits 2 when warnings exist but nothing is expired", async () => {
    const cfg = writeConfig("warn", {
      secrets: [
        {
          name: "warn-key",
          lastRotated: "2026-01-20",
          rotationDays: 90,
          requiredBy: ["billing"],
        },
      ],
    });
    const result = await runCli([
      "--config",
      cfg,
      "--format",
      "markdown",
      "--warning-days",
      "14",
      "--reference-date",
      REF,
    ]);
    expect(result.code).toBe(2);
    expect(result.stdout).toContain("# Secret Rotation Report");
    expect(result.stdout).toContain("## Warning");
    expect(result.stdout).toContain("warn-key");
  });

  test("exits 0 when everything is ok", async () => {
    const cfg = writeConfig("ok", {
      secrets: [
        {
          name: "ok-key",
          lastRotated: "2026-04-10",
          rotationDays: 365,
          requiredBy: ["svc"],
        },
      ],
    });
    const result = await runCli([
      "--config",
      cfg,
      "--format",
      "json",
      "--warning-days",
      "14",
      "--reference-date",
      REF,
    ]);
    expect(result.code).toBe(0);
  });

  test("writes a helpful error to stderr when config is malformed", async () => {
    const bad = join(tmpRoot, "bad.json");
    writeFileSync(bad, "{ not valid json");
    const result = await runCli([
      "--config",
      bad,
      "--format",
      "json",
      "--reference-date",
      REF,
    ]);
    expect(result.code).toBe(3);
    expect(result.stderr.toLowerCase()).toContain("config");
  });

  test("rejects unknown format", async () => {
    const cfg = writeConfig("ok-for-format", {
      secrets: [
        {
          name: "k",
          lastRotated: "2026-04-10",
          rotationDays: 90,
          requiredBy: [],
        },
      ],
    });
    const result = await runCli([
      "--config",
      cfg,
      "--format",
      "yaml",
      "--reference-date",
      REF,
    ]);
    expect(result.code).toBe(3);
    expect(result.stderr).toMatch(/format/i);
  });
});
