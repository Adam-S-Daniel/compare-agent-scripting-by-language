// Artifact retention engine. Pure functions — no I/O — so the same logic
// can be exercised by unit tests, CLI mode, and the GitHub Actions runner.

export interface Artifact {
  id: string;
  name: string;
  sizeBytes: number;
  createdAt: string; // ISO 8601
  workflowRunId: string;
}

export interface RetentionPolicy {
  // Delete anything older than this many days.
  maxAgeDays?: number;
  // If total retained size exceeds this, delete oldest until under cap.
  maxTotalSizeBytes?: number;
  // Per workflow, keep only the N most recent artifacts; older ones are deleted.
  keepLatestPerWorkflow?: number;
}

export interface CleanupSummary {
  totalCount: number;
  retainedCount: number;
  deletedCount: number;
  spaceReclaimedBytes: number;
  retainedSizeBytes: number;
}

export interface CleanupPlan {
  toDelete: Artifact[];
  toRetain: Artifact[];
  summary: CleanupSummary;
  reasons: Record<string, string[]>; // id -> reasons it's being deleted
}

const DAY_MS = 24 * 60 * 60 * 1000;

function validate(artifacts: Artifact[]): void {
  for (const a of artifacts) {
    if (typeof a.sizeBytes !== "number" || a.sizeBytes < 0 || !Number.isFinite(a.sizeBytes)) {
      throw new Error(`Artifact ${a.id}: invalid sizeBytes (${a.sizeBytes})`);
    }
    const t = Date.parse(a.createdAt);
    if (Number.isNaN(t)) {
      throw new Error(`Artifact ${a.id}: invalid createdAt (${a.createdAt})`);
    }
  }
}

export function planCleanup(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  now: number = Date.now(),
): CleanupPlan {
  validate(artifacts);

  const reasons: Record<string, string[]> = {};
  const markDelete = (id: string, reason: string) => {
    (reasons[id] ??= []).push(reason);
  };

  // Rule 1: max age.
  if (policy.maxAgeDays !== undefined) {
    const cutoff = now - policy.maxAgeDays * DAY_MS;
    for (const a of artifacts) {
      if (Date.parse(a.createdAt) < cutoff) {
        markDelete(a.id, `older than ${policy.maxAgeDays} days`);
      }
    }
  }

  // Rule 2: keep latest N per workflow.
  if (policy.keepLatestPerWorkflow !== undefined) {
    const byWorkflow = new Map<string, Artifact[]>();
    for (const a of artifacts) {
      (byWorkflow.get(a.workflowRunId) ?? byWorkflow.set(a.workflowRunId, []).get(a.workflowRunId)!).push(a);
    }
    for (const group of byWorkflow.values()) {
      const sorted = [...group].sort((x, y) => Date.parse(y.createdAt) - Date.parse(x.createdAt));
      const tail = sorted.slice(policy.keepLatestPerWorkflow);
      for (const a of tail) {
        markDelete(a.id, `not in latest ${policy.keepLatestPerWorkflow} for workflow ${a.workflowRunId}`);
      }
    }
  }

  // Rule 3: max total size — apply after the above so that "currently retained"
  // size is what we're trying to bring under the cap. Delete oldest first.
  if (policy.maxTotalSizeBytes !== undefined) {
    const stillRetained = artifacts
      .filter(a => !reasons[a.id])
      .sort((x, y) => Date.parse(x.createdAt) - Date.parse(y.createdAt)); // oldest first
    let total = stillRetained.reduce((s, a) => s + a.sizeBytes, 0);
    for (const a of stillRetained) {
      if (total <= policy.maxTotalSizeBytes) break;
      markDelete(a.id, `over total size cap of ${policy.maxTotalSizeBytes} bytes`);
      total -= a.sizeBytes;
    }
  }

  const toDelete = artifacts.filter(a => reasons[a.id]);
  const toRetain = artifacts.filter(a => !reasons[a.id]);
  const spaceReclaimedBytes = toDelete.reduce((s, a) => s + a.sizeBytes, 0);
  const retainedSizeBytes = toRetain.reduce((s, a) => s + a.sizeBytes, 0);

  return {
    toDelete,
    toRetain,
    summary: {
      totalCount: artifacts.length,
      retainedCount: toRetain.length,
      deletedCount: toDelete.length,
      spaceReclaimedBytes,
      retainedSizeBytes,
    },
    reasons,
  };
}

export function formatPlan(plan: CleanupPlan, dryRun: boolean): string {
  const lines: string[] = [];
  lines.push(dryRun ? "=== DRY RUN: no artifacts will be deleted ===" : "=== EXECUTING CLEANUP ===");
  lines.push(`Total artifacts: ${plan.summary.totalCount}`);
  lines.push(`Retained:        ${plan.summary.retainedCount} (${plan.summary.retainedSizeBytes} bytes)`);
  lines.push(`To delete:       ${plan.summary.deletedCount} (${plan.summary.spaceReclaimedBytes} bytes reclaimed)`);
  if (plan.toDelete.length > 0) {
    lines.push("--- Artifacts to delete ---");
    for (const a of plan.toDelete) {
      const why = plan.reasons[a.id]?.join("; ") ?? "";
      lines.push(`  - ${a.id} (${a.name}, ${a.sizeBytes}B) :: ${why}`);
    }
  }
  return lines.join("\n");
}
