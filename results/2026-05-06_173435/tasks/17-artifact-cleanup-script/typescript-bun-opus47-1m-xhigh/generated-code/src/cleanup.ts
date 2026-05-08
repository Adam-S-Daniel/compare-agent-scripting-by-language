// Artifact cleanup core. Pure functions only — the CLI layer composes these.
// Each policy function returns a {toKeep, toDelete} split, so policies can be
// chained: deletions accumulate across stages and surviving artifacts feed in
// to the next stage.

export interface Artifact {
  id: string;
  name: string;
  sizeBytes: number;
  createdAt: Date;
  workflowRunId: string;
}

export interface RetentionPolicy {
  maxAgeDays?: number;
  maxTotalSizeBytes?: number;
  keepLatestNPerWorkflow?: number;
}

export interface PolicyResult {
  toKeep: Artifact[];
  toDelete: Artifact[];
}

export interface DeletionPlan {
  toKeep: Artifact[];
  toDelete: Artifact[];
  summary: {
    totalArtifacts: number;
    retainedCount: number;
    deletedCount: number;
    spaceReclaimedBytes: number;
    spaceRetainedBytes: number;
    reasons: Record<string, number>;
  };
}

const MS_PER_DAY = 24 * 60 * 60 * 1000;

export function parseArtifactsJson(text: string): Artifact[] {
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    throw new Error(`Failed to parse artifacts JSON: ${msg}`);
  }
  if (!Array.isArray(parsed)) {
    throw new Error(
      "Artifacts JSON must be an array of artifact objects at the top level",
    );
  }
  return parsed.map((raw, index) => coerceArtifact(raw, index));
}

function coerceArtifact(raw: unknown, index: number): Artifact {
  if (typeof raw !== "object" || raw === null) {
    throw new Error(`Artifact at index ${index} is not an object`);
  }
  const obj = raw as Record<string, unknown>;
  const required = ["id", "name", "sizeBytes", "createdAt", "workflowRunId"];
  for (const field of required) {
    if (!(field in obj)) {
      throw new Error(
        `Artifact at index ${index} is missing required field '${field}'`,
      );
    }
  }
  if (typeof obj.id !== "string") {
    throw new Error(`Artifact at index ${index} has invalid id`);
  }
  if (typeof obj.name !== "string") {
    throw new Error(`Artifact at index ${index} has invalid name`);
  }
  if (typeof obj.sizeBytes !== "number" || !Number.isFinite(obj.sizeBytes)) {
    throw new Error(`Artifact at index ${index} has invalid sizeBytes`);
  }
  if (typeof obj.workflowRunId !== "string") {
    throw new Error(`Artifact at index ${index} has invalid workflowRunId`);
  }
  if (typeof obj.createdAt !== "string") {
    throw new Error(`Artifact at index ${index} has invalid createdAt`);
  }
  const createdAt = new Date(obj.createdAt);
  if (Number.isNaN(createdAt.getTime())) {
    throw new Error(
      `Artifact at index ${index} has invalid createdAt: '${obj.createdAt}'`,
    );
  }
  return {
    id: obj.id,
    name: obj.name,
    sizeBytes: obj.sizeBytes,
    createdAt,
    workflowRunId: obj.workflowRunId,
  };
}

export interface FormatOptions {
  dryRun: boolean;
}

export function formatPlanReport(
  plan: DeletionPlan,
  options: FormatOptions,
): string {
  // Output is mixed: a header line ("DRY-RUN" vs "APPLY") plus key=value
  // summary lines that an integration test can grep deterministically.
  // Per-artifact details follow for human readers.
  const header = options.dryRun
    ? "MODE: DRY-RUN (no artifacts will be deleted)"
    : "MODE: APPLY";
  const verb = options.dryRun ? "would delete" : "deleted";
  const reasonsList = Object.entries(plan.summary.reasons)
    .map(([k, v]) => `${k}=${v}`)
    .join(",");
  const lines: string[] = [
    "===== Artifact Cleanup Plan =====",
    header,
    `total_artifacts=${plan.summary.totalArtifacts}`,
    `retained_count=${plan.summary.retainedCount}`,
    `deleted_count=${plan.summary.deletedCount}`,
    `space_reclaimed_bytes=${plan.summary.spaceReclaimedBytes}`,
    `space_retained_bytes=${plan.summary.spaceRetainedBytes}`,
    `reasons=${reasonsList || "none"}`,
    `--- ${verb} (${plan.toDelete.length}) ---`,
    ...plan.toDelete.map(
      (a) =>
        `  - ${a.id} | ${a.name} | ${a.sizeBytes}B | ${a.createdAt.toISOString()} | wf=${a.workflowRunId}`,
    ),
    `--- retained (${plan.toKeep.length}) ---`,
    ...plan.toKeep.map(
      (a) =>
        `  + ${a.id} | ${a.name} | ${a.sizeBytes}B | ${a.createdAt.toISOString()} | wf=${a.workflowRunId}`,
    ),
    "===== End =====",
  ];
  return lines.join("\n");
}


export function applyMaxAgePolicy(
  artifacts: Artifact[],
  maxAgeDays: number | undefined,
  now: Date,
): PolicyResult {
  if (maxAgeDays === undefined) {
    return { toKeep: [...artifacts], toDelete: [] };
  }
  const threshold = now.getTime() - maxAgeDays * MS_PER_DAY;
  const toKeep: Artifact[] = [];
  const toDelete: Artifact[] = [];
  for (const a of artifacts) {
    // Keep when createdAt is at-or-after threshold (>= so the boundary stays).
    if (a.createdAt.getTime() >= threshold) {
      toKeep.push(a);
    } else {
      toDelete.push(a);
    }
  }
  return { toKeep, toDelete };
}

export function applyMaxTotalSizePolicy(
  artifacts: Artifact[],
  maxTotalSizeBytes: number | undefined,
): PolicyResult {
  if (maxTotalSizeBytes === undefined) {
    return { toKeep: [...artifacts], toDelete: [] };
  }
  // Strategy: sort newest-first, accumulate sizes, evict any that overflow
  // (which are the oldest entries). Returned toDelete preserves the eviction
  // order: oldest deleted first, walking back toward newer artifacts if more
  // need to be evicted.
  const newestFirst = [...artifacts].sort(
    (a, b) => b.createdAt.getTime() - a.createdAt.getTime(),
  );
  const toKeep: Artifact[] = [];
  const evicted: Artifact[] = [];
  let runningSize = 0;
  for (const a of newestFirst) {
    if (runningSize + a.sizeBytes <= maxTotalSizeBytes) {
      toKeep.push(a);
      runningSize += a.sizeBytes;
    } else {
      evicted.push(a);
    }
  }
  // evicted is currently newest-overflow first because of iteration order;
  // reverse so callers see deletions oldest-first (more natural to read).
  return { toKeep, toDelete: evicted.reverse() };
}

export function applyKeepLatestNPolicy(
  artifacts: Artifact[],
  keepLatestN: number | undefined,
): PolicyResult {
  if (keepLatestN === undefined) {
    return { toKeep: [...artifacts], toDelete: [] };
  }
  // Group by workflowRunId, then within each group keep the N newest.
  const groups = new Map<string, Artifact[]>();
  for (const a of artifacts) {
    const list = groups.get(a.workflowRunId);
    if (list) list.push(a);
    else groups.set(a.workflowRunId, [a]);
  }
  const toKeep: Artifact[] = [];
  const toDelete: Artifact[] = [];
  for (const list of groups.values()) {
    const newestFirst = [...list].sort(
      (a, b) => b.createdAt.getTime() - a.createdAt.getTime(),
    );
    toKeep.push(...newestFirst.slice(0, keepLatestN));
    toDelete.push(...newestFirst.slice(keepLatestN));
  }
  return { toKeep, toDelete };
}

export function buildDeletionPlan(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  now: Date,
): DeletionPlan {
  // Order matters: max-age first (cheapest filter), then size cap on the
  // survivors, then keep-latest-N within each remaining workflow.
  // Each stage tags its evictions with a reason for the summary.
  const reasons: Record<string, number> = {};
  const deletions: Artifact[] = [];

  const stageAge = applyMaxAgePolicy(artifacts, policy.maxAgeDays, now);
  if (stageAge.toDelete.length > 0) {
    reasons["max-age"] = stageAge.toDelete.length;
    deletions.push(...stageAge.toDelete);
  }

  const stageSize = applyMaxTotalSizePolicy(
    stageAge.toKeep,
    policy.maxTotalSizeBytes,
  );
  if (stageSize.toDelete.length > 0) {
    reasons["max-total-size"] = stageSize.toDelete.length;
    deletions.push(...stageSize.toDelete);
  }

  const stageKeep = applyKeepLatestNPolicy(
    stageSize.toKeep,
    policy.keepLatestNPerWorkflow,
  );
  if (stageKeep.toDelete.length > 0) {
    reasons["keep-latest-n"] = stageKeep.toDelete.length;
    deletions.push(...stageKeep.toDelete);
  }

  const finalKeep = stageKeep.toKeep;
  const sumBytes = (xs: Artifact[]): number =>
    xs.reduce((acc, a) => acc + a.sizeBytes, 0);

  return {
    toKeep: finalKeep,
    toDelete: deletions,
    summary: {
      totalArtifacts: artifacts.length,
      retainedCount: finalKeep.length,
      deletedCount: deletions.length,
      spaceReclaimedBytes: sumBytes(deletions),
      spaceRetainedBytes: sumBytes(finalKeep),
      reasons,
    },
  };
}
