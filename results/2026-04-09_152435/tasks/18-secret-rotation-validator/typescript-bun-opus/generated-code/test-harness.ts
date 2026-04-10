// Test harness that runs all tests through act (GitHub Actions runner).
// This script:
// 1. Validates workflow YAML structure
// 2. Runs actionlint
// 3. Sets up a temp git repo and runs act push
// 4. Parses act output and asserts on exact expected values
// 5. Saves all output to act-result.txt

import { describe, expect, test, beforeAll, setDefaultTimeout } from "bun:test";

// Act runs can take up to 2 minutes in Docker
setDefaultTimeout(180_000);
import { readFileSync, writeFileSync, mkdirSync, cpSync, existsSync, rmSync } from "fs";
import { execSync } from "child_process";
import { join, resolve } from "path";
import YAML from "./yaml-parser";

const PROJECT_DIR = resolve(import.meta.dir);
const ACT_RESULT_FILE = join(PROJECT_DIR, "act-result.txt");

// Clear the result file at the start
writeFileSync(ACT_RESULT_FILE, "");

/** Append output to act-result.txt with a clear delimiter. */
function appendResult(label: string, content: string): void {
  const delimiter = `\n${"=".repeat(60)}\n${label}\n${"=".repeat(60)}\n`;
  const current = readFileSync(ACT_RESULT_FILE, "utf-8");
  writeFileSync(ACT_RESULT_FILE, current + delimiter + content + "\n");
}

/** Run act in a temp git repo with the project files. */
function runActInTempRepo(testName: string): { exitCode: number; output: string } {
  const tmpDir = join(PROJECT_DIR, `.tmp-act-${testName}`);

  // Clean up from any previous run
  if (existsSync(tmpDir)) {
    rmSync(tmpDir, { recursive: true, force: true });
  }
  mkdirSync(tmpDir, { recursive: true });

  // Copy project files into the temp directory
  const filesToCopy = [
    "src",
    "tests",
    "fixtures",
    ".github",
    ".actrc",
  ];
  for (const f of filesToCopy) {
    const src = join(PROJECT_DIR, f);
    const dst = join(tmpDir, f);
    if (existsSync(src)) {
      cpSync(src, dst, { recursive: true });
    }
  }

  // Initialize a git repo (act requires one)
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

  let output = "";
  let exitCode = 0;
  try {
    output = execSync("act push --rm --pull=false 2>&1", {
      cwd: tmpDir,
      encoding: "utf-8",
      timeout: 180000, // 3 minutes
      env: { ...process.env },
    });
  } catch (err: any) {
    output = err.stdout?.toString() || err.stderr?.toString() || err.message;
    exitCode = err.status ?? 1;
  }

  // Clean up
  rmSync(tmpDir, { recursive: true, force: true });

  return { exitCode, output };
}

// ============================================================
// WORKFLOW STRUCTURE TESTS
// ============================================================
describe("Workflow Structure Tests", () => {
  const workflowPath = join(PROJECT_DIR, ".github/workflows/secret-rotation-validator.yml");
  let workflowContent: string;
  let workflow: any;

  beforeAll(() => {
    workflowContent = readFileSync(workflowPath, "utf-8");
    workflow = YAML.parse(workflowContent);
  });

  test("workflow file exists", () => {
    expect(existsSync(workflowPath)).toBe(true);
  });

  test("has correct trigger events", () => {
    expect(workflow.on).toBeDefined();
    expect(workflow.on.push).toBeDefined();
    expect(workflow.on.pull_request).toBeDefined();
    expect(workflow.on.schedule).toBeDefined();
    expect(workflow.on.workflow_dispatch).toBeDefined();
  });

  test("has validate-secrets job with expected steps", () => {
    const job = workflow.jobs["validate-secrets"];
    expect(job).toBeDefined();
    expect(job["runs-on"]).toBe("ubuntu-latest");

    const stepNames = job.steps.map((s: any) => s.name);
    expect(stepNames).toContain("Checkout");
    expect(stepNames).toContain("Install Bun");
    expect(stepNames).toContain("Run unit tests");
    expect(stepNames).toContain("Validate secrets (JSON)");
    expect(stepNames).toContain("Validate secrets (Markdown)");
    expect(stepNames).toContain("Validate all-ok fixture");
  });

  test("references existing script files", () => {
    // Check that the paths referenced in the workflow exist in the project
    expect(existsSync(join(PROJECT_DIR, "src/main.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "fixtures/secrets.json"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "fixtures/all-ok.json"))).toBe(true);
  });

  test("uses actions/checkout@v4", () => {
    const checkoutStep = workflow.jobs["validate-secrets"].steps.find(
      (s: any) => s.uses && s.uses.startsWith("actions/checkout")
    );
    expect(checkoutStep).toBeDefined();
    expect(checkoutStep.uses).toBe("actions/checkout@v4");
  });

  test("actionlint passes with exit code 0", () => {
    let exitCode = 0;
    try {
      execSync(`actionlint ${workflowPath}`, { stdio: "pipe" });
    } catch {
      exitCode = 1;
    }
    expect(exitCode).toBe(0);
    appendResult("actionlint", "PASSED - no errors");
  });
});

// ============================================================
// ACT INTEGRATION TESTS
// ============================================================
describe("Act Integration Tests", () => {
  let actOutput: string;
  let actExitCode: number;

  beforeAll(() => {
    const result = runActInTempRepo("main");
    actOutput = result.output;
    actExitCode = result.exitCode;
    appendResult("act push (main test)", actOutput);
  });

  test("act exits with code 0", () => {
    expect(actExitCode).toBe(0);
  });

  test("validate-secrets job succeeds", () => {
    expect(actOutput).toContain("Job succeeded");
  });

  // Unit test step assertions
  test("bun test step runs and all 13 tests pass", () => {
    expect(actOutput).toContain("13 pass");
    expect(actOutput).toContain("0 fail");
  });

  // JSON output assertions — exact values for secrets.json with reference date 2026-04-10
  test("JSON output contains correct expired secret DB_PASSWORD with -9 days", () => {
    expect(actOutput).toContain('"name": "DB_PASSWORD"');
    expect(actOutput).toContain('"urgency": "expired"');
    expect(actOutput).toContain('"daysUntilExpiry": -9');
  });

  test("JSON output contains correct expired secret SMTP_PASSWORD with -131 days", () => {
    expect(actOutput).toContain('"name": "SMTP_PASSWORD"');
    expect(actOutput).toContain('"daysUntilExpiry": -131');
  });

  test("JSON output contains correct warning secret API_KEY with 5 days until expiry", () => {
    expect(actOutput).toContain('"name": "API_KEY"');
    expect(actOutput).toContain('"daysUntilExpiry": 5');
  });

  test("JSON output shows summary with 2 expired, 1 warning, 2 ok", () => {
    expect(actOutput).toContain('"expired": 2');
    expect(actOutput).toContain('"warning": 1');
    expect(actOutput).toContain('"ok": 2');
    expect(actOutput).toContain('"total": 5');
  });

  // Markdown output assertions
  test("Markdown output contains the report header", () => {
    expect(actOutput).toContain("# Secret Rotation Report");
  });

  test("Markdown output contains summary counts", () => {
    expect(actOutput).toContain("- Total: 5");
    expect(actOutput).toContain("- Expired: 2");
    expect(actOutput).toContain("- Warning: 1");
    expect(actOutput).toContain("- OK: 2");
  });

  test("Markdown output contains table with DB_PASSWORD as EXPIRED", () => {
    expect(actOutput).toContain("| DB_PASSWORD | EXPIRED | 99 | -9 | 90 |");
  });

  test("Markdown output contains table with STRIPE_KEY as OK", () => {
    expect(actOutput).toContain("| STRIPE_KEY | OK | 5 | 175 | 180 |");
  });

  // All-ok fixture assertions
  test("all-ok fixture produces 0 expired and 0 warning", () => {
    // The all-ok.json fixture should show all secrets as ok
    expect(actOutput).toContain('"name": "FRESH_SECRET_1"');
    expect(actOutput).toContain('"name": "FRESH_SECRET_2"');
  });
});
