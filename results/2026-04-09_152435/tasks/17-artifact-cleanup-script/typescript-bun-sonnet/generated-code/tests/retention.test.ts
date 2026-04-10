// TDD: Red-Green-Refactor approach
// Step 1 (RED): Write failing tests first, then implement to make them pass.
//
// Tests cover each retention policy individually:
//   - maxAgeDays: delete artifacts older than N days
//   - maxTotalSizeBytes: keep newest artifacts within total size limit
//   - keepLatestNPerWorkflow: keep N most recent per artifact name

import { test, describe, expect } from "bun:test";
import {
  applyMaxAgePolicy,
  applyMaxTotalSizePolicy,
  applyKeepLatestNPolicy,
  applyRetentionPolicies,
} from "../src/retention";
import type { Artifact } from "../src/types";

// Reference date for all tests: 2026-04-10T00:00:00Z
const REFERENCE_DATE = new Date("2026-04-10T00:00:00Z");

// Shared fixture: 6 artifacts with different names, sizes, ages, and workflow runs
const ARTIFACTS: Artifact[] = [
  {
    id: "a1",
    name: "build-artifact",
    sizeBytes: 2097152, // 2MB
    createdAt: new Date("2026-01-01T00:00:00Z"), // 99 days old
    workflowRunId: "run-001",
  },
  {
    id: "a2",
    name: "build-artifact",
    sizeBytes: 1048576, // 1MB
    createdAt: new Date("2026-02-01T00:00:00Z"), // 68 days old
    workflowRunId: "run-002",
  },
  {
    id: "a3",
    name: "build-artifact",
    sizeBytes: 1048576, // 1MB
    createdAt: new Date("2026-03-01T00:00:00Z"), // 40 days old
    workflowRunId: "run-003",
  },
  {
    id: "a4",
    name: "test-results",
    sizeBytes: 524288, // 512KB
    createdAt: new Date("2026-02-15T00:00:00Z"), // 54 days old
    workflowRunId: "run-001",
  },
  {
    id: "a5",
    name: "test-results",
    sizeBytes: 524288, // 512KB
    createdAt: new Date("2026-03-15T00:00:00Z"), // 26 days old
    workflowRunId: "run-002",
  },
  {
    id: "a6",
    name: "coverage-report",
    sizeBytes: 262144, // 256KB
    createdAt: new Date("2026-03-20T00:00:00Z"), // 21 days old
    workflowRunId: "run-001",
  },
];

// Total size: 2097152 + 1048576 + 1048576 + 524288 + 524288 + 262144 = 5505024 bytes

describe("applyMaxAgePolicy", () => {
  test("deletes artifacts older than maxAgeDays", () => {
    // Cutoff: 2026-04-10 - 30 days = 2026-03-11
    // Older than 30 days: a1 (99d), a2 (68d), a3 (40d), a4 (54d)
    // Retained: a5 (26d), a6 (21d)
    const { toDelete, toRetain } = applyMaxAgePolicy(
      ARTIFACTS,
      30,
      REFERENCE_DATE
    );

    const deletedIds = toDelete.map((a) => a.id).sort();
    const retainedIds = toRetain.map((a) => a.id).sort();

    expect(deletedIds).toEqual(["a1", "a2", "a3", "a4"]);
    expect(retainedIds).toEqual(["a5", "a6"]);
  });

  test("retains all artifacts when maxAgeDays is large", () => {
    const { toDelete, toRetain } = applyMaxAgePolicy(
      ARTIFACTS,
      365,
      REFERENCE_DATE
    );
    expect(toDelete).toHaveLength(0);
    expect(toRetain).toHaveLength(6);
  });

  test("deletes all artifacts when maxAgeDays is 0", () => {
    const { toDelete, toRetain } = applyMaxAgePolicy(
      ARTIFACTS,
      0,
      REFERENCE_DATE
    );
    expect(toDelete).toHaveLength(6);
    expect(toRetain).toHaveLength(0);
  });

  test("handles empty artifact list", () => {
    const { toDelete, toRetain } = applyMaxAgePolicy([], 30, REFERENCE_DATE);
    expect(toDelete).toHaveLength(0);
    expect(toRetain).toHaveLength(0);
  });
});

describe("applyMaxTotalSizePolicy", () => {
  test("retains newest artifacts within size limit, deletes oldest", () => {
    // maxTotalSize = 2MB = 2097152 bytes
    // Sorted newest-first: a6(262144), a5(524288), a3(1048576), a4(524288), a2(1048576), a1(2097152)
    // Cumulative: 262144 → 786432 → 1835008 → 2359296 (exceeds 2097152, stop here)
    // Retain: a6, a5, a3 (cumulative 1835008 ≤ 2097152)
    // Delete: a4, a2, a1
    const { toDelete, toRetain } = applyMaxTotalSizePolicy(
      ARTIFACTS,
      2097152
    );

    const deletedIds = toDelete.map((a) => a.id).sort();
    const retainedIds = toRetain.map((a) => a.id).sort();

    expect(deletedIds).toEqual(["a1", "a2", "a4"]);
    expect(retainedIds).toEqual(["a3", "a5", "a6"]);
  });

  test("retains all artifacts when size limit is larger than total", () => {
    const { toDelete, toRetain } = applyMaxTotalSizePolicy(
      ARTIFACTS,
      10 * 1024 * 1024 // 10MB
    );
    expect(toDelete).toHaveLength(0);
    expect(toRetain).toHaveLength(6);
  });

  test("deletes all artifacts when size limit is 0", () => {
    const { toDelete, toRetain } = applyMaxTotalSizePolicy(ARTIFACTS, 0);
    expect(toDelete).toHaveLength(6);
    expect(toRetain).toHaveLength(0);
  });

  test("handles empty artifact list", () => {
    const { toDelete, toRetain } = applyMaxTotalSizePolicy([], 1024 * 1024);
    expect(toDelete).toHaveLength(0);
    expect(toRetain).toHaveLength(0);
  });
});

describe("applyKeepLatestNPolicy", () => {
  test("keeps N most recent per artifact name, deletes rest", () => {
    // build-artifact: a1(Jan1), a2(Feb1), a3(Mar1) → keep a2,a3 → delete a1
    // test-results: a4(Feb15), a5(Mar15) → keep both (only 2 exist)
    // coverage-report: a6(Mar20) → keep (only 1 exists)
    const { toDelete, toRetain } = applyKeepLatestNPolicy(ARTIFACTS, 2);

    const deletedIds = toDelete.map((a) => a.id).sort();
    const retainedIds = toRetain.map((a) => a.id).sort();

    expect(deletedIds).toEqual(["a1"]);
    expect(retainedIds).toEqual(["a2", "a3", "a4", "a5", "a6"]);
  });

  test("keeps only 1 most recent per artifact name", () => {
    // build-artifact: keep a3, delete a1, a2
    // test-results: keep a5, delete a4
    // coverage-report: keep a6
    const { toDelete, toRetain } = applyKeepLatestNPolicy(ARTIFACTS, 1);

    const deletedIds = toDelete.map((a) => a.id).sort();
    const retainedIds = toRetain.map((a) => a.id).sort();

    expect(deletedIds).toEqual(["a1", "a2", "a4"]);
    expect(retainedIds).toEqual(["a3", "a5", "a6"]);
  });

  test("retains all when N is larger than group size", () => {
    const { toDelete, toRetain } = applyKeepLatestNPolicy(ARTIFACTS, 100);
    expect(toDelete).toHaveLength(0);
    expect(toRetain).toHaveLength(6);
  });

  test("handles empty artifact list", () => {
    const { toDelete, toRetain } = applyKeepLatestNPolicy([], 2);
    expect(toDelete).toHaveLength(0);
    expect(toRetain).toHaveLength(0);
  });
});

describe("applyRetentionPolicies (combined)", () => {
  test("applies only maxAgeDays when specified alone", () => {
    const { toDelete, toRetain } = applyRetentionPolicies(
      ARTIFACTS,
      { maxAgeDays: 30 },
      REFERENCE_DATE
    );
    expect(toDelete.map((a) => a.id).sort()).toEqual(["a1", "a2", "a3", "a4"]);
    expect(toRetain.map((a) => a.id).sort()).toEqual(["a5", "a6"]);
  });

  test("applies only maxTotalSizeBytes when specified alone", () => {
    const { toDelete, toRetain } = applyRetentionPolicies(
      ARTIFACTS,
      { maxTotalSizeBytes: 2097152 },
      REFERENCE_DATE
    );
    expect(toDelete.map((a) => a.id).sort()).toEqual(["a1", "a2", "a4"]);
    expect(toRetain.map((a) => a.id).sort()).toEqual(["a3", "a5", "a6"]);
  });

  test("applies only keepLatestNPerWorkflow when specified alone", () => {
    const { toDelete, toRetain } = applyRetentionPolicies(
      ARTIFACTS,
      { keepLatestNPerWorkflow: 2 },
      REFERENCE_DATE
    );
    expect(toDelete.map((a) => a.id).sort()).toEqual(["a1"]);
    expect(toRetain.map((a) => a.id).sort()).toEqual(["a2", "a3", "a4", "a5", "a6"]);
  });

  test("unions deletions when multiple policies are specified", () => {
    // maxAgeDays=30 deletes: a1, a2, a3, a4
    // keepLatestN=2 deletes: a1
    // Union: a1, a2, a3, a4 → retain a5, a6
    const { toDelete, toRetain } = applyRetentionPolicies(
      ARTIFACTS,
      { maxAgeDays: 30, keepLatestNPerWorkflow: 2 },
      REFERENCE_DATE
    );
    expect(toDelete.map((a) => a.id).sort()).toEqual(["a1", "a2", "a3", "a4"]);
    expect(toRetain.map((a) => a.id).sort()).toEqual(["a5", "a6"]);
  });

  test("throws error when no policy is specified", () => {
    expect(() =>
      applyRetentionPolicies(ARTIFACTS, {}, REFERENCE_DATE)
    ).toThrow("At least one retention policy must be specified");
  });
});
