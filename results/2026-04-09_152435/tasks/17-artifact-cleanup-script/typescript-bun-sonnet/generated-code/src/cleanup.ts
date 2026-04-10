// Deletion plan generator.
// Combines retention policy evaluation with plan formatting.
// Supports dry-run mode: the plan is always generated but in dry-run mode
// nothing is actually deleted.
//
// TDD approach: tests were written first in tests/cleanup.test.ts.

import { applyRetentionPolicies } from "./retention";
import type { Artifact, DeletionPlan, RetentionPolicy } from "./types";

// Generates a deletion plan by applying retention policies.
// When dryRun=true, the plan is generated but no deletion should occur.
export function generateDeletionPlan(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  referenceDate: Date,
  dryRun: boolean
): DeletionPlan {
  const { toDelete, toRetain } = applyRetentionPolicies(
    artifacts,
    policy,
    referenceDate
  );

  const totalSpaceReclaimedBytes = toDelete.reduce(
    (sum, a) => sum + a.sizeBytes,
    0
  );

  return {
    toDelete,
    toRetain,
    summary: {
      totalSpaceReclaimedBytes,
      artifactsDeleted: toDelete.length,
      artifactsRetained: toRetain.length,
    },
    dryRun,
  };
}

// Format bytes as human-readable string (e.g. "2.00 MB")
function formatBytes(bytes: number): string {
  if (bytes === 0) return "0 B";
  const units = ["B", "KB", "MB", "GB"];
  const i = Math.min(
    Math.floor(Math.log2(bytes) / 10),
    units.length - 1
  );
  const value = bytes / Math.pow(1024, i);
  return `${value.toFixed(2)} ${units[i]}`;
}

// Render the deletion plan as a human-readable string with machine-parseable
// summary lines (DELETED_COUNT=N, RETAINED_COUNT=N, RECLAIMED_BYTES=N).
export function formatPlan(plan: DeletionPlan): string {
  const lines: string[] = [];

  lines.push("=== ARTIFACT CLEANUP PLAN ===");
  if (plan.dryRun) {
    lines.push("Mode: DRY RUN (no artifacts will actually be deleted)");
  } else {
    lines.push("Mode: EXECUTE");
  }
  lines.push("");

  lines.push(`Artifacts to DELETE (${plan.toDelete.length}):`);
  if (plan.toDelete.length === 0) {
    lines.push("  (none)");
  } else {
    for (const a of plan.toDelete) {
      const age = Math.floor(
        (Date.now() - a.createdAt.getTime()) / (24 * 60 * 60 * 1000)
      );
      lines.push(
        `  - [${a.id}] ${a.name} (${formatBytes(a.sizeBytes)}, ${age}d old, run: ${a.workflowRunId})`
      );
    }
  }

  lines.push("");
  lines.push(`Artifacts to RETAIN (${plan.toRetain.length}):`);
  if (plan.toRetain.length === 0) {
    lines.push("  (none)");
  } else {
    for (const a of plan.toRetain) {
      lines.push(
        `  - [${a.id}] ${a.name} (${formatBytes(a.sizeBytes)}, run: ${a.workflowRunId})`
      );
    }
  }

  lines.push("");
  lines.push("=== SUMMARY ===");
  lines.push(`  Space reclaimed: ${formatBytes(plan.summary.totalSpaceReclaimedBytes)}`);
  lines.push(`  Artifacts deleted: ${plan.summary.artifactsDeleted}`);
  lines.push(`  Artifacts retained: ${plan.summary.artifactsRetained}`);

  // Machine-readable summary lines — used by CI to assert exact expected values
  lines.push("");
  lines.push(`DELETED_COUNT=${plan.summary.artifactsDeleted}`);
  lines.push(`RETAINED_COUNT=${plan.summary.artifactsRetained}`);
  lines.push(`RECLAIMED_BYTES=${plan.summary.totalSpaceReclaimedBytes}`);

  return lines.join("\n");
}
