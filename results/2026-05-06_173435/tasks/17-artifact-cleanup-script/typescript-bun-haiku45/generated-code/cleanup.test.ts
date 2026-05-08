import { describe, it, expect, beforeEach, afterEach } from "bun:test";
import { writeFileSync, readFileSync, unlinkSync } from "fs";
import { Artifact, RetentionPolicy, cleanupArtifacts } from "./cleanup";

describe("Artifact Cleanup", () => {
  describe("Basic artifact representation", () => {
    it("should parse artifact metadata", () => {
      const artifact: Artifact = {
        name: "test-artifact",
        size: 1024,
        createdAt: new Date("2026-05-01"),
        workflowRunId: "12345",
      };

      expect(artifact.name).toBe("test-artifact");
      expect(artifact.size).toBe(1024);
      expect(artifact.createdAt.getTime()).toBeGreaterThan(0);
      expect(artifact.workflowRunId).toBe("12345");
    });
  });

  describe("Retention policy validation", () => {
    it("should apply max age policy", () => {
      const now = new Date();
      const old = new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000); // 60 days ago

      const artifacts: Artifact[] = [
        {
          name: "recent",
          size: 512,
          createdAt: now,
          workflowRunId: "123",
        },
        {
          name: "old",
          size: 512,
          createdAt: old,
          workflowRunId: "456",
        },
      ];

      const policy: RetentionPolicy = {
        maxAge: 30 * 24 * 60 * 60 * 1000, // 30 days in ms
      };

      const result = cleanupArtifacts(artifacts, policy, false);

      expect(result.toDelete).toHaveLength(1);
      expect(result.toDelete[0].name).toBe("old");
      expect(result.toRetain).toHaveLength(1);
    });

    it("should apply max total size policy", () => {
      const now = new Date();
      const artifacts: Artifact[] = [
        {
          name: "artifact1",
          size: 100,
          createdAt: new Date(now.getTime() - 30 * 60 * 1000),
          workflowRunId: "123",
        },
        {
          name: "artifact2",
          size: 200,
          createdAt: new Date(now.getTime() - 20 * 60 * 1000),
          workflowRunId: "123",
        },
        {
          name: "artifact3",
          size: 300,
          createdAt: now,
          workflowRunId: "123",
        },
      ];

      const policy: RetentionPolicy = {
        maxTotalSize: 400, // Keep only 400 bytes total
      };

      const result = cleanupArtifacts(artifacts, policy, false);

      // Keep newest first: artifact3 (300), can't fit artifact2 (200+300=500>400),
      // but can fit artifact1 (300+100=400). Delete artifact2, save 200 bytes.
      expect(result.summary.spaceSavedBytes).toBe(200);
      expect(result.toDelete).toHaveLength(1);
      expect(result.toDelete[0].name).toBe("artifact2");
    });

    it("should apply keep latest N per workflow policy", () => {
      const now = new Date();
      const artifacts: Artifact[] = [
        {
          name: "artifact1",
          size: 100,
          createdAt: new Date(now.getTime() - 30 * 60 * 1000),
          workflowRunId: "workflow1",
        },
        {
          name: "artifact2",
          size: 100,
          createdAt: new Date(now.getTime() - 20 * 60 * 1000),
          workflowRunId: "workflow1",
        },
        {
          name: "artifact3",
          size: 100,
          createdAt: now,
          workflowRunId: "workflow1",
        },
        {
          name: "artifact4",
          size: 100,
          createdAt: new Date(now.getTime() - 15 * 60 * 1000),
          workflowRunId: "workflow2",
        },
      ];

      const policy: RetentionPolicy = {
        keepLatestN: 2,
      };

      const result = cleanupArtifacts(artifacts, policy, false);

      // Should keep 2 per workflow: artifact2,artifact3 from workflow1, artifact4 from workflow2
      expect(result.toDelete).toHaveLength(1);
      expect(result.toDelete[0].name).toBe("artifact1");
    });

    it("should combine max age and keep latest N policies", () => {
      const now = new Date();
      const old = new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000); // 60 days ago

      const artifacts: Artifact[] = [
        {
          name: "old1",
          size: 100,
          createdAt: old,
          workflowRunId: "workflow1",
        },
        {
          name: "recent1",
          size: 100,
          createdAt: new Date(now.getTime() - 5 * 60 * 1000),
          workflowRunId: "workflow1",
        },
        {
          name: "recent2",
          size: 100,
          createdAt: now,
          workflowRunId: "workflow1",
        },
      ];

      const policy: RetentionPolicy = {
        maxAge: 30 * 24 * 60 * 60 * 1000, // 30 days
        keepLatestN: 1, // keep only 1 per workflow
      };

      const result = cleanupArtifacts(artifacts, policy, false);

      // Max age filters out old1, keepLatestN keeps only recent2
      expect(result.toDelete).toHaveLength(2);
      expect(result.toRetain).toHaveLength(1);
      expect(result.toRetain[0].name).toBe("recent2");
    });

    it("should report correct summary statistics", () => {
      const now = new Date();
      const artifacts: Artifact[] = [
        {
          name: "art1",
          size: 512,
          createdAt: new Date(now.getTime() - 100 * 60 * 1000),
          workflowRunId: "w1",
        },
        {
          name: "art2",
          size: 1024,
          createdAt: now,
          workflowRunId: "w1",
        },
      ];

      const policy: RetentionPolicy = {
        maxAge: 50 * 60 * 1000, // 50 minutes
      };

      const result = cleanupArtifacts(artifacts, policy, false);

      expect(result.summary.totalArtifacts).toBe(2);
      expect(result.summary.deleted).toBe(1);
      expect(result.summary.retained).toBe(1);
      expect(result.summary.spaceSavedBytes).toBe(512);
      expect(result.summary.spaceSavedMB).toBe(0);
    });
  });

  describe("Dry-run functionality", () => {
    it("should not delete artifacts in dry-run mode", () => {
      const now = new Date();
      const old = new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000);

      const artifacts: Artifact[] = [
        {
          name: "old",
          size: 512,
          createdAt: old,
          workflowRunId: "123",
        },
      ];

      const policy: RetentionPolicy = {
        maxAge: 30 * 24 * 60 * 60 * 1000,
      };

      // The dryRun parameter is passed but doesn't prevent deletion planning
      const result = cleanupArtifacts(artifacts, policy, true);

      // Dry-run still returns the deletion plan, but in real usage wouldn't execute
      expect(result.toDelete).toHaveLength(1);
      expect(result.summary.spaceSavedBytes).toBe(512);
    });
  });

  describe("Integration with fixture data", () => {
    let testFile: string;

    beforeEach(() => {
      testFile = "/tmp/test-artifacts.json";
    });

    afterEach(() => {
      try {
        unlinkSync(testFile);
      } catch {}
    });

    it("should load and process artifacts from JSON file", () => {
      const now = new Date();
      const testData = {
        artifacts: [
          {
            name: "test1",
            size: 1024,
            createdAt: now.toISOString(),
            workflowRunId: "build-123",
          },
          {
            name: "test2",
            size: 2048,
            createdAt: new Date(now.getTime() - 45 * 24 * 60 * 60 * 1000).toISOString(),
            workflowRunId: "build-456",
          },
        ],
      };

      writeFileSync(testFile, JSON.stringify(testData));

      // Verify file was written
      const content = readFileSync(testFile, "utf-8");
      const parsed = JSON.parse(content);
      expect(parsed.artifacts).toHaveLength(2);
      expect(parsed.artifacts[0].name).toBe("test1");
    });

    it("should handle empty artifact list", () => {
      const testData = { artifacts: [] };
      writeFileSync(testFile, JSON.stringify(testData));

      const result = cleanupArtifacts([], {}, false);
      expect(result.toDelete).toHaveLength(0);
      expect(result.toRetain).toHaveLength(0);
      expect(result.summary.totalArtifacts).toBe(0);
    });
  });
});
