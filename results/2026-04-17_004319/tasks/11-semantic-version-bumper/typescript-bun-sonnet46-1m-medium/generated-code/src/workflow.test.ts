// Tests for GitHub Actions workflow structure validation

import { test, expect, describe } from "bun:test";
import { readFileSync, existsSync } from "fs";
import { join } from "path";
import { spawnSync } from "child_process";

const ROOT = join(import.meta.dir, "..");
const WORKFLOW_PATH = join(ROOT, ".github/workflows/semantic-version-bumper.yml");

describe("workflow structure", () => {
  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("workflow YAML is valid (actionlint exits 0)", () => {
    const result = spawnSync("actionlint", [WORKFLOW_PATH], { encoding: "utf8" });
    if (result.status !== 0) {
      console.error("actionlint output:", result.stdout, result.stderr);
    }
    expect(result.status).toBe(0);
  });

  test("workflow references correct script path", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("src/main.ts");
  });

  test("workflow has push trigger", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("push:");
  });

  test("workflow has workflow_dispatch trigger", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("workflow_dispatch");
  });

  test("workflow uses actions/checkout@v4", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("actions/checkout@v4");
  });

  test("workflow has a job that runs on ubuntu", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("ubuntu");
  });

  test("script file exists at referenced path", () => {
    expect(existsSync(join(ROOT, "src/main.ts"))).toBe(true);
  });

  test("version-bumper source exists", () => {
    expect(existsSync(join(ROOT, "src/version-bumper.ts"))).toBe(true);
  });

  test("fixtures file exists", () => {
    expect(existsSync(join(ROOT, "src/fixtures.ts"))).toBe(true);
  });
});
