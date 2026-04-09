/**
 * Artifact Cleanup Script - Tests
 * TDD approach: write failing tests first, then implement to pass.
 *
 * Tests cover:
 * 1. Artifact data model
 * 2. Max-age retention policy
 * 3. Max total size retention policy
 * 4. Keep-latest-N per workflow policy
 * 5. Deletion plan generation with summary
 * 6. Dry-run mode
 * 7. Workflow structure validation
 * 8. actionlint validation
 */

import { describe, test, expect } from "bun:test";
import { spawnSync } from "child_process";
import { existsSync } from "fs";
import { join } from "path";
import * as yaml from "./vendor/yaml.ts";

import {
  type Artifact,
  type RetentionPolicy,
  type DeletionPlan,
  applyRetentionPolicies,
  generateDeletionPlan,
} from "./artifact-cleanup.ts";

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const NOW = new Date("2024-06-01T00:00:00Z");

function makeArtifact(overrides: Partial<Artifact> = {}): Artifact {
  return {
    name: "test-artifact",
    sizeMB: 10,
    createdAt: new Date("2024-05-15T00:00:00Z"), // 17 days before NOW
    workflowRunId: "run-1",
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// 1. Artifact model
// ---------------------------------------------------------------------------

describe("Artifact model", () => {
  test("can create an artifact with required fields", () => {
    const artifact = makeArtifact();
    expect(artifact.name).toBe("test-artifact");
    expect(artifact.sizeMB).toBe(10);
    expect(artifact.createdAt).toBeInstanceOf(Date);
    expect(artifact.workflowRunId).toBe("run-1");
  });
});

// ---------------------------------------------------------------------------
// 2. Max-age retention policy
// ---------------------------------------------------------------------------

describe("Max-age retention policy", () => {
  const policy: RetentionPolicy = { maxAgeDays: 14 };

  test("keeps artifacts within max age", () => {
    // 5 days old — should be retained
    const artifact = makeArtifact({
      createdAt: new Date("2024-05-27T00:00:00Z"),
    });
    const plan = applyRetentionPolicies([artifact], policy, NOW);
    expect(plan.toDelete).toHaveLength(0);
    expect(plan.toRetain).toHaveLength(1);
  });

  test("deletes artifacts older than max age", () => {
    // 17 days old — should be deleted
    const artifact = makeArtifact({
      createdAt: new Date("2024-05-15T00:00:00Z"),
    });
    const plan = applyRetentionPolicies([artifact], policy, NOW);
    expect(plan.toDelete).toHaveLength(1);
    expect(plan.toRetain).toHaveLength(0);
  });

  test("keeps artifact exactly at max age boundary", () => {
    // Exactly 14 days old
    const artifact = makeArtifact({
      createdAt: new Date("2024-05-18T00:00:00Z"),
    });
    const plan = applyRetentionPolicies([artifact], policy, NOW);
    expect(plan.toRetain).toHaveLength(1);
  });
});

// ---------------------------------------------------------------------------
// 3. Max total size retention policy
// ---------------------------------------------------------------------------

describe("Max total size retention policy", () => {
  test("deletes oldest artifacts when total size exceeds limit", () => {
    // 3 artifacts, 30 MB each = 90 MB total; limit is 50 MB
    // Should delete oldest first until under limit
    const artifacts: Artifact[] = [
      makeArtifact({ name: "a1", sizeMB: 30, createdAt: new Date("2024-04-01T00:00:00Z"), workflowRunId: "r1" }),
      makeArtifact({ name: "a2", sizeMB: 30, createdAt: new Date("2024-04-15T00:00:00Z"), workflowRunId: "r2" }),
      makeArtifact({ name: "a3", sizeMB: 30, createdAt: new Date("2024-05-01T00:00:00Z"), workflowRunId: "r3" }),
    ];
    const policy: RetentionPolicy = { maxTotalSizeMB: 50 };
    const plan = applyRetentionPolicies(artifacts, policy, NOW);
    // a1 (oldest) deleted first → 60 MB; still over → delete a2 → 30 MB under limit
    expect(plan.toDelete.map((a) => a.name)).toEqual(["a1", "a2"]);
    expect(plan.toRetain.map((a) => a.name)).toEqual(["a3"]);
  });

  test("retains all when total size is within limit", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "a1", sizeMB: 10, workflowRunId: "r1" }),
      makeArtifact({ name: "a2", sizeMB: 15, workflowRunId: "r2" }),
    ];
    const policy: RetentionPolicy = { maxTotalSizeMB: 100 };
    const plan = applyRetentionPolicies(artifacts, policy, NOW);
    expect(plan.toDelete).toHaveLength(0);
    expect(plan.toRetain).toHaveLength(2);
  });
});

// ---------------------------------------------------------------------------
// 4. Keep-latest-N per workflow retention policy
// ---------------------------------------------------------------------------

describe("Keep-latest-N per workflow retention policy", () => {
  test("keeps only the N most recent artifacts per workflow", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "r1-old", workflowRunId: "wf-1", createdAt: new Date("2024-04-01T00:00:00Z") }),
      makeArtifact({ name: "r1-mid", workflowRunId: "wf-1", createdAt: new Date("2024-04-15T00:00:00Z") }),
      makeArtifact({ name: "r1-new", workflowRunId: "wf-1", createdAt: new Date("2024-05-01T00:00:00Z") }),
      makeArtifact({ name: "r2-only", workflowRunId: "wf-2", createdAt: new Date("2024-04-01T00:00:00Z") }),
    ];
    const policy: RetentionPolicy = { keepLatestNPerWorkflow: 2 };
    const plan = applyRetentionPolicies(artifacts, policy, NOW);
    // wf-1: keep r1-new, r1-mid; delete r1-old
    // wf-2: only 1 artifact, keep it
    expect(plan.toDelete.map((a) => a.name)).toEqual(["r1-old"]);
    expect(plan.toRetain).toHaveLength(3);
  });

  test("retains all when count is within N", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "a1", workflowRunId: "wf-1", createdAt: new Date("2024-04-01T00:00:00Z") }),
      makeArtifact({ name: "a2", workflowRunId: "wf-1", createdAt: new Date("2024-05-01T00:00:00Z") }),
    ];
    const policy: RetentionPolicy = { keepLatestNPerWorkflow: 5 };
    const plan = applyRetentionPolicies(artifacts, policy, NOW);
    expect(plan.toDelete).toHaveLength(0);
    expect(plan.toRetain).toHaveLength(2);
  });
});

// ---------------------------------------------------------------------------
// 5. Deletion plan summary
// ---------------------------------------------------------------------------

describe("Deletion plan summary", () => {
  test("computes correct summary statistics", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "del1", sizeMB: 20, workflowRunId: "r1", createdAt: new Date("2024-01-01T00:00:00Z") }),
      makeArtifact({ name: "del2", sizeMB: 30, workflowRunId: "r2", createdAt: new Date("2024-01-02T00:00:00Z") }),
      makeArtifact({ name: "keep1", sizeMB: 10, workflowRunId: "r3", createdAt: new Date("2024-05-30T00:00:00Z") }),
    ];
    const policy: RetentionPolicy = { maxAgeDays: 14 };
    const plan = generateDeletionPlan(artifacts, policy, NOW);

    expect(plan.summary.totalArtifacts).toBe(3);
    expect(plan.summary.toDeleteCount).toBe(2);
    expect(plan.summary.toRetainCount).toBe(1);
    expect(plan.summary.spaceReclaimedMB).toBe(50);
    expect(plan.summary.spaceSavedPercent).toBeCloseTo(83.33, 1);
  });
});

// ---------------------------------------------------------------------------
// 6. Combined policies (union of deletions)
// ---------------------------------------------------------------------------

describe("Combined policies", () => {
  test("applies all policies and unions deletions", () => {
    // Artifact A: old (violates maxAge) AND large (violates maxTotalSize) — deleted once
    // Artifact B: fine on age, but workflow has too many — deleted by keepLatestN
    // Artifact C: retained by all policies
    const artifacts: Artifact[] = [
      makeArtifact({ name: "A", sizeMB: 200, workflowRunId: "wf-1", createdAt: new Date("2024-01-01T00:00:00Z") }),
      makeArtifact({ name: "B", sizeMB: 5, workflowRunId: "wf-1", createdAt: new Date("2024-05-20T00:00:00Z") }),
      makeArtifact({ name: "C", sizeMB: 5, workflowRunId: "wf-1", createdAt: new Date("2024-05-30T00:00:00Z") }),
    ];
    const policy: RetentionPolicy = {
      maxAgeDays: 14,
      maxTotalSizeMB: 100,
      keepLatestNPerWorkflow: 1,
    };
    const plan = applyRetentionPolicies(artifacts, policy, NOW);
    // A: deleted by maxAge AND maxTotalSize
    // B: deleted by keepLatestN (C is newer, only keep 1)
    // C: retained
    const deletedNames = plan.toDelete.map((a) => a.name).sort();
    expect(deletedNames).toEqual(["A", "B"]);
    expect(plan.toRetain.map((a) => a.name)).toEqual(["C"]);
  });
});

// ---------------------------------------------------------------------------
// 7. Dry-run mode
// ---------------------------------------------------------------------------

describe("Dry-run mode", () => {
  test("dry-run plan marks items as dry-run and does not actually delete", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "old", createdAt: new Date("2024-01-01T00:00:00Z") }),
    ];
    const policy: RetentionPolicy = { maxAgeDays: 14 };
    const plan = generateDeletionPlan(artifacts, policy, NOW, { dryRun: true });
    expect(plan.dryRun).toBe(true);
    expect(plan.toDelete).toHaveLength(1);
    // In dry-run, the summary still reflects what WOULD be deleted
    expect(plan.summary.spaceReclaimedMB).toBe(10);
  });

  test("non-dry-run plan has dryRun=false", () => {
    const plan = generateDeletionPlan([], {}, NOW);
    expect(plan.dryRun).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// 8. Workflow structure tests
// ---------------------------------------------------------------------------

describe("GitHub Actions workflow structure", () => {
  const workflowPath = join(import.meta.dir, ".github/workflows/artifact-cleanup-script.yml");

  test("workflow file exists", () => {
    expect(existsSync(workflowPath)).toBe(true);
  });

  test("workflow has expected triggers", async () => {
    const content = await Bun.file(workflowPath).text();
    const wf = yaml.parse(content);
    expect(wf.on).toBeDefined();
    // Must have push trigger
    expect(wf.on.push !== undefined || wf.on["push"] !== undefined).toBe(true);
  });

  test("workflow has at least one job", async () => {
    const content = await Bun.file(workflowPath).text();
    const wf = yaml.parse(content);
    expect(Object.keys(wf.jobs).length).toBeGreaterThan(0);
  });

  test("workflow references artifact-cleanup.ts", async () => {
    const content = await Bun.file(workflowPath).text();
    expect(content).toContain("artifact-cleanup.ts");
  });

  test("script file exists", () => {
    expect(existsSync(join(import.meta.dir, "artifact-cleanup.ts"))).toBe(true);
  });

  test("actionlint passes on workflow file", () => {
    const result = spawnSync("actionlint", [workflowPath], { encoding: "utf8" });
    if (result.status !== 0) {
      console.error("actionlint output:", result.stdout, result.stderr);
    }
    expect(result.status).toBe(0);
  });
});
