// Test harness for secret-rotation-validator
// All test cases run through the GitHub Actions workflow via `act`.
// Results are appended to act-result.txt as a required artifact.

import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import { readFileSync, writeFileSync, mkdirSync, cpSync, existsSync, appendFileSync, rmSync } from "fs";
import { execSync } from "child_process";
import { join } from "path";
import * as yaml from "js-yaml";

const PROJECT_DIR = import.meta.dir;
const ACT_RESULT_FILE = join(PROJECT_DIR, "act-result.txt");
const WORKFLOW_PATH = join(PROJECT_DIR, ".github/workflows/secret-rotation-validator.yml");

// Files to copy into each temp repo
const PROJECT_FILES = [
  "package.json",
  "bun.lock",
  "tsconfig.json",
  "types.ts",
  "validator.ts",
  "formatter.ts",
  "main.ts",
];

/** Set up a temp git repo with project files and a specific fixture */
function setupTempRepo(fixtureName: string): string {
  const tmpDir = execSync("mktemp -d").toString().trim();

  // Copy project source files
  for (const f of PROJECT_FILES) {
    cpSync(join(PROJECT_DIR, f), join(tmpDir, f));
  }

  // Copy .github/workflows
  mkdirSync(join(tmpDir, ".github", "workflows"), { recursive: true });
  cpSync(WORKFLOW_PATH, join(tmpDir, ".github", "workflows", "secret-rotation-validator.yml"));

  // Copy fixtures directory
  mkdirSync(join(tmpDir, "fixtures"), { recursive: true });
  cpSync(join(PROJECT_DIR, "fixtures", fixtureName), join(tmpDir, "fixtures", fixtureName));

  // Initialize git repo so act can work
  execSync("git init && git checkout -b main", { cwd: tmpDir, stdio: "pipe" });
  execSync("git add -A && git commit -m 'init'", { cwd: tmpDir, stdio: "pipe" });

  return tmpDir;
}

/** Run act in a temp repo, overriding env vars for the fixture */
function runAct(tmpDir: string, fixtureFile: string): { exitCode: number; output: string } {
  try {
    const output = execSync(
      `act push --rm -W .github/workflows/secret-rotation-validator.yml --env FIXTURE_FILE=${fixtureFile}`,
      { cwd: tmpDir, timeout: 180_000, stdio: "pipe" }
    ).toString();
    return { exitCode: 0, output };
  } catch (err: any) {
    // act returns non-zero when workflow has issues, but we may still get output
    return { exitCode: err.status ?? 1, output: (err.stdout?.toString() ?? "") + (err.stderr?.toString() ?? "") };
  }
}

function cleanup(tmpDir: string): void {
  try {
    rmSync(tmpDir, { recursive: true, force: true });
  } catch { /* ignore */ }
}

// Clear act-result.txt before tests run
beforeAll(() => {
  writeFileSync(ACT_RESULT_FILE, "");
});

// ─── Workflow Structure Tests ───────────────────────────────────────────

describe("Workflow structure tests", () => {
  test("workflow YAML parses correctly and has expected triggers", () => {
    const raw = readFileSync(WORKFLOW_PATH, "utf-8");
    const wf = yaml.load(raw) as any;

    // Verify triggers
    expect(wf.on).toBeDefined();
    expect(wf.on.push).toBeDefined();
    expect(wf.on.pull_request).toBeDefined();
    expect(wf.on.schedule).toBeDefined();
    expect(wf.on.workflow_dispatch).toBeDefined();

    // Verify push branches
    expect(wf.on.push.branches).toContain("main");

    // Verify workflow_dispatch inputs
    const inputs = wf.on.workflow_dispatch.inputs;
    expect(inputs.warning_days).toBeDefined();
    expect(inputs.output_format).toBeDefined();
    expect(inputs.reference_date).toBeDefined();
    expect(inputs.fixture_file).toBeDefined();

    appendFileSync(ACT_RESULT_FILE, "=== WORKFLOW STRUCTURE TEST ===\nPASS: YAML parses, triggers verified\n\n");
  });

  test("workflow has expected jobs and steps", () => {
    const raw = readFileSync(WORKFLOW_PATH, "utf-8");
    const wf = yaml.load(raw) as any;

    // Verify jobs
    expect(wf.jobs["validate-secrets"]).toBeDefined();
    const job = wf.jobs["validate-secrets"];

    // Verify runs-on
    expect(job["runs-on"]).toBe("ubuntu-latest");

    // Verify steps exist and include key steps
    const stepNames = job.steps.map((s: any) => s.name);
    expect(stepNames).toContain("Checkout repository");
    expect(stepNames).toContain("Setup Bun");
    expect(stepNames).toContain("Install dependencies");
    expect(stepNames).toContain("Run secret rotation validator (JSON)");
    expect(stepNames).toContain("Run secret rotation validator (Markdown)");
    expect(stepNames).toContain("Summary");

    appendFileSync(ACT_RESULT_FILE, "=== WORKFLOW JOBS/STEPS TEST ===\nPASS: jobs and steps verified\n\n");
  });

  test("workflow references existing script files", () => {
    // The workflow runs main.ts — verify it exists
    expect(existsSync(join(PROJECT_DIR, "main.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "validator.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "formatter.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "types.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_DIR, "package.json"))).toBe(true);

    appendFileSync(ACT_RESULT_FILE, "=== FILE REFERENCE TEST ===\nPASS: all referenced script files exist\n\n");
  });

  test("actionlint passes with exit code 0", () => {
    let exitCode = 0;
    try {
      execSync(`actionlint ${WORKFLOW_PATH}`, { stdio: "pipe" });
    } catch (err: any) {
      exitCode = err.status ?? 1;
    }
    expect(exitCode).toBe(0);

    appendFileSync(ACT_RESULT_FILE, "=== ACTIONLINT TEST ===\nPASS: actionlint exit code 0\n\n");
  });
});

// ─── Act Integration Tests ──────────────────────────────────────────────

describe("Act integration tests", () => {
  // Test case 1: mixed-urgency fixture — should have 1 expired, 1 warning, 1 ok
  test("mixed-urgency fixture: correct urgency classification", () => {
    const tmpDir = setupTempRepo("mixed-urgency.json");
    try {
      const { exitCode, output } = runAct(tmpDir, "fixtures/mixed-urgency.json");

      appendFileSync(ACT_RESULT_FILE, "=== ACT TEST: mixed-urgency ===\n" + output + "\n\n");

      // act should exit 0 (workflow succeeded)
      expect(exitCode).toBe(0);

      // Verify Job succeeded
      expect(output).toContain("Job succeeded");

      // Verify exact JSON values from the JSON report step
      // DB_PASSWORD should be expired with exactly 98 days since rotation, -68 days until expiry
      expect(output).toContain('"name": "DB_PASSWORD"');
      expect(output).toContain('"urgency": "expired"');
      expect(output).toContain('"daysSinceRotation": 98');
      expect(output).toContain('"daysUntilExpiry": -68');
      expect(output).toContain('"expiryDate": "2026-01-31"');

      // API_KEY_STRIPE should be warning with 20 days since rotation, 10 days until expiry
      expect(output).toContain('"name": "API_KEY_STRIPE"');
      expect(output).toContain('"urgency": "warning"');
      expect(output).toContain('"daysSinceRotation": 20');
      expect(output).toContain('"daysUntilExpiry": 10');
      expect(output).toContain('"expiryDate": "2026-04-19"');

      // JWT_SECRET should be ok with 4 days since rotation, 86 days until expiry
      expect(output).toContain('"name": "JWT_SECRET"');
      expect(output).toContain('"urgency": "ok"');
      expect(output).toContain('"daysSinceRotation": 4');
      expect(output).toContain('"daysUntilExpiry": 86');
      expect(output).toContain('"expiryDate": "2026-07-04"');

      // Verify grouping counts in markdown report
      expect(output).toContain("**Expired:** 1 | **Warning:** 1 | **OK:** 1");

      // Verify markdown table rows
      expect(output).toContain("| DB_PASSWORD | EXPIRED | 98 | -68 | 2026-01-31 | api-server, worker |");
      expect(output).toContain("| API_KEY_STRIPE | WARNING | 20 | 10 | 2026-04-19 | billing-service |");
      expect(output).toContain("| JWT_SECRET | OK | 4 | 86 | 2026-07-04 | auth-service, api-server |");

      // Verify summary step
      expect(output).toContain("Secret rotation validation complete.");
      expect(output).toContain("Warning window: 14 days");
      expect(output).toContain("Reference date: 2026-04-09");
    } finally {
      cleanup(tmpDir);
    }
  }, 180_000);

  // Test case 2: all-ok fixture — all secrets should be ok
  test("all-ok fixture: all secrets classified as ok", () => {
    const tmpDir = setupTempRepo("all-ok.json");
    try {
      // Override fixture file via env var in workflow
      // We need to modify the workflow env for this fixture
      const wfPath = join(tmpDir, ".github/workflows/secret-rotation-validator.yml");
      let wfContent = readFileSync(wfPath, "utf-8");
      wfContent = wfContent.replace(
        /FIXTURE_FILE:.*$/m,
        "FIXTURE_FILE: fixtures/all-ok.json"
      );
      writeFileSync(wfPath, wfContent);
      execSync("git add -A && git commit -m 'use all-ok fixture'", { cwd: tmpDir, stdio: "pipe" });

      const { exitCode, output } = runAct(tmpDir, "fixtures/all-ok.json");

      appendFileSync(ACT_RESULT_FILE, "=== ACT TEST: all-ok ===\n" + output + "\n\n");

      expect(exitCode).toBe(0);
      expect(output).toContain("Job succeeded");

      // Verify FRESH_SECRET is ok: 1 day since rotation, 89 until expiry
      expect(output).toContain('"name": "FRESH_SECRET"');
      expect(output).toContain('"daysSinceRotation": 1');
      expect(output).toContain('"daysUntilExpiry": 89');
      expect(output).toContain('"expiryDate": "2026-07-07"');

      // Verify ANOTHER_FRESH is ok: 8 days since rotation, 82 until expiry
      expect(output).toContain('"name": "ANOTHER_FRESH"');
      expect(output).toContain('"daysSinceRotation": 8');
      expect(output).toContain('"daysUntilExpiry": 82');
      expect(output).toContain('"expiryDate": "2026-06-30"');

      // Verify no expired or warning
      expect(output).toContain('"expired": []');
      expect(output).toContain('"warning": []');

      // Markdown grouping
      expect(output).toContain("**Expired:** 0 | **Warning:** 0 | **OK:** 2");
    } finally {
      cleanup(tmpDir);
    }
  }, 180_000);

  // Test case 3: all-expired fixture — all secrets should be expired
  test("all-expired fixture: all secrets classified as expired", () => {
    const tmpDir = setupTempRepo("all-expired.json");
    try {
      const wfPath = join(tmpDir, ".github/workflows/secret-rotation-validator.yml");
      let wfContent = readFileSync(wfPath, "utf-8");
      wfContent = wfContent.replace(
        /FIXTURE_FILE:.*$/m,
        "FIXTURE_FILE: fixtures/all-expired.json"
      );
      writeFileSync(wfPath, wfContent);
      execSync("git add -A && git commit -m 'use all-expired fixture'", { cwd: tmpDir, stdio: "pipe" });

      const { exitCode, output } = runAct(tmpDir, "fixtures/all-expired.json");

      appendFileSync(ACT_RESULT_FILE, "=== ACT TEST: all-expired ===\n" + output + "\n\n");

      expect(exitCode).toBe(0);
      expect(output).toContain("Job succeeded");

      // OLD_DB_PASS: lastRotated 2025-01-01, policy 30 → expired 2025-01-31
      // days since rotation = 463, until expiry = -433
      expect(output).toContain('"name": "OLD_DB_PASS"');
      expect(output).toContain('"urgency": "expired"');
      expect(output).toContain('"daysSinceRotation": 463');
      expect(output).toContain('"daysUntilExpiry": -433');
      expect(output).toContain('"expiryDate": "2025-01-31"');

      // OLD_API_KEY: lastRotated 2025-06-15, policy 60 → expired 2025-08-14
      // days since rotation = 298, until expiry = -238
      expect(output).toContain('"name": "OLD_API_KEY"');
      expect(output).toContain('"daysSinceRotation": 298');
      expect(output).toContain('"daysUntilExpiry": -238');
      expect(output).toContain('"expiryDate": "2025-08-14"');

      // Verify no ok or warning
      expect(output).toContain('"warning": []');
      expect(output).toContain('"ok": []');

      // Markdown grouping
      expect(output).toContain("**Expired:** 2 | **Warning:** 0 | **OK:** 0");

      // Verify exact markdown table rows
      expect(output).toContain("| OLD_DB_PASS | EXPIRED | 463 | -433 | 2025-01-31 | legacy-api |");
      expect(output).toContain("| OLD_API_KEY | EXPIRED | 298 | -238 | 2025-08-14 | payments, notifications |");
    } finally {
      cleanup(tmpDir);
    }
  }, 180_000);
});
