// Unit tests for cleanup logic (red/green TDD).
import { describe, test, expect } from "bun:test";
import { buildPlan, formatPlan, type Artifact } from "./cleanup";

const REF_NOW = new Date("2026-04-20T00:00:00Z");

function art(
  name: string,
  sizeBytes: number,
  createdAt: string,
  workflowRunId: string,
): Artifact {
  return { name, sizeBytes, createdAt, workflowRunId };
}

describe("buildPlan", () => {
  test("with no policies, retains everything", () => {
    const arts = [art("a", 100, "2026-04-10T00:00:00Z", "w1")];
    const plan = buildPlan(arts, {}, { now: REF_NOW });
    expect(plan.summary.deleted).toBe(0);
    expect(plan.summary.retained).toBe(1);
    expect(plan.summary.bytesReclaimed).toBe(0);
  });

  test("maxAgeDays deletes artifacts older than threshold", () => {
    const arts = [
      art("old", 100, "2026-03-01T00:00:00Z", "w1"), // ~50d old
      art("fresh", 200, "2026-04-18T00:00:00Z", "w1"), // 2d old
    ];
    const plan = buildPlan(arts, { maxAgeDays: 30 }, { now: REF_NOW });
    expect(plan.summary.deleted).toBe(1);
    expect(plan.entries.find((e) => e.artifact.name === "old")!.action).toBe(
      "delete",
    );
    expect(plan.entries.find((e) => e.artifact.name === "fresh")!.action).toBe(
      "keep",
    );
  });

  test("keepLatestPerWorkflow keeps N newest per workflowRunId", () => {
    const arts = [
      art("a1", 10, "2026-04-10T00:00:00Z", "w1"),
      art("a2", 10, "2026-04-11T00:00:00Z", "w1"),
      art("a3", 10, "2026-04-12T00:00:00Z", "w1"),
      art("b1", 10, "2026-04-10T00:00:00Z", "w2"),
    ];
    const plan = buildPlan(
      arts,
      { keepLatestPerWorkflow: 2 },
      { now: REF_NOW },
    );
    // w1: keep a3, a2; delete a1. w2: keep b1.
    const actionOf = (n: string) =>
      plan.entries.find((e) => e.artifact.name === n)!.action;
    expect(actionOf("a1")).toBe("delete");
    expect(actionOf("a2")).toBe("keep");
    expect(actionOf("a3")).toBe("keep");
    expect(actionOf("b1")).toBe("keep");
  });

  test("maxTotalBytes deletes oldest survivors until total <= limit", () => {
    const arts = [
      art("a", 100, "2026-04-10T00:00:00Z", "w1"),
      art("b", 100, "2026-04-11T00:00:00Z", "w1"),
      art("c", 100, "2026-04-12T00:00:00Z", "w1"),
    ];
    const plan = buildPlan(arts, { maxTotalBytes: 250 }, { now: REF_NOW });
    // Total 300, need to shed >=50, so delete oldest (a), total now 200.
    expect(plan.summary.deleted).toBe(1);
    expect(plan.summary.bytesReclaimed).toBe(100);
    expect(plan.entries.find((e) => e.artifact.name === "a")!.action).toBe(
      "delete",
    );
  });

  test("combines policies (OR semantics) and computes summary", () => {
    const arts = [
      art("old-big", 500, "2026-01-01T00:00:00Z", "w1"),
      art("new-small", 50, "2026-04-19T00:00:00Z", "w1"),
      art("extra1", 50, "2026-04-18T00:00:00Z", "w2"),
      art("extra2", 50, "2026-04-17T00:00:00Z", "w2"),
      art("extra3", 50, "2026-04-16T00:00:00Z", "w2"),
    ];
    const plan = buildPlan(
      arts,
      { maxAgeDays: 30, keepLatestPerWorkflow: 2 },
      { now: REF_NOW, dryRun: true },
    );
    // old-big: age>30 -> delete. extra3 oldest in w2 -> delete.
    expect(plan.summary.deleted).toBe(2);
    expect(plan.summary.retained).toBe(3);
    expect(plan.summary.bytesReclaimed).toBe(550);
    expect(plan.summary.dryRun).toBe(true);
  });

  test("throws on negative size", () => {
    expect(() =>
      buildPlan([art("bad", -1, "2026-04-10T00:00:00Z", "w1")], {}),
    ).toThrow(/negative sizeBytes/);
  });

  test("throws on invalid timestamp", () => {
    expect(() =>
      buildPlan(
        [art("bad", 1, "not-a-date", "w1")],
        { maxAgeDays: 1 },
        { now: REF_NOW },
      ),
    ).toThrow(/Invalid createdAt/);
  });
});

describe("formatPlan", () => {
  test("renders summary lines", () => {
    const arts = [art("a", 100, "2026-03-01T00:00:00Z", "w1")];
    const plan = buildPlan(arts, { maxAgeDays: 30 }, { now: REF_NOW });
    const text = formatPlan(plan);
    expect(text).toContain("Delete: 1");
    expect(text).toContain("Bytes reclaimed: 100");
    expect(text).toContain("[DELETE] a");
  });
});
