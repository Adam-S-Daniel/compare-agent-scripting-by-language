#!/usr/bin/env bun
/**
 * Test harness — runs all test cases through the GitHub Actions workflow via `act`.
 *
 * For each test case:
 *  1. Sets up a temp git repo with all project files + test fixture data
 *  2. Runs `act push --rm` to execute the workflow in Docker
 *  3. Captures output and appends to act-result.txt
 *  4. Asserts exit code 0, checks for "Job succeeded", and validates exact output values
 *
 * Also runs workflow structure tests (YAML parsing, file references, actionlint).
 */

import { describe, test, expect, beforeAll } from "bun:test";
import { existsSync, mkdirSync, writeFileSync, readFileSync, appendFileSync, rmSync, cpSync } from "fs";
import { join } from "path";
import { execSync } from "child_process";
import * as yaml from "js-yaml";

const PROJECT_DIR = import.meta.dir;
const ACT_RESULT_FILE = join(PROJECT_DIR, "act-result.txt");
const WORKFLOW_PATH = ".github/workflows/dependency-license-checker.yml";
const WORKFLOW_FULL_PATH = join(PROJECT_DIR, WORKFLOW_PATH);

// Clear the result file at start
writeFileSync(ACT_RESULT_FILE, "");

/** Helper: create a temp git repo with all project files */
function setupTempRepo(testName: string): string {
  const tmpDir = join(PROJECT_DIR, `.tmp-${testName}-${Date.now()}`);
  mkdirSync(tmpDir, { recursive: true });

  // Copy project files
  const filesToCopy = [
    "package.json",
    "tsconfig.json",
    "bun.lock",
    ".github",
    "src",
    "fixtures",
  ];

  for (const f of filesToCopy) {
    const src = join(PROJECT_DIR, f);
    const dst = join(tmpDir, f);
    if (existsSync(src)) {
      cpSync(src, dst, { recursive: true });
    }
  }

  // Initialize git repo (act requires it)
  execSync("git init && git add -A && git commit -m 'init' --allow-empty", {
    cwd: tmpDir,
    stdio: "pipe",
    env: {
      ...process.env,
      GIT_AUTHOR_NAME: "test",
      GIT_AUTHOR_EMAIL: "test@test.com",
      GIT_COMMITTER_NAME: "test",
      GIT_COMMITTER_EMAIL: "test@test.com",
    },
  });

  return tmpDir;
}

/** Helper: run act in a directory and return { exitCode, output } */
function runAct(cwd: string, job?: string): { exitCode: number; output: string } {
  const jobFlag = job ? `-j ${job}` : "";
  const cmd = `act push --rm ${jobFlag} -P ubuntu-latest=catthehacker/ubuntu:act-latest 2>&1`;
  try {
    const output = execSync(cmd, {
      cwd,
      timeout: 300000, // 5 min timeout
      maxBuffer: 10 * 1024 * 1024,
      env: { ...process.env },
    }).toString();
    return { exitCode: 0, output };
  } catch (err: unknown) {
    const e = err as { status?: number; stdout?: Buffer; stderr?: Buffer };
    const output = (e.stdout?.toString() ?? "") + (e.stderr?.toString() ?? "");
    return { exitCode: e.status ?? 1, output };
  }
}

/** Helper: append test output to act-result.txt */
function appendResult(testName: string, output: string, exitCode: number): void {
  const delimiter = `\n${"=".repeat(60)}\n`;
  const header = `TEST CASE: ${testName} | EXIT CODE: ${exitCode}`;
  appendFileSync(ACT_RESULT_FILE, `${delimiter}${header}${delimiter}${output}\n`);
}

/** Helper: clean up temp directory */
function cleanupTempDir(dir: string): void {
  try {
    rmSync(dir, { recursive: true, force: true });
  } catch {
    // Ignore cleanup errors
  }
}

// ========================
// WORKFLOW STRUCTURE TESTS
// ========================
describe("Workflow Structure Tests", () => {
  let workflowContent: string;
  let workflowYaml: Record<string, unknown>;

  beforeAll(() => {
    workflowContent = readFileSync(WORKFLOW_FULL_PATH, "utf-8");
    workflowYaml = yaml.load(workflowContent) as Record<string, unknown>;
  });

  test("workflow YAML parses successfully", () => {
    expect(workflowYaml).toBeDefined();
    expect(typeof workflowYaml).toBe("object");
  });

  test("workflow has correct trigger events", () => {
    const triggers = workflowYaml["on"] as Record<string, unknown>;
    expect(triggers).toBeDefined();
    expect(triggers["push"]).toBeDefined();
    expect(triggers["pull_request"]).toBeDefined();
    expect(triggers["workflow_dispatch"]).toBeDefined();
  });

  test("workflow has expected jobs", () => {
    const jobs = workflowYaml["jobs"] as Record<string, unknown>;
    expect(jobs).toBeDefined();
    expect(jobs["license-check-approved"]).toBeDefined();
    expect(jobs["license-check-mixed"]).toBeDefined();
    expect(jobs["license-check-requirements"]).toBeDefined();
    expect(jobs["unit-tests"]).toBeDefined();
  });

  test("workflow jobs use checkout@v4", () => {
    const jobs = workflowYaml["jobs"] as Record<string, Record<string, unknown>>;
    for (const [, job] of Object.entries(jobs)) {
      const steps = job["steps"] as Array<Record<string, unknown>>;
      const checkoutStep = steps.find(
        (s) => (s["uses"] as string)?.startsWith("actions/checkout")
      );
      expect(checkoutStep).toBeDefined();
      expect(checkoutStep!["uses"]).toBe("actions/checkout@v4");
    }
  });

  test("workflow references script files that exist", () => {
    // Check that src/main.ts exists
    expect(existsSync(join(PROJECT_DIR, "src/main.ts"))).toBe(true);
    // Check that fixture files referenced in the workflow exist
    expect(existsSync(join(PROJECT_DIR, "fixtures/all-approved-package.json"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "fixtures/mixed-package.json"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "fixtures/requirements.txt"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "fixtures/license-config.json"))).toBe(true);
  });

  test("actionlint passes with no errors", () => {
    const result = execSync(`actionlint ${WORKFLOW_FULL_PATH} 2>&1`, {
      encoding: "utf-8",
    });
    // actionlint outputs nothing on success
    expect(result.trim()).toBe("");
  });
});

// ========================
// ACT INTEGRATION TESTS
// ========================
describe("ACT Integration Tests", () => {
  // Test Case 1: All-Approved Package (license-check-approved job)
  test("license-check-approved job succeeds with all MIT deps", () => {
    const tmpDir = setupTempRepo("approved");
    try {
      const { exitCode, output } = runAct(tmpDir, "license-check-approved");
      appendResult("license-check-approved", output, exitCode);

      expect(exitCode).toBe(0);
      expect(output).toContain("Job succeeded");

      // Verify exact expected output values
      expect(output).toContain("express@^4.18.0 — MIT [APPROVED]");
      expect(output).toContain("lodash@~4.17.21 — MIT [APPROVED]");
      expect(output).toContain("axios@^1.4.0 — MIT [APPROVED]");
      expect(output).toContain("Total: 3");
      expect(output).toContain("Approved: 3");
      expect(output).toContain("Denied: 0");
      expect(output).toContain("Unknown: 0");
      expect(output).toContain("RESULT: PASS — all licenses approved");
    } finally {
      cleanupTempDir(tmpDir);
    }
  }, 300000);

  // Test Case 2: Mixed Package (license-check-mixed job)
  test("license-check-mixed job detects denied and unknown licenses", () => {
    const tmpDir = setupTempRepo("mixed");
    try {
      const { exitCode, output } = runAct(tmpDir, "license-check-mixed");
      appendResult("license-check-mixed", output, exitCode);

      expect(exitCode).toBe(0);
      expect(output).toContain("Job succeeded");

      // Verify exact expected output values
      expect(output).toContain("express@^4.18.0 — MIT [APPROVED]");
      expect(output).toContain("gpl-lib@^1.0.0 — GPL-3.0 [DENIED]");
      expect(output).toContain("mystery-pkg@^2.0.0 — UNKNOWN [UNKNOWN]");
      expect(output).toContain("Total: 3");
      expect(output).toContain("Approved: 1");
      expect(output).toContain("Denied: 1");
      expect(output).toContain("Unknown: 1");
      expect(output).toContain("RESULT: FAIL — denied licenses found");
      expect(output).toContain("LICENSE_CHECK_EXIT=2");
      expect(output).toContain("Detected denied licenses as expected (exit code 2)");
    } finally {
      cleanupTempDir(tmpDir);
    }
  }, 300000);

  // Test Case 3: Requirements.txt (license-check-requirements job)
  test("license-check-requirements job processes requirements.txt correctly", () => {
    const tmpDir = setupTempRepo("requirements");
    try {
      const { exitCode, output } = runAct(tmpDir, "license-check-requirements");
      appendResult("license-check-requirements", output, exitCode);

      expect(exitCode).toBe(0);
      expect(output).toContain("Job succeeded");

      // Verify exact expected output values
      expect(output).toContain("flask@2.3.0 — BSD-3-Clause [APPROVED]");
      expect(output).toContain("requests@2.28.0 — Apache-2.0 [APPROVED]");
      expect(output).toContain("numpy@1.24.0 — BSD-3-Clause [APPROVED]");
      expect(output).toContain("gpl-tool@1.0.0 — GPL-3.0 [DENIED]");
      expect(output).toContain("Total: 4");
      expect(output).toContain("Approved: 3");
      expect(output).toContain("Denied: 1");
      expect(output).toContain("Unknown: 0");
      expect(output).toContain("RESULT: FAIL — denied licenses found");
      expect(output).toContain("LICENSE_CHECK_EXIT=2");
    } finally {
      cleanupTempDir(tmpDir);
    }
  }, 300000);

  // Test Case 4: Unit Tests (unit-tests job)
  test("unit-tests job runs bun test successfully", () => {
    const tmpDir = setupTempRepo("unit-tests");
    try {
      const { exitCode, output } = runAct(tmpDir, "unit-tests");
      appendResult("unit-tests", output, exitCode);

      expect(exitCode).toBe(0);
      expect(output).toContain("Job succeeded");

      // Verify test output: all 19 tests pass, 0 fail
      expect(output).toContain("19 pass");
      expect(output).toContain("0 fail");
    } finally {
      cleanupTempDir(tmpDir);
    }
  }, 300000);
});
