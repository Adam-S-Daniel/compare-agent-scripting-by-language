// Workflow structure tests and act integration tests
// Verifies the GitHub Actions workflow YAML has correct structure,
// references valid files, passes actionlint, and runs correctly via act.

import { describe, expect, test } from "bun:test";
import { readFileSync, existsSync, writeFileSync, mkdirSync } from "fs";
import { execSync, spawnSync } from "child_process";
import { join } from "path";
import * as yaml from "js-yaml";

const WORKFLOW_PATH = ".github/workflows/secret-rotation-validator.yml";
const CWD = process.cwd();

// --- Workflow structure tests ---

describe("workflow structure", () => {
  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("workflow YAML is valid", () => {
    const raw = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(() => yaml.load(raw)).not.toThrow();
  });

  test("workflow has correct trigger events", () => {
    const raw = readFileSync(WORKFLOW_PATH, "utf-8");
    const wf = yaml.load(raw) as Record<string, unknown>;
    const on = wf["on"] as Record<string, unknown>;
    expect(on).toHaveProperty("push");
    expect(on).toHaveProperty("pull_request");
    expect(on).toHaveProperty("schedule");
    expect(on).toHaveProperty("workflow_dispatch");
  });

  test("workflow has validate-secrets job", () => {
    const raw = readFileSync(WORKFLOW_PATH, "utf-8");
    const wf = yaml.load(raw) as Record<string, unknown>;
    const jobs = wf["jobs"] as Record<string, unknown>;
    expect(jobs).toHaveProperty("validate-secrets");
  });

  test("validate-secrets job has checkout step", () => {
    const raw = readFileSync(WORKFLOW_PATH, "utf-8");
    const wf = yaml.load(raw) as Record<string, unknown>;
    const jobs = wf["jobs"] as Record<string, { steps: Array<{ uses?: string; name?: string }> }>;
    const steps = jobs["validate-secrets"].steps;
    const checkoutStep = steps.find((s) => s.uses?.startsWith("actions/checkout"));
    expect(checkoutStep).toBeDefined();
  });

  test("validate-secrets job has bun setup step", () => {
    const raw = readFileSync(WORKFLOW_PATH, "utf-8");
    const wf = yaml.load(raw) as Record<string, unknown>;
    const jobs = wf["jobs"] as Record<string, { steps: Array<{ uses?: string; name?: string }> }>;
    const steps = jobs["validate-secrets"].steps;
    const bunStep = steps.find((s) => s.uses?.startsWith("oven-sh/setup-bun"));
    expect(bunStep).toBeDefined();
  });

  test("workflow references existing script files", () => {
    // These files must exist for the workflow to run
    expect(existsSync("src/main.ts")).toBe(true);
    expect(existsSync("src/validator.ts")).toBe(true);
    expect(existsSync("src/assert-report.ts")).toBe(true);
    expect(existsSync("src/prepare-config.ts")).toBe(true);
    expect(existsSync("fixtures/secrets-mixed.json")).toBe(true);
  });

  test("actionlint passes on the workflow", () => {
    const result = spawnSync("actionlint", [WORKFLOW_PATH], { encoding: "utf-8" });
    if (result.error) {
      throw new Error(`actionlint not found: ${result.error.message}`);
    }
    expect(result.stdout).toBe("");
    expect(result.status).toBe(0);
  });
});

// --- Act integration test ---
// Runs the workflow via act in a temp git repo and asserts on exact output values.

describe("act integration", () => {
  test("workflow runs successfully and produces correct output", () => {
    // Set up a temp git repo with our project files
    const tmpDir = "/tmp/secret-rotation-act-test";
    execSync(`rm -rf ${tmpDir} && mkdir -p ${tmpDir}`);

    // Copy project files into temp repo
    execSync(`cp -r ${CWD}/src ${tmpDir}/src`);
    execSync(`cp -r ${CWD}/fixtures ${tmpDir}/fixtures`);
    execSync(`cp -r ${CWD}/.github ${tmpDir}/.github`);
    // Copy actrc if present
    if (existsSync(join(CWD, ".actrc"))) {
      execSync(`cp ${CWD}/.actrc ${tmpDir}/.actrc`);
    }

    // Initialize git repo (act requires a git repo)
    execSync("git init && git config user.email 'test@test.com' && git config user.name 'Test'", {
      cwd: tmpDir,
    });
    execSync("git add -A && git commit -m 'test'", { cwd: tmpDir });

    // Run act and capture output (uses .actrc for image mapping, no pull for local image)
    const actResult = spawnSync(
      "act",
      ["push", "--rm", "--job", "validate-secrets", "--pull=false"],
      {
        cwd: tmpDir,
        encoding: "utf-8",
        timeout: 300_000, // 5 minutes
      }
    );

    const output = (actResult.stdout ?? "") + (actResult.stderr ?? "");

    // Save act output to act-result.txt (append with delimiter)
    const delimiter = `\n${"=".repeat(80)}\nTEST CASE: act integration\n${"=".repeat(80)}\n`;
    const resultPath = join(CWD, "act-result.txt");
    const existingContent = existsSync(resultPath) ? readFileSync(resultPath, "utf-8") : "";
    writeFileSync(resultPath, existingContent + delimiter + output);

    // Assert act exited successfully
    expect(actResult.status).toBe(0);

    // Assert job succeeded
    expect(output).toContain("Job succeeded");

    // Assert exact expected values appear in output
    expect(output).toContain("Expired secrets: 1 (DB_PASSWORD, daysUntilExpiry=-14)");
    expect(output).toContain("Warning secrets: 1 (API_KEY, daysUntilExpiry=3)");
    expect(output).toContain("OK secrets: 1 (JWT_SECRET, daysUntilExpiry=76)");
    expect(output).toContain("All assertions passed");
  }, 300_000);
});
