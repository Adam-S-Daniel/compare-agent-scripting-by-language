// Workflow structure tests — validates YAML, triggers, jobs, and actionlint.

import { describe, test, expect } from "bun:test";
import { readFileSync, existsSync } from "fs";
import { parse } from "yaml";
import { join } from "path";

const WORKFLOW_PATH = join(import.meta.dir, ".github/workflows/semantic-version-bumper.yml");

describe("workflow structure", () => {
  const content = readFileSync(WORKFLOW_PATH, "utf-8");
  const workflow = parse(content);

  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("has correct name", () => {
    expect(workflow.name).toBe("Semantic Version Bumper");
  });

  test("triggers on push to main/master", () => {
    expect(workflow.on.push.branches).toContain("main");
    expect(workflow.on.push.branches).toContain("master");
  });

  test("triggers on pull_request", () => {
    expect(workflow.on.pull_request.branches).toContain("main");
  });

  test("supports workflow_dispatch", () => {
    expect(workflow.on.workflow_dispatch).toBeDefined();
  });

  test("has contents write permission", () => {
    expect(workflow.permissions.contents).toBe("write");
  });

  test("has bump-version job", () => {
    expect(workflow.jobs["bump-version"]).toBeDefined();
  });

  test("job runs on ubuntu-latest", () => {
    expect(workflow.jobs["bump-version"]["runs-on"]).toBe("ubuntu-latest");
  });

  test("job has checkout step", () => {
    const steps = workflow.jobs["bump-version"].steps;
    const checkout = steps.find((s: any) => s.uses?.startsWith("actions/checkout"));
    expect(checkout).toBeDefined();
    expect(checkout.uses).toBe("actions/checkout@v4");
  });

  test("job has bun setup step", () => {
    const steps = workflow.jobs["bump-version"].steps;
    const bun = steps.find((s: any) => s.uses?.startsWith("oven-sh/setup-bun"));
    expect(bun).toBeDefined();
  });

  test("job has install dependencies step", () => {
    const steps = workflow.jobs["bump-version"].steps;
    const install = steps.find((s: any) => s.name === "Install dependencies");
    expect(install).toBeDefined();
  });

  test("job has test step", () => {
    const steps = workflow.jobs["bump-version"].steps;
    const testStep = steps.find((s: any) => s.name === "Run unit tests");
    expect(testStep).toBeDefined();
    expect(testStep.run).toContain("bun test");
  });

  test("job runs the version bumper script", () => {
    const steps = workflow.jobs["bump-version"].steps;
    const bumpStep = steps.find((s: any) => s.name === "Run version bumper");
    expect(bumpStep).toBeDefined();
    expect(bumpStep.run).toContain("bump-version.ts");
  });

  test("referenced script files exist", () => {
    expect(existsSync(join(import.meta.dir, "bump-version.ts"))).toBe(true);
    expect(existsSync(join(import.meta.dir, "version-bumper.ts"))).toBe(true);
  });

  test("actionlint passes", () => {
    const result = Bun.spawnSync(["actionlint", WORKFLOW_PATH]);
    expect(result.exitCode).toBe(0);
  });
});
