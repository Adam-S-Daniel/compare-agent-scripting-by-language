// cleanup.ts — Core artifact cleanup logic
// Applies retention policies in a deterministic order:
//   1. Max age (remove expired artifacts)
//   2. Keep-latest-N per workflow (trim per-workflow excess)
//   3. Max total size (evict oldest until under budget)

import type {
  Artifact,
  RetentionPolicy,
  DeletionPlan,
  CleanupOptions,
} from "./types";

/**
 * Generates a deletion plan for artifacts based on retention policies.
 * Policies are applied sequentially so the result is deterministic.
 */
export function generateDeletionPlan(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  options: CleanupOptions = {}
): DeletionPlan {
  const { dryRun = false, referenceDate = new Date() } = options;

  // --- Input validation ---
  if (policy.maxAgeDays !== undefined && policy.maxAgeDays < 0) {
    throw new Error("maxAgeDays must be non-negative");
  }
  if (policy.maxTotalSizeBytes !== undefined && policy.maxTotalSizeBytes < 0) {
    throw new Error("maxTotalSizeBytes must be non-negative");
  }
  if (
    policy.keepLatestNPerWorkflow !== undefined &&
    policy.keepLatestNPerWorkflow < 0
  ) {
    throw new Error("keepLatestNPerWorkflow must be non-negative");
  }

  const toDelete: Artifact[] = [];
  let remaining = [...artifacts];

  // Step 1: Remove artifacts older than maxAgeDays
  if (policy.maxAgeDays !== undefined) {
    const cutoffMs = policy.maxAgeDays * 24 * 60 * 60 * 1000;
    const cutoffDate = new Date(referenceDate.getTime() - cutoffMs);

    const expired: Artifact[] = [];
    const kept: Artifact[] = [];
    for (const a of remaining) {
      if (new Date(a.createdAt) < cutoffDate) {
        expired.push(a);
      } else {
        kept.push(a);
      }
    }
    toDelete.push(...expired);
    remaining = kept;
  }

  // Step 2: Keep only the N most recent artifacts per workflow
  if (policy.keepLatestNPerWorkflow !== undefined) {
    const n = policy.keepLatestNPerWorkflow;
    const groups = new Map<string, Artifact[]>();
    for (const a of remaining) {
      const group = groups.get(a.workflowRunId) ?? [];
      group.push(a);
      groups.set(a.workflowRunId, group);
    }

    const kept: Artifact[] = [];
    for (const [, group] of groups) {
      // Sort newest-first so slice(0, n) keeps the most recent
      group.sort(
        (a, b) =>
          new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
      );
      kept.push(...group.slice(0, n));
      toDelete.push(...group.slice(n));
    }
    remaining = kept;
  }

  // Step 3: Evict oldest artifacts until total size is within budget
  if (policy.maxTotalSizeBytes !== undefined) {
    let totalSize = remaining.reduce((sum, a) => sum + a.sizeBytes, 0);

    if (totalSize > policy.maxTotalSizeBytes) {
      // Sort oldest-first so we remove the oldest first
      remaining.sort(
        (a, b) =>
          new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()
      );

      const kept: Artifact[] = [];
      for (const a of remaining) {
        if (totalSize > policy.maxTotalSizeBytes) {
          toDelete.push(a);
          totalSize -= a.sizeBytes;
        } else {
          kept.push(a);
        }
      }
      remaining = kept;
    }
  }

  // Sort both lists by creation date for consistent, predictable output
  const byDateAsc = (a: Artifact, b: Artifact) =>
    new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime();
  toDelete.sort(byDateAsc);
  remaining.sort(byDateAsc);

  const totalSpaceReclaimedBytes = toDelete.reduce(
    (sum, a) => sum + a.sizeBytes,
    0
  );

  return {
    toDelete,
    toRetain: remaining,
    summary: {
      totalSpaceReclaimedBytes,
      artifactsRetained: remaining.length,
      artifactsDeleted: toDelete.length,
      dryRun,
    },
  };
}

/** Formats a deletion plan as a human-readable string */
export function formatDeletionPlan(plan: DeletionPlan): string {
  const lines: string[] = [];
  const { summary } = plan;

  lines.push("=== ARTIFACT CLEANUP PLAN ===");
  lines.push(`Mode: ${summary.dryRun ? "DRY-RUN" : "EXECUTE"}`);
  lines.push(`Artifacts to delete: ${summary.artifactsDeleted}`);
  lines.push(`Artifacts to retain: ${summary.artifactsRetained}`);
  lines.push(`Space reclaimed: ${summary.totalSpaceReclaimedBytes} bytes`);
  lines.push("");

  for (const a of plan.toDelete) {
    lines.push(
      `DELETE: ${a.name} | ${a.sizeBytes} bytes | ${a.createdAt} | ${a.workflowRunId}`
    );
  }
  for (const a of plan.toRetain) {
    lines.push(
      `RETAIN: ${a.name} | ${a.sizeBytes} bytes | ${a.createdAt} | ${a.workflowRunId}`
    );
  }

  lines.push("=== END PLAN ===");
  return lines.join("\n");
}
