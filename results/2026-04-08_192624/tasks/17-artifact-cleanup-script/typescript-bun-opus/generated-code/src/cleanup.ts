// Core cleanup engine.
// Applies retention policies in a fixed order:
//   1. max age   — binary per-artifact decision
//   2. keep-latest-N — per-workflow decision
//   3. max total size — budget-based, removes oldest remaining
// Each later step sees what earlier steps already marked for deletion.

import type {
  Artifact,
  RetentionPolicy,
  DeletionPlan,
  DeletionEntry,
  DeletionReason,
} from "./types";

/** Validate policy values up-front so callers get clear errors. */
function validatePolicy(policy: RetentionPolicy): void {
  if (policy.maxAgeDays !== undefined && policy.maxAgeDays < 0) {
    throw new Error("maxAgeDays must be a non-negative number");
  }
  if (policy.maxTotalSizeBytes !== undefined && policy.maxTotalSizeBytes < 0) {
    throw new Error("maxTotalSizeBytes must be a non-negative number");
  }
  if (policy.keepLatestN !== undefined && policy.keepLatestN < 1) {
    throw new Error("keepLatestN must be at least 1");
  }
}

/**
 * Determine which artifacts to delete based on the given retention policy.
 *
 * @param artifacts  - list of artifact metadata
 * @param policy     - retention rules to apply
 * @param referenceDate - ISO 8601 "now" for age calculations (defaults to real now)
 * @returns a DeletionPlan describing what to delete, what to keep, and summary stats
 */
export function applyRetentionPolicies(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  referenceDate?: string
): DeletionPlan {
  validatePolicy(policy);

  const now = referenceDate ? new Date(referenceDate) : new Date();
  // Track deletions by artifact name (preserves insertion order)
  const toDelete = new Map<string, DeletionEntry>();

  // ── Step 1: max age ───────────────────────────────────────────────
  if (policy.maxAgeDays !== undefined) {
    const maxAgeMs = policy.maxAgeDays * 24 * 60 * 60 * 1000;
    for (const artifact of artifacts) {
      const ageMs = now.getTime() - new Date(artifact.createdAt).getTime();
      if (ageMs > maxAgeMs) {
        toDelete.set(artifact.name, { artifact, reason: "max_age" });
      }
    }
  }

  // ── Step 2: keep-latest-N per workflow ────────────────────────────
  if (policy.keepLatestN !== undefined) {
    // Group ALL artifacts by workflowRunId
    const byWorkflow = new Map<string, Artifact[]>();
    for (const artifact of artifacts) {
      const list = byWorkflow.get(artifact.workflowRunId) ?? [];
      list.push(artifact);
      byWorkflow.set(artifact.workflowRunId, list);
    }

    for (const [, group] of byWorkflow) {
      // Sort newest-first
      const sorted = [...group].sort(
        (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
      );
      // Everything beyond the first N gets marked for deletion
      for (let i = policy.keepLatestN; i < sorted.length; i++) {
        if (!toDelete.has(sorted[i].name)) {
          toDelete.set(sorted[i].name, {
            artifact: sorted[i],
            reason: "keep_latest_n",
          });
        }
      }
    }
  }

  // ── Step 3: max total size (oldest-first eviction) ────────────────
  if (policy.maxTotalSizeBytes !== undefined) {
    const remaining = artifacts.filter((a) => !toDelete.has(a.name));
    let currentSize = remaining.reduce((sum, a) => sum + a.sizeBytes, 0);

    if (currentSize > policy.maxTotalSizeBytes) {
      // Sort remaining oldest-first so we evict the oldest
      const sorted = [...remaining].sort(
        (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()
      );
      for (const artifact of sorted) {
        if (currentSize <= policy.maxTotalSizeBytes) break;
        toDelete.set(artifact.name, { artifact, reason: "max_total_size" });
        currentSize -= artifact.sizeBytes;
      }
    }
  }

  // ── Build the plan ────────────────────────────────────────────────
  const deleteEntries = Array.from(toDelete.values());
  const retainEntries = artifacts.filter((a) => !toDelete.has(a.name));

  return {
    toDelete: deleteEntries,
    toRetain: retainEntries,
    summary: {
      totalArtifacts: artifacts.length,
      deletedCount: deleteEntries.length,
      retainedCount: retainEntries.length,
      spaceReclaimedBytes: deleteEntries.reduce(
        (sum, e) => sum + e.artifact.sizeBytes,
        0
      ),
      spaceRetainedBytes: retainEntries.reduce(
        (sum, a) => sum + a.sizeBytes,
        0
      ),
    },
    dryRun: policy.dryRun ?? false,
  };
}
