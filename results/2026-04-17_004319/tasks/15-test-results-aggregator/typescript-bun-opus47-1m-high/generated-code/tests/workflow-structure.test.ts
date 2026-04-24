// Workflow structure tests: verify the GitHub Actions YAML is well-formed,
// references existing script files, and passes actionlint.
// These tests are fast (no Docker) and complement the full act pipeline tests.
import { describe, test, expect } from "bun:test";
import { $ } from "bun";
import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const projectRoot = resolve(import.meta.dir, "..");
const workflowPath = join(projectRoot, ".github/workflows/test-results-aggregator.yml");

describe("workflow structure", () => {
  test("workflow file exists", () => {
    expect(existsSync(workflowPath)).toBe(true);
  });

  test("declares required triggers (push, pull_request, workflow_dispatch)", () => {
    const src = readFileSync(workflowPath, "utf8");
    expect(src).toMatch(/\bpush:/);
    expect(src).toMatch(/\bpull_request:/);
    expect(src).toMatch(/\bworkflow_dispatch:/);
  });

  test("uses actions/checkout@v4", () => {
    const src = readFileSync(workflowPath, "utf8");
    expect(src).toContain("actions/checkout@v4");
  });

  test("installs Bun via oven-sh/setup-bun", () => {
    const src = readFileSync(workflowPath, "utf8");
    expect(src).toContain("oven-sh/setup-bun");
  });

  test("references the aggregator script path that exists on disk", () => {
    const src = readFileSync(workflowPath, "utf8");
    // The workflow runs `bun run src/cli.ts`; that file must exist.
    expect(src).toContain("src/cli.ts");
    expect(existsSync(join(projectRoot, "src/cli.ts"))).toBe(true);
  });

  test("declares a contents:read permission (least privilege)", () => {
    const src = readFileSync(workflowPath, "utf8");
    expect(src).toMatch(/permissions:\s*\n\s*contents:\s*read/);
  });

  test("actionlint passes cleanly (exit 0)", async () => {
    const result = await $`actionlint ${workflowPath}`.nothrow().quiet();
    const combined = result.stdout.toString() + result.stderr.toString();
    expect(combined, `actionlint output:\n${combined}`).toBe("");
    expect(result.exitCode).toBe(0);
  });
});
