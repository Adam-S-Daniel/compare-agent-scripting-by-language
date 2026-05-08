// Workflow structure tests: parse the YAML, verify structure, check file references,
// and assert actionlint passes.
import { describe, it, expect } from "bun:test";
import { readFileSync, existsSync } from "fs";
import { join } from "path";
import { spawnSync } from "child_process";

const ROOT = join(import.meta.dir, "..");
const WORKFLOW_PATH = join(ROOT, ".github/workflows/test-results-aggregator.yml");

describe("workflow file", () => {
  it("workflow YAML file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  it("contains expected trigger events (push, pull_request, workflow_dispatch)", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("push:");
    expect(content).toContain("pull_request");
    expect(content).toContain("workflow_dispatch");
  });

  it("references actions/checkout@v4", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("actions/checkout@v4");
  });

  it("references the aggregator script", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("aggregate.ts");
  });

  it("has a 'aggregate' job", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("aggregate:");
  });

  it("aggregate.ts script file exists", () => {
    expect(existsSync(join(ROOT, "aggregate.ts"))).toBe(true);
  });

  it("src/aggregator.ts exists", () => {
    expect(existsSync(join(ROOT, "src/aggregator.ts"))).toBe(true);
  });

  it("fixture files exist", () => {
    expect(existsSync(join(ROOT, "fixtures/matrix-linux.xml"))).toBe(true);
    expect(existsSync(join(ROOT, "fixtures/matrix-windows.xml"))).toBe(true);
    expect(existsSync(join(ROOT, "fixtures/unit-tests.json"))).toBe(true);
  });

  it("actionlint passes on the workflow file", () => {
    const result = spawnSync("actionlint", [WORKFLOW_PATH], { encoding: "utf-8" });
    expect(result.status).toBe(0);
    expect(result.stdout).toBe("");
  });
});
