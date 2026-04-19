import { describe, it, expect } from "bun:test";
import { readFile } from "fs/promises";
import { parse as parseYaml } from "yaml";

describe("GitHub Actions Workflow", () => {
  it("should have valid workflow file", async () => {
    const workflowPath = ".github/workflows/semantic-version-bumper.yml";
    const content = await readFile(workflowPath, "utf-8");
    expect(content).toBeDefined();
    expect(content.length).toBeGreaterThan(0);
  });

  it("should have correct workflow triggers", async () => {
    const workflowPath = ".github/workflows/semantic-version-bumper.yml";
    const content = await readFile(workflowPath, "utf-8");
    const yaml = parseYaml(content) as Record<string, any>;

    expect(yaml.name).toBe("Semantic Version Bumper");
    expect(yaml.on).toBeDefined();
    expect(yaml.on.push).toBeDefined();
    expect(yaml.on.pull_request).toBeDefined();
    expect(yaml.on.workflow_dispatch).toBeDefined();
  });

  it("should have test and bump-version jobs", async () => {
    const workflowPath = ".github/workflows/semantic-version-bumper.yml";
    const content = await readFile(workflowPath, "utf-8");
    const yaml = parseYaml(content) as Record<string, any>;

    expect(yaml.jobs).toBeDefined();
    expect(yaml.jobs.test).toBeDefined();
    expect(yaml.jobs["bump-version"]).toBeDefined();
  });

  it("should run bun test in test job", async () => {
    const workflowPath = ".github/workflows/semantic-version-bumper.yml";
    const content = await readFile(workflowPath, "utf-8");
    const yaml = parseYaml(content) as Record<string, any>;

    const testSteps = yaml.jobs.test.steps;
    const runTestsStep = testSteps.find(
      (step: Record<string, any>) => step.name === "Run unit tests"
    );

    expect(runTestsStep).toBeDefined();
    expect(runTestsStep.run).toContain("bun test");
  });

  it("should reference script files correctly", async () => {
    const workflowPath = ".github/workflows/semantic-version-bumper.yml";
    const content = await readFile(workflowPath, "utf-8");

    expect(content).toContain("./src/index.ts");
    expect(content).toContain("package.json");
  });

  it("should include proper permissions", async () => {
    const workflowPath = ".github/workflows/semantic-version-bumper.yml";
    const content = await readFile(workflowPath, "utf-8");
    const yaml = parseYaml(content) as Record<string, any>;

    expect(yaml.permissions).toBeDefined();
    expect(yaml.permissions.contents).toBe("read");
  });
});
