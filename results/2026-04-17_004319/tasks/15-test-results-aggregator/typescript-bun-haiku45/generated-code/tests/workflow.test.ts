import { describe, it, expect } from "bun:test";
import { readFileSync, existsSync } from "fs";
import { resolve } from "path";

describe("Workflow Structure Tests", () => {
  it("should have workflow file at correct location", () => {
    const workflowPath = resolve(
      process.cwd(),
      ".github/workflows/test-results-aggregator.yml"
    );
    const exists = existsSync(workflowPath);
    expect(exists).toBe(true);
  });

  it("should have valid YAML workflow structure", () => {
    const workflowPath = resolve(
      process.cwd(),
      ".github/workflows/test-results-aggregator.yml"
    );
    const content = readFileSync(workflowPath, "utf-8");

    // Check for required YAML structure
    expect(content).toContain("name: Test Results Aggregator");
    expect(content).toContain("on:");
    expect(content).toContain("jobs:");
    expect(content).toContain("test:");
    expect(content).toContain("validate-workflow:");
  });

  it("should reference script files correctly", () => {
    const workflowPath = resolve(
      process.cwd(),
      ".github/workflows/test-results-aggregator.yml"
    );
    const content = readFileSync(workflowPath, "utf-8");

    // Check for script references
    expect(content).toContain("src/parser.ts");
    expect(content).toContain("src/aggregator.ts");
    expect(content).toContain("src/markdown.ts");
    expect(content).toContain("src/main.ts");
  });

  it("should include required triggers", () => {
    const workflowPath = resolve(
      process.cwd(),
      ".github/workflows/test-results-aggregator.yml"
    );
    const content = readFileSync(workflowPath, "utf-8");

    expect(content).toContain("push:");
    expect(content).toContain("pull_request:");
    expect(content).toContain("schedule:");
    expect(content).toContain("workflow_dispatch:");
  });

  it("should include proper permissions", () => {
    const workflowPath = resolve(
      process.cwd(),
      ".github/workflows/test-results-aggregator.yml"
    );
    const content = readFileSync(workflowPath, "utf-8");

    expect(content).toContain("permissions:");
    expect(content).toContain("contents: read");
    expect(content).toContain("checks: write");
  });

  it("should reference actions/checkout@v4", () => {
    const workflowPath = resolve(
      process.cwd(),
      ".github/workflows/test-results-aggregator.yml"
    );
    const content = readFileSync(workflowPath, "utf-8");

    expect(content).toContain("actions/checkout@v4");
  });

  it("should use GITHUB_STEP_SUMMARY for output", () => {
    const workflowPath = resolve(
      process.cwd(),
      ".github/workflows/test-results-aggregator.yml"
    );
    const content = readFileSync(workflowPath, "utf-8");

    expect(content).toContain("GITHUB_STEP_SUMMARY");
  });

  it("should have all required script files", () => {
    const files = [
      "src/parser.ts",
      "src/aggregator.ts",
      "src/markdown.ts",
      "src/main.ts",
    ];

    for (const file of files) {
      const path = resolve(process.cwd(), file);
      const exists = existsSync(path);
      expect(exists).toBe(true);
    }
  });

  it("should have fixture files", () => {
    const files = [
      "fixtures/junit-run1.xml",
      "fixtures/junit-run2.xml",
      "fixtures/results-run3.json",
    ];

    for (const file of files) {
      const path = resolve(process.cwd(), file);
      const exists = existsSync(path);
      expect(exists).toBe(true);
    }
  });

  it("should have package.json with bun test script", () => {
    const packagePath = resolve(process.cwd(), "package.json");
    const content = JSON.parse(readFileSync(packagePath, "utf-8"));

    expect(content.scripts).toBeDefined();
    expect(content.scripts.test).toBe("bun test");
  });
});
