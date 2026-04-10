// TDD: Tests for the deletion plan generation and summary logic.
// These tests verify the DeletionPlan structure and dry-run mode behavior.

import { test, describe, expect } from "bun:test";
import { generateDeletionPlan, formatPlan } from "../src/cleanup";
import type { Artifact, RetentionPolicy } from "../src/types";

const REFERENCE_DATE = new Date("2026-04-10T00:00:00Z");

const ARTIFACTS: Artifact[] = [
  {
    id: "a1",
    name: "build-artifact",
    sizeBytes: 2097152,
    createdAt: new Date("2026-01-01T00:00:00Z"),
    workflowRunId: "run-001",
  },
  {
    id: "a2",
    name: "build-artifact",
    sizeBytes: 1048576,
    createdAt: new Date("2026-02-01T00:00:00Z"),
    workflowRunId: "run-002",
  },
  {
    id: "a3",
    name: "build-artifact",
    sizeBytes: 1048576,
    createdAt: new Date("2026-03-01T00:00:00Z"),
    workflowRunId: "run-003",
  },
  {
    id: "a4",
    name: "test-results",
    sizeBytes: 524288,
    createdAt: new Date("2026-02-15T00:00:00Z"),
    workflowRunId: "run-001",
  },
  {
    id: "a5",
    name: "test-results",
    sizeBytes: 524288,
    createdAt: new Date("2026-03-15T00:00:00Z"),
    workflowRunId: "run-002",
  },
  {
    id: "a6",
    name: "coverage-report",
    sizeBytes: 262144,
    createdAt: new Date("2026-03-20T00:00:00Z"),
    workflowRunId: "run-001",
  },
];

describe("generateDeletionPlan", () => {
  test("generates correct plan for maxAgeDays=30 policy", () => {
    const policy: RetentionPolicy = { maxAgeDays: 30 };
    const plan = generateDeletionPlan(ARTIFACTS, policy, REFERENCE_DATE, true);

    expect(plan.dryRun).toBe(true);
    expect(plan.toDelete.map((a) => a.id).sort()).toEqual(["a1", "a2", "a3", "a4"]);
    expect(plan.toRetain.map((a) => a.id).sort()).toEqual(["a5", "a6"]);
    expect(plan.summary.artifactsDeleted).toBe(4);
    expect(plan.summary.artifactsRetained).toBe(2);
    // Reclaimed: 2097152 + 1048576 + 1048576 + 524288 = 4718592
    expect(plan.summary.totalSpaceReclaimedBytes).toBe(4718592);
  });

  test("generates correct plan for maxTotalSizeBytes=2MB policy", () => {
    const policy: RetentionPolicy = { maxTotalSizeBytes: 2097152 };
    const plan = generateDeletionPlan(ARTIFACTS, policy, REFERENCE_DATE, true);

    expect(plan.toDelete.map((a) => a.id).sort()).toEqual(["a1", "a2", "a4"]);
    expect(plan.toRetain.map((a) => a.id).sort()).toEqual(["a3", "a5", "a6"]);
    expect(plan.summary.artifactsDeleted).toBe(3);
    expect(plan.summary.artifactsRetained).toBe(3);
    // Reclaimed: 524288 + 1048576 + 2097152 = 3670016
    expect(plan.summary.totalSpaceReclaimedBytes).toBe(3670016);
  });

  test("generates correct plan for keepLatestNPerWorkflow=2 policy", () => {
    const policy: RetentionPolicy = { keepLatestNPerWorkflow: 2 };
    const plan = generateDeletionPlan(ARTIFACTS, policy, REFERENCE_DATE, true);

    expect(plan.toDelete.map((a) => a.id).sort()).toEqual(["a1"]);
    expect(plan.toRetain.map((a) => a.id).sort()).toEqual(["a2", "a3", "a4", "a5", "a6"]);
    expect(plan.summary.artifactsDeleted).toBe(1);
    expect(plan.summary.artifactsRetained).toBe(5);
    expect(plan.summary.totalSpaceReclaimedBytes).toBe(2097152);
  });

  test("dry-run plan marks dryRun=true", () => {
    const plan = generateDeletionPlan(
      ARTIFACTS,
      { maxAgeDays: 30 },
      REFERENCE_DATE,
      true // dryRun
    );
    expect(plan.dryRun).toBe(true);
  });

  test("non-dry-run plan marks dryRun=false", () => {
    const plan = generateDeletionPlan(
      ARTIFACTS,
      { maxAgeDays: 30 },
      REFERENCE_DATE,
      false // not a dry run
    );
    expect(plan.dryRun).toBe(false);
  });

  test("summary has zero space reclaimed when nothing deleted", () => {
    const plan = generateDeletionPlan(
      ARTIFACTS,
      { maxAgeDays: 365 },
      REFERENCE_DATE,
      true
    );
    expect(plan.summary.artifactsDeleted).toBe(0);
    expect(plan.summary.totalSpaceReclaimedBytes).toBe(0);
    expect(plan.summary.artifactsRetained).toBe(6);
  });

  test("handles empty artifact list gracefully", () => {
    const plan = generateDeletionPlan([], { maxAgeDays: 30 }, REFERENCE_DATE, true);
    expect(plan.toDelete).toHaveLength(0);
    expect(plan.toRetain).toHaveLength(0);
    expect(plan.summary.artifactsDeleted).toBe(0);
    expect(plan.summary.artifactsRetained).toBe(0);
    expect(plan.summary.totalSpaceReclaimedBytes).toBe(0);
  });
});

describe("formatPlan (output format)", () => {
  test("output contains DRY RUN label when dryRun=true", () => {
    const plan = generateDeletionPlan(
      ARTIFACTS,
      { maxAgeDays: 30 },
      REFERENCE_DATE,
      true
    );
    const output = formatPlan(plan);
    expect(output).toContain("DRY RUN");
  });

  test("output does not contain DRY RUN when dryRun=false", () => {
    const plan = generateDeletionPlan(
      ARTIFACTS,
      { maxAgeDays: 30 },
      REFERENCE_DATE,
      false
    );
    const output = formatPlan(plan);
    expect(output).not.toContain("DRY RUN");
  });

  test("output contains machine-readable summary lines", () => {
    const plan = generateDeletionPlan(
      ARTIFACTS,
      { maxAgeDays: 30 },
      REFERENCE_DATE,
      true
    );
    const output = formatPlan(plan);
    // These exact lines are required for CI assertions
    expect(output).toContain("DELETED_COUNT=4");
    expect(output).toContain("RETAINED_COUNT=2");
    expect(output).toContain("RECLAIMED_BYTES=4718592");
  });

  test("output lists artifact names to be deleted", () => {
    const plan = generateDeletionPlan(
      ARTIFACTS,
      { maxAgeDays: 30 },
      REFERENCE_DATE,
      true
    );
    const output = formatPlan(plan);
    // Should list artifact names
    expect(output).toContain("build-artifact");
    expect(output).toContain("test-results");
  });
});
