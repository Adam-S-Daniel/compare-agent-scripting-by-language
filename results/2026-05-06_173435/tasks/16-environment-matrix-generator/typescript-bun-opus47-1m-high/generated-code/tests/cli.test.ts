// CLI tests: read a config file, write JSON to stdout. Errors -> non-zero exit.

import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const CLI = join(import.meta.dir, "..", "src", "cli.ts");
let workdir: string;

beforeAll(() => {
  workdir = mkdtempSync(join(tmpdir(), "matrix-cli-"));
});
afterAll(() => {
  rmSync(workdir, { recursive: true, force: true });
});

async function runCli(configPath: string): Promise<{ code: number; stdout: string; stderr: string }> {
  const proc = Bun.spawn(["bun", "run", CLI, configPath], {
    stdout: "pipe",
    stderr: "pipe",
  });
  const code = await proc.exited;
  const stdout = await new Response(proc.stdout).text();
  const stderr = await new Response(proc.stderr).text();
  return { code, stdout, stderr };
}

describe("cli", () => {
  test("emits valid GitHub Actions matrix JSON", async () => {
    const cfg = join(workdir, "ok.json");
    writeFileSync(
      cfg,
      JSON.stringify({
        axes: { os: ["ubuntu-latest"], node: ["18", "20"] },
        failFast: false,
        maxParallel: 2,
      }),
    );
    const { code, stdout } = await runCli(cfg);
    expect(code).toBe(0);
    const parsed = JSON.parse(stdout);
    expect(parsed.strategy["fail-fast"]).toBe(false);
    expect(parsed.strategy["max-parallel"]).toBe(2);
    expect(parsed.strategy.matrix.include).toHaveLength(2);
  });

  test("non-zero exit + error message when config is invalid", async () => {
    const cfg = join(workdir, "bad.json");
    writeFileSync(cfg, JSON.stringify({ axes: {} }));
    const { code, stderr } = await runCli(cfg);
    expect(code).not.toBe(0);
    expect(stderr).toMatch(/at least one axis/i);
  });

  test("non-zero exit when matrix exceeds max-size", async () => {
    const cfg = join(workdir, "toobig.json");
    writeFileSync(
      cfg,
      JSON.stringify({
        axes: { os: ["a", "b", "c"], node: ["1", "2", "3"] },
        maxSize: 4,
      }),
    );
    const { code, stderr } = await runCli(cfg);
    expect(code).not.toBe(0);
    expect(stderr).toMatch(/exceeds max-size/);
  });
});
