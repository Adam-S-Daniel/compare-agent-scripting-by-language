// Act test harness: runs the GitHub Actions workflow via `act` and asserts on output.
// This is the integration test layer — all functional tests run through the CI pipeline.

import { describe, test, expect, beforeAll } from "bun:test";
import { readFileSync, existsSync, appendFileSync, writeFileSync } from "fs";
import { execSync, spawnSync } from "child_process";
import * as path from "path";
import * as yaml from "js-yaml";

const WORKSPACE = path.resolve(import.meta.dir);
const WORKFLOW_PATH = path.join(WORKSPACE, ".github/workflows/pr-label-assigner.yml");
const ACT_RESULT_PATH = path.join(WORKSPACE, "act-result.txt");

// Helper: append a delimited section to act-result.txt
function appendActResult(label: string, output: string): void {
  const divider = "=".repeat(60);
  appendFileSync(
    ACT_RESULT_PATH,
    `\n${divider}\nTEST CASE: ${label}\n${divider}\n${output}\n`
  );
}

// ─── Workflow structure tests (no act needed, instant) ──────────────────────

describe("workflow structure", () => {
  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("workflow has correct triggers", () => {
    const raw = readFileSync(WORKFLOW_PATH, "utf8");
    const wf = yaml.load(raw) as Record<string, unknown>;
    const on = wf["on"] as Record<string, unknown>;
    expect(on).toHaveProperty("push");
    expect(on).toHaveProperty("pull_request");
    expect(on).toHaveProperty("workflow_dispatch");
  });

  test("workflow has test and assign-labels jobs", () => {
    const raw = readFileSync(WORKFLOW_PATH, "utf8");
    const wf = yaml.load(raw) as Record<string, unknown>;
    const jobs = wf["jobs"] as Record<string, unknown>;
    expect(jobs).toHaveProperty("test");
    expect(jobs).toHaveProperty("assign-labels");
  });

  test("test job runs bun test on label-assigner.test.ts", () => {
    const raw = readFileSync(WORKFLOW_PATH, "utf8");
    const wf = yaml.load(raw) as Record<string, unknown>;
    const jobs = wf["jobs"] as Record<string, { steps: Array<{ run?: string }> }>;
    const testJob = jobs["test"];
    const testStep = testJob.steps.find((s) => s.run?.includes("bun test"));
    expect(testStep).toBeDefined();
    expect(testStep!.run).toContain("label-assigner.test.ts");
  });

  test("assign-labels job runs the label-assigner script", () => {
    const raw = readFileSync(WORKFLOW_PATH, "utf8");
    const wf = yaml.load(raw) as Record<string, unknown>;
    const jobs = wf["jobs"] as Record<string, { steps: Array<{ run?: string }> }>;
    const labelJob = jobs["assign-labels"];
    const runStep = labelJob.steps.find((s) => s.run?.includes("label-assigner.ts"));
    expect(runStep).toBeDefined();
  });

  test("assign-labels job depends on test job", () => {
    const raw = readFileSync(WORKFLOW_PATH, "utf8");
    const wf = yaml.load(raw) as Record<string, unknown>;
    const jobs = wf["jobs"] as Record<string, { needs?: string | string[] }>;
    const labelJob = jobs["assign-labels"];
    const needs = labelJob.needs;
    const needsArr = Array.isArray(needs) ? needs : [needs];
    expect(needsArr).toContain("test");
  });

  test("script files referenced by workflow exist", () => {
    expect(existsSync(path.join(WORKSPACE, "label-assigner.ts"))).toBe(true);
    expect(existsSync(path.join(WORKSPACE, "label-assigner.test.ts"))).toBe(true);
  });

  test("actionlint passes on workflow", () => {
    const result = spawnSync("actionlint", [WORKFLOW_PATH], { encoding: "utf8" });
    if (result.stdout || result.stderr) {
      console.log("actionlint stdout:", result.stdout);
      console.log("actionlint stderr:", result.stderr);
    }
    expect(result.status).toBe(0);
  });
});

// ─── Act integration test ────────────────────────────────────────────────────

describe("act integration", () => {
  let actOutput = "";
  let actExitCode = -1;

  // 5-minute timeout for the act run in beforeAll
  beforeAll(() => {
    // Initialize act-result.txt fresh for this run
    writeFileSync(ACT_RESULT_PATH, `PR Label Assigner - act test run\nDate: ${new Date().toISOString()}\n`);

    // Run act push --rm; capture combined stdout+stderr
    const result = spawnSync(
      "act",
      ["push", "--rm", "--no-cache-server", "--pull=false"],
      {
        cwd: WORKSPACE,
        encoding: "utf8",
        timeout: 300_000, // 5 minutes
        maxBuffer: 20 * 1024 * 1024,
      }
    );
    actOutput = (result.stdout ?? "") + (result.stderr ?? "");
    actExitCode = result.status ?? 1;

    appendActResult("act push (full workflow)", actOutput);
  }, 300_000); // 5-minute timeout for the act run

  test("act exits with code 0", () => {
    if (actExitCode !== 0) {
      console.log("=== ACT OUTPUT (last 3000 chars) ===");
      console.log(actOutput.slice(-3000));
    }
    expect(actExitCode).toBe(0);
  });

  test("test job succeeds", () => {
    expect(actOutput).toContain("Job succeeded");
  });

  test("bun tests all pass inside the workflow", () => {
    // bun test reports "X pass" — check that at least 15 tests pass
    const passMatch = actOutput.match(/(\d+)\s+pass/);
    expect(passMatch).not.toBeNull();
    const passed = parseInt(passMatch![1]!, 10);
    expect(passed).toBeGreaterThanOrEqual(15);
  });

  test("zero failing tests", () => {
    // bun test reports "X fail" only when there are failures
    const failMatch = actOutput.match(/(\d+)\s+fail/);
    if (failMatch) {
      expect(parseInt(failMatch[1]!, 10)).toBe(0);
    }
    // No match is also fine (means no failures reported)
  });

  test("label assigner produces correct label set for default fixture", () => {
    // The assign-labels job runs the script with the default fixture
    // Files: docs/api-guide.md src/api/users.ts src/api/users.test.ts src/utils.ts
    // Expected labels (in priority order): api, tests, documentation, source
    expect(actOutput).toContain('"api"');
    expect(actOutput).toContain('"tests"');
    expect(actOutput).toContain('"documentation"');
    expect(actOutput).toContain('"source"');
  });

  test("label set output contains exact JSON array", () => {
    // The script outputs: Label set: ["api","tests","documentation","source"]
    expect(actOutput).toContain('Label set:');
    const match = actOutput.match(/Label set: (\[.*?\])/);
    expect(match).not.toBeNull();
    const labelSet = JSON.parse(match![1]!) as string[];
    expect(labelSet).toContain("api");
    expect(labelSet).toContain("tests");
    expect(labelSet).toContain("documentation");
    expect(labelSet).toContain("source");
    // api has priority 3 (highest) so it should be first
    expect(labelSet[0]).toBe("api");
  });
});
