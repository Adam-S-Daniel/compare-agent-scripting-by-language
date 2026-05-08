// Core artifact cleanup logic: applies retention policies to produce a deletion plan.
// Policies are applied in order: maxAgeDays → keepLatestNPerWorkflow → maxTotalSizeBytes.
// An artifact deleted by an earlier policy is never reconsidered by later ones.

import type { Artifact, RetentionPolicy, DeletionPlan, CleanupOptions } from "./types";

// Marks artifacts older than maxAgeDays for deletion.
function applyMaxAge(
  retained: Artifact[],
  toDelete: Artifact[],
  maxAgeDays: number,
  now: Date
): { retained: Artifact[]; toDelete: Artifact[] } {
  const cutoffMs = maxAgeDays * 24 * 60 * 60 * 1000;
  const newRetained: Artifact[] = [];
  const newToDelete = [...toDelete];

  for (const artifact of retained) {
    const ageMs = now.getTime() - new Date(artifact.createdAt).getTime();
    if (ageMs > cutoffMs) {
      newToDelete.push(artifact);
    } else {
      newRetained.push(artifact);
    }
  }

  return { retained: newRetained, toDelete: newToDelete };
}

// Within each workflowRunId group, keeps only the N most recently created artifacts.
function applyKeepLatestN(
  retained: Artifact[],
  toDelete: Artifact[],
  keepLatestN: number
): { retained: Artifact[]; toDelete: Artifact[] } {
  const groups = new Map<string, Artifact[]>();
  for (const artifact of retained) {
    const group = groups.get(artifact.workflowRunId) ?? [];
    group.push(artifact);
    groups.set(artifact.workflowRunId, group);
  }

  const newRetained: Artifact[] = [];
  const newToDelete = [...toDelete];

  for (const [, group] of groups) {
    // Sort newest-first so slice(0, n) keeps the n most recent
    const sorted = [...group].sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );
    newRetained.push(...sorted.slice(0, keepLatestN));
    newToDelete.push(...sorted.slice(keepLatestN));
  }

  return { retained: newRetained, toDelete: newToDelete };
}

// Deletes oldest artifacts (by createdAt) until total retained size is under the limit.
function applyMaxTotalSize(
  retained: Artifact[],
  toDelete: Artifact[],
  maxTotalSizeBytes: number
): { retained: Artifact[]; toDelete: Artifact[] } {
  const totalSize = retained.reduce((sum, a) => sum + a.size, 0);
  if (totalSize <= maxTotalSizeBytes) {
    return { retained, toDelete };
  }

  // Sort oldest-first so we delete the oldest artifacts first
  const sorted = [...retained].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()
  );

  let currentSize = totalSize;
  const newRetained: Artifact[] = [];
  const newToDelete = [...toDelete];

  for (const artifact of sorted) {
    if (currentSize > maxTotalSizeBytes) {
      newToDelete.push(artifact);
      currentSize -= artifact.size;
    } else {
      newRetained.push(artifact);
    }
  }

  return { retained: newRetained, toDelete: newToDelete };
}

export function applyRetentionPolicies(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  options: CleanupOptions = { dryRun: false }
): DeletionPlan {
  const now = options.now ?? new Date();
  let retained = [...artifacts];
  let toDelete: Artifact[] = [];

  if (policy.maxAgeDays !== undefined) {
    ({ retained, toDelete } = applyMaxAge(retained, toDelete, policy.maxAgeDays, now));
  }

  if (policy.keepLatestNPerWorkflow !== undefined) {
    ({ retained, toDelete } = applyKeepLatestN(retained, toDelete, policy.keepLatestNPerWorkflow));
  }

  if (policy.maxTotalSizeBytes !== undefined) {
    ({ retained, toDelete } = applyMaxTotalSize(retained, toDelete, policy.maxTotalSizeBytes));
  }

  const spaceReclaimedBytes = toDelete.reduce((sum, a) => sum + a.size, 0);

  return {
    toDelete,
    toRetain: retained,
    summary: {
      artifactsDeleted: toDelete.length,
      artifactsRetained: retained.length,
      spaceReclaimedBytes,
      dryRun: options.dryRun,
    },
  };
}

// Formats a DeletionPlan as a human-readable string for console output.
export function formatDeletionPlan(plan: DeletionPlan, label?: string): string {
  const { summary } = plan;
  const mb = (bytes: number): string => (bytes / 1024 / 1024).toFixed(2);
  const lines: string[] = [];

  if (label) lines.push(`=== Cleanup Plan: ${label} ===`);
  else lines.push("=== Artifact Cleanup Plan ===");

  lines.push(`Dry Run: ${summary.dryRun}`);
  lines.push(`Artifacts to delete: ${summary.artifactsDeleted}`);
  lines.push(`Artifacts to retain: ${summary.artifactsRetained}`);
  lines.push(`Space to reclaim: ${mb(summary.spaceReclaimedBytes)} MB (${summary.spaceReclaimedBytes} bytes)`);
  lines.push("");
  lines.push("Artifacts marked for deletion:");

  if (plan.toDelete.length === 0) {
    lines.push("  (none)");
  } else {
    for (const a of plan.toDelete) {
      lines.push(`  - ${a.name} (${mb(a.size)} MB, created ${a.createdAt}, run ${a.workflowRunId})`);
    }
  }

  lines.push("");
  lines.push("Artifacts to retain:");

  if (plan.toRetain.length === 0) {
    lines.push("  (none)");
  } else {
    for (const a of plan.toRetain) {
      lines.push(`  + ${a.name} (${mb(a.size)} MB, created ${a.createdAt}, run ${a.workflowRunId})`);
    }
  }

  lines.push("");
  lines.push("=== End of Cleanup Plan ===");

  return lines.join("\n");
}
