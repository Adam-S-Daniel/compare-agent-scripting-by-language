import { describe, test, expect } from "bun:test";
import {
  planCleanup,
  formatPlan,
  parseArtifactsJson,
  type Artifact,
  type RetentionPolicy,
} from "./cleanup";

// Reference "now" for deterministic age calculations across tests.
const NOW = new Date("2026-05-07T12:00:00Z").getTime();

const daysAgo = (n: number): string =>
  new Date(NOW - n * 24 * 60 * 60 * 1000).toISOString();

describe("planCleanup — max age", () => {
  test("flags artifacts older than maxAgeDays for deletion", () => {
    const artifacts: Artifact[] = [
      { name: "old", sizeBytes: 100, createdAt: daysAgo(40), workflowRunId: "wf-1" },
      { name: "young", sizeBytes: 200, createdAt: daysAgo(5), workflowRunId: "wf-1" },
    ];
    const policy: RetentionPolicy = { maxAgeDays: 30 };
    const plan = planCleanup(artifacts, policy, NOW);
    expect(plan.toDelete.map((a) => a.name)).toEqual(["old"]);
    expect(plan.toKeep.map((a) => a.name)).toEqual(["young"]);
    expect(plan.reasons["old"].join("; ")).toContain("older than 30 days");
  });

  test("returns empty deletion list when no policy applies", () => {
    const artifacts: Artifact[] = [
      { name: "a", sizeBytes: 100, createdAt: daysAgo(1), workflowRunId: "wf-1" },
    ];
    const plan = planCleanup(artifacts, {}, NOW);
    expect(plan.toDelete).toHaveLength(0);
    expect(plan.toKeep).toHaveLength(1);
  });
});

describe("planCleanup — keep latest N per workflow", () => {
  test("keeps newest N per workflow run id, deletes older ones", () => {
    const artifacts: Artifact[] = [
      { name: "wf1-old", sizeBytes: 50, createdAt: daysAgo(10), workflowRunId: "wf-1" },
      { name: "wf1-mid", sizeBytes: 50, createdAt: daysAgo(5), workflowRunId: "wf-1" },
      { name: "wf1-new", sizeBytes: 50, createdAt: daysAgo(1), workflowRunId: "wf-1" },
      { name: "wf2-only", sizeBytes: 50, createdAt: daysAgo(20), workflowRunId: "wf-2" },
    ];
    const policy: RetentionPolicy = { keepLatestPerWorkflow: 2 };
    const plan = planCleanup(artifacts, policy, NOW);
    expect(plan.toDelete.map((a) => a.name)).toEqual(["wf1-old"]);
    expect(plan.toKeep.map((a) => a.name).sort()).toEqual(
      ["wf1-mid", "wf1-new", "wf2-only"].sort(),
    );
    expect(plan.reasons["wf1-old"].join("; ")).toContain("not in latest 2 of workflow wf-1");
  });
});

describe("planCleanup — max total size", () => {
  test("deletes oldest first until total kept size is under limit", () => {
    const artifacts: Artifact[] = [
      { name: "huge-old", sizeBytes: 600, createdAt: daysAgo(10), workflowRunId: "wf-1" },
      { name: "med-mid", sizeBytes: 300, createdAt: daysAgo(5), workflowRunId: "wf-1" },
      { name: "small-new", sizeBytes: 200, createdAt: daysAgo(1), workflowRunId: "wf-1" },
    ];
    // Total = 1100. Limit 500 means we must shed 600 bytes.
    const policy: RetentionPolicy = { maxTotalSizeBytes: 500 };
    const plan = planCleanup(artifacts, policy, NOW);
    expect(plan.toDelete.map((a) => a.name)).toEqual(["huge-old"]);
    const keptSize = plan.toKeep.reduce((s, a) => s + a.sizeBytes, 0);
    expect(keptSize).toBeLessThanOrEqual(500);
    expect(plan.reasons["huge-old"].join("; ")).toContain("exceeds total size budget");
  });

  test("does nothing when total is already under limit", () => {
    const artifacts: Artifact[] = [
      { name: "a", sizeBytes: 100, createdAt: daysAgo(1), workflowRunId: "wf-1" },
    ];
    const plan = planCleanup(artifacts, { maxTotalSizeBytes: 1000 }, NOW);
    expect(plan.toDelete).toHaveLength(0);
  });
});

describe("planCleanup — combined policies & summary", () => {
  test("union of policies applies; summary tallies bytes reclaimed and counts", () => {
    const artifacts: Artifact[] = [
      { name: "ancient", sizeBytes: 100, createdAt: daysAgo(100), workflowRunId: "wf-1" },
      { name: "wf1-mid", sizeBytes: 100, createdAt: daysAgo(10), workflowRunId: "wf-1" },
      { name: "wf1-new", sizeBytes: 100, createdAt: daysAgo(1), workflowRunId: "wf-1" },
      { name: "wf2-old", sizeBytes: 500, createdAt: daysAgo(20), workflowRunId: "wf-2" },
      { name: "wf2-new", sizeBytes: 100, createdAt: daysAgo(2), workflowRunId: "wf-2" },
    ];
    const policy: RetentionPolicy = {
      maxAgeDays: 30,
      keepLatestPerWorkflow: 1,
      maxTotalSizeBytes: 1000,
    };
    const plan = planCleanup(artifacts, policy, NOW);

    // ancient: deleted by maxAgeDays AND keepLatest (only 1 per wf, wf1-new is newest).
    // wf1-mid: deleted by keepLatestPerWorkflow=1 (wf1-new is newer).
    // wf2-old: deleted by keepLatestPerWorkflow=1 (wf2-new is newer).
    // wf1-new, wf2-new: kept.
    expect(plan.toDelete.map((a) => a.name).sort()).toEqual(
      ["ancient", "wf1-mid", "wf2-old"].sort(),
    );
    expect(plan.summary.deletedCount).toBe(3);
    expect(plan.summary.keptCount).toBe(2);
    expect(plan.summary.bytesReclaimed).toBe(700);
    expect(plan.summary.totalCount).toBe(5);
  });
});

describe("formatPlan output", () => {
  test("includes summary header and per-artifact decisions", () => {
    const artifacts: Artifact[] = [
      { name: "old", sizeBytes: 100, createdAt: daysAgo(40), workflowRunId: "wf-1" },
      { name: "young", sizeBytes: 200, createdAt: daysAgo(5), workflowRunId: "wf-1" },
    ];
    const plan = planCleanup(artifacts, { maxAgeDays: 30 }, NOW);
    const out = formatPlan(plan, { dryRun: true });
    expect(out).toContain("DRY-RUN");
    expect(out).toContain("Artifacts deleted: 1");
    expect(out).toContain("Artifacts retained: 1");
    expect(out).toContain("Bytes reclaimed: 100");
    expect(out).toContain("DELETE  old");
    expect(out).toContain("KEEP    young");
  });

  test("non-dry-run output omits the DRY-RUN banner", () => {
    const plan = planCleanup([], { maxAgeDays: 30 }, NOW);
    const out = formatPlan(plan, { dryRun: false });
    expect(out).not.toContain("DRY-RUN");
    expect(out).toContain("EXECUTE");
  });
});

describe("parseArtifactsJson", () => {
  test("parses well-formed JSON array", () => {
    const json = JSON.stringify([
      { name: "a", sizeBytes: 1, createdAt: daysAgo(1), workflowRunId: "wf-1" },
    ]);
    const artifacts = parseArtifactsJson(json);
    expect(artifacts).toHaveLength(1);
    expect(artifacts[0].name).toBe("a");
  });

  test("throws a meaningful error on non-array input", () => {
    expect(() => parseArtifactsJson('{"not": "array"}')).toThrow(/array/i);
  });

  test("throws on missing required fields", () => {
    const json = JSON.stringify([{ name: "no-size" }]);
    expect(() => parseArtifactsJson(json)).toThrow(/sizeBytes/);
  });

  test("throws on malformed JSON with line context", () => {
    expect(() => parseArtifactsJson("not json")).toThrow(/JSON/i);
  });
});
