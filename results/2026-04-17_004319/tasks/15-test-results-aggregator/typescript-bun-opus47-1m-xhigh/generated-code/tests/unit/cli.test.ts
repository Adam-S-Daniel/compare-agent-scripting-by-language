// TDD: CLI behavior is part of the contract. The CLI is what the GitHub
// Actions workflow invokes, so we drive it with end-to-end tests that
// parse real fixtures and check the rendered markdown.
import { describe, expect, test, beforeAll } from "bun:test";
import { spawn } from "bun";
import { readFile, writeFile, mkdir, rm } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join } from "node:path";

const ROOT = new URL("../..", import.meta.url).pathname;
const CLI = join(ROOT, "src", "index.ts");
const TMP = join(ROOT, ".tmp-cli");

beforeAll(async () => {
  await rm(TMP, { recursive: true, force: true });
  await mkdir(TMP, { recursive: true });
});

async function runCli(args: string[], env: Record<string, string> = {}): Promise<{
  code: number;
  stdout: string;
  stderr: string;
}> {
  const proc = spawn({
    cmd: ["bun", "run", CLI, ...args],
    cwd: ROOT,
    env: { ...process.env, ...env },
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

describe("CLI", () => {
  test("prints markdown summary for real fixtures to stdout", async () => {
    const { code, stdout } = await runCli([
      "fixtures/run-1.xml",
      "fixtures/run-2.json",
    ]);
    expect(code).toBe(0);
    expect(stdout).toContain("# Test Results Summary");
    expect(stdout).toContain("| Passed | Failed | Skipped | Total | Duration |");
    // net.http.network_call_completes passed in run-1.xml and failed in
    // run-2.json — that makes it flaky.
    expect(stdout).toContain("## Flaky Tests");
    expect(stdout).toContain("net.http.network_call_completes");
    // math.div.divides_numbers failed in run-1.xml and passed in run-2.json — also flaky.
    expect(stdout).toContain("math.div.divides_numbers");
  });

  test("writes to GITHUB_STEP_SUMMARY when set", async () => {
    const summaryPath = join(TMP, "summary.md");
    await writeFile(summaryPath, "", "utf8");
    const { code } = await runCli(
      ["fixtures/run-1.xml", "fixtures/run-2.json"],
      { GITHUB_STEP_SUMMARY: summaryPath },
    );
    expect(code).toBe(0);
    expect(existsSync(summaryPath)).toBe(true);
    const written = await readFile(summaryPath, "utf8");
    expect(written).toContain("# Test Results Summary");
    expect(written).toContain("## Flaky Tests");
  });

  test("exits non-zero with a helpful message when no inputs are given", async () => {
    const { code, stderr } = await runCli([]);
    expect(code).not.toBe(0);
    expect(stderr.toLowerCase()).toContain("usage");
  });

  test("supports --exit-on-failure to exit 1 when failures exist", async () => {
    const { code } = await runCli([
      "--exit-on-failure",
      "fixtures/run-1.xml",
      "fixtures/run-2.json",
    ]);
    // Both fixtures contain at least one failure, so this should exit 1.
    expect(code).toBe(1);
  });

  test("without --exit-on-failure exits 0 even when tests failed", async () => {
    const { code } = await runCli([
      "fixtures/run-1.xml",
      "fixtures/run-2.json",
    ]);
    expect(code).toBe(0);
  });
});
