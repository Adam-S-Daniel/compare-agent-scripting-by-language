/**
 * Workflow structure tests.
 * These verify the GitHub Actions workflow file before we ever run `act`.
 *
 * TDD sequence:
 *  RED  — tests fail because the workflow file doesn't exist yet.
 *  GREEN — create the workflow; tests pass.
 */

import { describe, it, expect } from "bun:test";
import { existsSync, readFileSync } from "fs";
import { spawnSync } from "child_process";
import { resolve, join } from "path";

const WORKFLOW_PATH = resolve(
  __dirname,
  ".github/workflows/environment-matrix-generator.yml"
);

// ── File existence ─────────────────────────────────────────────────────────────
describe("workflow file", () => {
  it("exists at the expected path", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });
});

// ── Structural checks (string-level YAML inspection) ──────────────────────────
describe("workflow structure", () => {
  function workflowContent(): string {
    return readFileSync(WORKFLOW_PATH, "utf-8");
  }

  it("has a push trigger", () => {
    expect(workflowContent()).toMatch(/push:/);
  });

  it("has a workflow_dispatch trigger", () => {
    expect(workflowContent()).toMatch(/workflow_dispatch:/);
  });

  it("has at least one job", () => {
    expect(workflowContent()).toMatch(/jobs:/);
  });

  it("uses actions/checkout@v4", () => {
    expect(workflowContent()).toMatch(/actions\/checkout@v4/);
  });

  it("installs Bun", () => {
    // Either via npm install -g bun or oven-sh/setup-bun
    const content = workflowContent();
    expect(
      content.includes("bun") || content.includes("setup-bun")
    ).toBe(true);
  });

  it("runs bun test", () => {
    expect(workflowContent()).toMatch(/bun test/);
  });

  it("runs index.ts with fixtures/basic.json", () => {
    expect(workflowContent()).toMatch(/fixtures\/basic\.json/);
  });

  it("runs index.ts with fixtures/include-exclude.json", () => {
    expect(workflowContent()).toMatch(/fixtures\/include-exclude\.json/);
  });

  it("runs index.ts with fixtures/size-exceeded.json", () => {
    expect(workflowContent()).toMatch(/fixtures\/size-exceeded\.json/);
  });
});

// ── Referenced files exist ─────────────────────────────────────────────────────
describe("workflow referenced files", () => {
  it("index.ts exists", () => {
    expect(existsSync(join(__dirname, "index.ts"))).toBe(true);
  });

  it("matrix-generator.ts exists", () => {
    expect(existsSync(join(__dirname, "matrix-generator.ts"))).toBe(true);
  });

  it("fixtures/basic.json exists", () => {
    expect(existsSync(join(__dirname, "fixtures/basic.json"))).toBe(true);
  });

  it("fixtures/include-exclude.json exists", () => {
    expect(existsSync(join(__dirname, "fixtures/include-exclude.json"))).toBe(true);
  });

  it("fixtures/size-exceeded.json exists", () => {
    expect(existsSync(join(__dirname, "fixtures/size-exceeded.json"))).toBe(true);
  });
});

// ── actionlint validation ──────────────────────────────────────────────────────
describe("actionlint", () => {
  it("passes with exit code 0", () => {
    // Skip if workflow doesn't exist (avoids confusing actionlint error)
    if (!existsSync(WORKFLOW_PATH)) {
      console.log("Skipping actionlint: workflow file not found");
      return;
    }
    // Check if actionlint is installed; skip gracefully if not available
    // (e.g. inside the act Docker container which doesn't have actionlint).
    const which = spawnSync("which", ["actionlint"], { encoding: "utf-8" });
    if (which.status !== 0) {
      console.log("Skipping actionlint: binary not found in PATH");
      return;
    }
    const result = spawnSync("actionlint", [WORKFLOW_PATH], {
      encoding: "utf-8",
    });
    if (result.stdout) console.log(result.stdout);
    if (result.stderr) console.error(result.stderr);
    expect(result.status).toBe(0);
  });
});
