// Workflow tests: structure validation, actionlint, and act execution.
// All actual label-assignment testing goes through the GitHub Actions pipeline via act.

import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import { spawnSync } from "child_process";
import yaml from "js-yaml";

const WORKSPACE = import.meta.dir;
const WORKFLOW_PATH = path.join(WORKSPACE, ".github/workflows/pr-label-assigner.yml");
const ACT_RESULT_PATH = path.join(WORKSPACE, "act-result.txt");

// ── Workflow structure tests ──────────────────────────────────────────────────

describe("workflow structure", () => {
  let wf: Record<string, unknown>;

  beforeAll(() => {
    const raw = fs.readFileSync(WORKFLOW_PATH, "utf-8");
    wf = yaml.load(raw) as Record<string, unknown>;
  });

  test("workflow file exists", () => {
    expect(fs.existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("workflow has push trigger", () => {
    const on = wf["on"] as Record<string, unknown>;
    expect(on).toHaveProperty("push");
  });

  test("workflow has pull_request trigger", () => {
    const on = wf["on"] as Record<string, unknown>;
    expect(on).toHaveProperty("pull_request");
  });

  test("workflow has workflow_dispatch trigger", () => {
    const on = wf["on"] as Record<string, unknown>;
    expect(on).toHaveProperty("workflow_dispatch");
  });

  test("workflow has assign-labels job", () => {
    const jobs = wf["jobs"] as Record<string, unknown>;
    expect(jobs).toHaveProperty("assign-labels");
  });

  test("assign-labels job has checkout step", () => {
    const jobs = wf["jobs"] as Record<string, unknown>;
    const job = jobs["assign-labels"] as Record<string, unknown>;
    const steps = job["steps"] as Array<Record<string, unknown>>;
    const checkout = steps.find((s) => String(s["uses"] ?? "").startsWith("actions/checkout"));
    expect(checkout).toBeDefined();
  });

  test("assign-labels job has bun setup step", () => {
    const jobs = wf["jobs"] as Record<string, unknown>;
    const job = jobs["assign-labels"] as Record<string, unknown>;
    const steps = job["steps"] as Array<Record<string, unknown>>;
    const bunStep = steps.find((s) => String(s["uses"] ?? "").startsWith("oven-sh/setup-bun"));
    expect(bunStep).toBeDefined();
  });

  test("assign-labels job has step that runs pr-label-assigner.ts", () => {
    const jobs = wf["jobs"] as Record<string, unknown>;
    const job = jobs["assign-labels"] as Record<string, unknown>;
    const steps = job["steps"] as Array<Record<string, unknown>>;
    const runStep = steps.find((s) =>
      String(s["run"] ?? "").includes("pr-label-assigner.ts")
    );
    expect(runStep).toBeDefined();
  });

  test("referenced script file exists", () => {
    expect(fs.existsSync(path.join(WORKSPACE, "pr-label-assigner.ts"))).toBe(true);
  });

  test("label-rules.json exists", () => {
    expect(fs.existsSync(path.join(WORKSPACE, "label-rules.json"))).toBe(true);
  });

  test("actionlint passes on workflow file", () => {
    const result = spawnSync("actionlint", [WORKFLOW_PATH], { encoding: "utf-8" });
    expect(result.status).toBe(0);
    expect(result.stdout).toBe("");
  });
});

// ── Helpers for act test cases ────────────────────────────────────────────────

// Files to copy from workspace into each temp git repo for act runs
const PROJECT_FILES = [
  "pr-label-assigner.ts",
  "label-rules.json",
  "package.json",
  "bun.lockb",
];

interface ActTestCase {
  name: string;
  fixtureFile: string;        // path within fixtures/
  expectedLabels: string;     // exact "Labels: ..." substring expected in act output
}

const TEST_CASES: ActTestCase[] = [
  {
    name: "Case 1: docs only",
    fixtureFile: "fixtures/case1-docs-only.txt",
    expectedLabels: "Labels: documentation",
  },
  {
    name: "Case 2: api and tests",
    fixtureFile: "fixtures/case2-api-and-tests.txt",
    // api(5) > tests(3) > source(1); src/api/** also triggers source for api files
    expectedLabels: "Labels: api, tests, source",
  },
  {
    name: "Case 3: mixed docs, api, tests, source",
    fixtureFile: "fixtures/case3-mixed.txt",
    // documentation(10) > api(5) > tests(3) > source(1)
    expectedLabels: "Labels: documentation, api, tests, source",
  },
];

function setupTempRepo(testCase: ActTestCase): string {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "pr-label-act-"));

  // Copy project files
  for (const file of PROJECT_FILES) {
    const src = path.join(WORKSPACE, file);
    if (fs.existsSync(src)) {
      fs.mkdirSync(path.dirname(path.join(tmpDir, file)), { recursive: true });
      fs.copyFileSync(src, path.join(tmpDir, file));
    }
  }

  // Copy node_modules (bun install cache) to avoid re-downloading in act
  // Actually, let act install via bun install; lockfile is enough

  // Copy the workflow file
  const wfDir = path.join(tmpDir, ".github/workflows");
  fs.mkdirSync(wfDir, { recursive: true });
  fs.copyFileSync(WORKFLOW_PATH, path.join(wfDir, "pr-label-assigner.yml"));

  // Copy .actrc
  const actrc = path.join(WORKSPACE, ".actrc");
  if (fs.existsSync(actrc)) {
    fs.copyFileSync(actrc, path.join(tmpDir, ".actrc"));
  }

  // Write changed-files.txt from the fixture
  const fixtureContent = fs.readFileSync(path.join(WORKSPACE, testCase.fixtureFile), "utf-8");
  fs.writeFileSync(path.join(tmpDir, "changed-files.txt"), fixtureContent);

  // Initialize git repo and commit everything
  const gitOpts = { cwd: tmpDir, encoding: "utf-8" as const };
  spawnSync("git", ["init"], gitOpts);
  spawnSync("git", ["config", "user.email", "test@test.com"], gitOpts);
  spawnSync("git", ["config", "user.name", "Test"], gitOpts);
  spawnSync("git", ["add", "-A"], gitOpts);
  spawnSync("git", ["commit", "-m", `test: ${testCase.name}`], gitOpts);

  return tmpDir;
}

// ── Act execution tests ───────────────────────────────────────────────────────
// Each test case runs act push in an isolated temp git repo.
// Output is appended to act-result.txt.

// Clear act-result.txt at the start of the test run
beforeAll(() => {
  fs.writeFileSync(ACT_RESULT_PATH, "");
});

describe("act pipeline execution", () => {
  // Long timeout: act takes 30-90s per run
  const ACT_TIMEOUT_MS = 120_000;

  for (const testCase of TEST_CASES) {
    test(
      testCase.name,
      () => {
        const tmpDir = setupTempRepo(testCase);

        const delimiter = `\n${"=".repeat(60)}\n${testCase.name}\n${"=".repeat(60)}\n`;
        fs.appendFileSync(ACT_RESULT_PATH, delimiter);

        const result = spawnSync(
          "act",
          ["push", "--rm", "--pull=false"],
          {
            cwd: tmpDir,
            encoding: "utf-8",
            timeout: ACT_TIMEOUT_MS,
          }
        );

        const combined = (result.stdout ?? "") + (result.stderr ?? "");
        fs.appendFileSync(ACT_RESULT_PATH, combined);
        fs.appendFileSync(ACT_RESULT_PATH, `\n[exit code: ${result.status}]\n`);

        // Assert act exited successfully
        if (result.status !== 0) {
          console.error("act failed for:", testCase.name);
          console.error("stdout:", result.stdout?.slice(-3000));
          console.error("stderr:", result.stderr?.slice(-3000));
        }
        expect(result.status).toBe(0);

        // Assert "Job succeeded" appeared in output
        expect(combined).toContain("Job succeeded");

        // Assert exact expected label output
        expect(combined).toContain(testCase.expectedLabels);

        // Cleanup temp dir
        fs.rmSync(tmpDir, { recursive: true, force: true });
      },
      ACT_TIMEOUT_MS
    );
  }
});
