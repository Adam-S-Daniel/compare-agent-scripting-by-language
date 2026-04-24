// End-to-end CLI tests — run the script through `bun run` and assert on
// stdout/exit codes so the same code path we rely on in CI is exercised here.
import { describe, test, expect } from "bun:test";
import { spawnSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import * as fs from "node:fs";

const CLI = join(import.meta.dir, "..", "src", "cli.ts");

function runCli(configJson: string): { code: number; stdout: string; stderr: string } {
  const dir = fs.mkdtempSync(join(tmpdir(), "matrix-cli-"));
  const fixture = join(dir, "config.json");
  fs.writeFileSync(fixture, configJson);
  const result = Bun.spawnSync({
    cmd: ["bun", "run", CLI, fixture],
    stdout: "pipe",
    stderr: "pipe",
  });
  return {
    code: result.exitCode ?? -1,
    stdout: new TextDecoder().decode(result.stdout),
    stderr: new TextDecoder().decode(result.stderr),
  };
}

describe("CLI", () => {
  test("writes valid JSON with exit 0 for a valid config", () => {
    const r = runCli(
      JSON.stringify({
        axes: { os: ["ubuntu-latest"], node: ["20"] },
        failFast: false,
        maxParallel: 2,
      }),
    );
    expect(r.code).toBe(0);
    const parsed = JSON.parse(r.stdout);
    expect(parsed.total).toBe(1);
    expect(parsed.strategy["fail-fast"]).toBe(false);
    expect(parsed.strategy["max-parallel"]).toBe(2);
    expect(parsed.strategy.matrix.include).toEqual([{ os: "ubuntu-latest", node: "20" }]);
  });

  test("exits 2 when the matrix exceeds maxSize", () => {
    const r = runCli(
      JSON.stringify({
        axes: { a: [1, 2, 3], b: [1, 2, 3] },
        maxSize: 4,
      }),
    );
    expect(r.code).toBe(2);
    expect(r.stderr).toContain("exceeds maxSize");
  });

  test("exits 1 for an unreadable config path", () => {
    const result = Bun.spawnSync({
      cmd: ["bun", "run", CLI, "/nonexistent/does-not-exist.json"],
      stdout: "pipe",
      stderr: "pipe",
    });
    expect(result.exitCode).toBe(1);
  });
});
