// Core type definitions for the artifact cleanup script.

export interface Artifact {
  id: string;
  name: string;           // Artifact name (e.g., "build-artifact", "test-results")
  sizeBytes: number;      // Size in bytes
  createdAt: Date;        // Creation timestamp
  workflowRunId: string;  // Workflow run that produced this artifact
}

export interface RetentionPolicy {
  maxAgeDays?: number;              // Delete artifacts older than N days
  maxTotalSizeBytes?: number;       // Delete oldest to keep total under N bytes
  keepLatestNPerWorkflow?: number;  // Keep only N most recent per artifact name
}

export interface DeletionPlan {
  toDelete: Artifact[];
  toRetain: Artifact[];
  summary: {
    totalSpaceReclaimedBytes: number;
    artifactsDeleted: number;
    artifactsRetained: number;
  };
  dryRun: boolean;
}
