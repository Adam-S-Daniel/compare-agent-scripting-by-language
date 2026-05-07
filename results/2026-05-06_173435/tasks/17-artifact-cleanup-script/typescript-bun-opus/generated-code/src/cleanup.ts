import type { Artifact, RetentionPolicy, DeletionPlan, DeletionPlanEntry } from "./types";

export function generateDeletionPlan(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  options: { dryRun: boolean; now?: Date } = { dryRun: true }
): DeletionPlan {
  if (!artifacts || artifacts.length === 0) {
    return {
      toDelete: [],
      toRetain: [],
      summary: { totalSpaceReclaimedBytes: 0, artifactsRetained: 0, artifactsDeleted: 0 },
      dryRun: options.dryRun,
    };
  }

  const now = options.now ?? new Date();
  const markedForDeletion = new Map<string, string>();

  // Policy 1: max age — delete artifacts older than maxAgeDays
  if (policy.maxAgeDays !== undefined) {
    const cutoff = new Date(now.getTime() - policy.maxAgeDays * 24 * 60 * 60 * 1000);
    for (const artifact of artifacts) {
      if (artifact.createdAt < cutoff) {
        markedForDeletion.set(
          artifactKey(artifact),
          `exceeded max age of ${policy.maxAgeDays} days`
        );
      }
    }
  }

  // Policy 2: keep-latest-N per workflow — keep only the N most recent per workflow run ID
  if (policy.keepLatestNPerWorkflow !== undefined) {
    const byWorkflow = new Map<string, Artifact[]>();
    for (const artifact of artifacts) {
      const group = byWorkflow.get(artifact.workflowRunId) ?? [];
      group.push(artifact);
      byWorkflow.set(artifact.workflowRunId, group);
    }

    for (const [, group] of byWorkflow) {
      const sorted = [...group].sort(
        (a, b) => b.createdAt.getTime() - a.createdAt.getTime()
      );
      const toRemove = sorted.slice(policy.keepLatestNPerWorkflow);
      for (const artifact of toRemove) {
        markedForDeletion.set(
          artifactKey(artifact),
          `exceeds keep-latest-${policy.keepLatestNPerWorkflow} per workflow`
        );
      }
    }
  }

  // Policy 3: max total size — after other policies, if retained artifacts exceed budget,
  // delete oldest first until under budget
  if (policy.maxTotalSizeBytes !== undefined) {
    const retained = artifacts.filter((a) => !markedForDeletion.has(artifactKey(a)));
    const sortedByAge = [...retained].sort(
      (a, b) => a.createdAt.getTime() - b.createdAt.getTime()
    );

    let totalSize = sortedByAge.reduce((sum, a) => sum + a.sizeBytes, 0);

    for (const artifact of sortedByAge) {
      if (totalSize <= policy.maxTotalSizeBytes) break;
      markedForDeletion.set(
        artifactKey(artifact),
        `total size exceeds budget of ${policy.maxTotalSizeBytes} bytes`
      );
      totalSize -= artifact.sizeBytes;
    }
  }

  const toDelete: DeletionPlanEntry[] = [];
  const toRetain: Artifact[] = [];

  for (const artifact of artifacts) {
    const reason = markedForDeletion.get(artifactKey(artifact));
    if (reason) {
      toDelete.push({ artifact, reason });
    } else {
      toRetain.push(artifact);
    }
  }

  const totalSpaceReclaimedBytes = toDelete.reduce(
    (sum, entry) => sum + entry.artifact.sizeBytes,
    0
  );

  return {
    toDelete,
    toRetain,
    summary: {
      totalSpaceReclaimedBytes,
      artifactsRetained: toRetain.length,
      artifactsDeleted: toDelete.length,
    },
    dryRun: options.dryRun,
  };
}

function artifactKey(artifact: Artifact): string {
  return `${artifact.name}::${artifact.workflowRunId}::${artifact.createdAt.toISOString()}`;
}

export function formatPlan(plan: DeletionPlan): string {
  const lines: string[] = [];

  lines.push(`=== Artifact Cleanup ${plan.dryRun ? "(DRY RUN)" : "(LIVE)"} ===`);
  lines.push("");
  lines.push("--- Artifacts to DELETE ---");

  if (plan.toDelete.length === 0) {
    lines.push("  (none)");
  } else {
    for (const entry of plan.toDelete) {
      lines.push(
        `  - ${entry.artifact.name} (${formatBytes(entry.artifact.sizeBytes)}, workflow: ${entry.artifact.workflowRunId}) — ${entry.reason}`
      );
    }
  }

  lines.push("");
  lines.push("--- Artifacts to RETAIN ---");

  if (plan.toRetain.length === 0) {
    lines.push("  (none)");
  } else {
    for (const artifact of plan.toRetain) {
      lines.push(
        `  - ${artifact.name} (${formatBytes(artifact.sizeBytes)}, workflow: ${artifact.workflowRunId})`
      );
    }
  }

  lines.push("");
  lines.push("--- Summary ---");
  lines.push(`  Artifacts deleted: ${plan.summary.artifactsDeleted}`);
  lines.push(`  Artifacts retained: ${plan.summary.artifactsRetained}`);
  lines.push(`  Space reclaimed: ${formatBytes(plan.summary.totalSpaceReclaimedBytes)}`);

  return lines.join("\n");
}

function formatBytes(bytes: number): string {
  if (bytes === 0) return "0 B";
  const units = ["B", "KB", "MB", "GB"];
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  const value = bytes / Math.pow(1024, i);
  return `${value.toFixed(1)} ${units[i]}`;
}
