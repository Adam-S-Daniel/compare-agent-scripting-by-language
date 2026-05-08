// Core data types for the artifact cleanup system

export interface Artifact {
  name: string;
  size: number; // bytes
  createdAt: string; // ISO 8601 date string
  workflowRunId: string; // used for grouping in keepLatestNPerWorkflow
}

export interface RetentionPolicy {
  maxAgeDays?: number; // delete artifacts older than this many days
  maxTotalSizeBytes?: number; // delete oldest artifacts until total is under this limit
  keepLatestNPerWorkflow?: number; // per workflowRunId group, keep only the N most recent
}

export interface DeletionSummary {
  artifactsDeleted: number;
  artifactsRetained: number;
  spaceReclaimedBytes: number;
  dryRun: boolean;
}

export interface DeletionPlan {
  toDelete: Artifact[];
  toRetain: Artifact[];
  summary: DeletionSummary;
}

export interface CleanupOptions {
  dryRun: boolean;
  now?: Date; // override current time (used in tests for deterministic results)
}
