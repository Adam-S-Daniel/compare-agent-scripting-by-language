import { describe, it, expect, beforeEach } from "bun:test";
import {
  type Artifact,
  type RetentionPolicy,
  type DeletionPlan,
  applyRetentionPolicies,
  generateDeletionPlan,
} from "./artifact-cleanup";

// Test fixtures
const NOW = new Date("2024-01-15T12:00:00Z");

const makeArtifact = (
  overrides: Partial<Artifact> & { name: string }
): Artifact => ({
  id: overrides.name,
  name: overrides.name,
  sizeBytes: overrides.sizeBytes ?? 1024 * 1024, // 1MB default
  createdAt: overrides.createdAt ?? new Date("2024-01-10T00:00:00Z"),
  workflowRunId: overrides.workflowRunId ?? "run-1",
});

// --- max-age policy ---

describe("applyRetentionPolicies - maxAgeDays", () => {
  it("marks artifact as deleted when older than maxAgeDays", () => {
    const artifacts: Artifact[] = [
      makeArtifact({
        name: "old",
        createdAt: new Date("2024-01-01T00:00:00Z"), // 14 days old
      }),
    ];
    const policy: RetentionPolicy = { maxAgeDays: 7 };
    const result = applyRetentionPolicies(artifacts, policy, NOW);
    expect(result.toDelete).toContainEqual(expect.objectContaining({ name: "old" }));
  });

  it("keeps artifact within maxAgeDays", () => {
    const artifacts: Artifact[] = [
      makeArtifact({
        name: "recent",
        createdAt: new Date("2024-01-12T00:00:00Z"), // 3 days old
      }),
    ];
    const policy: RetentionPolicy = { maxAgeDays: 7 };
    const result = applyRetentionPolicies(artifacts, policy, NOW);
    expect(result.toKeep).toContainEqual(expect.objectContaining({ name: "recent" }));
    expect(result.toDelete).toHaveLength(0);
  });
});

// --- maxTotalSizeBytes policy ---

describe("applyRetentionPolicies - maxTotalSizeBytes", () => {
  it("deletes oldest artifacts when total size exceeds limit", () => {
    const artifacts: Artifact[] = [
      makeArtifact({
        name: "oldest",
        sizeBytes: 5 * 1024 * 1024,
        createdAt: new Date("2024-01-01T00:00:00Z"),
      }),
      makeArtifact({
        name: "middle",
        sizeBytes: 5 * 1024 * 1024,
        createdAt: new Date("2024-01-05T00:00:00Z"),
      }),
      makeArtifact({
        name: "newest",
        sizeBytes: 5 * 1024 * 1024,
        createdAt: new Date("2024-01-10T00:00:00Z"),
      }),
    ];
    // Limit to 8MB — "oldest" (5MB) must go to get under limit
    const policy: RetentionPolicy = { maxTotalSizeBytes: 8 * 1024 * 1024 };
    const result = applyRetentionPolicies(artifacts, policy, NOW);
    expect(result.toDelete).toContainEqual(expect.objectContaining({ name: "oldest" }));
    expect(result.toKeep.map((a) => a.name)).toContain("newest");
  });

  it("keeps all artifacts when total size is under limit", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "a", sizeBytes: 1024 }),
      makeArtifact({ name: "b", sizeBytes: 1024 }),
    ];
    const policy: RetentionPolicy = { maxTotalSizeBytes: 100 * 1024 * 1024 };
    const result = applyRetentionPolicies(artifacts, policy, NOW);
    expect(result.toDelete).toHaveLength(0);
    expect(result.toKeep).toHaveLength(2);
  });
});

// --- keepLatestNPerWorkflow policy ---

describe("applyRetentionPolicies - keepLatestNPerWorkflow", () => {
  it("keeps only the N most recent artifacts per workflow", () => {
    const artifacts: Artifact[] = [
      makeArtifact({
        name: "run1",
        workflowRunId: "wf-a",
        createdAt: new Date("2024-01-01T00:00:00Z"),
      }),
      makeArtifact({
        name: "run2",
        workflowRunId: "wf-a",
        createdAt: new Date("2024-01-05T00:00:00Z"),
      }),
      makeArtifact({
        name: "run3",
        workflowRunId: "wf-a",
        createdAt: new Date("2024-01-10T00:00:00Z"),
      }),
    ];
    const policy: RetentionPolicy = { keepLatestNPerWorkflow: 2 };
    const result = applyRetentionPolicies(artifacts, policy, NOW);
    // Only run1 (oldest) should be deleted
    expect(result.toDelete).toHaveLength(1);
    expect(result.toDelete[0].name).toBe("run1");
    expect(result.toKeep.map((a) => a.name).sort()).toEqual(["run2", "run3"].sort());
  });

  it("keeps all artifacts when count is within keepLatestN limit", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "a", workflowRunId: "wf-x" }),
      makeArtifact({ name: "b", workflowRunId: "wf-x" }),
    ];
    const policy: RetentionPolicy = { keepLatestNPerWorkflow: 5 };
    const result = applyRetentionPolicies(artifacts, policy, NOW);
    expect(result.toDelete).toHaveLength(0);
  });
});

// --- combined policies ---

describe("applyRetentionPolicies - combined policies", () => {
  it("applies all policies and unions deletions", () => {
    const artifacts: Artifact[] = [
      makeArtifact({
        name: "ancient",
        sizeBytes: 1024,
        createdAt: new Date("2023-12-01T00:00:00Z"), // very old
        workflowRunId: "wf-1",
      }),
      makeArtifact({
        name: "mid",
        sizeBytes: 1024,
        createdAt: new Date("2024-01-10T00:00:00Z"),
        workflowRunId: "wf-1",
      }),
      makeArtifact({
        name: "fresh",
        sizeBytes: 1024,
        createdAt: new Date("2024-01-14T00:00:00Z"),
        workflowRunId: "wf-1",
      }),
    ];
    const policy: RetentionPolicy = {
      maxAgeDays: 30,
      keepLatestNPerWorkflow: 2,
    };
    const result = applyRetentionPolicies(artifacts, policy, NOW);
    // "ancient" is caught by maxAgeDays; "mid" stays if keepLatestN keeps top 2 (mid+fresh)
    expect(result.toDelete.map((a) => a.name)).toContain("ancient");
  });
});

// --- generateDeletionPlan ---

describe("generateDeletionPlan", () => {
  const artifacts: Artifact[] = [
    makeArtifact({
      name: "old-big",
      sizeBytes: 50 * 1024 * 1024,
      createdAt: new Date("2024-01-01T00:00:00Z"),
      workflowRunId: "wf-1",
    }),
    makeArtifact({
      name: "recent-small",
      sizeBytes: 1024,
      createdAt: new Date("2024-01-14T00:00:00Z"),
      workflowRunId: "wf-1",
    }),
  ];
  const policy: RetentionPolicy = { maxAgeDays: 7 };

  it("returns correct summary counts", () => {
    const plan = generateDeletionPlan(artifacts, policy, { dryRun: true, now: NOW });
    expect(plan.summary.totalArtifacts).toBe(2);
    expect(plan.summary.deletedCount).toBe(1);
    expect(plan.summary.retainedCount).toBe(1);
  });

  it("calculates space reclaimed correctly", () => {
    const plan = generateDeletionPlan(artifacts, policy, { dryRun: true, now: NOW });
    expect(plan.summary.spaceReclaimedBytes).toBe(50 * 1024 * 1024);
  });

  it("sets dryRun flag in plan", () => {
    const plan = generateDeletionPlan(artifacts, policy, { dryRun: true, now: NOW });
    expect(plan.dryRun).toBe(true);
  });

  it("lists artifacts to delete and to keep", () => {
    const plan = generateDeletionPlan(artifacts, policy, { dryRun: false, now: NOW });
    expect(plan.toDelete.map((a) => a.name)).toContain("old-big");
    expect(plan.toKeep.map((a) => a.name)).toContain("recent-small");
  });

  it("returns empty deletions when no policy criteria matched", () => {
    const plan = generateDeletionPlan(artifacts, {}, { dryRun: false, now: NOW });
    expect(plan.toDelete).toHaveLength(0);
    expect(plan.summary.spaceReclaimedBytes).toBe(0);
  });
});

// --- edge cases ---

describe("edge cases", () => {
  it("handles empty artifact list", () => {
    const plan = generateDeletionPlan([], { maxAgeDays: 7 }, { dryRun: false, now: NOW });
    expect(plan.toDelete).toHaveLength(0);
    expect(plan.toKeep).toHaveLength(0);
    expect(plan.summary.spaceReclaimedBytes).toBe(0);
  });

  it("handles artifact created exactly on the age boundary", () => {
    const boundary = new Date(NOW.getTime() - 7 * 24 * 60 * 60 * 1000); // exactly 7 days ago
    const artifacts = [makeArtifact({ name: "boundary", createdAt: boundary })];
    const policy: RetentionPolicy = { maxAgeDays: 7 };
    const result = applyRetentionPolicies(artifacts, policy, NOW);
    // Exactly on boundary — keep (age < maxAgeDays is the comparison)
    expect(result.toKeep).toHaveLength(1);
  });
});
