// Artifact metadata representing a CI/CD build artifact
export interface Artifact {
  name: string;
  sizeBytes: number;
  createdAt: string; // ISO 8601 date string
  workflowRunId: string;
}

// Retention policy configuration — each field is optional;
// only specified fields are enforced
export interface RetentionPolicy {
  maxAgeDays?: number; // Delete artifacts older than this many days
  maxTotalSizeBytes?: number; // Delete oldest artifacts until total fits this budget
  keepLatestN?: number; // Keep only the N most recent artifacts per workflow
  dryRun?: boolean; // When true, plan but don't "execute" deletions
}

// Input format for the cleanup script (read from JSON file)
export interface CleanupInput {
  artifacts: Artifact[];
  policy: RetentionPolicy;
  referenceDate?: string; // ISO 8601 "now" override for deterministic testing
}

// Why an artifact was selected for deletion
export type DeletionReason = "max_age" | "max_total_size" | "keep_latest_n";

// A single artifact marked for deletion, with the triggering reason
export interface DeletionEntry {
  artifact: Artifact;
  reason: DeletionReason;
}

// The complete deletion plan produced by the cleanup engine
export interface DeletionPlan {
  toDelete: DeletionEntry[];
  toRetain: Artifact[];
  summary: {
    totalArtifacts: number;
    deletedCount: number;
    retainedCount: number;
    spaceReclaimedBytes: number;
    spaceRetainedBytes: number;
  };
  dryRun: boolean;
}
