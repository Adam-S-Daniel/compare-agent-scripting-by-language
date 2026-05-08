// Tests written using TDD red/green cycle for each policy.
// Each describe block represents one cycle: red (failing test) -> green (impl) -> refactor.

import { describe, test, expect } from "bun:test";
import {
  buildDeletionPlan,
  formatPlan,
  loadArtifactsFromFile,
  type Artifact,
} from "./cleanup.ts";

const NOW = new Date("2026-05-08T00:00:00Z");

function art(
  name: string,
  ageDays: number,
  sizeBytes: number,
  workflowRunId = "wf-1",
): Artifact {
  return {
    name,
    sizeBytes,
    createdAt: new Date(NOW.getTime() - ageDays * 86_400_000),
    workflowRunId,
  };
}

describe("buildDeletionPlan — empty/no-policy", () => {
  test("returns empty plan when no artifacts", () => {
    const plan = buildDeletionPlan([], {}, { now: NOW });
    expect(plan.summary.totalArtifacts).toBe(0);
    expect(plan.toDelete).toHaveLength(0);
    expect(plan.toKeep).toHaveLength(0);
    expect(plan.summary.bytesReclaimed).toBe(0);
  });

  test("retains all artifacts when no policy is given", () => {
    const arts = [art("a", 1, 100), art("b", 365, 200)];
    const plan = buildDeletionPlan(arts, {}, { now: NOW });
    expect(plan.toDelete).toHaveLength(0);
    expect(plan.toKeep).toHaveLength(2);
    expect(plan.summary.bytesRetained).toBe(300);
  });
});

describe("buildDeletionPlan — maxAgeDays", () => {
  test("deletes artifacts older than maxAgeDays", () => {
    const arts = [art("young", 5, 100), art("old", 40, 200)];
    const plan = buildDeletionPlan(arts, { maxAgeDays: 30 }, { now: NOW });
    expect(plan.toDelete).toHaveLength(1);
    expect(plan.toDelete[0]!.artifact.name).toBe("old");
    expect(plan.toDelete[0]!.reason).toBe("age");
    expect(plan.summary.bytesReclaimed).toBe(200);
  });

  test("boundary: artifact exactly at maxAgeDays is kept", () => {
    const arts = [art("edge", 30, 100)];
    const plan = buildDeletionPlan(arts, { maxAgeDays: 30 }, { now: NOW });
    expect(plan.toDelete).toHaveLength(0);
  });
});

describe("buildDeletionPlan — keepLatestPerWorkflow", () => {
  test("keeps the N newest artifacts per workflow run", () => {
    const arts = [
      art("a-newest", 1, 100, "wf-A"),
      art("a-mid", 5, 100, "wf-A"),
      art("a-old", 10, 100, "wf-A"),
      art("b-only", 2, 50, "wf-B"),
    ];
    const plan = buildDeletionPlan(
      arts,
      { keepLatestPerWorkflow: 2 },
      { now: NOW },
    );
    const deletedNames = plan.toDelete.map((e) => e.artifact.name).sort();
    expect(deletedNames).toEqual(["a-old"]);
    expect(plan.toDelete[0]!.reason).toBe("keep-latest");
  });

  test("keepLatestPerWorkflow=0 deletes all in each group via that policy", () => {
    const arts = [art("x", 1, 10, "wf-1"), art("y", 2, 10, "wf-1")];
    const plan = buildDeletionPlan(
      arts,
      { keepLatestPerWorkflow: 0 },
      { now: NOW },
    );
    expect(plan.toDelete).toHaveLength(2);
  });
});

describe("buildDeletionPlan — maxTotalBytes", () => {
  test("deletes oldest first to bring total under cap", () => {
    const arts = [
      art("a", 1, 500),
      art("b", 5, 500),
      art("c", 10, 500), // oldest
    ];
    const plan = buildDeletionPlan(arts, { maxTotalBytes: 1000 }, { now: NOW });
    expect(plan.toDelete.map((e) => e.artifact.name)).toEqual(["c"]);
    expect(plan.toDelete[0]!.reason).toBe("size");
    expect(plan.summary.bytesRetained).toBe(1000);
  });

  test("does nothing when total is already under cap", () => {
    const arts = [art("a", 1, 100), art("b", 2, 100)];
    const plan = buildDeletionPlan(arts, { maxTotalBytes: 10_000 }, { now: NOW });
    expect(plan.toDelete).toHaveLength(0);
  });
});

describe("buildDeletionPlan — combined policies", () => {
  test("age policy is applied before size cap", () => {
    const arts = [
      art("very-old", 100, 5000, "wf-1"),
      art("recent-1", 1, 500, "wf-1"),
      art("recent-2", 2, 500, "wf-1"),
    ];
    const plan = buildDeletionPlan(
      arts,
      { maxAgeDays: 30, maxTotalBytes: 10_000 },
      { now: NOW },
    );
    expect(plan.toDelete.map((e) => e.artifact.name)).toEqual(["very-old"]);
    expect(plan.toDelete[0]!.reason).toBe("age");
  });

  test("all three policies together", () => {
    const arts = [
      art("old-A", 100, 100, "wf-A"),
      art("new-A1", 1, 800, "wf-A"),
      art("new-A2", 2, 800, "wf-A"),
      art("new-A3", 3, 800, "wf-A"),
      art("solo-B", 1, 200, "wf-B"),
    ];
    const plan = buildDeletionPlan(
      arts,
      { maxAgeDays: 30, keepLatestPerWorkflow: 2, maxTotalBytes: 1500 },
      { now: NOW },
    );
    const byReason = new Map<string, string[]>();
    for (const e of plan.toDelete) {
      const list = byReason.get(e.reason) ?? [];
      list.push(e.artifact.name);
      byReason.set(e.reason, list);
    }
    expect(byReason.get("age")).toEqual(["old-A"]);
    expect(byReason.get("keep-latest")).toEqual(["new-A3"]);
    // After age+keep-latest, survivors total = 800+800+200 = 1800. Cap=1500.
    // Oldest survivor is solo-B (1 day) tied with new-A1/A2... actually solo-B age=1.
    // solo-B and new-A1 are both 1 day. JS sort is stable so input order wins; solo-B is later in input.
    // Oldest first => new-A2 (2d), new-A1 (1d), solo-B (1d).
    // Need to delete to get under 1500: remove new-A2 (800) -> 1000 under cap.
    expect(byReason.get("size")).toEqual(["new-A2"]);
  });
});

describe("dry-run flag", () => {
  test("plan reflects dryRun=true", () => {
    const plan = buildDeletionPlan(
      [art("x", 1, 1)],
      { maxAgeDays: 0 },
      { now: NOW, dryRun: true },
    );
    expect(plan.dryRun).toBe(true);
    expect(plan.toDelete).toHaveLength(1);
  });

  test("dryRun defaults to false", () => {
    const plan = buildDeletionPlan([], {}, { now: NOW });
    expect(plan.dryRun).toBe(false);
  });
});

describe("validation / error handling", () => {
  test("rejects negative maxAgeDays", () => {
    expect(() => buildDeletionPlan([], { maxAgeDays: -1 }, { now: NOW })).toThrow();
  });

  test("rejects non-integer keepLatestPerWorkflow", () => {
    expect(() =>
      buildDeletionPlan([], { keepLatestPerWorkflow: 1.5 }, { now: NOW }),
    ).toThrow();
  });

  test("rejects artifact with negative size", () => {
    const bad: Artifact = {
      name: "x",
      sizeBytes: -1,
      createdAt: NOW,
      workflowRunId: "wf-1",
    };
    expect(() => buildDeletionPlan([bad], {}, { now: NOW })).toThrow();
  });

  test("rejects artifact with invalid date", () => {
    const bad: Artifact = {
      name: "x",
      sizeBytes: 1,
      createdAt: new Date("not-a-date"),
      workflowRunId: "wf-1",
    };
    expect(() => buildDeletionPlan([bad], {}, { now: NOW })).toThrow();
  });
});

describe("formatPlan output", () => {
  test("includes summary lines and DRY RUN marker", () => {
    const plan = buildDeletionPlan(
      [art("x", 100, 50)],
      { maxAgeDays: 30 },
      { now: NOW, dryRun: true },
    );
    const out = formatPlan(plan);
    expect(out).toContain("DRY RUN");
    expect(out).toContain("Bytes reclaimed: 50");
    expect(out).toContain("reason=age");
  });
});

describe("loadArtifactsFromFile", () => {
  test("loads JSON and parses createdAt to Date", async () => {
    const tmp = `/tmp/cleanup-test-${process.pid}-${Date.now()}.json`;
    const data = [
      { name: "a", sizeBytes: 10, createdAt: "2026-05-01T00:00:00Z", workflowRunId: "wf-1" },
    ];
    await Bun.write(tmp, JSON.stringify(data));
    const arts = await loadArtifactsFromFile(tmp);
    expect(arts).toHaveLength(1);
    expect(arts[0]!.createdAt).toBeInstanceOf(Date);
    expect(arts[0]!.name).toBe("a");
  });

  test("rejects malformed JSON", async () => {
    const tmp = `/tmp/cleanup-test-bad-${process.pid}-${Date.now()}.json`;
    await Bun.write(tmp, "not json");
    await expect(loadArtifactsFromFile(tmp)).rejects.toThrow();
  });
});
