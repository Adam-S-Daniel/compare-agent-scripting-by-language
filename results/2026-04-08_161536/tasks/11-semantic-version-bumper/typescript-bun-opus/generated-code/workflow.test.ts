// Tests for the GitHub Actions workflow file

import { describe, test, expect } from "bun:test";
import { parse as parseYaml } from "yaml";
import { existsSync } from "node:fs";
import { resolve } from "node:path";

const WORKFLOW_PATH = ".github/workflows/semantic-version-bumper.yml";

// Load and parse the workflow once
const workflowContent = await Bun.file(WORKFLOW_PATH).text();
const workflow = parseYaml(workflowContent);

describe("workflow structure", () => {
  test("has a valid name", () => {
    expect(workflow.name).toBe("Semantic Version Bumper");
  });

  test("has correct trigger events", () => {
    expect(workflow.on).toBeDefined();
    expect(workflow.on.push).toBeDefined();
    expect(workflow.on.pull_request).toBeDefined();
    expect(workflow.on.workflow_dispatch).toBeDefined();
  });

  test("push trigger targets main/master branches", () => {
    expect(workflow.on.push.branches).toContain("main");
  });

  test("has permissions defined", () => {
    expect(workflow.permissions).toBeDefined();
    expect(workflow.permissions.contents).toBe("write");
  });
});

describe("jobs", () => {
  test("defines test and bump-version jobs", () => {
    expect(workflow.jobs.test).toBeDefined();
    expect(workflow.jobs["bump-version"]).toBeDefined();
  });

  test("bump-version depends on test job", () => {
    expect(workflow.jobs["bump-version"].needs).toBe("test");
  });

  test("bump-version only runs on push to main", () => {
    expect(workflow.jobs["bump-version"].if).toContain("push");
    expect(workflow.jobs["bump-version"].if).toContain("refs/heads/main");
  });
});

describe("test job steps", () => {
  const steps = workflow.jobs.test.steps;

  test("checks out code with actions/checkout@v4", () => {
    const checkout = steps.find(
      (s: { uses?: string }) => s.uses && s.uses.startsWith("actions/checkout")
    );
    expect(checkout).toBeDefined();
    expect(checkout.uses).toBe("actions/checkout@v4");
  });

  test("installs Bun", () => {
    const bunSetup = steps.find(
      (s: { uses?: string }) => s.uses && s.uses.includes("setup-bun")
    );
    expect(bunSetup).toBeDefined();
  });

  test("runs bun test", () => {
    const testStep = steps.find(
      (s: { run?: string }) => s.run && s.run.includes("bun test")
    );
    expect(testStep).toBeDefined();
  });
});

describe("bump-version job steps", () => {
  const steps = workflow.jobs["bump-version"].steps;

  test("checks out with full history (fetch-depth: 0)", () => {
    const checkout = steps.find(
      (s: { uses?: string }) => s.uses && s.uses.startsWith("actions/checkout")
    );
    expect(checkout).toBeDefined();
    expect(checkout.with["fetch-depth"]).toBe(0);
  });

  test("references bumper.ts script correctly", () => {
    const bumperStep = steps.find(
      (s: { run?: string }) => s.run && s.run.includes("bumper.ts")
    );
    expect(bumperStep).toBeDefined();
  });

  test("bumper.ts file actually exists", () => {
    expect(existsSync(resolve("bumper.ts"))).toBe(true);
  });

  test("step outputs are wired between commits and bumper steps", () => {
    const commitsStep = steps.find((s: { id?: string }) => s.id === "commits");
    const bumperStep = steps.find((s: { id?: string }) => s.id === "bumper");
    expect(commitsStep).toBeDefined();
    expect(bumperStep).toBeDefined();
    // Bumper step should reference commits step output
    expect(bumperStep.run).toContain("steps.commits.outputs");
  });

  test("bumper step output is used in final step", () => {
    const outputStep = steps.find(
      (s: { run?: string }) => s.run && s.run.includes("steps.bumper.outputs")
    );
    expect(outputStep).toBeDefined();
  });
});

describe("actionlint validation", () => {
  test("workflow passes actionlint", () => {
    // Check if actionlint is available (may not be in CI containers)
    const which = Bun.spawnSync(["which", "actionlint"]);
    if (which.exitCode !== 0) {
      console.log("actionlint not found, skipping validation");
      return;
    }
    const proc = Bun.spawnSync(["actionlint", WORKFLOW_PATH]);
    const stderr = proc.stderr.toString();
    if (stderr) console.log("actionlint output:", stderr);
    expect(proc.exitCode).toBe(0);
  });
});
