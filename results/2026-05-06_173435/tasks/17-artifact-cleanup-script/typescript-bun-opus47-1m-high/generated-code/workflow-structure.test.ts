// Static checks on the workflow file — fast, deterministic, no act required.
// Verifies:
//   - actionlint passes (exit 0).
//   - YAML parses.
//   - Expected triggers, jobs, steps, and script paths are present.

import { describe, test, expect } from "bun:test";
import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import { parse as parseYaml } from "yaml";

const ROOT = resolve(import.meta.dir);
const WORKFLOW = resolve(ROOT, ".github/workflows/artifact-cleanup-script.yml");

interface WorkflowDoc {
  name: string;
  // YAML's `on:` parses as the boolean `true` because YAML treats unquoted "on"
  // as a boolean key. Both styles can appear; we tolerate either.
  on?: unknown;
  true?: unknown;
  permissions?: Record<string, string>;
  env?: Record<string, string>;
  jobs: Record<string, {
    "runs-on": string;
    needs?: string | string[];
    steps: Array<{ name?: string; uses?: string; run?: string }>;
  }>;
}

describe("workflow file structure", () => {
  test("workflow file exists at the canonical path", () => {
    expect(existsSync(WORKFLOW)).toBe(true);
  });

  test("actionlint exits 0", () => {
    const r = spawnSync("actionlint", [WORKFLOW], { encoding: "utf8" });
    if (r.status !== 0) {
      // Surface diagnostics so a failing run shows the actual problem.
      console.error(r.stdout);
      console.error(r.stderr);
    }
    expect(r.status).toBe(0);
  });

  test("YAML parses and declares expected triggers", () => {
    const doc = parseYaml(readFileSync(WORKFLOW, "utf8")) as WorkflowDoc;
    const triggers = (doc.on ?? doc.true) as Record<string, unknown>;
    expect(triggers).toBeDefined();
    expect(triggers).toHaveProperty("push");
    expect(triggers).toHaveProperty("pull_request");
    expect(triggers).toHaveProperty("schedule");
    expect(triggers).toHaveProperty("workflow_dispatch");
  });

  test("declares both jobs with correct dependency ordering", () => {
    const doc = parseYaml(readFileSync(WORKFLOW, "utf8")) as WorkflowDoc;
    expect(doc.jobs).toHaveProperty("unit-tests");
    expect(doc.jobs).toHaveProperty("cleanup-plan");
    expect(doc.jobs["cleanup-plan"].needs).toBe("unit-tests");
  });

  test("uses actions/checkout@v4 in both jobs", () => {
    const doc = parseYaml(readFileSync(WORKFLOW, "utf8")) as WorkflowDoc;
    for (const jobName of Object.keys(doc.jobs)) {
      const usesCheckout = doc.jobs[jobName].steps.some(
        (s) => s.uses === "actions/checkout@v4",
      );
      expect(usesCheckout).toBe(true);
    }
  });

  test("references the cli.ts script and fixture path", () => {
    const text = readFileSync(WORKFLOW, "utf8");
    expect(text).toContain("cli.ts");
    expect(text).toContain("fixtures/");
  });

  test("declares read-only permissions", () => {
    const doc = parseYaml(readFileSync(WORKFLOW, "utf8")) as WorkflowDoc;
    expect(doc.permissions?.contents).toBe("read");
  });

  test("referenced files in the repo actually exist", () => {
    expect(existsSync(resolve(ROOT, "cli.ts"))).toBe(true);
    expect(existsSync(resolve(ROOT, "cleanup.ts"))).toBe(true);
    expect(existsSync(resolve(ROOT, "fixtures/combined/artifacts.json"))).toBe(true);
    expect(existsSync(resolve(ROOT, "fixtures/noop/artifacts.json"))).toBe(true);
  });
});
