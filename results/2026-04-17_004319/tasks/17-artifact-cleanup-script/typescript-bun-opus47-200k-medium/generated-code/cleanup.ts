// Artifact cleanup script: applies retention policies and produces a deletion plan.
// Policies:
//   - maxAgeDays: delete artifacts older than N days
//   - maxTotalBytes: delete oldest artifacts until total <= N
//   - keepLatestPerWorkflow: keep only the N newest artifacts per workflowRunId group
// An artifact is deleted if ANY policy marks it for deletion.

export interface Artifact {
  name: string;
  sizeBytes: number;
  createdAt: string; // ISO-8601
  workflowRunId: string;
}

export interface RetentionPolicy {
  maxAgeDays?: number;
  maxTotalBytes?: number;
  keepLatestPerWorkflow?: number;
}

export interface PlanEntry {
  artifact: Artifact;
  action: "keep" | "delete";
  reasons: string[];
}

export interface DeletionPlan {
  entries: PlanEntry[];
  summary: {
    totalArtifacts: number;
    deleted: number;
    retained: number;
    bytesReclaimed: number;
    dryRun: boolean;
  };
}

function ageDays(createdAt: string, now: Date): number {
  const created = new Date(createdAt).getTime();
  if (Number.isNaN(created)) {
    throw new Error(`Invalid createdAt timestamp: ${createdAt}`);
  }
  return (now.getTime() - created) / (1000 * 60 * 60 * 24);
}

export function buildPlan(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  options: { now?: Date; dryRun?: boolean } = {},
): DeletionPlan {
  const now = options.now ?? new Date();
  const dryRun = options.dryRun ?? false;

  // Validate inputs.
  for (const a of artifacts) {
    if (a.sizeBytes < 0) {
      throw new Error(`Artifact ${a.name} has negative sizeBytes`);
    }
  }

  const reasons = new Map<Artifact, string[]>();
  for (const a of artifacts) reasons.set(a, []);

  // Policy 1: maxAgeDays
  if (policy.maxAgeDays !== undefined) {
    for (const a of artifacts) {
      if (ageDays(a.createdAt, now) > policy.maxAgeDays) {
        reasons.get(a)!.push(`age > ${policy.maxAgeDays} days`);
      }
    }
  }

  // Policy 2: keepLatestPerWorkflow — per run, keep N newest; older ones marked.
  if (policy.keepLatestPerWorkflow !== undefined) {
    const groups = new Map<string, Artifact[]>();
    for (const a of artifacts) {
      const g = groups.get(a.workflowRunId) ?? [];
      g.push(a);
      groups.set(a.workflowRunId, g);
    }
    for (const [, list] of groups) {
      list.sort(
        (x, y) => new Date(y.createdAt).getTime() - new Date(x.createdAt).getTime(),
      );
      const excess = list.slice(policy.keepLatestPerWorkflow);
      for (const a of excess) {
        reasons
          .get(a)!
          .push(`exceeds keepLatestPerWorkflow=${policy.keepLatestPerWorkflow}`);
      }
    }
  }

  // Policy 3: maxTotalBytes — delete oldest first until total of kept <= limit.
  if (policy.maxTotalBytes !== undefined) {
    // Consider only artifacts not already marked. Sort oldest-first.
    const survivors = artifacts
      .filter((a) => reasons.get(a)!.length === 0)
      .sort(
        (x, y) => new Date(x.createdAt).getTime() - new Date(y.createdAt).getTime(),
      );
    let total = survivors.reduce((s, a) => s + a.sizeBytes, 0);
    for (const a of survivors) {
      if (total <= policy.maxTotalBytes) break;
      reasons
        .get(a)!
        .push(`maxTotalBytes=${policy.maxTotalBytes} exceeded`);
      total -= a.sizeBytes;
    }
  }

  const entries: PlanEntry[] = artifacts.map((a) => {
    const r = reasons.get(a)!;
    return {
      artifact: a,
      action: r.length > 0 ? "delete" : "keep",
      reasons: r,
    };
  });

  const deletedEntries = entries.filter((e) => e.action === "delete");
  return {
    entries,
    summary: {
      totalArtifacts: artifacts.length,
      deleted: deletedEntries.length,
      retained: entries.length - deletedEntries.length,
      bytesReclaimed: deletedEntries.reduce((s, e) => s + e.artifact.sizeBytes, 0),
      dryRun,
    },
  };
}

export function formatPlan(plan: DeletionPlan): string {
  const lines: string[] = [];
  lines.push(`Dry run: ${plan.summary.dryRun}`);
  lines.push(`Total artifacts: ${plan.summary.totalArtifacts}`);
  lines.push(`Delete: ${plan.summary.deleted}`);
  lines.push(`Retain: ${plan.summary.retained}`);
  lines.push(`Bytes reclaimed: ${plan.summary.bytesReclaimed}`);
  for (const e of plan.entries) {
    const reasonStr = e.reasons.length > 0 ? ` (${e.reasons.join("; ")})` : "";
    lines.push(`  [${e.action.toUpperCase()}] ${e.artifact.name}${reasonStr}`);
  }
  return lines.join("\n");
}

// CLI entry point. Reads artifacts JSON from --input, policy from flags.
async function main(argv: string[]): Promise<number> {
  const args = new Map<string, string>();
  const flags = new Set<string>();
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]!;
    if (a.startsWith("--")) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next && !next.startsWith("--")) {
        args.set(key, next);
        i++;
      } else {
        flags.add(key);
      }
    }
  }

  const inputPath = args.get("input");
  if (!inputPath) {
    console.error("Error: --input <path> is required");
    return 2;
  }

  let artifacts: Artifact[];
  try {
    const raw = await Bun.file(inputPath).text();
    artifacts = JSON.parse(raw);
  } catch (err) {
    console.error(`Error reading/parsing ${inputPath}: ${(err as Error).message}`);
    return 2;
  }

  const policy: RetentionPolicy = {};
  if (args.has("max-age-days")) policy.maxAgeDays = Number(args.get("max-age-days"));
  if (args.has("max-total-bytes"))
    policy.maxTotalBytes = Number(args.get("max-total-bytes"));
  if (args.has("keep-latest-per-workflow"))
    policy.keepLatestPerWorkflow = Number(args.get("keep-latest-per-workflow"));

  const now = args.has("now") ? new Date(args.get("now")!) : new Date();
  const dryRun = flags.has("dry-run");

  try {
    const plan = buildPlan(artifacts, policy, { now, dryRun });
    console.log(formatPlan(plan));
    if (!dryRun) {
      console.log(`Executed deletion of ${plan.summary.deleted} artifacts.`);
    }
    return 0;
  } catch (err) {
    console.error(`Error: ${(err as Error).message}`);
    return 1;
  }
}

if (import.meta.main) {
  const code = await main(Bun.argv.slice(2));
  process.exit(code);
}
