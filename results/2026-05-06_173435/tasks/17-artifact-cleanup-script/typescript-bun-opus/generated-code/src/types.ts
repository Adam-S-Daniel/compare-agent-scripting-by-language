export interface Artifact {
  name: string;
  sizeBytes: number;
  createdAt: Date;
  workflowRunId: string;
}

export interface RetentionPolicy {
  maxAgeDays?: number;
  maxTotalSizeBytes?: number;
  keepLatestNPerWorkflow?: number;
}

export interface DeletionPlanEntry {
  artifact: Artifact;
  reason: string;
}

export interface DeletionPlan {
  toDelete: DeletionPlanEntry[];
  toRetain: Artifact[];
  summary: {
    totalSpaceReclaimedBytes: number;
    artifactsRetained: number;
    artifactsDeleted: number;
  };
  dryRun: boolean;
}
