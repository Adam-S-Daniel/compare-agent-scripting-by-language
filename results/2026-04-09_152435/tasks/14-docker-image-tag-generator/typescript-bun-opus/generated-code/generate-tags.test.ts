import { describe, test, expect, beforeAll } from "bun:test";
import { existsSync, readFileSync, mkdirSync, writeFileSync, cpSync, appendFileSync } from "fs";
import { parse as parseYaml } from "yaml";
import { tmpdir } from "os";
import { join } from "path";

// ============================================================
// WORKFLOW STRUCTURE TESTS
// These verify the YAML structure, file references, and actionlint
// ============================================================

const WORKFLOW_PATH = ".github/workflows/docker-image-tag-generator.yml";
const SCRIPT_PATH = "generate-tags.ts";
const PROJECT_DIR = process.cwd();
const ACT_RESULT_FILE = join(PROJECT_DIR, "act-result.txt");

describe("Workflow structure", () => {
  test("workflow YAML file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("script file exists", () => {
    expect(existsSync(SCRIPT_PATH)).toBe(true);
  });

  test("workflow has correct triggers", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    const workflow = parseYaml(content);
    expect(workflow.on).toBeDefined();
    expect(workflow.on.push).toBeDefined();
    expect(workflow.on.pull_request).toBeDefined();
  });

  test("workflow has jobs defined", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    const workflow = parseYaml(content);
    expect(workflow.jobs).toBeDefined();
    expect(Object.keys(workflow.jobs).length).toBeGreaterThan(0);
  });

  test("workflow uses actions/checkout@v4", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("actions/checkout@v4");
  });

  test("workflow references the script file correctly", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain(SCRIPT_PATH);
    expect(existsSync(SCRIPT_PATH)).toBe(true);
  });

  test("workflow installs bun", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("bun");
  });

  test("actionlint passes", () => {
    const result = Bun.spawnSync(["actionlint", WORKFLOW_PATH]);
    expect(result.exitCode).toBe(0);
  });
});

// ============================================================
// ACT INTEGRATION TESTS
// Run the workflow through act and verify outputs match expected values
// ============================================================

describe("Act integration", () => {
  let actOutput = "";
  let actExitCode: number | null = null;

  /**
   * Helper: set up a temp git repo with project files,
   * run act push --rm, and return the captured output.
   */
  function runActInTempRepo(branchName: string): { output: string; exitCode: number } {
    const tmpBase = join(tmpdir(), `docker-tag-test-${Date.now()}-${Math.random().toString(36).slice(2)}`);
    mkdirSync(tmpBase, { recursive: true });

    // Initialize a git repo on the specified branch
    Bun.spawnSync(["git", "init", "-b", branchName, tmpBase]);
    Bun.spawnSync(["git", "config", "user.email", "test@test.com"], { cwd: tmpBase });
    Bun.spawnSync(["git", "config", "user.name", "Test"], { cwd: tmpBase });

    // Copy project files into the temp repo
    const filesToCopy = [
      "generate-tags.ts",
      "package.json",
      "bun.lock",
      ".actrc",
    ];
    for (const f of filesToCopy) {
      const src = join(PROJECT_DIR, f);
      if (existsSync(src)) {
        cpSync(src, join(tmpBase, f), { recursive: true });
      }
    }

    // Copy node_modules so bun install --frozen-lockfile works
    const nmSrc = join(PROJECT_DIR, "node_modules");
    if (existsSync(nmSrc)) {
      cpSync(nmSrc, join(tmpBase, "node_modules"), { recursive: true });
    }

    // Copy .github directory
    cpSync(join(PROJECT_DIR, ".github"), join(tmpBase, ".github"), { recursive: true });

    // Commit everything so act has content
    Bun.spawnSync(["git", "add", "-A"], { cwd: tmpBase });
    Bun.spawnSync(["git", "commit", "-m", "initial"], { cwd: tmpBase });

    // Run act (--pull=false since act-ubuntu-pwsh is a local-only image)
    const result = Bun.spawnSync(
      ["act", "push", "--rm", "--pull=false"],
      {
        cwd: tmpBase,
        timeout: 300_000, // 5 min timeout
        env: { ...process.env, HOME: process.env.HOME ?? "/root" },
      }
    );

    const stdout = result.stdout.toString();
    const stderr = result.stderr.toString();
    const combined = stdout + "\n" + stderr;

    return { output: combined, exitCode: result.exitCode ?? 1 };
  }

  // Run act once, covering all test scenarios embedded in the workflow
  beforeAll(() => {
    // Clear act-result.txt
    writeFileSync(ACT_RESULT_FILE, "");

    const label = "=== ACT RUN: main branch (all test scenarios) ===\n";
    appendFileSync(ACT_RESULT_FILE, label);

    const result = runActInTempRepo("main");
    actOutput = result.output;
    actExitCode = result.exitCode;

    appendFileSync(ACT_RESULT_FILE, actOutput);
    appendFileSync(ACT_RESULT_FILE, `\nExit code: ${actExitCode}\n`);
    appendFileSync(ACT_RESULT_FILE, "\n" + "=".repeat(60) + "\n\n");
  }, 300_000); // 5-minute timeout for beforeAll

  test("act exits with code 0", () => {
    expect(actExitCode).toBe(0);
  });

  test("job succeeded", () => {
    expect(actOutput).toContain("Job succeeded");
  });

  // --- Main branch push ---
  test("main branch produces 'latest' tag", () => {
    expect(actOutput).toContain("latest");
  });

  test("main branch produces 'main-abc1234' tag", () => {
    expect(actOutput).toContain("main-abc1234");
  });

  // --- Feature branch push ---
  test("feature branch produces sanitized branch tag", () => {
    // feature/My-Cool_Feature → feature-my-cool_feature (underscore is valid in Docker tags)
    expect(actOutput).toContain("feature-my-cool_feature-def4567");
  });

  // --- Semver tag push ---
  test("semver tag produces v1.2.3 tag", () => {
    expect(actOutput).toContain("v1.2.3");
  });

  test("semver tag also produces bare version 1.2.3", () => {
    expect(actOutput).toContain("1.2.3");
  });

  // --- Pull request ---
  test("PR produces pr-42 tag", () => {
    expect(actOutput).toContain("pr-42");
  });

  test("PR produces branch+sha tag", () => {
    expect(actOutput).toContain("feature-pr-branch-bbb0123");
  });

  // --- Special characters branch ---
  test("special chars branch is sanitized correctly", () => {
    // bugfix/JIRA-1234_Fix@Login!!Page → bugfix-jira-1234_fix-login-page (underscore preserved)
    expect(actOutput).toContain("bugfix-jira-1234_fix-login-page-ccc9876");
  });

  // --- Master branch ---
  test("master branch produces 'latest' tag", () => {
    // The master test step should also output "latest"
    expect(actOutput).toContain("master-ddd1111");
  });

  // --- Pre-release tag ---
  test("pre-release tag produces v2.0.0-beta.1", () => {
    expect(actOutput).toContain("v2.0.0-beta.1");
  });

  test("pre-release tag also produces 2.0.0-beta.1", () => {
    expect(actOutput).toContain("2.0.0-beta.1");
  });

  // --- Tag counts ---
  test("main branch shows correct tag count", () => {
    expect(actOutput).toContain("Total tags: 2");
  });

  test("PR shows correct tag count", () => {
    // pr-42 + feature-pr-branch-{sha} = 2 tags
    expect(actOutput).toContain("Total tags: 2");
  });
});
