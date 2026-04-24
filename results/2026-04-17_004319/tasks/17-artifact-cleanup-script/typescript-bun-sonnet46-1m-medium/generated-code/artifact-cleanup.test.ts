// TDD test suite for artifact-cleanup.ts
// Tests written FIRST (red phase), implementation follows

import { describe, test, expect } from "bun:test";
import { execSync, spawnSync } from "child_process";
import * as fs from "fs";
import * as path from "path";
import {
  type Artifact,
  type RetentionPolicy,
  type DeletionPlan,
  applyRetentionPolicies,
  formatDeletionPlan,
} from "./artifact-cleanup";

// Fixed "now" date for deterministic tests
const NOW = new Date("2026-04-20T00:00:00Z");

// Helper to create an artifact with sensible defaults
function makeArtifact(overrides: Partial<Artifact>): Artifact {
  return {
    name: "test-artifact",
    size: 1024 * 1024, // 1 MB
    createdAt: new Date("2026-04-15T00:00:00Z"),
    workflowRunId: "run-1",
    ...overrides,
  };
}

// --- Age policy tests ---

describe("applyRetentionPolicies - maxAgeDays", () => {
  test("deletes artifacts older than maxAgeDays", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "old-artifact", createdAt: new Date("2026-03-01T00:00:00Z") }), // 50 days old
      makeArtifact({ name: "recent-artifact", createdAt: new Date("2026-04-15T00:00:00Z") }), // 5 days old
    ];
    const policy: RetentionPolicy = { maxAgeDays: 30 };

    const plan = applyRetentionPolicies(artifacts, policy, false, NOW);

    expect(plan.toDelete.map((a) => a.name)).toContain("old-artifact");
    expect(plan.toKeep.map((a) => a.name)).toContain("recent-artifact");
    expect(plan.toDelete).toHaveLength(1);
    expect(plan.toKeep).toHaveLength(1);
  });

  test("keeps artifacts exactly at the age boundary (not strictly older)", () => {
    // 30 days old exactly - the cutoff is strictly before, so boundary is kept
    const artifacts: Artifact[] = [
      makeArtifact({
        name: "boundary-artifact",
        createdAt: new Date(NOW.getTime() - 30 * 24 * 60 * 60 * 1000),
      }),
    ];
    const policy: RetentionPolicy = { maxAgeDays: 30 };

    const plan = applyRetentionPolicies(artifacts, policy, false, NOW);

    expect(plan.toKeep.map((a) => a.name)).toContain("boundary-artifact");
    expect(plan.toDelete).toHaveLength(0);
  });

  test("deletes nothing when all artifacts are within maxAgeDays", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "fresh-1", createdAt: new Date("2026-04-18T00:00:00Z") }),
      makeArtifact({ name: "fresh-2", createdAt: new Date("2026-04-19T00:00:00Z") }),
    ];
    const plan = applyRetentionPolicies(artifacts, { maxAgeDays: 30 }, false, NOW);

    expect(plan.toDelete).toHaveLength(0);
    expect(plan.toKeep).toHaveLength(2);
  });
});

// --- Keep-latest-N per workflow tests ---

describe("applyRetentionPolicies - keepLatestNPerWorkflow", () => {
  test("keeps only the N most recent artifacts per workflow run", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "run1-oldest", createdAt: new Date("2026-01-01T00:00:00Z"), workflowRunId: "run-1" }),
      makeArtifact({ name: "run1-middle", createdAt: new Date("2026-02-01T00:00:00Z"), workflowRunId: "run-1" }),
      makeArtifact({ name: "run1-newest", createdAt: new Date("2026-03-01T00:00:00Z"), workflowRunId: "run-1" }),
    ];
    const policy: RetentionPolicy = { keepLatestNPerWorkflow: 2 };

    const plan = applyRetentionPolicies(artifacts, policy, false, NOW);

    expect(plan.toDelete.map((a) => a.name)).toContain("run1-oldest");
    expect(plan.toKeep.map((a) => a.name)).toContain("run1-middle");
    expect(plan.toKeep.map((a) => a.name)).toContain("run1-newest");
    expect(plan.toDelete).toHaveLength(1);
  });

  test("keeps all artifacts when count <= N", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "a", workflowRunId: "run-1" }),
      makeArtifact({ name: "b", workflowRunId: "run-1" }),
    ];
    const plan = applyRetentionPolicies(artifacts, { keepLatestNPerWorkflow: 2 }, false, NOW);

    expect(plan.toDelete).toHaveLength(0);
    expect(plan.toKeep).toHaveLength(2);
  });

  test("applies keep-latest-N independently per workflow run ID", () => {
    const artifacts: Artifact[] = [
      // run-1 has 3 artifacts
      makeArtifact({ name: "r1-a", createdAt: new Date("2026-01-01T00:00:00Z"), workflowRunId: "run-1" }),
      makeArtifact({ name: "r1-b", createdAt: new Date("2026-02-01T00:00:00Z"), workflowRunId: "run-1" }),
      makeArtifact({ name: "r1-c", createdAt: new Date("2026-03-01T00:00:00Z"), workflowRunId: "run-1" }),
      // run-2 has 2 artifacts
      makeArtifact({ name: "r2-a", createdAt: new Date("2026-01-15T00:00:00Z"), workflowRunId: "run-2" }),
      makeArtifact({ name: "r2-b", createdAt: new Date("2026-04-01T00:00:00Z"), workflowRunId: "run-2" }),
    ];
    const plan = applyRetentionPolicies(artifacts, { keepLatestNPerWorkflow: 2 }, false, NOW);

    // run-1 oldest deleted, run-2 unchanged
    expect(plan.toDelete.map((a) => a.name)).toEqual(["r1-a"]);
    expect(plan.toKeep).toHaveLength(4);
  });
});

// --- Max total size tests ---

describe("applyRetentionPolicies - maxTotalSizeBytes", () => {
  test("deletes oldest artifacts until total size is within budget", () => {
    const MB = 1024 * 1024;
    const artifacts: Artifact[] = [
      makeArtifact({ name: "oldest", size: 40 * MB, createdAt: new Date("2026-01-01T00:00:00Z") }),
      makeArtifact({ name: "middle", size: 40 * MB, createdAt: new Date("2026-02-01T00:00:00Z") }),
      makeArtifact({ name: "newest", size: 40 * MB, createdAt: new Date("2026-03-01T00:00:00Z") }),
    ];
    const policy: RetentionPolicy = { maxTotalSizeBytes: 100 * MB }; // 100 MB budget, 120 MB total

    const plan = applyRetentionPolicies(artifacts, policy, false, NOW);

    // Delete oldest (40MB) brings total to 80MB < 100MB
    expect(plan.toDelete.map((a) => a.name)).toContain("oldest");
    expect(plan.toDelete).toHaveLength(1);
    expect(plan.toKeep).toHaveLength(2);
  });

  test("does not delete anything when total size is within budget", () => {
    const MB = 1024 * 1024;
    const artifacts: Artifact[] = [
      makeArtifact({ name: "a", size: 10 * MB }),
      makeArtifact({ name: "b", size: 20 * MB }),
    ];
    const plan = applyRetentionPolicies(artifacts, { maxTotalSizeBytes: 100 * MB }, false, NOW);

    expect(plan.toDelete).toHaveLength(0);
  });

  test("computes correct space reclaimed", () => {
    const MB = 1024 * 1024;
    const artifacts: Artifact[] = [
      makeArtifact({ name: "a", size: 60 * MB, createdAt: new Date("2026-01-01T00:00:00Z") }),
      makeArtifact({ name: "b", size: 60 * MB, createdAt: new Date("2026-02-01T00:00:00Z") }),
    ];
    const plan = applyRetentionPolicies(artifacts, { maxTotalSizeBytes: 80 * MB }, false, NOW);

    expect(plan.totalSpaceReclaimed).toBe(60 * MB);
    expect(plan.summary.spaceReclaimedBytes).toBe(60 * MB);
    expect(plan.summary.spaceReclaimedMB).toBe(60);
  });
});

// --- Combined policy tests ---

describe("applyRetentionPolicies - combined policies", () => {
  test("applies all policies together (age + keep-N + size)", () => {
    const MB = 1024 * 1024;
    const artifacts: Artifact[] = [
      // This one is old (age policy deletes it)
      makeArtifact({ name: "very-old", size: 5 * MB, createdAt: new Date("2025-01-01T00:00:00Z"), workflowRunId: "run-1" }),
      // These three are in run-2 (all recent, within 30 days), keepN=2 so oldest gets deleted
      makeArtifact({ name: "r2-oldest", size: 20 * MB, createdAt: new Date("2026-03-25T00:00:00Z"), workflowRunId: "run-2" }),
      makeArtifact({ name: "r2-newer", size: 20 * MB, createdAt: new Date("2026-04-01T00:00:00Z"), workflowRunId: "run-2" }),
      makeArtifact({ name: "r2-newest", size: 20 * MB, createdAt: new Date("2026-04-10T00:00:00Z"), workflowRunId: "run-2" }),
    ];
    const policy: RetentionPolicy = {
      maxAgeDays: 30,
      keepLatestNPerWorkflow: 2,
      maxTotalSizeBytes: 100 * MB,
    };

    const plan = applyRetentionPolicies(artifacts, policy, false, NOW);

    expect(plan.toDelete.map((a) => a.name)).toContain("very-old");
    expect(plan.toDelete.map((a) => a.name)).toContain("r2-oldest");
    expect(plan.toDelete).toHaveLength(2);
  });
});

// --- Dry-run mode tests ---

describe("applyRetentionPolicies - dry-run mode", () => {
  test("dry-run flag is reflected in summary", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "old", createdAt: new Date("2025-01-01T00:00:00Z") }),
    ];
    const plan = applyRetentionPolicies(artifacts, { maxAgeDays: 30 }, true, NOW);

    expect(plan.summary.dryRun).toBe(true);
    // The plan still identifies what WOULD be deleted
    expect(plan.toDelete).toHaveLength(1);
  });

  test("dry-run false is reflected in summary", () => {
    const artifacts: Artifact[] = [makeArtifact({})];
    const plan = applyRetentionPolicies(artifacts, {}, false, NOW);

    expect(plan.summary.dryRun).toBe(false);
  });
});

// --- Summary correctness ---

describe("applyRetentionPolicies - summary fields", () => {
  test("summary counts are correct", () => {
    const MB = 1024 * 1024;
    const artifacts: Artifact[] = [
      makeArtifact({ name: "a", size: 10 * MB, createdAt: new Date("2025-01-01T00:00:00Z") }),
      makeArtifact({ name: "b", size: 20 * MB, createdAt: new Date("2025-01-01T00:00:00Z") }),
      makeArtifact({ name: "c", size: 5 * MB, createdAt: new Date("2026-04-19T00:00:00Z") }),
    ];

    const plan = applyRetentionPolicies(artifacts, { maxAgeDays: 30 }, false, NOW);

    expect(plan.summary.totalArtifacts).toBe(3);
    expect(plan.summary.artifactsToDelete).toBe(2);
    expect(plan.summary.artifactsToKeep).toBe(1);
    expect(plan.summary.spaceReclaimedBytes).toBe(30 * MB);
    expect(plan.summary.spaceReclaimedMB).toBe(30);
  });

  test("no-op policy produces zero deletions", () => {
    const artifacts: Artifact[] = [makeArtifact({}), makeArtifact({ name: "b" })];
    const plan = applyRetentionPolicies(artifacts, {}, false, NOW);

    expect(plan.summary.artifactsToDelete).toBe(0);
    expect(plan.summary.artifactsToKeep).toBe(2);
    expect(plan.summary.spaceReclaimedBytes).toBe(0);
  });
});

// --- Formatting tests ---

describe("formatDeletionPlan", () => {
  test("output includes expected summary lines", () => {
    const MB = 1024 * 1024;
    const artifacts: Artifact[] = [
      makeArtifact({ name: "old-art", size: 10 * MB, createdAt: new Date("2025-01-01T00:00:00Z") }),
      makeArtifact({ name: "keep-art", size: 5 * MB, createdAt: new Date("2026-04-19T00:00:00Z") }),
    ];
    const plan = applyRetentionPolicies(artifacts, { maxAgeDays: 30 }, false, NOW);
    const output = formatDeletionPlan(plan);

    expect(output).toContain("Artifacts to delete: 1");
    expect(output).toContain("Artifacts to keep: 1");
    expect(output).toContain("10.00 MB");
    expect(output).toContain("old-art");
  });

  test("dry-run output includes [DRY RUN] marker", () => {
    const plan = applyRetentionPolicies(
      [makeArtifact({ createdAt: new Date("2025-01-01T00:00:00Z") })],
      { maxAgeDays: 30 },
      true,
      NOW
    );
    const output = formatDeletionPlan(plan);

    expect(output).toContain("[DRY RUN]");
  });

  test("output includes 'No artifacts to delete' when plan is empty", () => {
    const plan = applyRetentionPolicies([makeArtifact({})], {}, false, NOW);
    const output = formatDeletionPlan(plan);

    expect(output).toContain("No artifacts to delete");
  });
});

// --- Edge cases ---

describe("applyRetentionPolicies - edge cases", () => {
  test("handles empty artifact list", () => {
    const plan = applyRetentionPolicies([], { maxAgeDays: 30 }, false, NOW);

    expect(plan.toDelete).toHaveLength(0);
    expect(plan.toKeep).toHaveLength(0);
    expect(plan.totalSpaceReclaimed).toBe(0);
  });

  test("handles single artifact within policy", () => {
    const plan = applyRetentionPolicies(
      [makeArtifact({})],
      { keepLatestNPerWorkflow: 1 },
      false,
      NOW
    );

    expect(plan.toDelete).toHaveLength(0);
    expect(plan.toKeep).toHaveLength(1);
  });

  test("keepLatestNPerWorkflow=0 deletes all artifacts", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "a" }),
      makeArtifact({ name: "b" }),
    ];
    const plan = applyRetentionPolicies(artifacts, { keepLatestNPerWorkflow: 0 }, false, NOW);

    expect(plan.toDelete).toHaveLength(2);
    expect(plan.toKeep).toHaveLength(0);
  });
});

// --- Workflow structure tests ---

const WORKFLOW_PATH = path.resolve(__dirname, ".github/workflows/artifact-cleanup-script.yml");
const WORKFLOW_DIR = path.resolve(__dirname, ".github/workflows");

describe("Workflow structure", () => {
  test("workflow file exists", () => {
    expect(fs.existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("workflow contains expected triggers", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("push:");
    expect(content).toContain("pull_request:");
    expect(content).toContain("schedule:");
    expect(content).toContain("workflow_dispatch:");
  });

  test("workflow contains a job", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("jobs:");
    expect(content).toContain("runs-on: ubuntu-latest");
  });

  test("workflow references actions/checkout@v4", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("actions/checkout@v4");
  });

  test("workflow installs Bun", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("bun");
  });

  test("workflow runs unit tests", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("bun test");
  });

  test("workflow references artifact-cleanup.ts", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("artifact-cleanup.ts");
  });

  test("workflow references fixture files that exist", () => {
    const content = fs.readFileSync(WORKFLOW_PATH, "utf-8");
    expect(content).toContain("workflow-test-artifacts.json");
    expect(content).toContain("workflow-test-policy.json");

    const artifactsFile = path.resolve(__dirname, "fixtures/workflow-test-artifacts.json");
    const policyFile = path.resolve(__dirname, "fixtures/workflow-test-policy.json");
    expect(fs.existsSync(artifactsFile)).toBe(true);
    expect(fs.existsSync(policyFile)).toBe(true);
  });

  test("actionlint passes on the workflow file", () => {
    // actionlint may not be installed in all environments (e.g., act Docker container)
    const whichResult = spawnSync("which", ["actionlint"], { encoding: "utf-8" });
    if (whichResult.status !== 0) {
      // Not installed — skip gracefully (validated separately on the host)
      return;
    }
    let exitCode = 0;
    try {
      execSync(`actionlint "${WORKFLOW_PATH}"`, { stdio: "pipe" });
    } catch (e: unknown) {
      exitCode = (e as { status: number }).status ?? 1;
    }
    expect(exitCode).toBe(0);
  });

  test("script file exists at path referenced by workflow", () => {
    expect(fs.existsSync(path.resolve(__dirname, "artifact-cleanup.ts"))).toBe(true);
  });
});
