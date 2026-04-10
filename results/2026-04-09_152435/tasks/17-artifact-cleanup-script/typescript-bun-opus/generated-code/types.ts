// types.ts — Type definitions for the artifact cleanup script

/** Represents a GitHub Actions artifact with metadata */
export interface Artifact {
  name: string;
  sizeBytes: number;
  createdAt: string; // ISO 8601 date string
  workflowRunId: string;
}

/** Retention policy configuration */
export interface RetentionPolicy {
  maxAgeDays?: number;
  maxTotalSizeBytes?: number;
  keepLatestNPerWorkflow?: number;
}

/** Summary statistics for the deletion plan */
export interface DeletionSummary {
  totalSpaceReclaimedBytes: number;
  artifactsRetained: number;
  artifactsDeleted: number;
  dryRun: boolean;
}

/** The complete deletion plan with lists and summary */
export interface DeletionPlan {
  toDelete: Artifact[];
  toRetain: Artifact[];
  summary: DeletionSummary;
}

/** Options controlling plan generation */
export interface CleanupOptions {
  dryRun?: boolean;
  referenceDate?: Date; // Allows deterministic testing with a fixed "now"
}
