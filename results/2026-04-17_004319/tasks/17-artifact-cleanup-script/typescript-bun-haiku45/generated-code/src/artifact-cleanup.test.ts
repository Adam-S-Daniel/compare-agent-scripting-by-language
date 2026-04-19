import { describe, it, expect } from "bun:test";
import {
  parseArtifacts,
  applyRetentionPolicies,
  generateDeletionPlan,
  type Artifact,
  type DeletionPlan,
} from "./artifact-cleanup";

describe("artifact-cleanup", () => {
  describe("parseArtifacts", () => {
    it("should parse a list of artifact objects into Artifact type", () => {
      const rawArtifacts = [
        {
          name: "build-output-1",
          size: 1024,
          createdAt: "2024-01-01",
          workflowRunId: "run-1",
        },
        {
          name: "build-output-2",
          size: 2048,
          createdAt: "2024-01-02",
          workflowRunId: "run-1",
        },
      ];

      const parsed = parseArtifacts(rawArtifacts);

      expect(parsed).toHaveLength(2);
      expect(parsed[0].name).toBe("build-output-1");
      expect(parsed[0].size).toBe(1024);
    });
  });

  describe("applyRetentionPolicies", () => {
    it("should filter artifacts older than maxAgeDays", () => {
      const now = new Date("2026-04-19");
      const artifacts: Artifact[] = [
        {
          name: "old-artifact",
          size: 1024,
          createdAt: new Date("2026-01-01"), // ~110 days old
          workflowRunId: "run-1",
        },
        {
          name: "new-artifact",
          size: 1024,
          createdAt: new Date("2026-04-10"), // 9 days old
          workflowRunId: "run-2",
        },
      ];

      const toDelete = applyRetentionPolicies(
        artifacts,
        {
          maxAgeDays: 30,
          maxTotalSizeMB: 1000,
          keepLatestNPerWorkflow: 10,
        },
        now
      );

      expect(toDelete).toHaveLength(1);
      expect(toDelete[0].name).toBe("old-artifact");
    });
  });

  describe("generateDeletionPlan", () => {
    it("should create a plan with summary of deleted vs retained artifacts", () => {
      const artifacts: Artifact[] = [
        {
          name: "artifact-1",
          size: 1024,
          createdAt: new Date("2024-01-01"),
          workflowRunId: "run-1",
        },
      ];

      const toDelete: Artifact[] = [artifacts[0]];

      const plan = generateDeletionPlan(artifacts, toDelete, false);

      expect(plan.toDelete).toHaveLength(1);
      expect(plan.toRetain).toHaveLength(0);
      expect(plan.spaceSavedMB).toBeCloseTo(0.001, 3);
      expect(plan.summary).toContain("Artifacts to delete: 1");
      expect(plan.summary).toContain("EXECUTE");
    });

    it("should mark plan as dry-run when dryRun=true", () => {
      const artifacts: Artifact[] = [];
      const plan = generateDeletionPlan(artifacts, [], true);

      expect(plan.dryRun).toBe(true);
      expect(plan.summary).toContain("DRY-RUN");
    });
  });

  describe("applyRetentionPolicies - maxTotalSizeMB", () => {
    it("should delete oldest artifacts when total size exceeds limit", () => {
      const now = new Date("2026-04-19");
      const artifacts: Artifact[] = [
        {
          name: "artifact-1",
          size: 1024 * 1024 * 2, // 2MB
          createdAt: new Date("2026-04-18"),
          workflowRunId: "run-1",
        },
        {
          name: "artifact-2",
          size: 1024 * 1024 * 2, // 2MB
          createdAt: new Date("2026-04-19"),
          workflowRunId: "run-1",
        },
      ];

      const toDelete = applyRetentionPolicies(
        artifacts,
        {
          maxAgeDays: 365,
          maxTotalSizeMB: 3, // Only 3MB allowed, need to delete one
          keepLatestNPerWorkflow: 10,
        },
        now
      );

      expect(toDelete).toHaveLength(1);
      expect(toDelete[0].name).toBe("artifact-1");
    });
  });

  describe("applyRetentionPolicies - keepLatestNPerWorkflow", () => {
    it("should keep only N latest artifacts per workflow", () => {
      const now = new Date("2026-04-19");
      const artifacts: Artifact[] = [
        {
          name: "artifact-1",
          size: 1024,
          createdAt: new Date("2026-04-01"),
          workflowRunId: "run-1",
        },
        {
          name: "artifact-2",
          size: 1024,
          createdAt: new Date("2026-04-10"),
          workflowRunId: "run-1",
        },
        {
          name: "artifact-3",
          size: 1024,
          createdAt: new Date("2026-04-19"),
          workflowRunId: "run-1",
        },
      ];

      const toDelete = applyRetentionPolicies(
        artifacts,
        {
          maxAgeDays: 365,
          maxTotalSizeMB: 1000,
          keepLatestNPerWorkflow: 1, // Keep only the latest
        },
        now
      );

      expect(toDelete).toHaveLength(2);
      expect(toDelete.map((a) => a.name)).toContain("artifact-1");
      expect(toDelete.map((a) => a.name)).toContain("artifact-2");
    });
  });
});
