// Workflow-structure tests: parse the YAML and confirm the expected
// triggers, jobs, steps, and script paths exist. Also run actionlint and
// assert its exit code is 0. These tests are pure — no Docker needed —
// so they run in the default `bun test` suite.

import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { parse as parseYaml } from "yaml";

const repoRoot = join(import.meta.dir, "..");
const workflowPath = join(repoRoot, ".github/workflows/dependency-license-checker.yml");

type WorkflowStep = { name?: string; uses?: string; run?: string };
type Workflow = {
  on: Record<string, unknown>;
  jobs: Record<string, { steps: WorkflowStep[]; "runs-on": string }>;
};

function loadWorkflow(): Workflow {
  return parseYaml(readFileSync(workflowPath, "utf8")) as Workflow;
}

describe("workflow YAML structure", () => {
  test("file exists at the expected path", () => {
    expect(existsSync(workflowPath)).toBe(true);
  });

  test("declares push, pull_request, schedule, and workflow_dispatch triggers", () => {
    const wf = loadWorkflow();
    expect(Object.keys(wf.on).sort()).toEqual([
      "pull_request",
      "push",
      "schedule",
      "workflow_dispatch",
    ]);
  });

  test("declares a single license-check job running on ubuntu-latest", () => {
    const wf = loadWorkflow();
    expect(Object.keys(wf.jobs)).toEqual(["license-check"]);
    expect(wf.jobs["license-check"]?.["runs-on"]).toBe("ubuntu-latest");
  });

  test("uses actions/checkout@v4 as the first step", () => {
    const wf = loadWorkflow();
    const steps = wf.jobs["license-check"]!.steps;
    expect(steps[0]?.uses).toBe("actions/checkout@v4");
  });

  test("has a step that runs the CLI against the fixture files", () => {
    const wf = loadWorkflow();
    const steps = wf.jobs["license-check"]!.steps;
    const runStep = steps.find((s) => s.run?.includes("src/cli.ts"));
    expect(runStep).toBeDefined();
    expect(runStep?.run).toContain("--manifest fixtures/manifest.json");
    expect(runStep?.run).toContain("--config fixtures/policy.json");
  });

  test("references scripts and fixtures that exist on disk", () => {
    expect(existsSync(join(repoRoot, "src/cli.ts"))).toBe(true);
    expect(existsSync(join(repoRoot, "fixtures/manifest.json"))).toBe(true);
    expect(existsSync(join(repoRoot, "fixtures/policy.json"))).toBe(true);
  });
});

describe("actionlint", () => {
  // actionlint is a host-side lint check — when the binary isn't on PATH
  // (e.g. inside the act container the workflow itself runs in), skip
  // instead of hard-failing. The same test run on the host still asserts
  // actionlint exits 0, which is what we care about.
  const hasActionlint = spawnSync("actionlint", ["-version"], { encoding: "utf8" }).status === 0;
  const maybeTest: typeof test = hasActionlint ? test : test.skip;

  maybeTest("passes on the workflow file", () => {
    const result = spawnSync("actionlint", [workflowPath], {
      encoding: "utf8",
    });
    if (result.status !== 0) {
      // Surface stdout + stderr so a failure is self-explanatory.
      throw new Error(
        `actionlint exited ${result.status}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`,
      );
    }
    expect(result.status).toBe(0);
  });
});
