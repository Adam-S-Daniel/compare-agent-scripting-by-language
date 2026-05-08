import { describe, test, expect } from "bun:test";
import { generateDeletionPlan, formatPlan } from "../src/cleanup";
import type { Artifact, RetentionPolicy } from "../src/types";

// Helper to create artifacts with controlled dates
function makeArtifact(overrides: Partial<Artifact> & { name: string }): Artifact {
  return {
    sizeBytes: 1000000,
    createdAt: new Date("2026-05-01T00:00:00Z"),
    workflowRunId: "wf-default",
    ...overrides,
  };
}

describe("generateDeletionPlan", () => {
  test("returns empty plan for empty artifact list", () => {
    const plan = generateDeletionPlan([], {}, { dryRun: true });
    expect(plan.toDelete).toHaveLength(0);
    expect(plan.toRetain).toHaveLength(0);
    expect(plan.summary.totalSpaceReclaimedBytes).toBe(0);
    expect(plan.summary.artifactsDeleted).toBe(0);
    expect(plan.summary.artifactsRetained).toBe(0);
    expect(plan.dryRun).toBe(true);
  });

  test("max age policy deletes artifacts older than threshold", () => {
    const now = new Date("2026-05-07T00:00:00Z");
    const artifacts: Artifact[] = [
      makeArtifact({ name: "old", createdAt: new Date("2026-03-01T00:00:00Z"), sizeBytes: 5242880 }),
      makeArtifact({ name: "recent", createdAt: new Date("2026-05-05T00:00:00Z"), sizeBytes: 3145728 }),
    ];

    const plan = generateDeletionPlan(artifacts, { maxAgeDays: 30 }, { dryRun: true, now });

    expect(plan.toDelete).toHaveLength(1);
    expect(plan.toDelete[0].artifact.name).toBe("old");
    expect(plan.toDelete[0].reason).toContain("max age");
    expect(plan.toRetain).toHaveLength(1);
    expect(plan.toRetain[0].name).toBe("recent");
    expect(plan.summary.totalSpaceReclaimedBytes).toBe(5242880);
  });

  test("keep-latest-N per workflow retains only N most recent", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "a1", createdAt: new Date("2026-05-01T00:00:00Z"), workflowRunId: "wf-200" }),
      makeArtifact({ name: "a2", createdAt: new Date("2026-05-02T00:00:00Z"), workflowRunId: "wf-200" }),
      makeArtifact({ name: "a3", createdAt: new Date("2026-05-03T00:00:00Z"), workflowRunId: "wf-200" }),
      makeArtifact({ name: "a4", createdAt: new Date("2026-05-04T00:00:00Z"), workflowRunId: "wf-200" }),
      makeArtifact({ name: "other", createdAt: new Date("2026-05-01T00:00:00Z"), workflowRunId: "wf-300" }),
    ];

    const plan = generateDeletionPlan(artifacts, { keepLatestNPerWorkflow: 2 }, { dryRun: true });

    expect(plan.toDelete).toHaveLength(2);
    const deletedNames = plan.toDelete.map((e) => e.artifact.name).sort();
    expect(deletedNames).toEqual(["a1", "a2"]);
    expect(plan.toRetain).toHaveLength(3);
  });

  test("max total size deletes oldest artifacts first to meet budget", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "large", sizeBytes: 10485760, createdAt: new Date("2026-05-01T00:00:00Z") }),
      makeArtifact({ name: "medium", sizeBytes: 5242880, createdAt: new Date("2026-05-03T00:00:00Z") }),
      makeArtifact({ name: "small", sizeBytes: 1048576, createdAt: new Date("2026-05-05T00:00:00Z") }),
    ];

    const plan = generateDeletionPlan(artifacts, { maxTotalSizeBytes: 6291456 }, { dryRun: true });

    expect(plan.toDelete).toHaveLength(1);
    expect(plan.toDelete[0].artifact.name).toBe("large");
    expect(plan.summary.totalSpaceReclaimedBytes).toBe(10485760);
    expect(plan.toRetain).toHaveLength(2);
  });

  test("combined policies apply in order: age, keep-N, then size budget", () => {
    const now = new Date("2026-05-07T00:00:00Z");
    const artifacts: Artifact[] = [
      makeArtifact({ name: "ancient", sizeBytes: 8000000, createdAt: new Date("2026-01-01T00:00:00Z"), workflowRunId: "wf-500" }),
      makeArtifact({ name: "old", sizeBytes: 4000000, createdAt: new Date("2026-04-01T00:00:00Z"), workflowRunId: "wf-500" }),
      makeArtifact({ name: "r1", sizeBytes: 3000000, createdAt: new Date("2026-05-05T00:00:00Z"), workflowRunId: "wf-500" }),
      makeArtifact({ name: "r2", sizeBytes: 2000000, createdAt: new Date("2026-05-06T00:00:00Z"), workflowRunId: "wf-500" }),
      makeArtifact({ name: "r3", sizeBytes: 2500000, createdAt: new Date("2026-05-07T00:00:00Z"), workflowRunId: "wf-500" }),
    ];

    const policy: RetentionPolicy = {
      maxAgeDays: 30,
      keepLatestNPerWorkflow: 3,
      maxTotalSizeBytes: 7000000,
    };

    const plan = generateDeletionPlan(artifacts, policy, { dryRun: true, now });

    // "ancient" deleted by max age, "old" deleted by max age (36 days old)
    // After age filter: r1, r2, r3 remain (all within 30 days)
    // keep-latest-3: all 3 are kept (only 3 remain)
    // Size check: r1+r2+r3 = 7500000 > 7000000, so r1 (oldest) gets deleted
    expect(plan.summary.artifactsDeleted).toBe(3);
    expect(plan.summary.artifactsRetained).toBe(2);
    const deletedNames = plan.toDelete.map((e) => e.artifact.name).sort();
    expect(deletedNames).toContain("ancient");
    expect(deletedNames).toContain("old");
    expect(deletedNames).toContain("r1");
  });

  test("dry run flag is correctly set", () => {
    const artifacts = [makeArtifact({ name: "a" })];
    const planDry = generateDeletionPlan(artifacts, {}, { dryRun: true });
    expect(planDry.dryRun).toBe(true);

    const planLive = generateDeletionPlan(artifacts, {}, { dryRun: false });
    expect(planLive.dryRun).toBe(false);
  });
});

describe("formatPlan", () => {
  test("formats output with DRY RUN label", () => {
    const plan = generateDeletionPlan(
      [makeArtifact({ name: "test-artifact", sizeBytes: 2048 })],
      {},
      { dryRun: true }
    );
    const output = formatPlan(plan);
    expect(output).toContain("DRY RUN");
    expect(output).toContain("Artifacts deleted: 0");
    expect(output).toContain("Artifacts retained: 1");
  });

  test("formats output with LIVE label when not dry run", () => {
    const plan = generateDeletionPlan([], {}, { dryRun: false });
    const output = formatPlan(plan);
    expect(output).toContain("LIVE");
  });
});
