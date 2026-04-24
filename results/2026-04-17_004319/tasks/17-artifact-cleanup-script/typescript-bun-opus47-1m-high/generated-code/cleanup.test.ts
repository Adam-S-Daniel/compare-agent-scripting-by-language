import { describe, expect, test } from "bun:test";
import {
  planCleanup,
  formatPlanSummary,
  type Artifact,
  type RetentionPolicy,
} from "./cleanup";

// Reference "now" used by all test fixtures. Policies compute age relative to this.
const NOW = new Date("2026-04-19T00:00:00Z").getTime();

function makeArtifact(overrides: Partial<Artifact> = {}): Artifact {
  return {
    id: overrides.id ?? "a1",
    name: overrides.name ?? "build-output",
    sizeBytes: overrides.sizeBytes ?? 1000,
    createdAt: overrides.createdAt ?? new Date(NOW - 1000 * 60 * 60).toISOString(),
    workflowRunId: overrides.workflowRunId ?? "wf-1",
  };
}

describe("planCleanup - max age policy", () => {
  test("deletes artifacts older than maxAgeDays", () => {
    const daysAgo = (d: number) => new Date(NOW - d * 86_400_000).toISOString();
    const artifacts: Artifact[] = [
      makeArtifact({ id: "old", createdAt: daysAgo(40) }),
      makeArtifact({ id: "fresh", createdAt: daysAgo(5) }),
    ];
    const policy: RetentionPolicy = { maxAgeDays: 30 };
    const plan = planCleanup(artifacts, policy, NOW);
    expect(plan.toDelete.map((a) => a.id)).toEqual(["old"]);
    expect(plan.toRetain.map((a) => a.id)).toEqual(["fresh"]);
  });

  test("keeps everything when maxAgeDays not set", () => {
    const daysAgo = (d: number) => new Date(NOW - d * 86_400_000).toISOString();
    const artifacts: Artifact[] = [
      makeArtifact({ id: "ancient", createdAt: daysAgo(365) }),
    ];
    const plan = planCleanup(artifacts, {}, NOW);
    expect(plan.toDelete).toHaveLength(0);
    expect(plan.toRetain).toHaveLength(1);
  });
});

describe("planCleanup - keep-latest-N per workflow", () => {
  test("keeps only N most-recent artifacts per workflow, oldest deleted", () => {
    const daysAgo = (d: number) => new Date(NOW - d * 86_400_000).toISOString();
    const artifacts: Artifact[] = [
      makeArtifact({ id: "w1-old", workflowRunId: "wf-A", createdAt: daysAgo(5) }),
      makeArtifact({ id: "w1-mid", workflowRunId: "wf-A", createdAt: daysAgo(3) }),
      makeArtifact({ id: "w1-new", workflowRunId: "wf-A", createdAt: daysAgo(1) }),
      makeArtifact({ id: "w2-only", workflowRunId: "wf-B", createdAt: daysAgo(2) }),
    ];
    const policy: RetentionPolicy = { keepLatestPerWorkflow: 2 };
    const plan = planCleanup(artifacts, policy, NOW);
    expect(plan.toDelete.map((a) => a.id).sort()).toEqual(["w1-old"]);
    expect(plan.toRetain.map((a) => a.id).sort()).toEqual(
      ["w1-mid", "w1-new", "w2-only"]
    );
  });
});

describe("planCleanup - max total size policy", () => {
  test("deletes oldest artifacts until total size is under cap", () => {
    const daysAgo = (d: number) => new Date(NOW - d * 86_400_000).toISOString();
    // Three artifacts, each 100 bytes; cap = 150. Should delete two oldest.
    const artifacts: Artifact[] = [
      makeArtifact({ id: "oldest", sizeBytes: 100, createdAt: daysAgo(10) }),
      makeArtifact({ id: "middle", sizeBytes: 100, createdAt: daysAgo(5) }),
      makeArtifact({ id: "newest", sizeBytes: 100, createdAt: daysAgo(1) }),
    ];
    const policy: RetentionPolicy = { maxTotalSizeBytes: 150 };
    const plan = planCleanup(artifacts, policy, NOW);
    expect(plan.toDelete.map((a) => a.id).sort()).toEqual(["middle", "oldest"]);
    expect(plan.toRetain.map((a) => a.id)).toEqual(["newest"]);
  });

  test("does nothing when under the cap", () => {
    const artifacts: Artifact[] = [
      makeArtifact({ id: "small", sizeBytes: 100 }),
    ];
    const policy: RetentionPolicy = { maxTotalSizeBytes: 10_000 };
    const plan = planCleanup(artifacts, policy, NOW);
    expect(plan.toDelete).toHaveLength(0);
  });
});

describe("planCleanup - policy composition", () => {
  test("combines all three policies; an artifact deleted by any rule is deleted", () => {
    const daysAgo = (d: number) => new Date(NOW - d * 86_400_000).toISOString();
    const artifacts: Artifact[] = [
      makeArtifact({
        id: "very-old",
        workflowRunId: "wf-A",
        sizeBytes: 50,
        createdAt: daysAgo(100),
      }),
      makeArtifact({
        id: "recent-A",
        workflowRunId: "wf-A",
        sizeBytes: 50,
        createdAt: daysAgo(2),
      }),
      makeArtifact({
        id: "recent-B",
        workflowRunId: "wf-B",
        sizeBytes: 50,
        createdAt: daysAgo(1),
      }),
    ];
    const policy: RetentionPolicy = {
      maxAgeDays: 30,
      keepLatestPerWorkflow: 5,
      maxTotalSizeBytes: 1_000,
    };
    const plan = planCleanup(artifacts, policy, NOW);
    expect(plan.toDelete.map((a) => a.id)).toEqual(["very-old"]);
    expect(plan.toRetain.map((a) => a.id).sort()).toEqual(
      ["recent-A", "recent-B"]
    );
  });
});

describe("planCleanup - summary", () => {
  test("reports reclaimed bytes and counts", () => {
    const daysAgo = (d: number) => new Date(NOW - d * 86_400_000).toISOString();
    const artifacts: Artifact[] = [
      makeArtifact({ id: "a", sizeBytes: 200, createdAt: daysAgo(40) }),
      makeArtifact({ id: "b", sizeBytes: 300, createdAt: daysAgo(40) }),
      makeArtifact({ id: "c", sizeBytes: 400, createdAt: daysAgo(1) }),
    ];
    const plan = planCleanup(artifacts, { maxAgeDays: 30 }, NOW);
    expect(plan.summary.deletedCount).toBe(2);
    expect(plan.summary.retainedCount).toBe(1);
    expect(plan.summary.bytesReclaimed).toBe(500);
    expect(plan.summary.totalArtifacts).toBe(3);
  });
});

describe("planCleanup - error handling", () => {
  test("throws meaningful error on negative maxAgeDays", () => {
    expect(() => planCleanup([], { maxAgeDays: -1 }, NOW)).toThrow(
      /maxAgeDays must be >= 0/
    );
  });

  test("throws meaningful error on non-integer keepLatestPerWorkflow", () => {
    expect(() =>
      planCleanup([], { keepLatestPerWorkflow: 1.5 }, NOW)
    ).toThrow(/keepLatestPerWorkflow must be a non-negative integer/);
  });

  test("throws on malformed artifact input", () => {
    const bad = [{ id: "x" } as unknown as Artifact];
    expect(() => planCleanup(bad, {}, NOW)).toThrow(/invalid artifact/i);
  });
});

describe("planCleanup - dry run flag", () => {
  test("plan carries dryRun flag through", () => {
    const plan = planCleanup([], {}, NOW, { dryRun: true });
    expect(plan.dryRun).toBe(true);
  });

  test("defaults dryRun to false", () => {
    const plan = planCleanup([], {}, NOW);
    expect(plan.dryRun).toBe(false);
  });
});

describe("formatPlanSummary", () => {
  test("renders a human-readable summary with dry-run marker", () => {
    const daysAgo = (d: number) => new Date(NOW - d * 86_400_000).toISOString();
    const artifacts: Artifact[] = [
      makeArtifact({ id: "a", sizeBytes: 200, createdAt: daysAgo(40) }),
      makeArtifact({ id: "b", sizeBytes: 300, createdAt: daysAgo(1) }),
    ];
    const plan = planCleanup(artifacts, { maxAgeDays: 30 }, NOW, {
      dryRun: true,
    });
    const out = formatPlanSummary(plan);
    expect(out).toContain("DRY RUN");
    expect(out).toContain("Artifacts to delete: 1");
    expect(out).toContain("Artifacts retained: 1");
    expect(out).toContain("Bytes reclaimed: 200");
  });

  test("omits dry-run marker when not a dry run", () => {
    const plan = planCleanup([], {}, NOW);
    const out = formatPlanSummary(plan);
    expect(out).not.toContain("DRY RUN");
  });
});
