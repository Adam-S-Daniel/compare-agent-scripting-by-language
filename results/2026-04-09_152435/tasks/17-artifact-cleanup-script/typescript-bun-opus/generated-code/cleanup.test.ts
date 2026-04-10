// cleanup.test.ts — TDD tests for artifact cleanup logic
// Written BEFORE the implementation (red/green/refactor cycle).
// Each test documents the exact expected behavior with precise values.

import { describe, test, expect } from "bun:test";
import { generateDeletionPlan } from "./cleanup";
import { TEST_ARTIFACTS, REFERENCE_DATE } from "./fixtures";
import type { Artifact } from "./types";

const opts = { referenceDate: REFERENCE_DATE };

describe("generateDeletionPlan", () => {
  // --- Max Age Policy ---
  describe("max age policy", () => {
    test("deletes artifacts older than maxAgeDays", () => {
      // With maxAgeDays=30 and ref date 2026-04-10, cutoff is 2026-03-11.
      // Expired: deploy-bundle-1 (54d), build-artifact-1 (40d), test-results-1 (31d)
      const plan = generateDeletionPlan(
        TEST_ARTIFACTS,
        { maxAgeDays: 30 },
        opts
      );

      expect(plan.summary.artifactsDeleted).toBe(3);
      expect(plan.summary.artifactsRetained).toBe(4);
      expect(plan.summary.totalSpaceReclaimedBytes).toBe(6_500_000);
      expect(plan.toDelete.map((a) => a.name).sort()).toEqual([
        "build-artifact-1",
        "deploy-bundle-1",
        "test-results-1",
      ]);
    });

    test("retains all when no artifacts exceed max age", () => {
      const plan = generateDeletionPlan(
        TEST_ARTIFACTS,
        { maxAgeDays: 365 },
        opts
      );
      expect(plan.summary.artifactsDeleted).toBe(0);
      expect(plan.summary.artifactsRetained).toBe(7);
      expect(plan.summary.totalSpaceReclaimedBytes).toBe(0);
    });
  });

  // --- Keep Latest N Per Workflow ---
  describe("keep-latest-N policy", () => {
    test("keeps only N most recent artifacts per workflow", () => {
      // keepLatestNPerWorkflow=1:
      //   workflow-a: keep build-artifact-3, delete build-artifact-1 & 2
      //   workflow-b: keep test-results-2, delete test-results-1
      //   workflow-c: keep deploy-bundle-2, delete deploy-bundle-1
      const plan = generateDeletionPlan(
        TEST_ARTIFACTS,
        { keepLatestNPerWorkflow: 1 },
        opts
      );

      expect(plan.summary.artifactsDeleted).toBe(4);
      expect(plan.summary.artifactsRetained).toBe(3);
      expect(plan.summary.totalSpaceReclaimedBytes).toBe(8_500_000);
      expect(plan.toDelete.map((a) => a.name).sort()).toEqual([
        "build-artifact-1",
        "build-artifact-2",
        "deploy-bundle-1",
        "test-results-1",
      ]);
      expect(plan.toRetain.map((a) => a.name).sort()).toEqual([
        "build-artifact-3",
        "deploy-bundle-2",
        "test-results-2",
      ]);
    });

    test("keeps 2 per workflow", () => {
      // workflow-a has 3 -> delete oldest 1 (build-artifact-1)
      // workflow-b has 2 -> keep both
      // workflow-c has 2 -> keep both
      const plan = generateDeletionPlan(
        TEST_ARTIFACTS,
        { keepLatestNPerWorkflow: 2 },
        opts
      );

      expect(plan.summary.artifactsDeleted).toBe(1);
      expect(plan.summary.artifactsRetained).toBe(6);
      expect(plan.toDelete[0].name).toBe("build-artifact-1");
    });
  });

  // --- Max Total Size Policy ---
  describe("max total size policy", () => {
    test("removes oldest artifacts until under size limit", () => {
      // Total = 13,750,000. Limit = 10,000,000.
      // Remove oldest: deploy-bundle-1 (5M) -> remaining 8,750,000 < 10M
      const plan = generateDeletionPlan(
        TEST_ARTIFACTS,
        { maxTotalSizeBytes: 10_000_000 },
        opts
      );

      expect(plan.summary.artifactsDeleted).toBe(1);
      expect(plan.summary.artifactsRetained).toBe(6);
      expect(plan.summary.totalSpaceReclaimedBytes).toBe(5_000_000);
      expect(plan.toDelete[0].name).toBe("deploy-bundle-1");
    });

    test("removes multiple artifacts for tight size limit", () => {
      // Limit = 5,000,000. Total = 13,750,000. Need to remove 8,750,000.
      // Remove oldest-first: deploy-bundle-1 (5M), build-artifact-1 (1M),
      // test-results-1 (500K), build-artifact-2 (2M) -> remaining 5,250,000
      // Still over! Remove build-artifact-3 (1.5M) -> remaining 3,750,000
      const plan = generateDeletionPlan(
        TEST_ARTIFACTS,
        { maxTotalSizeBytes: 5_000_000 },
        opts
      );

      expect(plan.summary.artifactsDeleted).toBe(5);
      expect(plan.summary.artifactsRetained).toBe(2);
      expect(plan.summary.totalSpaceReclaimedBytes).toBe(10_000_000);
    });

    test("retains all when already under limit", () => {
      const plan = generateDeletionPlan(
        TEST_ARTIFACTS,
        { maxTotalSizeBytes: 100_000_000 },
        opts
      );
      expect(plan.summary.artifactsDeleted).toBe(0);
      expect(plan.summary.artifactsRetained).toBe(7);
    });
  });

  // --- Combined Policies ---
  describe("combined policies", () => {
    test("applies max-age then keep-latest-N then max-total-size in order", () => {
      // Step 1: maxAgeDays=30 removes deploy-bundle-1, build-artifact-1, test-results-1
      // Step 2: keepLatestN=1 on remaining: removes build-artifact-2
      //   (workflow-a: keep build-artifact-3, workflow-b/c: 1 each already)
      // Step 3: maxTotalSize=8M: remaining=5,250,000 < 8M, no more removals
      const plan = generateDeletionPlan(
        TEST_ARTIFACTS,
        {
          maxAgeDays: 30,
          keepLatestNPerWorkflow: 1,
          maxTotalSizeBytes: 8_000_000,
        },
        opts
      );

      expect(plan.summary.artifactsDeleted).toBe(4);
      expect(plan.summary.artifactsRetained).toBe(3);
      expect(plan.summary.totalSpaceReclaimedBytes).toBe(8_500_000);
      expect(plan.toDelete.map((a) => a.name).sort()).toEqual([
        "build-artifact-1",
        "build-artifact-2",
        "deploy-bundle-1",
        "test-results-1",
      ]);
    });
  });

  // --- Dry-Run Mode ---
  describe("dry-run mode", () => {
    test("marks plan as dry-run without changing deletion logic", () => {
      const plan = generateDeletionPlan(
        TEST_ARTIFACTS,
        { maxAgeDays: 30 },
        { ...opts, dryRun: true }
      );

      expect(plan.summary.dryRun).toBe(true);
      expect(plan.summary.artifactsDeleted).toBe(3);
      expect(plan.summary.artifactsRetained).toBe(4);
      expect(plan.summary.totalSpaceReclaimedBytes).toBe(6_500_000);
    });

    test("defaults to dryRun=false", () => {
      const plan = generateDeletionPlan(TEST_ARTIFACTS, { maxAgeDays: 30 }, opts);
      expect(plan.summary.dryRun).toBe(false);
    });
  });

  // --- Edge Cases ---
  describe("edge cases", () => {
    test("handles empty artifact list", () => {
      const plan = generateDeletionPlan([], { maxAgeDays: 30 }, opts);
      expect(plan.summary.artifactsDeleted).toBe(0);
      expect(plan.summary.artifactsRetained).toBe(0);
      expect(plan.summary.totalSpaceReclaimedBytes).toBe(0);
      expect(plan.toDelete).toEqual([]);
      expect(plan.toRetain).toEqual([]);
    });

    test("retains all when no policies specified", () => {
      const plan = generateDeletionPlan(TEST_ARTIFACTS, {}, opts);
      expect(plan.summary.artifactsDeleted).toBe(0);
      expect(plan.summary.artifactsRetained).toBe(7);
      expect(plan.summary.totalSpaceReclaimedBytes).toBe(0);
    });

    test("throws on negative maxAgeDays", () => {
      expect(() =>
        generateDeletionPlan(TEST_ARTIFACTS, { maxAgeDays: -1 }, opts)
      ).toThrow("maxAgeDays must be non-negative");
    });

    test("throws on negative maxTotalSizeBytes", () => {
      expect(() =>
        generateDeletionPlan(
          TEST_ARTIFACTS,
          { maxTotalSizeBytes: -1 },
          opts
        )
      ).toThrow("maxTotalSizeBytes must be non-negative");
    });

    test("throws on negative keepLatestNPerWorkflow", () => {
      expect(() =>
        generateDeletionPlan(
          TEST_ARTIFACTS,
          { keepLatestNPerWorkflow: -1 },
          opts
        )
      ).toThrow("keepLatestNPerWorkflow must be non-negative");
    });

    test("keepLatestN=0 deletes all artifacts", () => {
      const plan = generateDeletionPlan(
        TEST_ARTIFACTS,
        { keepLatestNPerWorkflow: 0 },
        opts
      );
      expect(plan.summary.artifactsDeleted).toBe(7);
      expect(plan.summary.artifactsRetained).toBe(0);
    });

    test("output lists are sorted by creation date ascending", () => {
      const plan = generateDeletionPlan(
        TEST_ARTIFACTS,
        { maxAgeDays: 30 },
        opts
      );
      // toDelete should be sorted oldest-first
      const deleteDates = plan.toDelete.map((a) => a.createdAt);
      for (let i = 1; i < deleteDates.length; i++) {
        expect(new Date(deleteDates[i]).getTime()).toBeGreaterThanOrEqual(
          new Date(deleteDates[i - 1]).getTime()
        );
      }
      // toRetain should be sorted oldest-first
      const retainDates = plan.toRetain.map((a) => a.createdAt);
      for (let i = 1; i < retainDates.length; i++) {
        expect(new Date(retainDates[i]).getTime()).toBeGreaterThanOrEqual(
          new Date(retainDates[i - 1]).getTime()
        );
      }
    });
  });
});
