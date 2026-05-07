// Artifact cleanup script with retention policies
// Supports: max age, max total size, keep-latest-N per workflow

export interface Artifact {
  name: string;
  size: number;
  createdAt: Date;
  workflowRunId: string;
}

export interface RetentionPolicy {
  maxAge?: number;
  maxTotalSize?: number;
  keepLatestN?: number;
}

export interface CleanupResult {
  toDelete: Artifact[];
  toRetain: Artifact[];
  spaceSaved: number;
  summary: {
    totalArtifacts: number;
    deleted: number;
    retained: number;
    spaceSavedBytes: number;
    spaceSavedMB: number;
  };
}

export function cleanupArtifacts(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  dryRun: boolean
): CleanupResult {
  const now = new Date();
  let candidates = [...artifacts];

  // Apply max age policy
  if (policy.maxAge !== undefined) {
    candidates = candidates.filter((artifact) => {
      const age = now.getTime() - artifact.createdAt.getTime();
      return age <= policy.maxAge!;
    });
  }

  // Apply keep latest N per workflow policy
  if (policy.keepLatestN !== undefined) {
    const grouped = new Map<string, Artifact[]>();
    for (const artifact of candidates) {
      if (!grouped.has(artifact.workflowRunId)) {
        grouped.set(artifact.workflowRunId, []);
      }
      grouped.get(artifact.workflowRunId)!.push(artifact);
    }

    candidates = [];
    for (const [, workflowArtifacts] of grouped) {
      workflowArtifacts.sort(
        (a, b) => b.createdAt.getTime() - a.createdAt.getTime()
      );
      candidates.push(...workflowArtifacts.slice(0, policy.keepLatestN));
    }
  }

  // Apply max total size policy
  if (policy.maxTotalSize !== undefined) {
    candidates.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
    let totalSize = 0;
    const kept: Artifact[] = [];

    for (const artifact of candidates) {
      if (totalSize + artifact.size <= policy.maxTotalSize) {
        kept.push(artifact);
        totalSize += artifact.size;
      }
    }
    candidates = kept;
  }

  const toDelete = artifacts.filter((a) => !candidates.includes(a));
  const spaceSavedBytes = toDelete.reduce((sum, a) => sum + a.size, 0);

  return {
    toDelete,
    toRetain: candidates,
    spaceSaved: spaceSavedBytes,
    summary: {
      totalArtifacts: artifacts.length,
      deleted: toDelete.length,
      retained: candidates.length,
      spaceSavedBytes,
      spaceSavedMB: Math.round(spaceSavedBytes / (1024 * 1024) * 100) / 100,
    },
  };
}
