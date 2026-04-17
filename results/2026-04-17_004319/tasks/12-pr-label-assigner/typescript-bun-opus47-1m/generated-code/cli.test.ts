// CLI-level integration tests.
// Spawn the actual Bun process so we exercise arg parsing, stdin, and exit codes.

import { describe, expect, test } from "bun:test";
import { resolve } from "node:path";

const CLI = resolve(import.meta.dir, "cli.ts");
const CONFIG = resolve(import.meta.dir, "labels.config.json");

async function runCli(
  args: string[],
  stdin?: string,
): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  const proc = Bun.spawn(["bun", "run", CLI, ...args], {
    stdin: stdin !== undefined ? "pipe" : "ignore",
    stdout: "pipe",
    stderr: "pipe",
  });
  if (stdin !== undefined) {
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
  test("exits 1 when --config is missing", async () => {
    const { exitCode, stderr } = await runCli([]);
    expect(exitCode).toBe(1);
    expect(stderr).toContain("--config");
  });

  test("reads positional file args and prints JSON labels", async () => {
    const { exitCode, stdout } = await runCli([
      "--config",
      CONFIG,
      "docs/readme.md",
    ]);
    expect(exitCode).toBe(0);
    const parsed = JSON.parse(stdout) as { labels: string[] };
    expect(parsed.labels).toContain("documentation");
  });

  test("reads file list from --files-stdin", async () => {
    const { exitCode, stdout } = await runCli(
      ["--config", CONFIG, "--files-stdin"],
      "src/api/users.ts\nsrc/api/users.test.ts\n",
    );
    expect(exitCode).toBe(0);
    const parsed = JSON.parse(stdout) as { labels: string[] };
    // api is priority 10, tests priority 3, size/L priority 10.
    expect(parsed.labels).toEqual(["api", "size/L", "tests"]);
  });

  test("reads file list from --files <path>", async () => {
    const fixture = resolve(import.meta.dir, "fixtures/docs-only.txt");
    const { exitCode, stdout } = await runCli([
      "--config",
      CONFIG,
      "--files",
      fixture,
    ]);
    expect(exitCode).toBe(0);
    const parsed = JSON.parse(stdout) as { labels: string[] };
    // size/S wins the "size" group since src/** doesn't match docs paths.
    expect(parsed.labels).toEqual(["documentation", "size/S"]);
  });

  test("empty file list yields empty labels array", async () => {
    const { exitCode, stdout } = await runCli(
      ["--config", CONFIG, "--files-stdin"],
      "",
    );
    expect(exitCode).toBe(0);
    expect(JSON.parse(stdout)).toEqual({ labels: [] });
  });

  test("mixed fixture produces the expected deterministic label set", async () => {
    const fixture = resolve(import.meta.dir, "fixtures/mixed.txt");
    const { exitCode, stdout } = await runCli([
      "--config",
      CONFIG,
      "--files",
      fixture,
    ]);
    expect(exitCode).toBe(0);
    const parsed = JSON.parse(stdout) as { labels: string[] };
    // Expected (sorted by priority DESC then label ASC):
    //   backend (5), frontend (5), dependencies (4), tests (3), ci (2),
    //   documentation (1), size/M (from exclusive "size" group, priority 5)
    expect(parsed.labels).toEqual([
      "backend",
      "frontend",
      "size/M",
      "dependencies",
      "tests",
      "ci",
      "documentation",
    ]);
  });
});
