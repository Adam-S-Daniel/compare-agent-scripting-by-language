// Artifact cleanup: applies retention policies and produces a deletion plan.
//
// Approach:
//   1. Tag artifacts for deletion in priority order:
//        a) age   — older than maxAgeDays
//        b) keep-N — beyond the newest N per workflow run ID
//        c) size  — oldest-first until total kept size <= maxTotalBytes
//   2. Surviving artifacts are "kept". Output a plan with a summary.
//
// All policies are optional. If none are supplied, nothing is deleted.

export interface Artifact {
  name: string;
  sizeBytes: number;
  createdAt: Date;        // accepts string in JSON; converted on load
  workflowRunId: string;
}

export interface RetentionPolicy {
  maxAgeDays?: number;
  maxTotalBytes?: number;
  keepLatestPerWorkflow?: number;
}

export interface DeletionEntry {
  artifact: Artifact;
  reason: "age" | "keep-latest" | "size";
}

export interface DeletionPlan {
  toDelete: DeletionEntry[];
  toKeep: Artifact[];
  summary: {
    totalArtifacts: number;
    deletedCount: number;
    retainedCount: number;
    bytesReclaimed: number;
    bytesRetained: number;
  };
  dryRun: boolean;
}

export function buildDeletionPlan(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  options: { dryRun?: boolean; now?: Date } = {},
): DeletionPlan {
  validateArtifacts(artifacts);
  validatePolicy(policy);

  const now = options.now ?? new Date();
  const dryRun = options.dryRun ?? false;

  // Map artifact -> deletion reason. Earliest reason wins.
  const reasons = new Map<Artifact, DeletionEntry["reason"]>();

  // 1. Age policy
  if (policy.maxAgeDays !== undefined) {
    const cutoff = now.getTime() - policy.maxAgeDays * 86_400_000;
    for (const a of artifacts) {
      if (a.createdAt.getTime() < cutoff) reasons.set(a, "age");
    }
  }

  // 2. Keep-latest-N per workflow run ID (newest first survive)
  if (policy.keepLatestPerWorkflow !== undefined) {
    const groups = new Map<string, Artifact[]>();
    for (const a of artifacts) {
      const list = groups.get(a.workflowRunId) ?? [];
      list.push(a);
      groups.set(a.workflowRunId, list);
    }
    for (const list of groups.values()) {
      list.sort((x, y) => y.createdAt.getTime() - x.createdAt.getTime());
      for (let i = policy.keepLatestPerWorkflow; i < list.length; i++) {
        if (!reasons.has(list[i]!)) reasons.set(list[i]!, "keep-latest");
      }
    }
  }

  // 3. Total size cap — delete oldest survivors until under cap
  if (policy.maxTotalBytes !== undefined) {
    const survivors = artifacts
      .filter((a) => !reasons.has(a))
      .sort((x, y) => x.createdAt.getTime() - y.createdAt.getTime()); // oldest first
    let total = survivors.reduce((s, a) => s + a.sizeBytes, 0);
    for (const a of survivors) {
      if (total <= policy.maxTotalBytes) break;
      reasons.set(a, "size");
      total -= a.sizeBytes;
    }
  }

  const toDelete: DeletionEntry[] = [];
  const toKeep: Artifact[] = [];
  for (const a of artifacts) {
    const r = reasons.get(a);
    if (r) toDelete.push({ artifact: a, reason: r });
    else toKeep.push(a);
  }

  const bytesReclaimed = toDelete.reduce((s, e) => s + e.artifact.sizeBytes, 0);
  const bytesRetained = toKeep.reduce((s, a) => s + a.sizeBytes, 0);

  return {
    toDelete,
    toKeep,
    summary: {
      totalArtifacts: artifacts.length,
      deletedCount: toDelete.length,
      retainedCount: toKeep.length,
      bytesReclaimed,
      bytesRetained,
    },
    dryRun,
  };
}

function validateArtifacts(artifacts: Artifact[]): void {
  if (!Array.isArray(artifacts)) {
    throw new Error("artifacts must be an array");
  }
  for (const a of artifacts) {
    if (!a.name) throw new Error("artifact missing name");
    if (!Number.isFinite(a.sizeBytes) || a.sizeBytes < 0) {
      throw new Error(`artifact ${a.name}: invalid sizeBytes`);
    }
    if (!(a.createdAt instanceof Date) || isNaN(a.createdAt.getTime())) {
      throw new Error(`artifact ${a.name}: invalid createdAt`);
    }
    if (!a.workflowRunId) {
      throw new Error(`artifact ${a.name}: missing workflowRunId`);
    }
  }
}

function validatePolicy(policy: RetentionPolicy): void {
  const { maxAgeDays, maxTotalBytes, keepLatestPerWorkflow } = policy;
  if (maxAgeDays !== undefined && (!Number.isFinite(maxAgeDays) || maxAgeDays < 0)) {
    throw new Error("maxAgeDays must be a non-negative number");
  }
  if (maxTotalBytes !== undefined && (!Number.isFinite(maxTotalBytes) || maxTotalBytes < 0)) {
    throw new Error("maxTotalBytes must be a non-negative number");
  }
  if (
    keepLatestPerWorkflow !== undefined &&
    (!Number.isInteger(keepLatestPerWorkflow) || keepLatestPerWorkflow < 0)
  ) {
    throw new Error("keepLatestPerWorkflow must be a non-negative integer");
  }
}

export function formatPlan(plan: DeletionPlan): string {
  const lines: string[] = [];
  lines.push(`=== Artifact Cleanup Plan${plan.dryRun ? " (DRY RUN)" : ""} ===`);
  lines.push(`Total artifacts: ${plan.summary.totalArtifacts}`);
  lines.push(`To delete:       ${plan.summary.deletedCount}`);
  lines.push(`To retain:       ${plan.summary.retainedCount}`);
  lines.push(`Bytes reclaimed: ${plan.summary.bytesReclaimed}`);
  lines.push(`Bytes retained:  ${plan.summary.bytesRetained}`);
  if (plan.toDelete.length > 0) {
    lines.push("");
    lines.push("Deletions:");
    for (const e of plan.toDelete) {
      lines.push(
        `  - ${e.artifact.name} (run=${e.artifact.workflowRunId}, ${e.artifact.sizeBytes}B) reason=${e.reason}`,
      );
    }
  }
  return lines.join("\n");
}

// Load artifacts from a JSON file. createdAt strings are converted to Date.
export async function loadArtifactsFromFile(path: string): Promise<Artifact[]> {
  const text = await Bun.file(path).text();
  let raw: unknown;
  try {
    raw = JSON.parse(text);
  } catch (e) {
    throw new Error(`failed to parse JSON in ${path}: ${(e as Error).message}`);
  }
  if (!Array.isArray(raw)) {
    throw new Error(`${path}: expected JSON array of artifacts`);
  }
  return raw.map((r: any, i: number) => {
    if (!r || typeof r !== "object") {
      throw new Error(`${path}[${i}]: not an object`);
    }
    const d = new Date(r.createdAt);
    return {
      name: String(r.name),
      sizeBytes: Number(r.sizeBytes),
      createdAt: d,
      workflowRunId: String(r.workflowRunId),
    };
  });
}

// CLI entry point. Run with: bun run cleanup.ts <artifacts.json> [flags]
//   --dry-run
//   --max-age-days=N
//   --max-total-bytes=N
//   --keep-latest=N
async function main(argv: string[]): Promise<number> {
  const args = argv.slice(2);
  if (args.length === 0 || args[0] === "--help" || args[0] === "-h") {
    console.log(
      "Usage: bun run cleanup.ts <artifacts.json> [--dry-run] [--max-age-days=N] [--max-total-bytes=N] [--keep-latest=N]",
    );
    return args.length === 0 ? 1 : 0;
  }
  const file = args[0]!;
  const policy: RetentionPolicy = {};
  let dryRun = false;
  let now: Date | undefined;
  for (const a of args.slice(1)) {
    if (a === "--dry-run") dryRun = true;
    else if (a.startsWith("--max-age-days=")) policy.maxAgeDays = Number(a.split("=")[1]);
    else if (a.startsWith("--max-total-bytes=")) policy.maxTotalBytes = Number(a.split("=")[1]);
    else if (a.startsWith("--keep-latest=")) policy.keepLatestPerWorkflow = Number(a.split("=")[1]);
    else if (a.startsWith("--now=")) {
      now = new Date(a.slice("--now=".length));
      if (isNaN(now.getTime())) {
        console.error(`Invalid --now value: ${a}`);
        return 2;
      }
    } else {
      console.error(`Unknown argument: ${a}`);
      return 2;
    }
  }
  try {
    const artifacts = await loadArtifactsFromFile(file);
    const plan = buildDeletionPlan(artifacts, policy, { dryRun, now });
    console.log(formatPlan(plan));
    return 0;
  } catch (e) {
    console.error(`ERROR: ${(e as Error).message}`);
    return 1;
  }
}

if (import.meta.main) {
  process.exit(await main(process.argv));
}
