// TDD: Tests for workflow structure validation.
// These tests ensure the GitHub Actions workflow is correctly defined
// and references the right script files.

import { test, describe, expect } from "bun:test";
import { existsSync } from "fs";
import { parse as parseYAML } from "yaml";
import { readFileSync } from "fs";
import { spawnSync } from "child_process";

const WORKFLOW_PATH = ".github/workflows/artifact-cleanup-script.yml";

describe("GitHub Actions workflow structure", () => {
  test("workflow file exists at expected path", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("workflow has correct trigger events", () => {
    const raw = readFileSync(WORKFLOW_PATH, "utf-8");
    const workflow = parseYAML(raw) as Record<string, unknown>;

    const on = workflow["on"] as Record<string, unknown>;
    // Must have push, pull_request, schedule, and workflow_dispatch triggers
    expect(on).toHaveProperty("push");
    expect(on).toHaveProperty("pull_request");
    expect(on).toHaveProperty("schedule");
    expect(on).toHaveProperty("workflow_dispatch");
  });

  test("workflow has required jobs", () => {
    const raw = readFileSync(WORKFLOW_PATH, "utf-8");
    const workflow = parseYAML(raw) as Record<string, unknown>;

    const jobs = workflow["jobs"] as Record<string, unknown>;
    // Must have at least unit-tests and integration-tests jobs
    expect(Object.keys(jobs)).toContain("unit-tests");
    expect(Object.keys(jobs)).toContain("integration-tests");
  });

  test("integration-tests job depends on unit-tests", () => {
    const raw = readFileSync(WORKFLOW_PATH, "utf-8");
    const workflow = parseYAML(raw) as Record<string, unknown>;

    const jobs = workflow["jobs"] as Record<string, Record<string, unknown>>;
    const integrationJob = jobs["integration-tests"];
    expect(integrationJob).toHaveProperty("needs");
    const needs = integrationJob["needs"] as string | string[];
    const needsArray = Array.isArray(needs) ? needs : [needs];
    expect(needsArray).toContain("unit-tests");
  });

  test("script source file exists", () => {
    expect(existsSync("src/main.ts")).toBe(true);
  });

  test("fixtures file exists", () => {
    expect(existsSync("fixtures/artifacts.json")).toBe(true);
  });

  test("actionlint passes on the workflow file", () => {
    const result = spawnSync("actionlint", [WORKFLOW_PATH], {
      encoding: "utf-8",
    });
    if (result.status !== 0) {
      console.error("actionlint stdout:", result.stdout);
      console.error("actionlint stderr:", result.stderr);
    }
    expect(result.status).toBe(0);
  });
});
