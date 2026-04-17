// CLI tests. The CLI reads a config (from a file path argument or stdin)
// and writes the generated matrix JSON to stdout. Errors go to stderr with
// a non-zero exit code.

import { describe, expect, test } from "bun:test";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const CLI = new URL("../src/cli.ts", import.meta.url).pathname;

async function runCli(
  args: string[],
  stdin?: string,
): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  const proc = Bun.spawn(["bun", "run", CLI, ...args], {
    stdin: stdin !== undefined ? "pipe" : "ignore",
    stdout: "pipe",
    stderr: "pipe",
  });
  if (stdin !== undefined && proc.stdin) {
    proc.stdin.write(stdin);
    await proc.stdin.end();
  }
  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  const exitCode = await proc.exited;
  return { stdout, stderr, exitCode };
}

describe("cli", () => {
  test("reads config file and writes matrix JSON to stdout", async () => {
    const dir = mkdtempSync(join(tmpdir(), "emg-cli-"));
    try {
      const cfg = join(dir, "cfg.json");
      writeFileSync(
        cfg,
        JSON.stringify({
          dimensions: { os: ["ubuntu-latest"], node: [18, 20] },
          failFast: true,
          maxParallel: 2,
        }),
      );
      const { stdout, exitCode } = await runCli([cfg]);
      expect(exitCode).toBe(0);
      const parsed = JSON.parse(stdout);
      expect(parsed.matrix.include).toEqual([
        { os: "ubuntu-latest", node: 18 },
        { os: "ubuntu-latest", node: 20 },
      ]);
      expect(parsed["fail-fast"]).toBe(true);
      expect(parsed["max-parallel"]).toBe(2);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("reads config from stdin when path is -", async () => {
    const cfg = JSON.stringify({ dimensions: { os: ["ubuntu-latest"] } });
    const { stdout, exitCode } = await runCli(["-"], cfg);
    expect(exitCode).toBe(0);
    expect(JSON.parse(stdout).matrix.include).toEqual([{ os: "ubuntu-latest" }]);
  });

  test("exits non-zero with a clear message on validation error", async () => {
    const cfg = JSON.stringify({
      dimensions: { os: ["a", "b"], node: [1, 2] },
      maxSize: 1,
    });
    const { stderr, exitCode } = await runCli(["-"], cfg);
    expect(exitCode).not.toBe(0);
    expect(stderr).toContain("maxSize");
  });

  test("exits non-zero with a clear message on bad JSON", async () => {
    const { stderr, exitCode } = await runCli(["-"], "{not json");
    expect(exitCode).not.toBe(0);
    expect(stderr.toLowerCase()).toContain("json");
  });

  test("supports --output <path> to write JSON to a file", async () => {
    const dir = mkdtempSync(join(tmpdir(), "emg-cli-"));
    try {
      const cfg = join(dir, "cfg.json");
      const out = join(dir, "out.json");
      writeFileSync(cfg, JSON.stringify({ dimensions: { os: ["ubuntu-latest"] } }));
      const { exitCode } = await runCli([cfg, "--output", out]);
      expect(exitCode).toBe(0);
      const parsed = JSON.parse(await Bun.file(out).text());
      expect(parsed.matrix.include).toEqual([{ os: "ubuntu-latest" }]);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
