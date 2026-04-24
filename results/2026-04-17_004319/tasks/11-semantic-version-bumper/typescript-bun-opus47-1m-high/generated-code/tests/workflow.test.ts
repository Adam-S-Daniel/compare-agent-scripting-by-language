// Workflow-structure tests. These don't run act; they just validate the
// YAML shape, that referenced paths exist, and that actionlint is clean.
// Running act is done by the dedicated harness in act-harness.ts.
import { describe, expect, test } from "bun:test";
import { readFileSync, existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { parse } from "yaml";
import { join } from "node:path";

const WF_PATH = join(import.meta.dir, "..", ".github/workflows/semantic-version-bumper.yml");

interface WorkflowDoc {
  name: string;
  on: Record<string, unknown>;
  permissions?: Record<string, string>;
  env?: Record<string, string>;
  jobs: Record<string, { "runs-on": string; steps: Array<Record<string, unknown>> }>;
}

const doc = parse(readFileSync(WF_PATH, "utf8")) as WorkflowDoc;

describe("workflow YAML structure", () => {
  test("has a human-readable name", () => {
    expect(doc.name).toBe("Semantic Version Bumper");
  });

  test("registers push, pull_request, workflow_dispatch, schedule triggers", () => {
    expect(doc.on).toBeTruthy();
    const keys = Object.keys(doc.on);
    for (const k of ["push", "pull_request", "workflow_dispatch", "schedule"]) {
      expect(keys).toContain(k);
    }
  });

  test("declares least-privilege permissions", () => {
    expect(doc.permissions?.contents).toBe("read");
  });

  test("defines the bump job with the expected steps", () => {
    const job = doc.jobs["bump"];
    expect(job).toBeDefined();
    expect(job!["runs-on"]).toBe("ubuntu-latest");
    const stepNames = job!.steps.map((s) => s["name"]) as string[];
    for (const required of [
      "Checkout",
      "Install bun",
      "Install deps",
      "Run bun unit tests",
      "Run semantic-version-bumper",
      "Assert expected version",
    ]) {
      expect(stepNames).toContain(required);
    }
  });

  test("uses actions/checkout@v4", () => {
    const steps = doc.jobs["bump"]!.steps;
    const checkout = steps.find((s) => s["uses"] === "actions/checkout@v4");
    expect(checkout).toBeTruthy();
  });
});

describe("workflow references real files", () => {
  test("referenced script files exist", () => {
    const root = join(import.meta.dir, "..");
    expect(existsSync(join(root, "src/main.ts"))).toBe(true);
    expect(existsSync(join(root, "src/parser.ts"))).toBe(true);
    expect(existsSync(join(root, "src/bumper.ts"))).toBe(true);
    expect(existsSync(join(root, "src/changelog.ts"))).toBe(true);
  });

  test("default fixture referenced in workflow exists on disk", () => {
    const root = join(import.meta.dir, "..");
    // The workflow hard-codes 'fixtures/minor.txt' as the ultimate fallback
    // inside the "Run semantic-version-bumper" step's shell script.
    const raw = readFileSync(WF_PATH, "utf8");
    expect(raw).toContain("fixtures/minor.txt");
    expect(existsSync(join(root, "fixtures/minor.txt"))).toBe(true);
  });
});

describe("actionlint", () => {
  test("passes cleanly", () => {
    const r = spawnSync("actionlint", [WF_PATH], { encoding: "utf8" });
    if (r.status !== 0) {
      console.error(r.stdout);
      console.error(r.stderr);
    }
    expect(r.status).toBe(0);
  });
});
