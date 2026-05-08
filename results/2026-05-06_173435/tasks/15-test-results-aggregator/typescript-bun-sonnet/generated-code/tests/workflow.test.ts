// Workflow structure tests: YAML parsing, file existence, actionlint validation
// These tests verify the workflow is correctly structured and references real files

import { test, expect, describe } from "bun:test";
import { readFileSync, existsSync } from "fs";
import { execSync } from "child_process";
import { join } from "path";

const ROOT = join(import.meta.dir, "..");
const WORKFLOW_PATH = join(ROOT, ".github/workflows/test-results-aggregator.yml");

describe("Workflow file", () => {
  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("workflow has push trigger", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("push:");
  });

  test("workflow has pull_request trigger", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("pull_request");
  });

  test("workflow has workflow_dispatch trigger", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("workflow_dispatch");
  });

  test("workflow references checkout action", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("actions/checkout@v4");
  });

  test("workflow references main.ts", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("main.ts");
  });

  test("workflow runs unit tests explicitly", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("parsers.test.ts");
  });

  test("workflow references fixture files", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("fixtures/junit-run1.xml");
    expect(content).toContain("fixtures/junit-run2.xml");
    expect(content).toContain("fixtures/results-run3.json");
  });

  test("workflow has at least one job", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("jobs:");
  });

  test("actionlint passes with exit code 0", () => {
    let exitCode = 0;
    let output = "";
    try {
      output = execSync(`actionlint "${WORKFLOW_PATH}"`, { encoding: "utf-8" });
    } catch (err: unknown) {
      const execErr = err as { status?: number; stdout?: string; stderr?: string };
      exitCode = execErr.status ?? 1;
      output = (execErr.stdout ?? "") + (execErr.stderr ?? "");
    }
    expect(exitCode).toBe(0);
    if (output.trim()) {
      console.log("actionlint output:", output);
    }
  });
});

describe("Script and fixture files exist", () => {
  test("main.ts exists", () => {
    expect(existsSync(join(ROOT, "main.ts"))).toBe(true);
  });

  test("src/parsers.ts exists", () => {
    expect(existsSync(join(ROOT, "src/parsers.ts"))).toBe(true);
  });

  test("src/aggregator.ts exists", () => {
    expect(existsSync(join(ROOT, "src/aggregator.ts"))).toBe(true);
  });

  test("src/markdown.ts exists", () => {
    expect(existsSync(join(ROOT, "src/markdown.ts"))).toBe(true);
  });

  test("fixtures/junit-run1.xml exists", () => {
    expect(existsSync(join(ROOT, "fixtures/junit-run1.xml"))).toBe(true);
  });

  test("fixtures/junit-run2.xml exists", () => {
    expect(existsSync(join(ROOT, "fixtures/junit-run2.xml"))).toBe(true);
  });

  test("fixtures/results-run3.json exists", () => {
    expect(existsSync(join(ROOT, "fixtures/results-run3.json"))).toBe(true);
  });
});
