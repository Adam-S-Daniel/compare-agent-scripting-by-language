// Artifact cleanup planner.
//
// Given a list of artifacts and a retention policy, decide which ones to delete.
// Pure logic — no filesystem or network — so callers (CLI, CI, tests) can drive it
// with mock data and inspect the resulting plan.
//
// Policies, all optional, can be combined:
//   - maxAgeDays: anything older than this is deleted.
//   - keepLatestPerWorkflow: per workflowRunId, keep N newest, delete the rest.
//   - maxTotalSizeBytes: if kept-set still exceeds this budget, delete oldest first
//     until under the budget.
//
// The order matters: we apply age + per-workflow first, then the size-budget pass
// runs on the remaining "kept" set so we don't double-count bytes that another
// policy already reclaimed.

export interface Artifact {
  name: string;
  sizeBytes: number;
  createdAt: string; // ISO 8601
  workflowRunId: string;
}

export interface RetentionPolicy {
  maxAgeDays?: number;
  keepLatestPerWorkflow?: number;
  maxTotalSizeBytes?: number;
}

export interface CleanupSummary {
  totalCount: number;
  keptCount: number;
  deletedCount: number;
  bytesReclaimed: number;
  bytesRetained: number;
}

export interface CleanupPlan {
  toKeep: Artifact[];
  toDelete: Artifact[];
  reasons: Record<string, string[]>;
  summary: CleanupSummary;
}

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Build a deletion plan for a set of artifacts under the given retention policy.
 * `now` is injectable so tests can pin a deterministic clock.
 */
export function planCleanup(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  now: number = Date.now(),
): CleanupPlan {
  const reasons: Record<string, string[]> = {};
  const markDelete = new Set<string>();

  const addReason = (name: string, why: string) => {
    if (!reasons[name]) reasons[name] = [];
    reasons[name].push(why);
  };

  // Pass 1 — max age.
  if (policy.maxAgeDays !== undefined) {
    const cutoff = now - policy.maxAgeDays * DAY_MS;
    for (const a of artifacts) {
      const created = Date.parse(a.createdAt);
      if (Number.isNaN(created)) {
        throw new Error(`Invalid createdAt for artifact "${a.name}": ${a.createdAt}`);
      }
      if (created < cutoff) {
        markDelete.add(a.name);
        addReason(a.name, `older than ${policy.maxAgeDays} days`);
      }
    }
  }

  // Pass 2 — keep latest N per workflow.
  if (policy.keepLatestPerWorkflow !== undefined) {
    const N = policy.keepLatestPerWorkflow;
    const byWorkflow = new Map<string, Artifact[]>();
    for (const a of artifacts) {
      const list = byWorkflow.get(a.workflowRunId) ?? [];
      list.push(a);
      byWorkflow.set(a.workflowRunId, list);
    }
    for (const [wfId, list] of byWorkflow) {
      const sorted = [...list].sort(
        (a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt),
      );
      const losers = sorted.slice(N);
      for (const l of losers) {
        markDelete.add(l.name);
        addReason(l.name, `not in latest ${N} of workflow ${wfId}`);
      }
    }
  }

  // Pass 3 — total-size budget. Operate on what's still kept after passes 1+2.
  if (policy.maxTotalSizeBytes !== undefined) {
    const stillKept = artifacts.filter((a) => !markDelete.has(a.name));
    const totalBytes = stillKept.reduce((s, a) => s + a.sizeBytes, 0);
    if (totalBytes > policy.maxTotalSizeBytes) {
      // Evict oldest first until under budget.
      const oldestFirst = [...stillKept].sort(
        (a, b) => Date.parse(a.createdAt) - Date.parse(b.createdAt),
      );
      let running = totalBytes;
      for (const a of oldestFirst) {
        if (running <= policy.maxTotalSizeBytes) break;
        markDelete.add(a.name);
        addReason(a.name, `exceeds total size budget of ${policy.maxTotalSizeBytes} bytes`);
        running -= a.sizeBytes;
      }
    }
  }

  const toDelete = artifacts.filter((a) => markDelete.has(a.name));
  const toKeep = artifacts.filter((a) => !markDelete.has(a.name));
  const bytesReclaimed = toDelete.reduce((s, a) => s + a.sizeBytes, 0);
  const bytesRetained = toKeep.reduce((s, a) => s + a.sizeBytes, 0);

  return {
    toKeep,
    toDelete,
    reasons,
    summary: {
      totalCount: artifacts.length,
      keptCount: toKeep.length,
      deletedCount: toDelete.length,
      bytesReclaimed,
      bytesRetained,
    },
  };
}

/**
 * Format a plan as a human-readable report. `dryRun` controls the banner only —
 * the plan itself is identical either way; this module never deletes anything.
 */
export function formatPlan(plan: CleanupPlan, opts: { dryRun: boolean }): string {
  const lines: string[] = [];
  const banner = opts.dryRun
    ? "=== Artifact cleanup plan (DRY-RUN — nothing will be deleted) ==="
    : "=== Artifact cleanup plan (EXECUTE) ===";
  lines.push(banner);
  lines.push("");
  lines.push("Summary:");
  lines.push(`  Total artifacts: ${plan.summary.totalCount}`);
  lines.push(`  Artifacts retained: ${plan.summary.keptCount}`);
  lines.push(`  Artifacts deleted: ${plan.summary.deletedCount}`);
  lines.push(`  Bytes reclaimed: ${plan.summary.bytesReclaimed}`);
  lines.push(`  Bytes retained: ${plan.summary.bytesRetained}`);
  lines.push("");
  lines.push("Decisions:");
  // Stable, alphabetical order so test expectations are deterministic.
  const all = [...plan.toDelete, ...plan.toKeep].sort((a, b) =>
    a.name.localeCompare(b.name),
  );
  const deleteSet = new Set(plan.toDelete.map((a) => a.name));
  for (const a of all) {
    const verb = deleteSet.has(a.name) ? "DELETE" : "KEEP  ";
    const why = plan.reasons[a.name]?.join("; ") ?? "retained";
    lines.push(`  ${verb}  ${a.name}  (${a.sizeBytes}B, wf=${a.workflowRunId})  -- ${why}`);
  }
  return lines.join("\n");
}

/**
 * Parse a JSON string into a list of validated Artifacts.
 * Throws with a descriptive message on malformed input — we'd rather fail loudly
 * than silently coerce bad data through the pipeline.
 */
export function parseArtifactsJson(json: string): Artifact[] {
  let raw: unknown;
  try {
    raw = JSON.parse(json);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    throw new Error(`Invalid JSON: ${msg}`);
  }
  if (!Array.isArray(raw)) {
    throw new Error("Expected a JSON array of artifacts");
  }
  return raw.map((item, i) => validateArtifact(item, i));
}

function validateArtifact(item: unknown, idx: number): Artifact {
  if (typeof item !== "object" || item === null) {
    throw new Error(`Artifact at index ${idx} is not an object`);
  }
  const o = item as Record<string, unknown>;
  const required = ["name", "sizeBytes", "createdAt", "workflowRunId"] as const;
  for (const key of required) {
    if (!(key in o)) {
      throw new Error(`Artifact at index ${idx} is missing required field: ${key}`);
    }
  }
  if (typeof o.name !== "string" || o.name.length === 0) {
    throw new Error(`Artifact at index ${idx}: "name" must be a non-empty string`);
  }
  if (typeof o.sizeBytes !== "number" || o.sizeBytes < 0) {
    throw new Error(`Artifact at index ${idx}: "sizeBytes" must be a non-negative number`);
  }
  if (typeof o.createdAt !== "string" || Number.isNaN(Date.parse(o.createdAt))) {
    throw new Error(`Artifact at index ${idx}: "createdAt" must be an ISO date string`);
  }
  if (typeof o.workflowRunId !== "string" || o.workflowRunId.length === 0) {
    throw new Error(`Artifact at index ${idx}: "workflowRunId" must be a non-empty string`);
  }
  return {
    name: o.name,
    sizeBytes: o.sizeBytes,
    createdAt: o.createdAt,
    workflowRunId: o.workflowRunId,
  };
}
