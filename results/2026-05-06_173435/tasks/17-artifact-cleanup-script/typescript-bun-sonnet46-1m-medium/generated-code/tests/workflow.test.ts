// Workflow structure tests:
// - Parse the YAML and verify expected triggers, jobs, and steps
// - Verify referenced script files exist
// - Verify actionlint passes (exit code 0)

import { describe, test, expect } from "bun:test";
import { existsSync, readFileSync } from "fs";
import { join } from "path";
import { spawnSync } from "child_process";

const ROOT = join(import.meta.dir, "..");
const WORKFLOW_PATH = join(ROOT, ".github/workflows/artifact-cleanup-script.yml");

// Minimal YAML parser for the values we need: avoids adding a yaml dep.
// Reads key: value pairs and the `on:` block to verify structure.
function parseWorkflowYaml(content: string): {
  name: string;
  triggers: string[];
  jobs: string[];
  stepNames: string[];
} {
  const lines = content.split("\n");

  // Extract workflow name
  const nameLine = lines.find((l) => l.match(/^name:/));
  const name = nameLine ? nameLine.replace(/^name:\s*/, "").trim() : "";

  // Extract top-level triggers from the `on:` block
  const triggers: string[] = [];
  let inOn = false;
  for (const line of lines) {
    if (line.match(/^on:/)) { inOn = true; continue; }
    if (inOn) {
      if (line.match(/^\S/) && !line.match(/^on:/)) { inOn = false; continue; }
      const m = line.match(/^  (\w+):/);
      if (m) triggers.push(m[1]!);
    }
  }

  // Extract job names from the `jobs:` block
  const jobs: string[] = [];
  let inJobs = false;
  for (const line of lines) {
    if (line.match(/^jobs:/)) { inJobs = true; continue; }
    if (inJobs) {
      const m = line.match(/^  (\S+):/);
      if (m && !m[1]!.startsWith("#")) jobs.push(m[1]!);
    }
  }

  // Extract step names
  const stepNames: string[] = [];
  for (const line of lines) {
    const m = line.match(/^\s+- name:\s*(.+)/);
    if (m) stepNames.push(m[1]!.trim());
  }

  return { name, triggers, jobs, stepNames };
}

describe("Workflow file structure", () => {
  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("workflow has expected name", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    const { name } = parseWorkflowYaml(content);
    expect(name).toBe("Artifact Cleanup Script");
  });

  test("workflow has required trigger events", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    const { triggers } = parseWorkflowYaml(content);
    expect(triggers).toContain("push");
    expect(triggers).toContain("pull_request");
    expect(triggers).toContain("workflow_dispatch");
    expect(triggers).toContain("schedule");
  });

  test("workflow has a test-and-run job", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    const { jobs } = parseWorkflowYaml(content);
    expect(jobs).toContain("test-and-run");
  });

  test("workflow steps include checkout, bun setup, unit tests, and all 4 test cases", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    const { stepNames } = parseWorkflowYaml(content);

    expect(stepNames).toContain("Checkout");
    expect(stepNames).toContain("Setup Bun");
    expect(stepNames).toContain("Run unit tests");

    // All 4 test cases must be present
    const hasCase = (n: number): boolean => stepNames.some((s) => s.includes(`Case ${n}`));
    expect(hasCase(1)).toBe(true);
    expect(hasCase(2)).toBe(true);
    expect(hasCase(3)).toBe(true);
    expect(hasCase(4)).toBe(true);
  });

  test("workflow references fixture and source files that exist", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");

    // Extract all fixture/source paths referenced in run: blocks
    const paths = [...content.matchAll(/(?:--input|--policy|bun run)\s+([\w./]+)/g)]
      .map((m) => m[1]!)
      .filter((p) => p.endsWith(".json") || p.endsWith(".ts"));

    expect(paths.length).toBeGreaterThan(0);
    for (const relativePath of paths) {
      const fullPath = join(ROOT, relativePath);
      expect(existsSync(fullPath)).toBe(true);
    }
  });
});

describe("actionlint validation", () => {
  test("workflow passes actionlint with exit code 0", () => {
    const result = spawnSync("actionlint", [WORKFLOW_PATH], { encoding: "utf-8" });
    const output = (result.stdout ?? "") + (result.stderr ?? "");

    if (result.status !== 0) {
      console.error("actionlint errors:", output);
    }
    expect(result.status).toBe(0);
  });
});
