// Act integration tests: run the GitHub Actions workflow via `act` in Docker
// Each test sets up a temp git repo, runs act push --rm, and asserts exact output values

import { test, expect, describe, afterAll } from "bun:test";
import { mkdirSync, cpSync, writeFileSync, appendFileSync, existsSync, rmSync } from "fs";
import { execSync, spawnSync } from "child_process";
import { join } from "path";
import { tmpdir } from "os";
import { randomBytes } from "crypto";

const ROOT = join(import.meta.dir, "..");
const ACT_RESULT_FILE = join(ROOT, "act-result.txt");

// Files to copy into each temp repo (excludes node_modules, .git, act-result.txt)
const COPY_ITEMS = [
  "main.ts",
  "package.json",
  "src",
  "fixtures",
  "tests",
  ".github",
  ".actrc",
];

function setupTempRepo(): string {
  const id = randomBytes(4).toString("hex");
  const dir = join(tmpdir(), `act-test-${id}`);
  mkdirSync(dir, { recursive: true });

  for (const item of COPY_ITEMS) {
    const src = join(ROOT, item);
    if (existsSync(src)) {
      cpSync(src, join(dir, item), { recursive: true });
    }
  }

  // Initialize git repo and commit all files
  execSync("git init", { cwd: dir, stdio: "pipe" });
  execSync("git config user.email 'test@test.com'", { cwd: dir, stdio: "pipe" });
  execSync("git config user.name 'Test'", { cwd: dir, stdio: "pipe" });
  execSync("git add -A", { cwd: dir, stdio: "pipe" });
  execSync("git commit -m 'test: initial commit'", { cwd: dir, stdio: "pipe" });

  return dir;
}

function runAct(dir: string): { output: string; exitCode: number } {
  const result = spawnSync("act", ["push", "--rm", "--pull=false"], {
    cwd: dir,
    encoding: "utf-8",
    timeout: 300_000, // 5 min timeout
    env: { ...process.env, HOME: process.env.HOME ?? "/root" },
  });

  const output = (result.stdout ?? "") + (result.stderr ?? "");
  const exitCode = result.status ?? 1;
  return { output, exitCode };
}

function appendToResultFile(delimiter: string, output: string): void {
  appendFileSync(ACT_RESULT_FILE, `\n${"=".repeat(60)}\n${delimiter}\n${"=".repeat(60)}\n`);
  appendFileSync(ACT_RESULT_FILE, output);
  appendFileSync(ACT_RESULT_FILE, "\n");
}

// Initialize act-result.txt
writeFileSync(ACT_RESULT_FILE, `Act Integration Test Results\nTimestamp: ${new Date().toISOString()}\n`);

describe("act integration: test results aggregator workflow", () => {
  let tempDir: string;
  let actOutput: string;
  let actExitCode: number;

  // Run act once and reuse the result for all assertions
  test("act runs successfully (exit code 0)", () => {
    tempDir = setupTempRepo();
    const result = runAct(tempDir);
    actOutput = result.output;
    actExitCode = result.exitCode;

    appendToResultFile("Test Case: full aggregation run", actOutput);

    expect(actExitCode).toBe(0);
  }, 300_000);

  test("workflow job succeeds", () => {
    expect(actOutput).toMatch(/Job succeeded|✅|success/i);
  });

  test("output contains correct total tests count", () => {
    expect(actOutput).toContain("| Total Tests | 12 |");
  });

  test("output contains correct passed count", () => {
    expect(actOutput).toContain("| Passed | 9 |");
  });

  test("output contains correct failed count", () => {
    expect(actOutput).toContain("| Failed | 2 |");
  });

  test("output contains correct skipped count", () => {
    expect(actOutput).toContain("| Skipped | 1 |");
  });

  test("output contains correct duration", () => {
    expect(actOutput).toContain("| Duration | 3.75s |");
  });

  test("output contains correct run count", () => {
    expect(actOutput).toContain("| Runs | 3 |");
  });

  test("output contains flaky tests section with count 2", () => {
    expect(actOutput).toContain("### Flaky Tests (2)");
  });

  test("output identifies TestFlaky as flaky", () => {
    expect(actOutput).toContain("**TestFlaky**");
  });

  test("output identifies TestGamma as flaky", () => {
    expect(actOutput).toContain("**TestGamma**");
  });

  test("unit tests pass inside workflow", () => {
    // bun test output will show pass counts
    expect(actOutput).toMatch(/\d+ pass/);
  });

  afterAll(() => {
    if (tempDir && existsSync(tempDir)) {
      rmSync(tempDir, { recursive: true, force: true });
    }
  });
});
