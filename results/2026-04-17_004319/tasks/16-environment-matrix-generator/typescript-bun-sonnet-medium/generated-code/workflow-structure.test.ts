// Workflow structure tests: verify the GHA workflow file is well-formed
// and references real files. All checks run via bun test.

import { describe, it, expect } from "bun:test";
import { existsSync } from "fs";
import { spawnSync } from "child_process";

const WORKFLOW_PATH = ".github/workflows/environment-matrix-generator.yml";

describe("workflow file", () => {
  it("workflow file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  it("matrix-generator.ts exists", () => {
    expect(existsSync("matrix-generator.ts")).toBe(true);
  });

  it("matrix-generator.test.ts exists", () => {
    expect(existsSync("matrix-generator.test.ts")).toBe(true);
  });

  it("all fixture files referenced in workflow exist", () => {
    const fixtures = [
      "fixtures/basic.json",
      "fixtures/with-exclude.json",
      "fixtures/with-include.json",
      "fixtures/too-large.json",
    ];
    for (const f of fixtures) {
      expect(existsSync(f)).toBe(true);
    }
  });

  it("actionlint passes on the workflow file", () => {
    const result = spawnSync("actionlint", [WORKFLOW_PATH], {
      encoding: "utf8",
    });
    expect(result.stdout).toBe("");
    expect(result.status).toBe(0);
  });

  it("workflow YAML contains expected triggers", () => {
    const raw = Bun.file(WORKFLOW_PATH).toString();
    // Synchronous read
    const content = require("fs").readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("push:");
    expect(content).toContain("pull_request");
    expect(content).toContain("workflow_dispatch");
  });

  it("workflow YAML contains expected jobs and steps", () => {
    const content = require("fs").readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("generate-matrix:");
    expect(content).toContain("actions/checkout@v4");
    expect(content).toContain("oven-sh/setup-bun");
    expect(content).toContain("bun test");
    expect(content).toContain("matrix-generator.ts");
  });

  it("workflow YAML contains all fixture references", () => {
    const content = require("fs").readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("fixtures/basic.json");
    expect(content).toContain("fixtures/with-exclude.json");
    expect(content).toContain("fixtures/with-include.json");
    expect(content).toContain("fixtures/too-large.json");
  });
});
