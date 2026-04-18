// Tests for the artifact cleanup logic.
// We use red/green TDD: each block here was written before the corresponding
// implementation in cleanup.ts.
import { describe, expect, test } from "bun:test";
import {
  applyRetention,
  formatPlan,
  parseArtifacts,
  type Artifact,
  type RetentionPolicy,
} from "./cleanup.ts";

// A fixed "now" so date math in tests is deterministic.
const NOW = new Date("2026-04-17T00:00:00Z");
const DAY_MS = 24 * 60 * 60 * 1000;

// Helper: build an artifact with a creation date N days ago.
function art(
  partial: Partial<Artifact> & { name: string; ageDays: number },
): Artifact {
  return {
    name: partial.name,
    sizeBytes: partial.sizeBytes ?? 1_000,
    createdAt: new Date(NOW.getTime() - partial.ageDays * DAY_MS).toISOString(),
    workflowRunId: partial.workflowRunId ?? "run-1",
    workflowName: partial.workflowName ?? "ci",
  };
}

describe("max-age policy", () => {
  test("deletes artifacts older than maxAgeDays", () => {
    const artifacts = [
      art({ name: "old", ageDays: 40 }),
      art({ name: "fresh", ageDays: 5 }),
    ];
    const plan = applyRetention(artifacts, { maxAgeDays: 30 }, NOW);
    expect(plan.toDelete.map((a) => a.name)).toEqual(["old"]);
    expect(plan.toKeep.map((a) => a.name)).toEqual(["fresh"]);
    expect(plan.reasons["old"]).toContain("older than 30 days");
  });

  test("no deletions when policy is empty", () => {
    const artifacts = [art({ name: "a", ageDays: 100 })];
    const plan = applyRetention(artifacts, {}, NOW);
    expect(plan.toDelete).toHaveLength(0);
    expect(plan.toKeep).toHaveLength(1);
  });
});

describe("keep-latest-N per workflow", () => {
  test("keeps only the N newest per workflow run group", () => {
    const artifacts = [
      art({ name: "ci-1", ageDays: 1, workflowName: "ci" }),
      art({ name: "ci-2", ageDays: 2, workflowName: "ci" }),
      art({ name: "ci-3", ageDays: 3, workflowName: "ci" }),
      art({ name: "ci-4", ageDays: 4, workflowName: "ci" }),
      art({ name: "rel-1", ageDays: 1, workflowName: "release" }),
      art({ name: "rel-2", ageDays: 2, workflowName: "release" }),
    ];
    const plan = applyRetention(artifacts, { keepLatestPerWorkflow: 2 }, NOW);
    // For ci, keep 2 newest (ci-1, ci-2); delete ci-3, ci-4.
    // For release, keep both.
    expect(plan.toDelete.map((a) => a.name).sort()).toEqual(["ci-3", "ci-4"]);
    expect(plan.toKeep.map((a) => a.name).sort()).toEqual([
      "ci-1",
      "ci-2",
      "rel-1",
      "rel-2",
    ]);
  });
});

describe("max-total-size policy", () => {
  test("deletes oldest first until under budget", () => {
    const artifacts = [
      art({ name: "old-big", ageDays: 10, sizeBytes: 500 }),
      art({ name: "mid", ageDays: 5, sizeBytes: 500 }),
      art({ name: "new", ageDays: 1, sizeBytes: 500 }),
    ];
    const plan = applyRetention(artifacts, { maxTotalSizeBytes: 1000 }, NOW);
    // Total is 1500, budget is 1000. Drop oldest (old-big, 500) → 1000 fits.
    expect(plan.toDelete.map((a) => a.name)).toEqual(["old-big"]);
    expect(plan.toKeep.map((a) => a.name).sort()).toEqual(["mid", "new"]);
  });

  test("keeps everything when under budget", () => {
    const artifacts = [
      art({ name: "a", ageDays: 1, sizeBytes: 100 }),
      art({ name: "b", ageDays: 2, sizeBytes: 100 }),
    ];
    const plan = applyRetention(artifacts, { maxTotalSizeBytes: 1000 }, NOW);
    expect(plan.toDelete).toHaveLength(0);
  });
});

describe("combined policies", () => {
  test("union of all three policy effects", () => {
    const artifacts = [
      art({ name: "ancient", ageDays: 100, sizeBytes: 200 }),
      art({ name: "ci-extra", ageDays: 5, sizeBytes: 200, workflowName: "ci" }),
      art({ name: "ci-keep", ageDays: 1, sizeBytes: 200, workflowName: "ci" }),
      art({
        name: "huge-recent",
        ageDays: 2,
        sizeBytes: 5000,
        workflowName: "rel",
      }),
    ];
    const policy: RetentionPolicy = {
      maxAgeDays: 30,
      keepLatestPerWorkflow: 1,
      maxTotalSizeBytes: 1000,
    };
    const plan = applyRetention(artifacts, policy, NOW);
    // ancient → max-age. ci-extra → keep-latest-1 (ci-keep newer). Then check
    // remaining size: ci-keep(200) + huge-recent(5000) = 5200, over 1000.
    // Delete oldest first → huge-recent is age 2 vs ci-keep age 1, so
    // huge-recent goes (older).
    expect(plan.toDelete.map((a) => a.name).sort()).toEqual([
      "ancient",
      "ci-extra",
      "huge-recent",
    ]);
    expect(plan.toKeep.map((a) => a.name)).toEqual(["ci-keep"]);
  });
});

describe("summary stats", () => {
  test("reports reclaimed bytes and counts", () => {
    const artifacts = [
      art({ name: "a", ageDays: 100, sizeBytes: 1000 }),
      art({ name: "b", ageDays: 100, sizeBytes: 2000 }),
      art({ name: "c", ageDays: 1, sizeBytes: 500 }),
    ];
    const plan = applyRetention(artifacts, { maxAgeDays: 30 }, NOW);
    expect(plan.summary.totalArtifacts).toBe(3);
    expect(plan.summary.deletedCount).toBe(2);
    expect(plan.summary.retainedCount).toBe(1);
    expect(plan.summary.bytesReclaimed).toBe(3000);
    expect(plan.summary.bytesRetained).toBe(500);
  });
});

describe("formatPlan rendering", () => {
  test("includes summary lines and DRY RUN banner", () => {
    const artifacts = [art({ name: "old", ageDays: 100, sizeBytes: 2048 })];
    const plan = applyRetention(artifacts, { maxAgeDays: 30 }, NOW);
    const out = formatPlan(plan, { dryRun: true });
    expect(out).toContain("DRY RUN");
    expect(out).toContain("Total artifacts: 1");
    expect(out).toContain("To delete: 1");
    expect(out).toContain("Bytes reclaimed: 2048");
    expect(out).toContain("old");
  });

  test("no DRY RUN banner when dryRun is false", () => {
    const plan = applyRetention([], {}, NOW);
    const out = formatPlan(plan, { dryRun: false });
    expect(out).not.toContain("DRY RUN");
  });
});

describe("parseArtifacts validation", () => {
  test("accepts a well-formed JSON array", () => {
    const json = JSON.stringify([
      {
        name: "a",
        sizeBytes: 1,
        createdAt: NOW.toISOString(),
        workflowRunId: "r1",
        workflowName: "ci",
      },
    ]);
    expect(parseArtifacts(json)).toHaveLength(1);
  });

  test("rejects non-array input with a clear error", () => {
    expect(() => parseArtifacts('{"oops": 1}')).toThrow(/array/i);
  });

  test("rejects entries missing required fields", () => {
    const bad = JSON.stringify([{ name: "x" }]);
    expect(() => parseArtifacts(bad)).toThrow(/sizeBytes|createdAt/i);
  });

  test("rejects non-JSON gracefully", () => {
    expect(() => parseArtifacts("not json")).toThrow(/parse|json/i);
  });
});
