// Integration tests: run the full workflow through act (nektos/act)
// Sets up a temp git repo, copies project files, runs act, and verifies output.

import { describe, test, expect, beforeAll } from "bun:test";
import { mkdtempSync, cpSync, existsSync, writeFileSync, appendFileSync, readFileSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";

const PROJECT_DIR = process.cwd();
const ACT_RESULT_FILE = join(PROJECT_DIR, "act-result.txt");

// Clear act-result.txt at start
writeFileSync(ACT_RESULT_FILE, "");

/** Set up a temp git repo with project files and run act push */
async function runActForTest(testName: string): Promise<{ exitCode: number; output: string }> {
  const tmpDir = mkdtempSync(join(tmpdir(), "license-check-"));

  // Copy project files
  const filesToCopy = [
    "src",
    "tests",
    "fixtures",
    ".github",
    "package.json",
    "tsconfig.json",
    "bun.lock",
  ];
  for (const f of filesToCopy) {
    const src = join(PROJECT_DIR, f);
    if (existsSync(src)) {
      cpSync(src, join(tmpDir, f), { recursive: true });
    }
  }

  // Write .actrc mapping ubuntu-latest to local image
  writeFileSync(join(tmpDir, ".actrc"), "-P ubuntu-latest=act-ubuntu-pwsh:latest\n--pull=false\n");

  // Initialize git repo (act requires it)
  const gitInit = Bun.spawn(
    ["bash", "-c", "git init && git add -A && git commit -m 'init'"],
    {
      cwd: tmpDir,
      stdout: "pipe",
      stderr: "pipe",
      env: {
        ...process.env,
        GIT_AUTHOR_NAME: "test",
        GIT_AUTHOR_EMAIL: "test@test.com",
        GIT_COMMITTER_NAME: "test",
        GIT_COMMITTER_EMAIL: "test@test.com",
      },
    }
  );
  await gitInit.exited;

  // Run act push with --pull=false to use local image
  const actProc = Bun.spawn(
    ["act", "push", "--rm", "--pull=false"],
    {
      cwd: tmpDir,
      stdout: "pipe",
      stderr: "pipe",
      env: { ...process.env },
    }
  );

  const [stdout, stderr] = await Promise.all([
    new Response(actProc.stdout).text(),
    new Response(actProc.stderr).text(),
  ]);
  const exitCode = await actProc.exited;

  const output = stdout + "\n" + stderr;

  // Append to act-result.txt
  const delimiter = `\n${"=".repeat(60)}\nTEST CASE: ${testName}\n${"=".repeat(60)}\n`;
  appendFileSync(ACT_RESULT_FILE, delimiter + output + "\n");

  return { exitCode, output };
}

describe("act integration tests", () => {
  let actResult: { exitCode: number; output: string };

  beforeAll(async () => {
    actResult = await runActForTest("full-workflow");
  }, 300000); // 5 min timeout

  test("act exits with code 0", () => {
    expect(actResult.exitCode).toBe(0);
  });

  // Unit tests job
  test("unit tests pass within workflow", () => {
    // The workflow runs parser, checker, report tests (21 tests total across 3 files)
    expect(actResult.output).toContain("pass");
    expect(actResult.output).toContain("0 fail");
  });

  // All-approved fixture checks
  test("all-approved fixture shows 4 dependencies found", () => {
    expect(actResult.output).toContain("Found 4 dependencies in all-approved-package.json");
  });

  test("all-approved fixture shows Approved: 4, Denied: 0", () => {
    expect(actResult.output).toContain("Approved: 4");
    expect(actResult.output).toContain("Denied: 0");
  });

  test("all-approved fixture shows PASS message", () => {
    expect(actResult.output).toContain("PASS: All dependencies have acceptable licenses.");
  });

  test("all-approved fixture confirms exit marker", () => {
    expect(actResult.output).toContain("ALL_APPROVED_EXIT=0");
  });

  test("all-approved shows express MIT and typescript Apache-2.0", () => {
    expect(actResult.output).toContain("express");
    expect(actResult.output).toContain("MIT");
    expect(actResult.output).toContain("typescript");
    expect(actResult.output).toContain("Apache-2.0");
  });

  // Has-denied fixture checks
  test("denied fixture detects gpl-crypto GPL-3.0 as DENIED", () => {
    expect(actResult.output).toContain("gpl-crypto");
    expect(actResult.output).toContain("GPL-3.0");
    expect(actResult.output).toContain("DENIED");
  });

  test("denied fixture reports DENIED_EXIT=1", () => {
    expect(actResult.output).toContain("DENIED_EXIT=1");
  });

  test("denied fixture prints correct detection message", () => {
    expect(actResult.output).toContain("Correctly detected denied licenses");
  });

  // Requirements.txt fixture checks
  test("requirements fixture finds 4 dependencies", () => {
    expect(actResult.output).toContain("Found 4 dependencies in mixed-requirements.txt");
  });

  test("requirements fixture detects gpl-tool as denied", () => {
    expect(actResult.output).toContain("gpl-tool");
  });

  test("requirements fixture reports REQUIREMENTS_EXIT=1", () => {
    expect(actResult.output).toContain("REQUIREMENTS_EXIT=1");
  });

  test("requirements fixture prints correct detection message", () => {
    expect(actResult.output).toContain("Correctly detected denied licenses in requirements.txt");
  });

  // Job success verification
  test("job shows success", () => {
    const successCount = (actResult.output.match(/Job succeeded/g) || []).length;
    expect(successCount).toBeGreaterThanOrEqual(1);
  });

  test("act-result.txt exists and has content", () => {
    expect(existsSync(ACT_RESULT_FILE)).toBe(true);
    const content = readFileSync(ACT_RESULT_FILE, "utf-8");
    expect(content.length).toBeGreaterThan(0);
    expect(content).toContain("TEST CASE: full-workflow");
  });
});
