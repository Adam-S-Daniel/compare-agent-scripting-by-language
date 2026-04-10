/**
 * Test Results Aggregator — Tests
 *
 * All tests run through the GitHub Actions workflow via act.
 * We also verify workflow YAML structure and actionlint compliance.
 *
 * TDD approach: each test was written before the implementation code
 * that makes it pass.
 */

import { describe, test, expect } from "bun:test";
import { readFileSync, existsSync, mkdirSync, cpSync, writeFileSync, appendFileSync, rmSync } from "fs";
import { join, resolve } from "path";
import { execSync } from "child_process";
import { parse as parseYaml } from "./yaml-parser.ts";

const PROJECT_DIR = resolve(import.meta.dir);
const ACT_RESULT_FILE = join(PROJECT_DIR, "act-result.txt");
const WORKFLOW_PATH = join(PROJECT_DIR, ".github", "workflows", "test-results-aggregator.yml");

// ── Helper: set up a temp git repo, copy project files, run act ────────────

function runActForFixtures(fixtureDir: string, label: string): { exitCode: number; output: string } {
  const tmpDir = execSync("mktemp -d").toString().trim();

  try {
    // Copy project files into temp repo
    cpSync(join(PROJECT_DIR, "aggregator.ts"), join(tmpDir, "aggregator.ts"));
    cpSync(join(PROJECT_DIR, "yaml-parser.ts"), join(tmpDir, "yaml-parser.ts"));
    cpSync(join(PROJECT_DIR, ".github"), join(tmpDir, ".github"), { recursive: true });

    // Copy .actrc for container image mapping
    if (existsSync(join(PROJECT_DIR, ".actrc"))) {
      cpSync(join(PROJECT_DIR, ".actrc"), join(tmpDir, ".actrc"));
    }

    // Copy fixtures
    mkdirSync(join(tmpDir, "fixtures"), { recursive: true });
    const files = execSync(`ls "${fixtureDir}"`).toString().trim().split("\n").filter(Boolean);
    for (const f of files) {
      cpSync(join(fixtureDir, f), join(tmpDir, "fixtures", f));
    }

    // Initialize git repo (required by act + actions/checkout)
    execSync(
      `cd "${tmpDir}" && git init && git add -A && git commit -m "test"`,
      { stdio: "pipe" }
    );

    // Run act
    let output: string;
    let exitCode: number;
    try {
      output = execSync(`cd "${tmpDir}" && act push --rm 2>&1`, {
        timeout: 120000,
        maxBuffer: 10 * 1024 * 1024,
      }).toString();
      exitCode = 0;
    } catch (err: unknown) {
      const e = err as { status?: number; stdout?: Buffer; stderr?: Buffer };
      exitCode = e.status || 1;
      output = (e.stdout?.toString() || "") + (e.stderr?.toString() || "");
    }

    // Append to act-result.txt
    const delimiter = `\n${"=".repeat(60)}\n[ACT RUN: ${label}] exit_code=${exitCode}\n${"=".repeat(60)}\n`;
    appendFileSync(ACT_RESULT_FILE, delimiter + output + "\n");

    return { exitCode, output };
  } finally {
    rmSync(tmpDir, { recursive: true, force: true });
  }
}

// ── Lazy act result caching ────────────────────────────────────────────────

// Run act once per fixture set, cache the result for all tests in that group.
let fullFixtureResult: { exitCode: number; output: string } | null = null;
function getFullFixtureResult(): { exitCode: number; output: string } {
  if (!fullFixtureResult) {
    // Clear previous act-result.txt
    writeFileSync(ACT_RESULT_FILE, "");
    fullFixtureResult = runActForFixtures(join(PROJECT_DIR, "fixtures"), "full-fixtures");
  }
  return fullFixtureResult;
}

let passOnlyResult: { exitCode: number; output: string } | null = null;
function getPassOnlyResult(): { exitCode: number; output: string } {
  if (!passOnlyResult) {
    // Create temporary fixture directory with only passing tests
    const tmpFixtureDir = execSync("mktemp -d").toString().trim();
    writeFileSync(
      join(tmpFixtureDir, "all-pass.json"),
      JSON.stringify({
        testSuites: [
          {
            name: "MathService",
            tests: [
              { name: "adds numbers", classname: "MathService", status: "passed", duration: 0.1 },
              { name: "subtracts numbers", classname: "MathService", status: "passed", duration: 0.2 },
            ],
          },
        ],
      })
    );
    passOnlyResult = runActForFixtures(tmpFixtureDir, "pass-only");
    rmSync(tmpFixtureDir, { recursive: true, force: true });
  }
  return passOnlyResult;
}

// ── Workflow Structure Tests ───────────────────────────────────────────────

describe("Workflow structure", () => {
  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("has correct trigger events", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    const workflow = parseYaml(content);
    const on = workflow["on"] as Record<string, unknown>;
    expect(on).toBeDefined();
    expect("push" in on).toBe(true);
    expect("pull_request" in on).toBe(true);
    expect("workflow_dispatch" in on).toBe(true);
  });

  test("has aggregate job with expected steps", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    const workflow = parseYaml(content);
    const jobs = workflow["jobs"] as Record<string, unknown>;
    expect(jobs).toBeDefined();
    expect("aggregate" in jobs).toBe(true);

    const aggregate = jobs["aggregate"] as Record<string, unknown>;
    expect(aggregate["runs-on"]).toBe("ubuntu-latest");

    const steps = aggregate["steps"] as Array<Record<string, unknown>>;
    expect(steps.length).toBeGreaterThanOrEqual(3);

    const stepNames = steps.map((s) => s["name"] as string);
    expect(stepNames).toContain("Checkout");
    expect(stepNames).toContain("Install Bun");
    expect(stepNames).toContain("Run aggregator and show summary");
  });

  test("workflow references script files that exist", () => {
    expect(existsSync(join(PROJECT_DIR, "aggregator.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "fixtures"))).toBe(true);
  });

  test("actionlint passes", () => {
    const result = Bun.spawnSync(["actionlint", WORKFLOW_PATH]);
    expect(result.exitCode).toBe(0);
  });
});

// ── Act Integration Tests ──────────────────────────────────────────────────

describe("Act integration — full fixtures", () => {
  test("act exits with code 0", () => {
    const { exitCode } = getFullFixtureResult();
    expect(exitCode).toBe(0);
  }, 120_000);

  test("aggregate job succeeded", () => {
    const { output } = getFullFixtureResult();
    expect(output).toContain("Job succeeded");
  }, 120_000);

  test("act-result.txt exists and has content", () => {
    getFullFixtureResult(); // ensure it ran
    expect(existsSync(ACT_RESULT_FILE)).toBe(true);
    const content = readFileSync(ACT_RESULT_FILE, "utf-8");
    expect(content.length).toBeGreaterThan(0);
  }, 120_000);

  test("output contains exact total: 16 tests", () => {
    const { output } = getFullFixtureResult();
    expect(output).toContain("| Total tests | 16 |");
  }, 120_000);

  test("output contains exact passed count: 11", () => {
    const { output } = getFullFixtureResult();
    expect(output).toContain("| Passed | 11 |");
  }, 120_000);

  test("output contains exact failed count: 3", () => {
    const { output } = getFullFixtureResult();
    expect(output).toContain("| Failed | 3 |");
  }, 120_000);

  test("output contains exact skipped count: 2", () => {
    const { output } = getFullFixtureResult();
    expect(output).toContain("| Skipped | 2 |");
  }, 120_000);

  test("output contains exact duration: 11.75s", () => {
    const { output } = getFullFixtureResult();
    expect(output).toContain("| Duration | 11.75s |");
  }, 120_000);

  test("output shows FAIL status", () => {
    const { output } = getFullFixtureResult();
    expect(output).toContain("**Status:** FAIL");
  }, 120_000);

  test("output lists the 3 specific failed tests", () => {
    const { output } = getFullFixtureResult();
    expect(output).toContain("AuthService > login fails with invalid password");
    expect(output).toContain("PaymentService > handles declined card");
    expect(output).toContain("AuthService > token refresh works");
  }, 120_000);

  test("output identifies exactly 2 flaky tests with correct counts", () => {
    const { output } = getFullFixtureResult();
    expect(output).toContain("## Flaky Tests");
    expect(output).toContain("AuthService > login fails with invalid password | 2 | 1 | 33%");
    expect(output).toContain("AuthService > token refresh works | 2 | 1 | 33%");
  }, 120_000);

  test("output shows per-file breakdown with correct values", () => {
    const { output } = getFullFixtureResult();
    expect(output).toContain("| junit-run1.xml | 3 | 1 | 1 | 3.15s |");
    expect(output).toContain("| junit-run2.xml | 4 | 0 | 1 | 2.90s |");
    expect(output).toContain("| results-run3.json | 4 | 2 | 0 | 5.70s |");
    expect(output).toContain("| empty-suite.xml | 0 | 0 | 0 | 0.00s |");
  }, 120_000);
});

// ── Act Integration: Pass-only fixtures ────────────────────────────────────

describe("Act integration — pass-only fixtures", () => {
  test("act exits with code 0", () => {
    const { exitCode } = getPassOnlyResult();
    expect(exitCode).toBe(0);
  }, 120_000);

  test("job succeeded", () => {
    const { output } = getPassOnlyResult();
    expect(output).toContain("Job succeeded");
  }, 120_000);

  test("output shows PASS status", () => {
    const { output } = getPassOnlyResult();
    expect(output).toContain("**Status:** PASS");
  }, 120_000);

  test("output shows exact totals for pass-only run", () => {
    const { output } = getPassOnlyResult();
    expect(output).toContain("| Total tests | 2 |");
    expect(output).toContain("| Passed | 2 |");
    expect(output).toContain("| Failed | 0 |");
    expect(output).toContain("| Skipped | 0 |");
    expect(output).toContain("| Duration | 0.30s |");
  }, 120_000);

  test("output does NOT contain flaky or failed sections", () => {
    const { output } = getPassOnlyResult();
    expect(output).not.toContain("## Flaky Tests");
    expect(output).not.toContain("## Failed Tests");
  }, 120_000);
});
