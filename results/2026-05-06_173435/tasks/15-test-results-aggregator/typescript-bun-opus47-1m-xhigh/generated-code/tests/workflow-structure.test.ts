// Structural validation of the GitHub Actions workflow. These tests do not
// invoke act — they only inspect the YAML and the files it references, so
// they run in milliseconds and catch regressions like a renamed script path
// or a removed trigger before we burn 30+ seconds on an act run.
import { describe, expect, test } from "bun:test";
import { execSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const WORKFLOW_PATH = resolve(import.meta.dir, "..", ".github/workflows/test-results-aggregator.yml");

function readWorkflow(): string {
  return readFileSync(WORKFLOW_PATH, "utf8");
}

describe("workflow structure", () => {
  test("workflow file exists at the canonical path", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("declares push, pull_request, and workflow_dispatch triggers", () => {
    const yml = readWorkflow();
    expect(yml).toMatch(/^on:/m);
    expect(yml).toMatch(/^\s+push:/m);
    expect(yml).toMatch(/^\s+pull_request:/m);
    expect(yml).toMatch(/^\s+workflow_dispatch:/m);
  });

  test("declares an explicit minimal contents:read permission", () => {
    const yml = readWorkflow();
    expect(yml).toMatch(/permissions:\s*\n\s+contents:\s*read/);
  });

  test("uses actions/checkout@v4 (full pin handled separately)", () => {
    const yml = readWorkflow();
    expect(yml).toContain("actions/checkout@v4");
  });

  test("references files that actually exist in the repo", () => {
    const yml = readWorkflow();
    // The aggregator step calls `bun run src/main.ts ...` — make sure that
    // file is present so the workflow does not silently break.
    expect(yml).toContain("src/main.ts");
    expect(existsSync(resolve(import.meta.dir, "..", "src/main.ts"))).toBe(true);
    expect(existsSync(resolve(import.meta.dir, "..", "src/parser.ts"))).toBe(true);
    expect(existsSync(resolve(import.meta.dir, "..", "src/aggregator.ts"))).toBe(true);
    expect(existsSync(resolve(import.meta.dir, "..", "src/markdown.ts"))).toBe(true);
    expect(existsSync(resolve(import.meta.dir, "..", "package.json"))).toBe(true);
  });

  test("passes actionlint", () => {
    // exit code 0 means clean; non-zero throws and the test fails with the
    // captured stderr/stdout attached.
    const result = execSync(`actionlint ${WORKFLOW_PATH}`, { stdio: "pipe" });
    expect(result.toString()).toBe("");
  });
});
