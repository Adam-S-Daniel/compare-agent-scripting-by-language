// Structural tests for the GitHub Actions workflow file.
//
// These run under `bun test` and check that:
//   1. The YAML parses cleanly.
//   2. Required triggers are wired up.
//   3. Each job runs the steps that the act-based harness depends on.
//   4. Files referenced by the workflow exist on disk.
//   5. actionlint passes (asserts exit code 0).

import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parse as parseYaml } from "yaml";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = resolve(__dirname, "..");
const WORKFLOW_PATH = join(
  PROJECT_ROOT,
  ".github/workflows/artifact-cleanup-script.yml",
);

interface WorkflowStep {
  name?: string;
  uses?: string;
  run?: string;
}

interface WorkflowJob {
  name?: string;
  "runs-on"?: string;
  needs?: string | string[];
  steps?: WorkflowStep[];
  "timeout-minutes"?: number;
}

interface WorkflowDoc {
  name?: string;
  on?: Record<string, unknown> | string | string[];
  permissions?: Record<string, string>;
  env?: Record<string, string>;
  jobs?: Record<string, WorkflowJob>;
}

const workflowYaml = readFileSync(WORKFLOW_PATH, "utf8");
const doc = parseYaml(workflowYaml) as WorkflowDoc;

describe("workflow YAML", () => {
  test("parses successfully", () => {
    expect(doc).toBeTruthy();
    expect(typeof doc).toBe("object");
  });

  test("has the expected name", () => {
    expect(doc.name).toBe("artifact-cleanup-script");
  });

  test("declares the required triggers", () => {
    // YAML 1.2 'on' is parsed as a key — yaml lib returns it correctly.
    expect(doc.on).toBeTruthy();
    const triggers = doc.on as Record<string, unknown>;
    expect(triggers).toHaveProperty("push");
    expect(triggers).toHaveProperty("pull_request");
    expect(triggers).toHaveProperty("schedule");
    expect(triggers).toHaveProperty("workflow_dispatch");
  });

  test("declares minimal permissions (contents: read)", () => {
    expect(doc.permissions).toBeTruthy();
    expect(doc.permissions?.contents).toBe("read");
  });
});

describe("workflow jobs", () => {
  test("defines unit-tests and cleanup-plan jobs", () => {
    expect(doc.jobs).toBeTruthy();
    expect(doc.jobs).toHaveProperty("unit-tests");
    expect(doc.jobs).toHaveProperty("cleanup-plan");
  });

  test("cleanup-plan depends on unit-tests", () => {
    const job = doc.jobs!["cleanup-plan"]!;
    const needs = Array.isArray(job.needs) ? job.needs : [job.needs];
    expect(needs).toContain("unit-tests");
  });

  test("unit-tests runs `bun test` and checks out the repo", () => {
    const steps = doc.jobs!["unit-tests"]!.steps!;
    const checkout = steps.find((s) => s.uses?.startsWith("actions/checkout"));
    expect(checkout).toBeDefined();
    const runsBunTest = steps.some((s) => s.run?.includes("bun test"));
    expect(runsBunTest).toBe(true);
  });

  test("cleanup-plan invokes run-from-config.ts", () => {
    const steps = doc.jobs!["cleanup-plan"]!.steps!;
    const ranScript = steps.some((s) =>
      s.run?.includes("src/run-from-config.ts"),
    );
    expect(ranScript).toBe(true);
  });
});

describe("workflow file references", () => {
  test("the script files referenced by the workflow exist", () => {
    expect(existsSync(join(PROJECT_ROOT, "src/run-from-config.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_ROOT, "src/cli.ts"))).toBe(true);
    expect(existsSync(join(PROJECT_ROOT, "src/cleanup.ts"))).toBe(true);
  });

  test("the default fixture config and artifacts exist", () => {
    expect(existsSync(join(PROJECT_ROOT, "fixtures/cleanup.config.json"))).toBe(
      true,
    );
    expect(existsSync(join(PROJECT_ROOT, "fixtures/artifacts.json"))).toBe(
      true,
    );
  });
});

// actionlint isn't bundled into the act runner image; skip cleanly when it's
// missing so this same test file can run locally (where actionlint exists)
// and inside the act-driven CI flow without conditional branches there.
const actionlintAvailable = (() => {
  const probe = spawnSync("actionlint", ["-version"], { encoding: "utf8" });
  return probe.status === 0;
})();
const actionlintTest = actionlintAvailable ? test : test.skip;

describe("actionlint", () => {
  actionlintTest("workflow passes actionlint with exit code 0", () => {
    const result = spawnSync("actionlint", [WORKFLOW_PATH], {
      encoding: "utf8",
    });
    if (result.status !== 0) {
      // Surface actionlint's diagnostics in the failure message.
      const out = `${result.stdout ?? ""}${result.stderr ?? ""}`;
      throw new Error(`actionlint failed (status=${result.status}):\n${out}`);
    }
    expect(result.status).toBe(0);
  });
});
