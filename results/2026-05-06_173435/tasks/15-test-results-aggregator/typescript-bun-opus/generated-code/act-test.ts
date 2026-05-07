import { describe, test, expect, beforeAll } from "bun:test";
import { mkdtempSync, cpSync, writeFileSync, readFileSync, existsSync } from "fs";
import { execSync } from "child_process";
import { join } from "path";
import { tmpdir } from "os";
import { parse as parseYaml } from "./yaml-parser";

const PROJECT_DIR = import.meta.dir;
const ACT_RESULT_FILE = join(PROJECT_DIR, "act-result.txt");

// Clear any prior act-result.txt
writeFileSync(ACT_RESULT_FILE, "");

function setupTempRepo(fixturesToInclude: string[]): string {
  const tmp = mkdtempSync(join(tmpdir(), "act-test-"));

  execSync("git init", { cwd: tmp, stdio: "pipe" });
  execSync('git config user.email "test@test.com"', { cwd: tmp, stdio: "pipe" });
  execSync('git config user.name "Test"', { cwd: tmp, stdio: "pipe" });

  const filesToCopy = [
    "index.ts",
    "parser.ts",
    "aggregator.ts",
    "markdown.ts",
    "types.ts",
    "package.json",
    "tsconfig.json",
    ".actrc",
    "parser.test.ts",
    "aggregator.test.ts",
    "markdown.test.ts",
  ];

  for (const f of filesToCopy) {
    const src = join(PROJECT_DIR, f);
    if (existsSync(src)) {
      cpSync(src, join(tmp, f));
    }
  }

  cpSync(join(PROJECT_DIR, ".github"), join(tmp, ".github"), {
    recursive: true,
  });

  // Always copy all fixtures (unit tests reference them all)
  cpSync(join(PROJECT_DIR, "fixtures"), join(tmp, "fixtures"), {
    recursive: true,
  });

  // Create a subset directory for the aggregator step
  execSync("mkdir -p test-input", { cwd: tmp, stdio: "pipe" });
  for (const f of fixturesToInclude) {
    cpSync(join(PROJECT_DIR, "fixtures", f), join(tmp, "test-input", f));
  }

  // Copy bun.lock if it exists
  if (existsSync(join(PROJECT_DIR, "bun.lock"))) {
    cpSync(join(PROJECT_DIR, "bun.lock"), join(tmp, "bun.lock"));
  }

  execSync("git add -A && git commit -m 'init'", {
    cwd: tmp,
    stdio: "pipe",
  });

  return tmp;
}

function runAct(repoDir: string, label: string): { exitCode: number; output: string } {
  let output: string;
  let exitCode: number;

  try {
    output = execSync("act push --rm --pull=false 2>&1", {
      cwd: repoDir,
      timeout: 300_000,
      maxBuffer: 10 * 1024 * 1024,
    }).toString();
    exitCode = 0;
  } catch (err: unknown) {
    const e = err as { stdout?: Buffer; stderr?: Buffer; status?: number };
    output = (e.stdout?.toString() || "") + (e.stderr?.toString() || "");
    exitCode = e.status ?? 1;
  }

  // Append to act-result.txt
  const delimiter = `\n${"=".repeat(60)}\n=== TEST CASE: ${label}\n${"=".repeat(60)}\n`;
  const existing = readFileSync(ACT_RESULT_FILE, "utf-8");
  writeFileSync(ACT_RESULT_FILE, existing + delimiter + output + "\n");

  return { exitCode, output };
}

// ============================================================
// Workflow Structure Tests
// ============================================================
describe("Workflow structure tests", () => {
  test("workflow YAML is valid and has expected triggers", () => {
    const yamlPath = join(
      PROJECT_DIR,
      ".github/workflows/test-results-aggregator.yml"
    );
    const content = readFileSync(yamlPath, "utf-8");
    const wf = parseYaml(content);

    expect(wf.name).toBe("Test Results Aggregator");
    expect(wf.on.push).toBeDefined();
    expect(wf.on.pull_request).toBeDefined();
    expect(wf.on.workflow_dispatch).toBeDefined();
  });

  test("workflow has aggregate job with correct steps", () => {
    const yamlPath = join(
      PROJECT_DIR,
      ".github/workflows/test-results-aggregator.yml"
    );
    const content = readFileSync(yamlPath, "utf-8");
    const wf = parseYaml(content);

    expect(wf.jobs.aggregate).toBeDefined();
    const steps = wf.jobs.aggregate.steps;

    const stepNames = steps.map((s: { name: string }) => s.name);
    expect(stepNames).toContain("Checkout");
    expect(stepNames).toContain("Install Bun");
    expect(stepNames).toContain("Install dependencies");
    expect(stepNames).toContain("Run unit tests");
    expect(stepNames).toContain("Run aggregator");
  });

  test("workflow references existing script files", () => {
    expect(existsSync(join(PROJECT_DIR, "index.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "parser.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "aggregator.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "markdown.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "types.ts"))).toBe(true);
  });

  test("actionlint passes with exit code 0", () => {
    const yamlPath = join(
      PROJECT_DIR,
      ".github/workflows/test-results-aggregator.yml"
    );
    const result = execSync(`actionlint ${yamlPath} 2>&1`, {
      encoding: "utf-8",
    });
    // actionlint outputs nothing on success
    expect(result.trim()).toBe("");
  });
});

// ============================================================
// Act Integration Tests
// ============================================================
describe("Act integration tests", () => {
  test("full pipeline with all fixtures succeeds and produces correct output", () => {
    const tmp = setupTempRepo([
      "junit-run1.xml",
      "junit-run2.xml",
      "results-run1.json",
      "results-run2.json",
    ]);
    const { exitCode, output } = runAct(tmp, "all-fixtures");

    expect(exitCode).toBe(0);
    expect(output).toContain("Job succeeded");

    // Verify exact totals from the aggregator output
    expect(output).toContain("TOTAL_TESTS=20");
    expect(output).toContain("PASSED=13");
    expect(output).toContain("FAILED=3");
    expect(output).toContain("SKIPPED=4");
    expect(output).toMatch(/DURATION=20\.1[78]/);
    expect(output).toContain("FLAKY_COUNT=3");

    // Verify specific flaky tests identified
    expect(output).toContain("FLAKY_TEST=APITests::DELETE /users requires auth");
    expect(output).toContain("FLAKY_TEST=APITests::POST /users creates user");
    expect(output).toContain("FLAKY_TEST=AuthTests::session expires after timeout");

    // Verify markdown output structure
    expect(output).toContain("# Test Results Summary");
    expect(output).toContain("Pass Rate: 65.0%");
    expect(output).toContain("| Total | 20 |");
    expect(output).toContain("| Passed | 13 |");
    expect(output).toContain("| Failed | 3 |");
    expect(output).toContain("| Skipped | 4 |");

    // Verify bun test passed (26 tests)
    expect(output).toContain("26 pass");
    expect(output).toContain("0 fail");
  }, 300_000);

  test("pipeline with only XML fixtures produces correct XML-only totals", () => {
    const tmp = setupTempRepo(["junit-run1.xml", "junit-run2.xml"]);
    const { exitCode, output } = runAct(tmp, "xml-only");

    expect(exitCode).toBe(0);
    expect(output).toContain("Job succeeded");

    // 5 tests per XML file x 2 = 10 total
    // run1: 3 passed, 1 failed, 1 skipped
    // run2: 4 passed, 0 failed, 1 skipped
    expect(output).toContain("TOTAL_TESTS=10");
    expect(output).toContain("PASSED=7");
    expect(output).toContain("FAILED=1");
    expect(output).toContain("SKIPPED=2");
    expect(output).toContain("FLAKY_COUNT=1");
    expect(output).toContain(
      "FLAKY_TEST=AuthTests::session expires after timeout"
    );
    expect(output).toContain("Pass Rate: 70.0%");
  }, 300_000);
});
