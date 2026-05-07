// Tests follow red/green TDD methodology. Each test exercises one piece of
// behavior of the artifact retention engine.
import { describe, expect, test } from "bun:test";
import { planCleanup, type Artifact, type RetentionPolicy } from "./cleanup";

const NOW = new Date("2026-05-07T12:00:00Z").getTime();
const DAY = 24 * 60 * 60 * 1000;

const baseArtifact = (over: Partial<Artifact>): Artifact => ({
  id: "a",
  name: "build",
  sizeBytes: 1000,
  createdAt: new Date(NOW).toISOString(),
  workflowRunId: "run-1",
  ...over,
});

describe("planCleanup", () => {
  test("retains all artifacts when no policy violations", () => {
    const artifacts: Artifact[] = [
      baseArtifact({ id: "a1", createdAt: new Date(NOW - 1 * DAY).toISOString() }),
    ];
    const policy: RetentionPolicy = { maxAgeDays: 30, maxTotalSizeBytes: 1_000_000, keepLatestPerWorkflow: 5 };
    const plan = planCleanup(artifacts, policy, NOW);
    expect(plan.toDelete).toEqual([]);
    expect(plan.toRetain.map(a => a.id)).toEqual(["a1"]);
    expect(plan.summary.spaceReclaimedBytes).toBe(0);
    expect(plan.summary.retainedCount).toBe(1);
    expect(plan.summary.deletedCount).toBe(0);
  });

  test("deletes artifacts older than maxAgeDays", () => {
    const artifacts: Artifact[] = [
      baseArtifact({ id: "old", createdAt: new Date(NOW - 60 * DAY).toISOString(), sizeBytes: 500 }),
      baseArtifact({ id: "new", createdAt: new Date(NOW - 5 * DAY).toISOString(), sizeBytes: 200 }),
    ];
    const policy: RetentionPolicy = { maxAgeDays: 30 };
    const plan = planCleanup(artifacts, policy, NOW);
    expect(plan.toDelete.map(a => a.id)).toEqual(["old"]);
    expect(plan.toRetain.map(a => a.id)).toEqual(["new"]);
    expect(plan.summary.spaceReclaimedBytes).toBe(500);
  });

  test("deletes oldest artifacts when over maxTotalSizeBytes", () => {
    const artifacts: Artifact[] = [
      baseArtifact({ id: "a1", createdAt: new Date(NOW - 3 * DAY).toISOString(), sizeBytes: 600 }),
      baseArtifact({ id: "a2", createdAt: new Date(NOW - 2 * DAY).toISOString(), sizeBytes: 600 }),
      baseArtifact({ id: "a3", createdAt: new Date(NOW - 1 * DAY).toISOString(), sizeBytes: 600 }),
    ];
    // Total = 1800; max = 1300 -> must delete oldest (a1) leaving 1200
    const policy: RetentionPolicy = { maxTotalSizeBytes: 1300 };
    const plan = planCleanup(artifacts, policy, NOW);
    expect(plan.toDelete.map(a => a.id)).toEqual(["a1"]);
    expect(plan.toRetain.map(a => a.id).sort()).toEqual(["a2", "a3"]);
  });

  test("keepLatestPerWorkflow keeps N newest per workflow", () => {
    const artifacts: Artifact[] = [
      baseArtifact({ id: "w1-old", workflowRunId: "w1", createdAt: new Date(NOW - 3 * DAY).toISOString(), sizeBytes: 100 }),
      baseArtifact({ id: "w1-mid", workflowRunId: "w1", createdAt: new Date(NOW - 2 * DAY).toISOString(), sizeBytes: 100 }),
      baseArtifact({ id: "w1-new", workflowRunId: "w1", createdAt: new Date(NOW - 1 * DAY).toISOString(), sizeBytes: 100 }),
      baseArtifact({ id: "w2-only", workflowRunId: "w2", createdAt: new Date(NOW - 1 * DAY).toISOString(), sizeBytes: 100 }),
    ];
    const policy: RetentionPolicy = { keepLatestPerWorkflow: 2 };
    const plan = planCleanup(artifacts, policy, NOW);
    expect(plan.toDelete.map(a => a.id)).toEqual(["w1-old"]);
  });

  test("policies combine: artifact deleted if ANY policy says so", () => {
    const artifacts: Artifact[] = [
      baseArtifact({ id: "old-but-only-one", workflowRunId: "w1", createdAt: new Date(NOW - 90 * DAY).toISOString(), sizeBytes: 100 }),
    ];
    // keepLatestPerWorkflow would keep this, but maxAgeDays says delete
    const policy: RetentionPolicy = { maxAgeDays: 30, keepLatestPerWorkflow: 5 };
    const plan = planCleanup(artifacts, policy, NOW);
    expect(plan.toDelete.map(a => a.id)).toEqual(["old-but-only-one"]);
  });

  test("summary aggregates totals correctly", () => {
    const artifacts: Artifact[] = [
      baseArtifact({ id: "old", createdAt: new Date(NOW - 90 * DAY).toISOString(), sizeBytes: 1000 }),
      baseArtifact({ id: "old2", createdAt: new Date(NOW - 60 * DAY).toISOString(), sizeBytes: 500 }),
      baseArtifact({ id: "fresh", createdAt: new Date(NOW - 1 * DAY).toISOString(), sizeBytes: 200 }),
    ];
    const policy: RetentionPolicy = { maxAgeDays: 30 };
    const plan = planCleanup(artifacts, policy, NOW);
    expect(plan.summary.totalCount).toBe(3);
    expect(plan.summary.deletedCount).toBe(2);
    expect(plan.summary.retainedCount).toBe(1);
    expect(plan.summary.spaceReclaimedBytes).toBe(1500);
    expect(plan.summary.retainedSizeBytes).toBe(200);
  });

  test("throws on invalid artifact size", () => {
    const artifacts: Artifact[] = [baseArtifact({ id: "bad", sizeBytes: -1 })];
    expect(() => planCleanup(artifacts, { maxAgeDays: 1 }, NOW)).toThrow(/sizeBytes/);
  });

  test("throws on invalid date", () => {
    const artifacts: Artifact[] = [baseArtifact({ id: "bad", createdAt: "not-a-date" })];
    expect(() => planCleanup(artifacts, { maxAgeDays: 1 }, NOW)).toThrow(/createdAt/);
  });
});
