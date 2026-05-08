// TDD: Tests written FIRST before implementation exists.
// Red phase: these tests fail because src/cleanup.ts doesn't exist yet.
// Green phase: implement the minimum code to make each test pass.
// Refactor phase: clean up while keeping tests green.

import { describe, test, expect } from "bun:test";
import { applyRetentionPolicies } from "../src/cleanup";
import type { Artifact, RetentionPolicy, CleanupOptions } from "../src/types";

// Fixed "now" date for deterministic age calculations: 2026-05-08
const NOW = new Date("2026-05-08T00:00:00Z");
const OPTS = (dryRun = false): CleanupOptions => ({ dryRun, now: NOW });

// Test fixtures
const OLD_ARTIFACT: Artifact = {
  name: "artifact-old",
  size: 31457280, // 30 MB
  createdAt: "2020-01-01T00:00:00Z", // 2318 days before NOW
  workflowRunId: "run-1",
};
const MEDIUM_ARTIFACT: Artifact = {
  name: "artifact-medium",
  size: 10485760, // 10 MB
  createdAt: "2024-01-01T00:00:00Z", // ~857 days before NOW
  workflowRunId: "run-2",
};
const NEW_ARTIFACT: Artifact = {
  name: "artifact-new",
  size: 5242880, // 5 MB
  createdAt: "2025-06-01T00:00:00Z", // ~341 days before NOW
  workflowRunId: "run-3",
};

// --- TDD STEP 1: empty policy returns all artifacts as retained ---
describe("applyRetentionPolicies - empty policy", () => {
  test("with no policy rules, all artifacts are retained and none deleted", () => {
    const artifacts = [OLD_ARTIFACT, MEDIUM_ARTIFACT, NEW_ARTIFACT];
    const policy: RetentionPolicy = {};
    const plan = applyRetentionPolicies(artifacts, policy, OPTS());

    expect(plan.toDelete).toHaveLength(0);
    expect(plan.toRetain).toHaveLength(3);
    expect(plan.summary.artifactsDeleted).toBe(0);
    expect(plan.summary.artifactsRetained).toBe(3);
    expect(plan.summary.spaceReclaimedBytes).toBe(0);
    expect(plan.summary.dryRun).toBe(false);
  });
});

// --- TDD STEP 2: max age policy ---
describe("applyRetentionPolicies - maxAgeDays", () => {
  test("artifacts older than maxAgeDays are marked for deletion", () => {
    const artifacts = [OLD_ARTIFACT, MEDIUM_ARTIFACT, NEW_ARTIFACT];
    // maxAgeDays=1000: OLD_ARTIFACT (2318 days) deleted, others retained
    const policy: RetentionPolicy = { maxAgeDays: 1000 };
    const plan = applyRetentionPolicies(artifacts, policy, OPTS());

    expect(plan.toDelete).toHaveLength(1);
    expect(plan.toDelete[0]!.name).toBe("artifact-old");
    expect(plan.toRetain).toHaveLength(2);
    expect(plan.summary.artifactsDeleted).toBe(1);
    expect(plan.summary.artifactsRetained).toBe(2);
    expect(plan.summary.spaceReclaimedBytes).toBe(31457280);
  });

  test("artifacts exactly at the age boundary are retained (boundary is exclusive)", () => {
    // 2319 days old artifact, maxAgeDays=2319 → retained (age == limit, not strictly over)
    const policy: RetentionPolicy = { maxAgeDays: 2319 };
    const plan = applyRetentionPolicies([OLD_ARTIFACT], policy, OPTS());
    // actual age: 2026-05-08 - 2020-01-01 = 2319 days exactly
    // The check is: age > cutoff (strictly greater), so equal is retained
    expect(plan.toRetain).toHaveLength(1);
    expect(plan.toDelete).toHaveLength(0);
  });

  test("all artifacts within max age are retained", () => {
    const artifacts = [OLD_ARTIFACT, MEDIUM_ARTIFACT, NEW_ARTIFACT];
    const policy: RetentionPolicy = { maxAgeDays: 9999 };
    const plan = applyRetentionPolicies(artifacts, policy, OPTS());

    expect(plan.toDelete).toHaveLength(0);
    expect(plan.toRetain).toHaveLength(3);
  });
});

// --- TDD STEP 3: keepLatestNPerWorkflow policy ---
describe("applyRetentionPolicies - keepLatestNPerWorkflow", () => {
  const SAME_WORKFLOW_ARTIFACTS: Artifact[] = [
    { name: "build-run1", size: 5242880, createdAt: "2025-06-01T00:00:00Z", workflowRunId: "ci-workflow" },
    { name: "build-run2", size: 5242880, createdAt: "2025-01-01T00:00:00Z", workflowRunId: "ci-workflow" },
    { name: "build-run3", size: 5242880, createdAt: "2024-06-01T00:00:00Z", workflowRunId: "ci-workflow" },
    { name: "build-run4", size: 5242880, createdAt: "2024-01-01T00:00:00Z", workflowRunId: "ci-workflow" },
  ];

  test("keeps only the N most recent artifacts per workflowRunId group", () => {
    const policy: RetentionPolicy = { keepLatestNPerWorkflow: 2 };
    const plan = applyRetentionPolicies(SAME_WORKFLOW_ARTIFACTS, policy, OPTS());

    expect(plan.toDelete).toHaveLength(2);
    expect(plan.toRetain).toHaveLength(2);
    // Most recent two should be retained
    const retainedNames = plan.toRetain.map((a) => a.name).sort();
    expect(retainedNames).toEqual(["build-run1", "build-run2"]);
    expect(plan.summary.spaceReclaimedBytes).toBe(10485760); // 2 × 5 MB
  });

  test("handles multiple workflow groups independently", () => {
    const artifacts: Artifact[] = [
      { name: "ci-new", size: 1000, createdAt: "2025-06-01T00:00:00Z", workflowRunId: "ci" },
      { name: "ci-old", size: 1000, createdAt: "2024-01-01T00:00:00Z", workflowRunId: "ci" },
      { name: "deploy-new", size: 2000, createdAt: "2025-06-01T00:00:00Z", workflowRunId: "deploy" },
      { name: "deploy-mid", size: 2000, createdAt: "2024-06-01T00:00:00Z", workflowRunId: "deploy" },
      { name: "deploy-old", size: 2000, createdAt: "2023-01-01T00:00:00Z", workflowRunId: "deploy" },
    ];
    const policy: RetentionPolicy = { keepLatestNPerWorkflow: 1 };
    const plan = applyRetentionPolicies(artifacts, policy, OPTS());

    // ci: keep ci-new, delete ci-old
    // deploy: keep deploy-new, delete deploy-mid and deploy-old
    expect(plan.toDelete).toHaveLength(3);
    expect(plan.toRetain).toHaveLength(2);
    const retainedNames = plan.toRetain.map((a) => a.name).sort();
    expect(retainedNames).toEqual(["ci-new", "deploy-new"]);
  });

  test("if N >= group size, nothing is deleted from that group", () => {
    const policy: RetentionPolicy = { keepLatestNPerWorkflow: 10 };
    const plan = applyRetentionPolicies(SAME_WORKFLOW_ARTIFACTS, policy, OPTS());

    expect(plan.toDelete).toHaveLength(0);
    expect(plan.toRetain).toHaveLength(4);
  });
});

// --- TDD STEP 4: maxTotalSizeBytes policy ---
describe("applyRetentionPolicies - maxTotalSizeBytes", () => {
  const SIZE_ARTIFACTS: Artifact[] = [
    { name: "cache-2025", size: 15728640, createdAt: "2025-01-01T00:00:00Z", workflowRunId: "build-1" },
    { name: "cache-2024", size: 10485760, createdAt: "2024-06-01T00:00:00Z", workflowRunId: "build-2" },
    { name: "cache-2023", size: 10485760, createdAt: "2023-01-01T00:00:00Z", workflowRunId: "build-3" },
  ];
  // Total: 36700160 bytes

  test("deletes oldest artifacts until total size is under the limit", () => {
    // Limit 31457280 (30 MB). Total is 36700160. Delete oldest (cache-2023, 10MB) → 26214400 ≤ 30MB.
    const policy: RetentionPolicy = { maxTotalSizeBytes: 31457280 };
    const plan = applyRetentionPolicies(SIZE_ARTIFACTS, policy, OPTS());

    expect(plan.toDelete).toHaveLength(1);
    expect(plan.toDelete[0]!.name).toBe("cache-2023");
    expect(plan.toRetain).toHaveLength(2);
    expect(plan.summary.spaceReclaimedBytes).toBe(10485760);
  });

  test("does not delete anything if total size is already within limit", () => {
    const policy: RetentionPolicy = { maxTotalSizeBytes: 999999999 };
    const plan = applyRetentionPolicies(SIZE_ARTIFACTS, policy, OPTS());

    expect(plan.toDelete).toHaveLength(0);
    expect(plan.toRetain).toHaveLength(3);
  });

  test("deletes multiple oldest artifacts when needed to get under limit", () => {
    // Limit 10 MB. Must delete cache-2023 (10MB → 26MB) then cache-2024 (10MB → 16MB) then partially — but we delete whole artifacts.
    // Delete cache-2023: 36700160-10485760=26214400 > 10485760
    // Delete cache-2024: 26214400-10485760=15728640 > 10485760
    // Delete cache-2025: 15728640-15728640=0 ≤ 10485760 — all deleted!
    const policy: RetentionPolicy = { maxTotalSizeBytes: 10485760 };
    const plan = applyRetentionPolicies(SIZE_ARTIFACTS, policy, OPTS());

    expect(plan.toDelete).toHaveLength(3);
    expect(plan.toRetain).toHaveLength(0);
  });
});

// --- TDD STEP 5: dry-run mode ---
describe("applyRetentionPolicies - dry-run mode", () => {
  test("dry-run produces the same deletion plan but flags dryRun=true in summary", () => {
    const artifacts = [OLD_ARTIFACT, MEDIUM_ARTIFACT, NEW_ARTIFACT];
    const policy: RetentionPolicy = { maxAgeDays: 1000 };

    const livePlan = applyRetentionPolicies(artifacts, policy, OPTS(false));
    const dryPlan = applyRetentionPolicies(artifacts, policy, OPTS(true));

    // Same artifacts deleted/retained
    expect(dryPlan.toDelete).toHaveLength(livePlan.toDelete.length);
    expect(dryPlan.toRetain).toHaveLength(livePlan.toRetain.length);
    expect(dryPlan.summary.spaceReclaimedBytes).toBe(livePlan.summary.spaceReclaimedBytes);

    // Only difference: dryRun flag
    expect(livePlan.summary.dryRun).toBe(false);
    expect(dryPlan.summary.dryRun).toBe(true);
  });
});

// --- TDD STEP 6: combined policies ---
describe("applyRetentionPolicies - combined policies", () => {
  test("max age is applied first, then keep-latest-N on remaining artifacts", () => {
    // Artifacts: old1 (2020, run-A), old2 (2020, run-A), new1 (2025, run-A), new2 (2025, run-A)
    // max age 1000 days → old1 and old2 deleted
    // keepLatestN=1 on remaining [new1, new2] (same workflowRunId run-A) → delete older (new2)
    const artifacts: Artifact[] = [
      { name: "old1", size: 1000, createdAt: "2020-01-01T00:00:00Z", workflowRunId: "run-A" },
      { name: "old2", size: 1000, createdAt: "2020-06-01T00:00:00Z", workflowRunId: "run-A" },
      { name: "new1", size: 1000, createdAt: "2025-06-01T00:00:00Z", workflowRunId: "run-A" },
      { name: "new2", size: 1000, createdAt: "2025-01-01T00:00:00Z", workflowRunId: "run-A" },
    ];
    const policy: RetentionPolicy = { maxAgeDays: 1000, keepLatestNPerWorkflow: 1 };
    const plan = applyRetentionPolicies(artifacts, policy, OPTS());

    expect(plan.toDelete).toHaveLength(3);
    expect(plan.toRetain).toHaveLength(1);
    expect(plan.toRetain[0]!.name).toBe("new1"); // newest after age filter
  });
});
