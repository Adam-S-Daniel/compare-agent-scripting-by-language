import { describe, expect, test } from "bun:test";
import {
  applyMaxAgePolicy,
  applyMaxTotalSizePolicy,
  applyKeepLatestNPolicy,
  buildDeletionPlan,
  parseArtifactsJson,
  formatPlanReport,
  type Artifact,
  type RetentionPolicy,
} from "../src/cleanup";

// "Now" reference used by every test so age math stays deterministic.
const NOW = new Date("2026-05-07T12:00:00.000Z");

const daysAgo = (n: number): Date =>
  new Date(NOW.getTime() - n * 24 * 60 * 60 * 1000);

const makeArtifact = (overrides: Partial<Artifact> = {}): Artifact => ({
  id: "a1",
  name: "build-output",
  sizeBytes: 1024,
  createdAt: NOW,
  workflowRunId: "wf-1",
  ...overrides,
});

describe("applyMaxAgePolicy", () => {
  test("marks artifacts older than maxAgeDays for deletion", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ id: "fresh", createdAt: daysAgo(5) }),
      makeArtifact({ id: "old", createdAt: daysAgo(40) }),
    ];

    const result = applyMaxAgePolicy(artifacts, 30, NOW);

    expect(result.toDelete.map((a) => a.id)).toEqual(["old"]);
    expect(result.toKeep.map((a) => a.id)).toEqual(["fresh"]);
  });

  test("keeps everything when policy is undefined", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ id: "old", createdAt: daysAgo(400) }),
    ];

    const result = applyMaxAgePolicy(artifacts, undefined, NOW);

    expect(result.toDelete).toEqual([]);
    expect(result.toKeep.map((a) => a.id)).toEqual(["old"]);
  });

  test("treats artifacts exactly at the threshold as kept", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ id: "edge", createdAt: daysAgo(30) }),
    ];

    const result = applyMaxAgePolicy(artifacts, 30, NOW);

    expect(result.toDelete).toEqual([]);
    expect(result.toKeep.map((a) => a.id)).toEqual(["edge"]);
  });
});

describe("applyMaxTotalSizePolicy", () => {
  test("deletes oldest artifacts until total size is at or below cap", () => {
    // 3 artifacts of 100 bytes each, cap at 200 -> oldest must go.
    const artifacts: Artifact[] = [
      makeArtifact({ id: "newest", sizeBytes: 100, createdAt: daysAgo(1) }),
      makeArtifact({ id: "middle", sizeBytes: 100, createdAt: daysAgo(5) }),
      makeArtifact({ id: "oldest", sizeBytes: 100, createdAt: daysAgo(10) }),
    ];

    const result = applyMaxTotalSizePolicy(artifacts, 200);

    expect(result.toDelete.map((a) => a.id)).toEqual(["oldest"]);
    expect(result.toKeep.map((a) => a.id).sort()).toEqual(["middle", "newest"]);
  });

  test("keeps everything when cap is undefined", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ id: "a", sizeBytes: 9999 }),
    ];

    const result = applyMaxTotalSizePolicy(artifacts, undefined);

    expect(result.toDelete).toEqual([]);
    expect(result.toKeep.map((a) => a.id)).toEqual(["a"]);
  });

  test("keeps everything when total already fits under cap", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ id: "a", sizeBytes: 50 }),
      makeArtifact({ id: "b", sizeBytes: 50 }),
    ];

    const result = applyMaxTotalSizePolicy(artifacts, 200);

    expect(result.toDelete).toEqual([]);
    expect(result.toKeep.map((a) => a.id).sort()).toEqual(["a", "b"]);
  });

  test("evicts multiple oldest artifacts when one is not enough", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ id: "newest", sizeBytes: 100, createdAt: daysAgo(1) }),
      makeArtifact({ id: "mid1", sizeBytes: 100, createdAt: daysAgo(5) }),
      makeArtifact({ id: "mid2", sizeBytes: 100, createdAt: daysAgo(7) }),
      makeArtifact({ id: "oldest", sizeBytes: 100, createdAt: daysAgo(10) }),
    ];

    const result = applyMaxTotalSizePolicy(artifacts, 150);

    // Oldest first — 400 -> 300 -> 200 -> 100 (fits at-or-below 150 only after 3 evictions)
    expect(result.toDelete.map((a) => a.id)).toEqual(["oldest", "mid2", "mid1"]);
    expect(result.toKeep.map((a) => a.id)).toEqual(["newest"]);
  });
});

describe("applyKeepLatestNPolicy", () => {
  test("keeps the N newest artifacts within each workflow", () => {
    const artifacts: Artifact[] = [
      // workflow A: 3 artifacts, keep 2 newest
      makeArtifact({ id: "a-old", workflowRunId: "A", createdAt: daysAgo(10) }),
      makeArtifact({ id: "a-mid", workflowRunId: "A", createdAt: daysAgo(5) }),
      makeArtifact({ id: "a-new", workflowRunId: "A", createdAt: daysAgo(1) }),
      // workflow B: 1 artifact, kept regardless
      makeArtifact({ id: "b-only", workflowRunId: "B", createdAt: daysAgo(20) }),
    ];

    const result = applyKeepLatestNPolicy(artifacts, 2);

    expect(result.toDelete.map((a) => a.id)).toEqual(["a-old"]);
    expect(result.toKeep.map((a) => a.id).sort()).toEqual([
      "a-mid",
      "a-new",
      "b-only",
    ]);
  });

  test("keeps everything when N is undefined", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ id: "a", workflowRunId: "A", createdAt: daysAgo(1) }),
      makeArtifact({ id: "b", workflowRunId: "A", createdAt: daysAgo(2) }),
      makeArtifact({ id: "c", workflowRunId: "A", createdAt: daysAgo(3) }),
    ];

    const result = applyKeepLatestNPolicy(artifacts, undefined);

    expect(result.toDelete).toEqual([]);
    expect(result.toKeep).toHaveLength(3);
  });

  test("keeps all when each workflow has fewer than N artifacts", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ id: "a1", workflowRunId: "A" }),
      makeArtifact({ id: "b1", workflowRunId: "B" }),
    ];

    const result = applyKeepLatestNPolicy(artifacts, 5);

    expect(result.toDelete).toEqual([]);
    expect(result.toKeep).toHaveLength(2);
  });

  test("treats N=0 as 'delete everything'", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ id: "a", workflowRunId: "A" }),
      makeArtifact({ id: "b", workflowRunId: "B" }),
    ];

    const result = applyKeepLatestNPolicy(artifacts, 0);

    expect(result.toKeep).toEqual([]);
    expect(result.toDelete.map((a) => a.id).sort()).toEqual(["a", "b"]);
  });
});

describe("buildDeletionPlan", () => {
  test("composes all three policies and produces a summary", () => {
    const artifacts: Artifact[] = [
      // workflow A: 4 artifacts at varying age + size
      makeArtifact({
        id: "A1",
        workflowRunId: "A",
        sizeBytes: 100,
        createdAt: daysAgo(1),
      }),
      makeArtifact({
        id: "A2",
        workflowRunId: "A",
        sizeBytes: 100,
        createdAt: daysAgo(3),
      }),
      makeArtifact({
        id: "A3",
        workflowRunId: "A",
        sizeBytes: 100,
        createdAt: daysAgo(7),
      }),
      makeArtifact({
        id: "A-old",
        workflowRunId: "A",
        sizeBytes: 100,
        createdAt: daysAgo(60),
      }),
      // workflow B: 1 artifact, recent
      makeArtifact({
        id: "B1",
        workflowRunId: "B",
        sizeBytes: 100,
        createdAt: daysAgo(2),
      }),
    ];

    const policy: RetentionPolicy = {
      maxAgeDays: 30, // evicts A-old
      maxTotalSizeBytes: 300, // remaining 4 artifacts = 400 bytes; evict 1 oldest -> A3
      keepLatestNPerWorkflow: 2, // workflow A then has A1+A2 (already 2), nothing more
    };

    const plan = buildDeletionPlan(artifacts, policy, NOW);

    expect(plan.toDelete.map((a) => a.id).sort()).toEqual(["A-old", "A3"]);
    expect(plan.toKeep.map((a) => a.id).sort()).toEqual(["A1", "A2", "B1"]);
    expect(plan.summary.totalArtifacts).toBe(5);
    expect(plan.summary.retainedCount).toBe(3);
    expect(plan.summary.deletedCount).toBe(2);
    expect(plan.summary.spaceReclaimedBytes).toBe(200);
    expect(plan.summary.spaceRetainedBytes).toBe(300);
    expect(plan.summary.reasons["max-age"]).toBe(1);
    expect(plan.summary.reasons["max-total-size"]).toBe(1);
  });

  test("with no policies, plan keeps everything and reports no deletions", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ id: "a", sizeBytes: 50 }),
      makeArtifact({ id: "b", sizeBytes: 70 }),
    ];

    const plan = buildDeletionPlan(artifacts, {}, NOW);

    expect(plan.toDelete).toEqual([]);
    expect(plan.summary.deletedCount).toBe(0);
    expect(plan.summary.retainedCount).toBe(2);
    expect(plan.summary.spaceReclaimedBytes).toBe(0);
    expect(plan.summary.spaceRetainedBytes).toBe(120);
  });

  test("dry-run flag shows up in formatted report header and not apply", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ id: "a", sizeBytes: 100, createdAt: daysAgo(60) }),
      makeArtifact({ id: "b", sizeBytes: 100, createdAt: daysAgo(1) }),
    ];

    const plan = buildDeletionPlan(artifacts, { maxAgeDays: 30 }, NOW);
    const dryReport = formatPlanReport(plan, { dryRun: true });
    const applyReport = formatPlanReport(plan, { dryRun: false });

    expect(dryReport).toContain("DRY-RUN");
    expect(dryReport).toContain("would delete");
    expect(applyReport).toContain("APPLY");
    expect(applyReport).toContain("deleted");
    // Both modes should report the same numerical summary.
    expect(dryReport).toContain("retained_count=1");
    expect(applyReport).toContain("retained_count=1");
    expect(dryReport).toContain("deleted_count=1");
    expect(dryReport).toContain("space_reclaimed_bytes=100");
  });

  test("keep-latest-N runs after age and size to preserve newest within workflow", () => {
    // Workflow C has 5 recent artifacts; keep only 2 newest.
    const artifacts: Artifact[] = [
      makeArtifact({ id: "C1", workflowRunId: "C", createdAt: daysAgo(1) }),
      makeArtifact({ id: "C2", workflowRunId: "C", createdAt: daysAgo(2) }),
      makeArtifact({ id: "C3", workflowRunId: "C", createdAt: daysAgo(3) }),
      makeArtifact({ id: "C4", workflowRunId: "C", createdAt: daysAgo(4) }),
      makeArtifact({ id: "C5", workflowRunId: "C", createdAt: daysAgo(5) }),
    ];

    const plan = buildDeletionPlan(
      artifacts,
      { keepLatestNPerWorkflow: 2 },
      NOW,
    );

    expect(plan.toKeep.map((a) => a.id).sort()).toEqual(["C1", "C2"]);
    expect(plan.toDelete.map((a) => a.id).sort()).toEqual(["C3", "C4", "C5"]);
    expect(plan.summary.reasons["keep-latest-n"]).toBe(3);
  });
});

describe("parseArtifactsJson", () => {
  test("parses ISO date strings into Date instances", () => {
    const json = JSON.stringify([
      {
        id: "x",
        name: "build",
        sizeBytes: 1024,
        createdAt: "2026-04-01T00:00:00.000Z",
        workflowRunId: "wf-1",
      },
    ]);

    const artifacts = parseArtifactsJson(json);

    expect(artifacts).toHaveLength(1);
    expect(artifacts[0]!.createdAt).toBeInstanceOf(Date);
    expect(artifacts[0]!.createdAt.toISOString()).toBe(
      "2026-04-01T00:00:00.000Z",
    );
    expect(artifacts[0]!.id).toBe("x");
  });

  test("throws a clear error when the input is not a JSON array", () => {
    expect(() => parseArtifactsJson("{}")).toThrow(/array/);
  });

  test("throws when an artifact is missing required fields", () => {
    const json = JSON.stringify([{ id: "x" }]);
    expect(() => parseArtifactsJson(json)).toThrow(
      /missing required field|invalid/i,
    );
  });

  test("throws when createdAt is not a valid date", () => {
    const json = JSON.stringify([
      {
        id: "x",
        name: "build",
        sizeBytes: 1024,
        createdAt: "not-a-date",
        workflowRunId: "wf-1",
      },
    ]);
    expect(() => parseArtifactsJson(json)).toThrow(/createdAt/i);
  });
});
