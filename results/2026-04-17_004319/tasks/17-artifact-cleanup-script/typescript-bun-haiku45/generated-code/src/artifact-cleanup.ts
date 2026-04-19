// Artifact type definition
export interface Artifact {
  name: string;
  size: number; // in bytes
  createdAt: Date;
  workflowRunId: string;
}

// Retention policy configuration
export interface RetentionPolicy {
  maxAgeDays: number;
  maxTotalSizeMB: number;
  keepLatestNPerWorkflow: number;
}

// Deletion plan output
export interface DeletionPlan {
  toDelete: Artifact[];
  toRetain: Artifact[];
  spaceSavedMB: number;
  summary: string;
  dryRun: boolean;
}

// Parse raw artifact data into typed Artifacts
export function parseArtifacts(
  rawArtifacts: Array<{
    name: string;
    size: number;
    createdAt: string;
    workflowRunId: string;
  }>
): Artifact[] {
  return rawArtifacts.map((raw) => ({
    name: raw.name,
    size: raw.size,
    createdAt: new Date(raw.createdAt),
    workflowRunId: raw.workflowRunId,
  }));
}

// Apply retention policies to determine which artifacts to delete
export function applyRetentionPolicies(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  now: Date = new Date()
): Artifact[] {
  const toDelete: Artifact[] = [];
  const maxAgeMs = policy.maxAgeDays * 24 * 60 * 60 * 1000;

  // Rule 1: Delete artifacts older than maxAgeDays
  for (const artifact of artifacts) {
    const ageMs = now.getTime() - artifact.createdAt.getTime();
    if (ageMs > maxAgeMs) {
      toDelete.push(artifact);
    }
  }

  // Rule 2: Keep only latest N per workflow (excluding already marked for deletion)
  const remaining = artifacts.filter((a) => !toDelete.includes(a));
  const byWorkflow = new Map<string, Artifact[]>();

  for (const artifact of remaining) {
    if (!byWorkflow.has(artifact.workflowRunId)) {
      byWorkflow.set(artifact.workflowRunId, []);
    }
    byWorkflow.get(artifact.workflowRunId)!.push(artifact);
  }

  for (const workflowArtifacts of byWorkflow.values()) {
    workflowArtifacts.sort(
      (a, b) => b.createdAt.getTime() - a.createdAt.getTime()
    );
    for (let i = policy.keepLatestNPerWorkflow; i < workflowArtifacts.length; i++) {
      if (!toDelete.includes(workflowArtifacts[i])) {
        toDelete.push(workflowArtifacts[i]);
      }
    }
  }

  // Rule 3: If total size exceeds maxTotalSizeMB, delete oldest artifacts
  let totalSizeBytes = artifacts.reduce((sum, a) => sum + a.size, 0);
  const maxSizeBytes = policy.maxTotalSizeMB * 1024 * 1024;

  if (totalSizeBytes > maxSizeBytes) {
    const notMarkedForDeletion = artifacts
      .filter((a) => !toDelete.includes(a))
      .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());

    for (const artifact of notMarkedForDeletion) {
      if (totalSizeBytes <= maxSizeBytes) break;
      toDelete.push(artifact);
      totalSizeBytes -= artifact.size;
    }
  }

  return toDelete;
}

// Generate a deletion plan with summary
export function generateDeletionPlan(
  allArtifacts: Artifact[],
  toDelete: Artifact[],
  dryRun: boolean
): DeletionPlan {
  const toRetain = allArtifacts.filter((a) => !toDelete.includes(a));
  const spaceSavedBytes = toDelete.reduce((sum, a) => sum + a.size, 0);
  const spaceSavedMB = spaceSavedBytes / (1024 * 1024);

  const summary = `
Deletion Plan Summary:
- Total artifacts: ${allArtifacts.length}
- Artifacts to delete: ${toDelete.length}
- Artifacts to retain: ${toRetain.length}
- Space reclaimed: ${spaceSavedMB.toFixed(2)} MB
- Mode: ${dryRun ? "DRY-RUN (no changes)" : "EXECUTE"}
  `.trim();

  return {
    toDelete,
    toRetain,
    spaceSavedMB,
    summary,
    dryRun,
  };
}
