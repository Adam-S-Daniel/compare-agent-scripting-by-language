// TDD: Tests written BEFORE implementation (red phase).
// Each describe block targets one retention policy dimension.

import { describe, test, expect } from "bun:test";
import { applyRetentionPolicies } from "./cleanup";
import type { Artifact, RetentionPolicy } from "./types";

// Helper — create an artifact with sensible defaults, override as needed
function makeArtifact(overrides: Partial<Artifact> & { name: string }): Artifact {
  return {
    sizeBytes: 104_857_600, // 100 MB
    createdAt: "2026-04-01T00:00:00Z",
    workflowRunId: "run-1",
    ...overrides,
  };
}

const REF_DATE = "2026-04-09T00:00:00Z";

// ── Max age policy ──────────────────────────────────────────────────
describe("max age policy", () => {
  test("deletes artifacts older than maxAgeDays", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "recent", createdAt: "2026-04-01T00:00:00Z", sizeBytes: 104_857_600 }),
      makeArtifact({ name: "old", createdAt: "2026-03-01T00:00:00Z", sizeBytes: 209_715_200 }),
      makeArtifact({ name: "very-old", createdAt: "2026-02-01T00:00:00Z", sizeBytes: 314_572_800 }),
    ];
    const policy: RetentionPolicy = { maxAgeDays: 30 };
    const plan = applyRetentionPolicies(artifacts, policy, REF_DATE);

    expect(plan.toDelete.length).toBe(2);
    expect(plan.toRetain.length).toBe(1);
    expect(plan.toRetain[0].name).toBe("recent");
    expect(plan.summary.spaceReclaimedBytes).toBe(524_288_000); // 500 MB
    expect(plan.toDelete.every((e) => e.reason === "max_age")).toBe(true);
  });

  test("retains all when none exceed max age", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "a1", createdAt: "2026-04-08T00:00:00Z" }),
      makeArtifact({ name: "a2", createdAt: "2026-04-07T00:00:00Z" }),
    ];
    const plan = applyRetentionPolicies(artifacts, { maxAgeDays: 30 }, REF_DATE);

    expect(plan.toDelete.length).toBe(0);
    expect(plan.toRetain.length).toBe(2);
  });
});

// ── Keep-latest-N per workflow ──────────────────────────────────────
describe("keep-latest-N policy", () => {
  test("keeps only N most recent per workflow", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "build-3", createdAt: "2026-04-03T00:00:00Z", workflowRunId: "build" }),
      makeArtifact({ name: "build-2", createdAt: "2026-04-02T00:00:00Z", workflowRunId: "build" }),
      makeArtifact({ name: "build-1", createdAt: "2026-04-01T00:00:00Z", workflowRunId: "build" }),
      makeArtifact({ name: "test-2", createdAt: "2026-04-03T00:00:00Z", workflowRunId: "test" }),
      makeArtifact({ name: "test-1", createdAt: "2026-04-01T00:00:00Z", workflowRunId: "test" }),
    ];
    const plan = applyRetentionPolicies(artifacts, { keepLatestN: 1 }, REF_DATE);

    expect(plan.toDelete.length).toBe(3);
    expect(plan.toRetain.length).toBe(2);
    // The two retained should be the newest per workflow
    expect(plan.toRetain.map((a) => a.name).sort()).toEqual(["build-3", "test-2"]);
    expect(plan.toDelete.every((e) => e.reason === "keep_latest_n")).toBe(true);
  });

  test("retains all when each workflow has <= N artifacts", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "b1", workflowRunId: "build" }),
      makeArtifact({ name: "t1", workflowRunId: "test" }),
    ];
    const plan = applyRetentionPolicies(artifacts, { keepLatestN: 5 }, REF_DATE);

    expect(plan.toDelete.length).toBe(0);
    expect(plan.toRetain.length).toBe(2);
  });
});

// ── Max total size policy ───────────────────────────────────────────
describe("max total size policy", () => {
  test("deletes oldest artifacts to fit within size budget", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "newest", createdAt: "2026-04-08T00:00:00Z", sizeBytes: 209_715_200 }),
      makeArtifact({ name: "middle", createdAt: "2026-04-06T00:00:00Z", sizeBytes: 157_286_400 }),
      makeArtifact({ name: "older", createdAt: "2026-04-04T00:00:00Z", sizeBytes: 262_144_000 }),
      makeArtifact({ name: "oldest", createdAt: "2026-04-02T00:00:00Z", sizeBytes: 314_572_800 }),
    ];
    // Total 900 MB, budget 500 MB → delete oldest (300 MB), then older (250 MB)
    const plan = applyRetentionPolicies(
      artifacts,
      { maxTotalSizeBytes: 524_288_000 },
      REF_DATE
    );

    expect(plan.toDelete.length).toBe(2);
    expect(plan.toDelete.map((e) => e.artifact.name).sort()).toEqual(["older", "oldest"]);
    expect(plan.summary.spaceReclaimedBytes).toBe(576_716_800); // 550 MB
    expect(plan.toDelete.every((e) => e.reason === "max_total_size")).toBe(true);
  });

  test("retains all when total size is under budget", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "small", sizeBytes: 52_428_800 }),
    ];
    const plan = applyRetentionPolicies(
      artifacts,
      { maxTotalSizeBytes: 1_073_741_824 },
      REF_DATE
    );

    expect(plan.toDelete.length).toBe(0);
  });
});

// ── Combined policies ───────────────────────────────────────────────
describe("combined policies", () => {
  test("applies all three policies together (most restrictive wins)", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "build-new", createdAt: "2026-04-08T00:00:00Z", sizeBytes: 104_857_600, workflowRunId: "build" }),
      makeArtifact({ name: "build-old", createdAt: "2026-02-01T00:00:00Z", sizeBytes: 209_715_200, workflowRunId: "build" }),
      makeArtifact({ name: "test-new", createdAt: "2026-04-07T00:00:00Z", sizeBytes: 157_286_400, workflowRunId: "test" }),
      makeArtifact({ name: "test-mid", createdAt: "2026-04-01T00:00:00Z", sizeBytes: 104_857_600, workflowRunId: "test" }),
      makeArtifact({ name: "test-old", createdAt: "2026-03-01T00:00:00Z", sizeBytes: 314_572_800, workflowRunId: "test" }),
    ];
    // maxAge 30d → deletes build-old (67d), test-old (39d)
    // keepLatestN 2 → remaining per-wf counts <=2, no extra deletions
    // maxTotalSize 300MB → remaining: build-new(100)+test-new(150)+test-mid(100)=350MB
    //   → delete oldest remaining (test-mid 100MB) → 250MB, under budget
    const plan = applyRetentionPolicies(
      artifacts,
      { maxAgeDays: 30, keepLatestN: 2, maxTotalSizeBytes: 314_572_800 },
      REF_DATE
    );

    expect(plan.summary.deletedCount).toBe(3);
    expect(plan.summary.retainedCount).toBe(2);
    expect(plan.toRetain.map((a) => a.name).sort()).toEqual(["build-new", "test-new"]);
  });
});

// ── Dry-run mode ────────────────────────────────────────────────────
describe("dry-run mode", () => {
  test("produces the same plan but flags dryRun=true", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "keep", createdAt: "2026-04-08T00:00:00Z" }),
      makeArtifact({ name: "delete-me", createdAt: "2026-02-01T00:00:00Z" }),
    ];
    const plan = applyRetentionPolicies(
      artifacts,
      { maxAgeDays: 30, dryRun: true },
      REF_DATE
    );

    expect(plan.dryRun).toBe(true);
    expect(plan.toDelete.length).toBe(1);
    expect(plan.toDelete[0].artifact.name).toBe("delete-me");
  });
});

// ── Edge cases ──────────────────────────────────────────────────────
describe("edge cases", () => {
  test("handles empty artifact list", () => {
    const plan = applyRetentionPolicies([], { maxAgeDays: 30 }, REF_DATE);

    expect(plan.toDelete.length).toBe(0);
    expect(plan.toRetain.length).toBe(0);
    expect(plan.summary.totalArtifacts).toBe(0);
    expect(plan.summary.spaceReclaimedBytes).toBe(0);
  });

  test("handles no policy constraints (retains everything)", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ name: "a1" }),
      makeArtifact({ name: "a2" }),
    ];
    const plan = applyRetentionPolicies(artifacts, {}, REF_DATE);

    expect(plan.toDelete.length).toBe(0);
    expect(plan.toRetain.length).toBe(2);
  });

  test("rejects negative maxAgeDays", () => {
    expect(() =>
      applyRetentionPolicies([], { maxAgeDays: -1 }, REF_DATE)
    ).toThrow("maxAgeDays must be a non-negative number");
  });

  test("rejects negative maxTotalSizeBytes", () => {
    expect(() =>
      applyRetentionPolicies([], { maxTotalSizeBytes: -1 }, REF_DATE)
    ).toThrow("maxTotalSizeBytes must be a non-negative number");
  });

  test("rejects keepLatestN < 1", () => {
    expect(() =>
      applyRetentionPolicies([], { keepLatestN: 0 }, REF_DATE)
    ).toThrow("keepLatestN must be at least 1");
  });
});
