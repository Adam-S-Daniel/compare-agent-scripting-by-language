// TDD: tests written first, implementation follows
// Red/green cycle: each test was written before the code it tests

import { test, expect, describe, beforeAll } from "bun:test";
import { spawnSync } from "child_process";
import { existsSync, readFileSync } from "fs";
import { join } from "path";
import {
  type Artifact,
  type RetentionPolicy,
  applyMaxAge,
  applyKeepLatestN,
  applyMaxTotalSize,
  applyRetentionPolicies,
  formatDeletionPlan,
} from "./artifact-cleanup";

// ── Helpers ───────────────────────────────────────────────────────────────────

function makeArtifact(overrides: Partial<Artifact> & { name: string }): Artifact {
  return {
    size: 1024,
    createdAt: new Date("2026-05-01T00:00:00Z"),
    workflowRunId: "run-default",
    ...overrides,
  };
}

const REF_DATE = new Date("2026-05-07T00:00:00Z");

// ── applyMaxAge ───────────────────────────────────────────────────────────────

describe("applyMaxAge", () => {
  const old1 = makeArtifact({ name: "old-1", createdAt: new Date("2026-03-01T00:00:00Z") }); // 67 days old
  const old2 = makeArtifact({ name: "old-2", createdAt: new Date("2026-03-15T00:00:00Z") }); // 53 days old
  const recent1 = makeArtifact({ name: "recent-1", createdAt: new Date("2026-04-20T00:00:00Z") }); // 17 days old
  const recent2 = makeArtifact({ name: "recent-2", createdAt: new Date("2026-05-06T00:00:00Z") }); // 1 day old

  test("removes artifacts older than maxAgeDays", () => {
    const { toDelete, toRetain } = applyMaxAge([old1, old2, recent1], 30, REF_DATE);
    expect(toDelete.map((a) => a.name)).toEqual(["old-1", "old-2"]);
    expect(toRetain.map((a) => a.name)).toEqual(["recent-1"]);
  });

  test("retains artifacts within age limit", () => {
    const { toDelete, toRetain } = applyMaxAge([recent1, recent2], 30, REF_DATE);
    expect(toDelete).toHaveLength(0);
    expect(toRetain).toHaveLength(2);
  });

  test("retains artifact exactly at the age boundary (not strictly over)", () => {
    // An artifact that is exactly 30 days old should be retained (>30 deletes, not >=30)
    const exactly30 = makeArtifact({ name: "exact", createdAt: new Date("2026-04-07T00:00:00Z") });
    const { toDelete, toRetain } = applyMaxAge([exactly30], 30, REF_DATE);
    expect(toDelete).toHaveLength(0);
    expect(toRetain).toHaveLength(1);
  });

  test("returns all as retained when maxAgeDays is undefined", () => {
    const { toDelete, toRetain } = applyMaxAge([old1, old2], undefined, REF_DATE);
    expect(toDelete).toHaveLength(0);
    expect(toRetain).toHaveLength(2);
  });
});

// ── applyKeepLatestN ─────────────────────────────────────────────────────────

describe("applyKeepLatestN", () => {
  const deploy1 = makeArtifact({ name: "d1", createdAt: new Date("2026-05-01T00:00:00Z"), workflowRunId: "deploy" });
  const deploy2 = makeArtifact({ name: "d2", createdAt: new Date("2026-05-02T00:00:00Z"), workflowRunId: "deploy" });
  const deploy3 = makeArtifact({ name: "d3", createdAt: new Date("2026-05-03T00:00:00Z"), workflowRunId: "deploy" });
  const deploy4 = makeArtifact({ name: "d4", createdAt: new Date("2026-05-04T00:00:00Z"), workflowRunId: "deploy" });
  const other1 = makeArtifact({ name: "o1", createdAt: new Date("2026-05-01T00:00:00Z"), workflowRunId: "other" });
  const other2 = makeArtifact({ name: "o2", createdAt: new Date("2026-05-02T00:00:00Z"), workflowRunId: "other" });

  test("keeps N most recent per workflowRunId, deletes the rest", () => {
    const { toDelete, toRetain } = applyKeepLatestN(
      [deploy1, deploy2, deploy3, deploy4],
      2
    );
    // Oldest two should be deleted, newest two retained
    expect(toDelete.map((a) => a.name).sort()).toEqual(["d1", "d2"]);
    expect(toRetain.map((a) => a.name).sort()).toEqual(["d3", "d4"]);
  });

  test("retains all when group size <= N", () => {
    const { toDelete, toRetain } = applyKeepLatestN([other1, other2], 2);
    expect(toDelete).toHaveLength(0);
    expect(toRetain).toHaveLength(2);
  });

  test("handles multiple workflow groups independently", () => {
    const { toDelete, toRetain } = applyKeepLatestN(
      [deploy1, deploy2, deploy3, deploy4, other1, other2],
      2
    );
    expect(toDelete.map((a) => a.name).sort()).toEqual(["d1", "d2"]);
    expect(toRetain).toHaveLength(4);
  });

  test("returns all as retained when keepLatestN is undefined", () => {
    const { toDelete, toRetain } = applyKeepLatestN([deploy1, deploy2], undefined);
    expect(toDelete).toHaveLength(0);
    expect(toRetain).toHaveLength(2);
  });
});

// ── applyMaxTotalSize ─────────────────────────────────────────────────────────

describe("applyMaxTotalSize", () => {
  // 3 MB + 2 MB + 1 MB = 6 MB total
  const large1 = makeArtifact({ name: "l1", size: 3145728, createdAt: new Date("2026-04-01T00:00:00Z") });
  const large2 = makeArtifact({ name: "l2", size: 2097152, createdAt: new Date("2026-04-15T00:00:00Z") });
  const large3 = makeArtifact({ name: "l3", size: 1048576, createdAt: new Date("2026-05-01T00:00:00Z") });

  test("deletes oldest artifacts until total size is under limit", () => {
    // 5 MB limit: total is 6 MB, delete oldest (l1=3MB) → 3 MB left ≤ 5 MB → stop
    const { toDelete, toRetain } = applyMaxTotalSize([large1, large2, large3], 5242880);
    expect(toDelete.map((a) => a.name)).toEqual(["l1"]);
    expect(toRetain.map((a) => a.name)).toEqual(["l2", "l3"]);
  });

  test("retains all when total size is already under limit", () => {
    const { toDelete, toRetain } = applyMaxTotalSize([large1, large2, large3], 10485760);
    expect(toDelete).toHaveLength(0);
    expect(toRetain).toHaveLength(3);
  });

  test("returns all as retained when maxTotalSizeBytes is undefined", () => {
    const { toDelete, toRetain } = applyMaxTotalSize([large1, large2], undefined);
    expect(toDelete).toHaveLength(0);
    expect(toRetain).toHaveLength(2);
  });
});

// ── applyRetentionPolicies ───────────────────────────────────────────────────

describe("applyRetentionPolicies", () => {
  const artifacts: Artifact[] = [
    makeArtifact({ name: "a1", size: 1048576, createdAt: new Date("2026-03-01T00:00:00Z"), workflowRunId: "wf-1" }),
    makeArtifact({ name: "a2", size: 524288,  createdAt: new Date("2026-04-20T00:00:00Z"), workflowRunId: "wf-1" }),
    makeArtifact({ name: "a3", size: 262144,  createdAt: new Date("2026-05-05T00:00:00Z"), workflowRunId: "wf-1" }),
  ];

  test("applies max age policy correctly", () => {
    const plan = applyRetentionPolicies(artifacts, { maxAgeDays: 30 }, { now: REF_DATE });
    expect(plan.toDelete.map((a) => a.name)).toEqual(["a1"]);
    expect(plan.toRetain).toHaveLength(2);
    expect(plan.summary.artifactsDeleted).toBe(1);
    expect(plan.summary.spaceReclaimed).toBe(1048576);
  });

  test("deduplicates artifacts marked by multiple policies", () => {
    // a1 is both old AND would be cut by keepLatestN=2 (but it's the oldest, so yes)
    const plan = applyRetentionPolicies(
      artifacts,
      { maxAgeDays: 30, keepLatestN: 2 },
      { now: REF_DATE }
    );
    // a1 flagged by both policies — should appear once in toDelete
    const deleteNames = plan.toDelete.map((a) => a.name);
    expect(new Set(deleteNames).size).toBe(deleteNames.length); // no dupes
    expect(plan.toDelete.map((a) => a.name)).toEqual(["a1"]);
  });

  test("generates correct summary totals", () => {
    const plan = applyRetentionPolicies(artifacts, { maxAgeDays: 30 }, { now: REF_DATE });
    expect(plan.summary.totalArtifacts).toBe(3);
    expect(plan.summary.artifactsDeleted).toBe(1);
    expect(plan.summary.artifactsRetained).toBe(2);
  });

  test("dry run flag is recorded in the plan", () => {
    const livePlan = applyRetentionPolicies(artifacts, {}, { now: REF_DATE, dryRun: false });
    const dryPlan = applyRetentionPolicies(artifacts, {}, { now: REF_DATE, dryRun: true });
    expect(livePlan.dryRun).toBe(false);
    expect(dryPlan.dryRun).toBe(true);
  });
});

// ── formatDeletionPlan ────────────────────────────────────────────────────────

describe("formatDeletionPlan", () => {
  const artifacts: Artifact[] = [
    makeArtifact({ name: "old-artifact", size: 2097152, createdAt: new Date("2026-03-01T00:00:00Z"), workflowRunId: "wf-x" }),
    makeArtifact({ name: "new-artifact", size: 524288,  createdAt: new Date("2026-05-01T00:00:00Z"), workflowRunId: "wf-x" }),
  ];

  test("includes dry-run header when in dry-run mode", () => {
    const plan = applyRetentionPolicies(artifacts, { maxAgeDays: 30 }, { now: REF_DATE, dryRun: true });
    const output = formatDeletionPlan(plan);
    expect(output).toContain("DRY RUN");
  });

  test("lists artifacts to delete and retain", () => {
    const plan = applyRetentionPolicies(artifacts, { maxAgeDays: 30 }, { now: REF_DATE });
    const output = formatDeletionPlan(plan);
    expect(output).toContain("old-artifact");
    expect(output).toContain("new-artifact");
    expect(output).toContain("DELETE");
    expect(output).toContain("RETAIN");
  });

  test("shows correct summary statistics", () => {
    const plan = applyRetentionPolicies(artifacts, { maxAgeDays: 30 }, { now: REF_DATE });
    const output = formatDeletionPlan(plan);
    expect(output).toContain("Artifacts deleted:  1");
    expect(output).toContain("Artifacts retained: 1");
    expect(output).toContain("Space reclaimed:    2097152 bytes");
  });
});

// ── Workflow structure tests ──────────────────────────────────────────────────

describe("Workflow structure", () => {
  const workflowPath = join(import.meta.dir, ".github/workflows/artifact-cleanup-script.yml");
  let workflowContent = "";

  beforeAll(() => {
    if (existsSync(workflowPath)) {
      workflowContent = readFileSync(workflowPath, "utf8");
    }
  });

  test("workflow file exists", () => {
    expect(existsSync(workflowPath)).toBe(true);
  });

  test("has expected triggers (push, pull_request, workflow_dispatch, schedule)", () => {
    expect(workflowContent).toContain("push:");
    expect(workflowContent).toContain("pull_request:");
    expect(workflowContent).toContain("workflow_dispatch:");
    expect(workflowContent).toContain("schedule:");
  });

  test("has cleanup job with expected steps", () => {
    expect(workflowContent).toContain("actions/checkout@v4");
    expect(workflowContent).toContain("bun test");
    expect(workflowContent).toContain("artifact-cleanup.ts");
  });

  test("references script files that exist on disk", () => {
    expect(existsSync(join(import.meta.dir, "artifact-cleanup.ts"))).toBe(true);
    expect(existsSync(join(import.meta.dir, "fixtures/tc1-max-age.json"))).toBe(true);
    expect(existsSync(join(import.meta.dir, "fixtures/tc2-keep-latest.json"))).toBe(true);
    expect(existsSync(join(import.meta.dir, "fixtures/tc3-max-size.json"))).toBe(true);
  });

  test("passes actionlint validation", () => {
    const result = spawnSync("actionlint", [workflowPath], { encoding: "utf8" });
    if (result.error) {
      // actionlint not on PATH — skip rather than fail
      console.warn("actionlint not found, skipping lint check");
      return;
    }
    expect(result.status).toBe(0);
    expect(result.stderr).toBe("");
  });
});
