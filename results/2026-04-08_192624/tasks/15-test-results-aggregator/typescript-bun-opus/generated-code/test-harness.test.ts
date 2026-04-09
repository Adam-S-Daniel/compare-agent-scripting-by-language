// Test harness: all tests run through the GitHub Actions workflow via act.
// Each test case sets up a temp git repo with project files and specific fixtures,
// runs `act push --rm`, captures output, and asserts on exact expected values.

import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import { mkdtempSync, cpSync, writeFileSync, readFileSync, existsSync, mkdirSync, appendFileSync, rmSync } from "fs";
import { join } from "path";
import { execSync } from "child_process";
import { tmpdir } from "os";
import { parse as parseYaml } from "./yaml-helper";

// Path to the main project directory
const PROJECT_DIR = import.meta.dir;
// Path to the act-result.txt output file (in the project directory)
const ACT_RESULT_FILE = join(PROJECT_DIR, "act-result.txt");

// Source files needed for each temp repo
const SOURCE_FILES = [
  "package.json",
  "tsconfig.json",
  "src/types.ts",
  "src/parser.ts",
  "src/aggregator.ts",
  "src/formatter.ts",
  "src/main.ts",
  ".github/workflows/test-results-aggregator.yml",
];

/** Clear act-result.txt at the start of the test run */
beforeAll(() => {
  writeFileSync(ACT_RESULT_FILE, "");
});

/**
 * Helper: set up a temp git repo with project source files and given fixture files.
 * Returns the temp directory path.
 */
function setupTempRepo(fixtureFiles: Record<string, string>): string {
  const tmpDir = mkdtempSync(join(tmpdir(), "act-test-"));

  // Copy source files
  for (const file of SOURCE_FILES) {
    const src = join(PROJECT_DIR, file);
    const dest = join(tmpDir, file);
    const destDir = join(dest, "..");
    mkdirSync(destDir, { recursive: true });
    cpSync(src, dest);
  }

  // Write fixture files
  mkdirSync(join(tmpDir, "fixtures"), { recursive: true });
  for (const [name, content] of Object.entries(fixtureFiles)) {
    writeFileSync(join(tmpDir, "fixtures", name), content);
  }

  // Initialize git repo (act requires a git repo for checkout)
  execSync("git init && git add -A && git commit -m 'init'", {
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

/**
 * Helper: run act in a temp repo directory. Returns { exitCode, output }.
 */
function runAct(repoDir: string): { exitCode: number; output: string } {
  try {
    const output = execSync(
      'act push --rm -W .github/workflows/test-results-aggregator.yml --defaultbranch main -P ubuntu-latest=catthehacker/ubuntu:act-latest',
      {
        cwd: repoDir,
        timeout: 300_000,
        stdio: "pipe",
        env: { ...process.env, DOCKER_HOST: process.env.DOCKER_HOST },
      }
    ).toString();
    return { exitCode: 0, output };
  } catch (err: unknown) {
    const execErr = err as { status: number; stdout: Buffer; stderr: Buffer };
    const output = (execErr.stdout?.toString() || "") + (execErr.stderr?.toString() || "");
    return { exitCode: execErr.status || 1, output };
  }
}

/**
 * Helper: append test case output to act-result.txt
 */
function appendResult(testName: string, output: string, exitCode: number) {
  const delimiter = `\n${"=".repeat(60)}\n`;
  const entry = `${delimiter}TEST CASE: ${testName}\nEXIT CODE: ${exitCode}${delimiter}${output}${delimiter}\n`;
  appendFileSync(ACT_RESULT_FILE, entry);
}

// ============================================================
// WORKFLOW STRUCTURE TESTS
// ============================================================

describe("Workflow structure tests", () => {
  test("workflow YAML has expected structure (triggers, jobs, steps)", () => {
    const yamlPath = join(PROJECT_DIR, ".github/workflows/test-results-aggregator.yml");
    expect(existsSync(yamlPath)).toBe(true);

    const content = readFileSync(yamlPath, "utf-8");
    const workflow = parseYaml(content);

    // Check triggers
    expect(workflow.on).toBeDefined();
    expect(workflow.on.push).toBeDefined();
    expect(workflow.on.pull_request).toBeDefined();
    expect(workflow.on.workflow_dispatch).toBeDefined();

    // Check jobs
    expect(workflow.jobs).toBeDefined();
    expect(workflow.jobs["aggregate-test-results"]).toBeDefined();

    const job = workflow.jobs["aggregate-test-results"];
    expect(job["runs-on"]).toBe("ubuntu-latest");
    expect(Array.isArray(job.steps)).toBe(true);
    expect(job.steps.length).toBeGreaterThanOrEqual(3);

    // Verify step names
    const stepNames: string[] = job.steps.map((s: { name: string }) => s.name);
    expect(stepNames).toContain("Checkout code");
    expect(stepNames).toContain("Install Bun");
    expect(stepNames).toContain("Run test results aggregator");
  });

  test("workflow references script files that exist", () => {
    // Check that all source files referenced by the workflow exist
    for (const file of ["src/main.ts", "src/parser.ts", "src/aggregator.ts", "src/formatter.ts", "src/types.ts"]) {
      const fullPath = join(PROJECT_DIR, file);
      expect(existsSync(fullPath)).toBe(true);
    }
  });

  test("actionlint passes with exit code 0", () => {
    const yamlPath = join(PROJECT_DIR, ".github/workflows/test-results-aggregator.yml");
    let exitCode = 0;
    let output = "";
    try {
      output = execSync(`actionlint ${yamlPath}`, { stdio: "pipe" }).toString();
    } catch (err: unknown) {
      const execErr = err as { status: number; stdout: Buffer; stderr: Buffer };
      exitCode = execErr.status || 1;
      output = (execErr.stdout?.toString() || "") + (execErr.stderr?.toString() || "");
    }
    expect(exitCode).toBe(0);
  });
});

// ============================================================
// ACT-BASED INTEGRATION TESTS
// ============================================================

describe("Act integration tests", () => {
  test("JUnit XML parsing: correct counts for basic JUnit file", () => {
    // Fixture: single JUnit XML with 4 tests (2 passed, 1 failed, 1 skipped)
    const fixtures: Record<string, string> = {
      "junit-basic.xml": readFileSync(join(PROJECT_DIR, "fixtures/junit-basic.xml"), "utf-8"),
    };

    const tmpDir = setupTempRepo(fixtures);
    const { exitCode, output } = runAct(tmpDir);
    appendResult("JUnit XML parsing", output, exitCode);
    rmSync(tmpDir, { recursive: true, force: true });

    expect(exitCode).toBe(0);
    expect(output).toContain("Job succeeded");

    // Assert exact values from the JUnit fixture:
    // math suite: add(pass), subtract(pass), multiply(fail), divide(skip)
    expect(output).toContain("TOTAL_TESTS=4");
    expect(output).toContain("TOTAL_PASSED=2");
    expect(output).toContain("TOTAL_FAILED=1");
    expect(output).toContain("TOTAL_SKIPPED=1");
    expect(output).toContain("TOTAL_DURATION=1.80");
    expect(output).toContain("FLAKY_TESTS=none");
  }, 300_000);

  test("JSON parsing: correct counts for basic JSON file", () => {
    // Fixture: single JSON with 3 tests (2 passed, 0 failed, 1 skipped)
    const fixtures: Record<string, string> = {
      "json-basic.json": readFileSync(join(PROJECT_DIR, "fixtures/json-basic.json"), "utf-8"),
    };

    const tmpDir = setupTempRepo(fixtures);
    const { exitCode, output } = runAct(tmpDir);
    appendResult("JSON parsing", output, exitCode);
    rmSync(tmpDir, { recursive: true, force: true });

    expect(exitCode).toBe(0);
    expect(output).toContain("Job succeeded");

    // Assert exact values from JSON fixture:
    // string-utils: capitalize(pass), trim(pass), reverse(skip)
    expect(output).toContain("TOTAL_TESTS=3");
    expect(output).toContain("TOTAL_PASSED=2");
    expect(output).toContain("TOTAL_FAILED=0");
    expect(output).toContain("TOTAL_SKIPPED=1");
    expect(output).toContain("TOTAL_DURATION=0.30");
    expect(output).toContain("FLAKY_TESTS=none");
  }, 300_000);

  test("Multi-file aggregation: correct totals across JUnit XML and JSON", () => {
    // Combine both basic fixtures: 4 + 3 = 7 tests total
    const fixtures: Record<string, string> = {
      "junit-basic.xml": readFileSync(join(PROJECT_DIR, "fixtures/junit-basic.xml"), "utf-8"),
      "json-basic.json": readFileSync(join(PROJECT_DIR, "fixtures/json-basic.json"), "utf-8"),
    };

    const tmpDir = setupTempRepo(fixtures);
    const { exitCode, output } = runAct(tmpDir);
    appendResult("Multi-file aggregation", output, exitCode);
    rmSync(tmpDir, { recursive: true, force: true });

    expect(exitCode).toBe(0);
    expect(output).toContain("Job succeeded");

    // Aggregated: 4 (junit) + 3 (json) = 7 tests
    // Passed: 2 + 2 = 4, Failed: 1 + 0 = 1, Skipped: 1 + 1 = 2
    // Duration: 1.80 + 0.30 = 2.10
    expect(output).toContain("TOTAL_TESTS=7");
    expect(output).toContain("TOTAL_PASSED=4");
    expect(output).toContain("TOTAL_FAILED=1");
    expect(output).toContain("TOTAL_SKIPPED=2");
    expect(output).toContain("TOTAL_DURATION=2.10");
    expect(output).toContain("FLAKY_TESTS=none");
  }, 300_000);

  test("Flaky test detection: identifies tests with mixed outcomes", () => {
    // Matrix runs: run1 has fetchOrder=fail, run2 has fetchOrder=pass, run3 has fetchProduct=fail
    // fetchOrder: 2 pass, 1 fail -> flaky
    // fetchProduct: 2 pass, 1 fail -> flaky
    const fixtures: Record<string, string> = {
      "matrix-run1.xml": readFileSync(join(PROJECT_DIR, "fixtures/matrix-run1.xml"), "utf-8"),
      "matrix-run2.xml": readFileSync(join(PROJECT_DIR, "fixtures/matrix-run2.xml"), "utf-8"),
      "matrix-run3.json": readFileSync(join(PROJECT_DIR, "fixtures/matrix-run3.json"), "utf-8"),
    };

    const tmpDir = setupTempRepo(fixtures);
    const { exitCode, output } = runAct(tmpDir);
    appendResult("Flaky test detection", output, exitCode);
    rmSync(tmpDir, { recursive: true, force: true });

    expect(exitCode).toBe(0);
    expect(output).toContain("Job succeeded");

    // 3 runs x 3 tests = 9 total
    expect(output).toContain("TOTAL_TESTS=9");
    expect(output).toContain("TOTAL_PASSED=7");
    expect(output).toContain("TOTAL_FAILED=2");
    expect(output).toContain("TOTAL_SKIPPED=0");

    // Flaky tests identified
    expect(output).toContain("FLAKY_TESTS=api::fetchOrder,api::fetchProduct");
  }, 300_000);

  test("Markdown summary: contains expected sections and data", () => {
    // Use all fixtures to get a full markdown output
    const fixtures: Record<string, string> = {
      "matrix-run1.xml": readFileSync(join(PROJECT_DIR, "fixtures/matrix-run1.xml"), "utf-8"),
      "matrix-run2.xml": readFileSync(join(PROJECT_DIR, "fixtures/matrix-run2.xml"), "utf-8"),
      "matrix-run3.json": readFileSync(join(PROJECT_DIR, "fixtures/matrix-run3.json"), "utf-8"),
    };

    const tmpDir = setupTempRepo(fixtures);
    const { exitCode, output } = runAct(tmpDir);
    appendResult("Markdown summary", output, exitCode);
    rmSync(tmpDir, { recursive: true, force: true });

    expect(exitCode).toBe(0);
    expect(output).toContain("Job succeeded");

    // Verify markdown structure
    expect(output).toContain("Test Results Summary");
    expect(output).toContain("## Totals");
    expect(output).toContain("## Suite Breakdown");
    expect(output).toContain("Flaky Tests");

    // Verify markdown table content
    expect(output).toContain("| Total Tests | 9 |");
    expect(output).toContain("| Passed | 7 |");
    expect(output).toContain("| Failed | 2 |");
    expect(output).toContain("| Status | **FAIL** |");

    // Suite table has api suite row
    expect(output).toContain("| api |");

    // Flaky tests table
    expect(output).toContain("| api | fetchOrder |");
    expect(output).toContain("| api | fetchProduct |");
  }, 300_000);
});
