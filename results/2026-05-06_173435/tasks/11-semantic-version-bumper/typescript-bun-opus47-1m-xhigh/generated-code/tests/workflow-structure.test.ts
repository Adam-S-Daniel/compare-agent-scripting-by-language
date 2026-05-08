// Workflow STRUCTURE tests — fast, no docker/act required.
//
// These verify that the YAML file at .github/workflows/semantic-version-bumper.yml
// has the trigger/job/step shape the act harness expects, that every script
// path it references actually exists on disk, and that actionlint is happy.

import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { join } from "node:path";

const REPO_ROOT = join(import.meta.dir, "..");
const WORKFLOW = join(REPO_ROOT, ".github", "workflows", "semantic-version-bumper.yml");

describe("workflow structure", () => {
  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW)).toBe(true);
  });

  test("declares all required triggers", () => {
    const yaml = readFileSync(WORKFLOW, "utf8");
    // We treat "appears literally as an event key" as good enough — actionlint
    // covers the structural validity, this just guards against accidental drift.
    for (const trigger of ["push:", "pull_request:", "workflow_dispatch:", "schedule:"]) {
      expect(yaml).toContain(trigger);
    }
  });

  test("includes a checkout step pinned to v4", () => {
    const yaml = readFileSync(WORKFLOW, "utf8");
    expect(yaml).toContain("actions/checkout@v4");
  });

  test("invokes the script under src/cli.ts", () => {
    const yaml = readFileSync(WORKFLOW, "utf8");
    expect(yaml).toContain("bun run src/cli.ts");
    expect(existsSync(join(REPO_ROOT, "src", "cli.ts"))).toBe(true);
    expect(existsSync(join(REPO_ROOT, "src", "lib.ts"))).toBe(true);
  });

  test("explicitly grants minimum permissions", () => {
    const yaml = readFileSync(WORKFLOW, "utf8");
    expect(yaml).toMatch(/permissions:\s*\n\s+contents:\s+read/);
  });

  test("runs `bun test` somewhere in the job", () => {
    const yaml = readFileSync(WORKFLOW, "utf8");
    expect(yaml).toContain("bun test");
  });

  test("passes actionlint", () => {
    const result = spawnSync("actionlint", [WORKFLOW], { encoding: "utf8" });
    if (result.status !== 0) {
      console.error("actionlint stdout:", result.stdout);
      console.error("actionlint stderr:", result.stderr);
    }
    expect(result.status).toBe(0);
  });
});
