// Core cleanup library. Pure functions — no I/O. The CLI wrapper lives in cli.ts.
//
// Design: each retention policy decides independently which artifacts to delete.
// The final delete set is the union. "Keep latest N per workflow" and "max total
// size" both operate on the artifact list that survives max-age, so a stricter
// rule never accidentally rescues something a looser rule already condemned.

export interface Artifact {
  id: string;
  name: string;
  sizeBytes: number;
  createdAt: string; // ISO-8601 timestamp
  workflowRunId: string;
}

export interface RetentionPolicy {
  maxAgeDays?: number;
  keepLatestPerWorkflow?: number;
  maxTotalSizeBytes?: number;
}

export interface PlanSummary {
  totalArtifacts: number;
  deletedCount: number;
  retainedCount: number;
  bytesReclaimed: number;
}

export interface DeletionPlan {
  toDelete: Artifact[];
  toRetain: Artifact[];
  summary: PlanSummary;
  dryRun: boolean;
  policy: RetentionPolicy;
}

export interface PlanOptions {
  dryRun?: boolean;
}

function validatePolicy(policy: RetentionPolicy): void {
  if (policy.maxAgeDays !== undefined && policy.maxAgeDays < 0) {
    throw new Error("maxAgeDays must be >= 0");
  }
  if (policy.keepLatestPerWorkflow !== undefined) {
    const n = policy.keepLatestPerWorkflow;
    if (!Number.isInteger(n) || n < 0) {
      throw new Error("keepLatestPerWorkflow must be a non-negative integer");
    }
  }
  if (
    policy.maxTotalSizeBytes !== undefined &&
    policy.maxTotalSizeBytes < 0
  ) {
    throw new Error("maxTotalSizeBytes must be >= 0");
  }
}

function validateArtifact(a: unknown, index: number): asserts a is Artifact {
  if (!a || typeof a !== "object") {
    throw new Error(`invalid artifact at index ${index}: not an object`);
  }
  const o = a as Record<string, unknown>;
  const needStrings = ["id", "name", "createdAt", "workflowRunId"] as const;
  for (const k of needStrings) {
    if (typeof o[k] !== "string" || (o[k] as string).length === 0) {
      throw new Error(
        `invalid artifact at index ${index}: missing/invalid '${k}'`
      );
    }
  }
  if (typeof o.sizeBytes !== "number" || o.sizeBytes < 0) {
    throw new Error(
      `invalid artifact at index ${index}: 'sizeBytes' must be a non-negative number`
    );
  }
  if (Number.isNaN(Date.parse(o.createdAt as string))) {
    throw new Error(
      `invalid artifact at index ${index}: 'createdAt' is not a parseable date`
    );
  }
}

/** Artifacts older than maxAgeDays relative to `now`. */
function deletionsByAge(
  artifacts: Artifact[],
  maxAgeDays: number | undefined,
  now: number
): Set<string> {
  const ids = new Set<string>();
  if (maxAgeDays === undefined) return ids;
  const cutoff = now - maxAgeDays * 86_400_000;
  for (const a of artifacts) {
    if (Date.parse(a.createdAt) < cutoff) ids.add(a.id);
  }
  return ids;
}

/** For each workflowRunId, keep only the N newest; mark the rest for deletion. */
function deletionsByKeepLatest(
  artifacts: Artifact[],
  keep: number | undefined
): Set<string> {
  const ids = new Set<string>();
  if (keep === undefined) return ids;
  const byWorkflow = new Map<string, Artifact[]>();
  for (const a of artifacts) {
    const list = byWorkflow.get(a.workflowRunId) ?? [];
    list.push(a);
    byWorkflow.set(a.workflowRunId, list);
  }
  for (const [, list] of byWorkflow) {
    list.sort((x, y) => Date.parse(y.createdAt) - Date.parse(x.createdAt));
    for (const a of list.slice(keep)) ids.add(a.id);
  }
  return ids;
}

/**
 * Greedily delete oldest surviving artifacts until total size fits under the cap.
 * Operates on artifacts that the other policies have not already condemned —
 * otherwise size accounting would double-count soon-to-be-deleted bytes.
 */
function deletionsBySize(
  artifacts: Artifact[],
  alreadyDeleted: Set<string>,
  cap: number | undefined
): Set<string> {
  const ids = new Set<string>();
  if (cap === undefined) return ids;
  const survivors = artifacts
    .filter((a) => !alreadyDeleted.has(a.id))
    .slice()
    .sort((x, y) => Date.parse(x.createdAt) - Date.parse(y.createdAt)); // oldest first
  let total = survivors.reduce((s, a) => s + a.sizeBytes, 0);
  for (const a of survivors) {
    if (total <= cap) break;
    ids.add(a.id);
    total -= a.sizeBytes;
  }
  return ids;
}

export function planCleanup(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  now: number = Date.now(),
  options: PlanOptions = {}
): DeletionPlan {
  validatePolicy(policy);
  artifacts.forEach((a, i) => validateArtifact(a, i));

  const byAge = deletionsByAge(artifacts, policy.maxAgeDays, now);
  const byKeep = deletionsByKeepLatest(artifacts, policy.keepLatestPerWorkflow);
  const combined = new Set<string>([...byAge, ...byKeep]);
  const bySize = deletionsBySize(artifacts, combined, policy.maxTotalSizeBytes);
  for (const id of bySize) combined.add(id);

  const toDelete = artifacts.filter((a) => combined.has(a.id));
  const toRetain = artifacts.filter((a) => !combined.has(a.id));
  const bytesReclaimed = toDelete.reduce((s, a) => s + a.sizeBytes, 0);

  return {
    toDelete,
    toRetain,
    summary: {
      totalArtifacts: artifacts.length,
      deletedCount: toDelete.length,
      retainedCount: toRetain.length,
      bytesReclaimed,
    },
    dryRun: options.dryRun ?? false,
    policy,
  };
}

export function formatPlanSummary(plan: DeletionPlan): string {
  const lines: string[] = [];
  if (plan.dryRun) lines.push("=== DRY RUN: no artifacts will be deleted ===");
  lines.push(`Total artifacts evaluated: ${plan.summary.totalArtifacts}`);
  lines.push(`Artifacts to delete: ${plan.summary.deletedCount}`);
  lines.push(`Artifacts retained: ${plan.summary.retainedCount}`);
  lines.push(`Bytes reclaimed: ${plan.summary.bytesReclaimed}`);
  if (plan.toDelete.length > 0) {
    lines.push("Deleted artifacts:");
    for (const a of plan.toDelete) {
      lines.push(`  - ${a.id} (${a.name}, ${a.sizeBytes}B, wf=${a.workflowRunId})`);
    }
  }
  return lines.join("\n");
}
