// Human-readable formatting for the deletion plan output.

import type { DeletionPlan } from "./types";

/** Convert a byte count to a human-friendly string (e.g. "150.0 MB"). */
export function formatBytes(bytes: number): string {
  if (bytes === 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  const value = bytes / Math.pow(1024, i);
  return `${value.toFixed(1)} ${units[i]}`;
}

/** Format a full DeletionPlan as a multi-line report. */
export function formatPlan(plan: DeletionPlan): string {
  const lines: string[] = [];

  lines.push("=== Artifact Cleanup Plan ===");
  lines.push(`Mode: ${plan.dryRun ? "DRY-RUN" : "EXECUTE"}`);
  lines.push("");

  // Deletion list
  if (plan.toDelete.length > 0) {
    lines.push("Artifacts to DELETE:");
    for (const entry of plan.toDelete) {
      const a = entry.artifact;
      const date = a.createdAt.split("T")[0];
      lines.push(
        `  - ${a.name} (${formatBytes(a.sizeBytes)}, created ${date}, workflow ${a.workflowRunId}) [reason: ${entry.reason}]`
      );
    }
  } else {
    lines.push("Artifacts to DELETE: none");
  }

  lines.push("");

  // Retention list
  if (plan.toRetain.length > 0) {
    lines.push("Artifacts to RETAIN:");
    for (const a of plan.toRetain) {
      const date = a.createdAt.split("T")[0];
      lines.push(
        `  - ${a.name} (${formatBytes(a.sizeBytes)}, created ${date}, workflow ${a.workflowRunId})`
      );
    }
  } else {
    lines.push("Artifacts to RETAIN: none");
  }

  lines.push("");
  lines.push("=== Summary ===");
  lines.push(`Total artifacts: ${plan.summary.totalArtifacts}`);
  lines.push(`Artifacts to delete: ${plan.summary.deletedCount}`);
  lines.push(`Artifacts to retain: ${plan.summary.retainedCount}`);
  lines.push(`Space reclaimed: ${formatBytes(plan.summary.spaceReclaimedBytes)}`);
  lines.push(`Space retained: ${formatBytes(plan.summary.spaceRetainedBytes)}`);

  return lines.join("\n");
}
