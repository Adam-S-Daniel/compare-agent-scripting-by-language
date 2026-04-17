import { describe, test, expect } from "bun:test";
import {
  planCleanup,
  formatSummary,
  type Artifact,
  type Policy,
} from "./cleanup";

// Fixed "now" so tests are deterministic.
const NOW = new Date("2026-04-17T00:00:00Z").getTime();

const mk = (
  id: string,
  days: number,
  size: number,
  workflow: string,
): Artifact => ({
  id,
  name: `artifact-${id}`,
  sizeBytes: size,
  createdAt: new Date(NOW - days * 86_400_000).toISOString(),
  workflowRunId: workflow,
});

describe("planCleanup - max age", () => {
  test("deletes artifacts older than maxAgeDays", () => {
    const artifacts = [mk("a", 10, 100, "w1"), mk("b", 40, 100, "w1")];
    const plan = planCleanup(artifacts, { maxAgeDays: 30 }, NOW);
    const deletedIds = plan.deleted.map((a) => a.id).sort();
    expect(deletedIds).toEqual(["b"]);
    expect(plan.retained.map((a) => a.id).sort()).toEqual(["a"]);
    expect(plan.reasons["b"]?.join(",")).toContain("age");
  });

  test("keeps everything when no policy applied", () => {
    const artifacts = [mk("a", 100, 100, "w1")];
    const plan = planCleanup(artifacts, {}, NOW);
    expect(plan.deleted.length).toBe(0);
    expect(plan.retained.length).toBe(1);
  });
});

describe("planCleanup - keep-latest-N per workflow", () => {
  test("keeps newest N per workflow, deletes older", () => {
    const artifacts = [
      mk("a", 1, 100, "w1"),
      mk("b", 2, 100, "w1"),
      mk("c", 3, 100, "w1"),
      mk("d", 1, 100, "w2"),
    ];
    const plan = planCleanup(artifacts, { keepLatestPerWorkflow: 2 }, NOW);
    expect(plan.deleted.map((a) => a.id).sort()).toEqual(["c"]);
    expect(plan.reasons["c"]?.join(",")).toContain("keep-latest");
  });
});

describe("planCleanup - max total size", () => {
  test("deletes oldest first until under size budget", () => {
    const artifacts = [
      mk("a", 1, 500, "w1"),
      mk("b", 2, 500, "w1"),
      mk("c", 3, 500, "w1"),
    ];
    // Budget 1000 -> must delete oldest (c).
    const plan = planCleanup(artifacts, { maxTotalSizeBytes: 1000 }, NOW);
    expect(plan.deleted.map((a) => a.id)).toEqual(["c"]);
    expect(plan.reasons["c"]?.join(",")).toContain("size");
  });

  test("respects already-deleted artifacts when computing size", () => {
    // 'c' is already deleted by age; remaining = a+b = 1000, budget 1000, nothing more to delete.
    const artifacts = [
      mk("a", 1, 500, "w1"),
      mk("b", 2, 500, "w1"),
      mk("c", 40, 500, "w1"),
    ];
    const plan = planCleanup(
      artifacts,
      { maxAgeDays: 30, maxTotalSizeBytes: 1000 },
      NOW,
    );
    expect(plan.deleted.map((a) => a.id).sort()).toEqual(["c"]);
  });
});

describe("planCleanup - combined policies", () => {
  test("applies all policies and aggregates reasons", () => {
    const artifacts = [
      mk("a", 1, 100, "w1"),
      mk("b", 2, 100, "w1"),
      mk("c", 50, 100, "w1"),
      mk("d", 3, 100, "w1"),
    ];
    const plan = planCleanup(
      artifacts,
      { maxAgeDays: 30, keepLatestPerWorkflow: 2 },
      NOW,
    );
    // c deleted by age; d deleted by keep-latest (only a,b survive).
    expect(plan.deleted.map((a) => a.id).sort()).toEqual(["c", "d"]);
  });
});

describe("planCleanup - summary", () => {
  test("summary totals match", () => {
    const artifacts = [mk("a", 1, 100, "w1"), mk("b", 40, 200, "w1")];
    const plan = planCleanup(artifacts, { maxAgeDays: 30 }, NOW);
    expect(plan.summary.totalArtifacts).toBe(2);
    expect(plan.summary.deletedCount).toBe(1);
    expect(plan.summary.retainedCount).toBe(1);
    expect(plan.summary.bytesReclaimed).toBe(200);
  });
});

describe("planCleanup - errors", () => {
  test("throws on invalid date", () => {
    const bad: Artifact[] = [
      { id: "x", name: "x", sizeBytes: 1, createdAt: "not-a-date", workflowRunId: "w" },
    ];
    expect(() => planCleanup(bad, { maxAgeDays: 1 }, NOW)).toThrow(/createdAt/);
  });

  test("throws on negative size", () => {
    const bad: Artifact[] = [
      {
        id: "x",
        name: "x",
        sizeBytes: -1,
        createdAt: new Date(NOW).toISOString(),
        workflowRunId: "w",
      },
    ];
    expect(() => planCleanup(bad, {}, NOW)).toThrow(/sizeBytes/);
  });
});

describe("formatSummary", () => {
  test("includes key numbers and dry-run flag", () => {
    const artifacts = [mk("a", 1, 100, "w1"), mk("b", 40, 200, "w1")];
    const plan = planCleanup(artifacts, { maxAgeDays: 30 }, NOW);
    const out = formatSummary(plan, true);
    expect(out).toContain("DRY-RUN");
    expect(out).toContain("Deleted: 1");
    expect(out).toContain("Retained: 1");
    expect(out).toContain("200"); // bytes reclaimed
  });

  test("non-dry-run omits DRY-RUN marker", () => {
    const plan = planCleanup([], {}, NOW);
    const out = formatSummary(plan, false);
    expect(out).not.toContain("DRY-RUN");
  });
});
