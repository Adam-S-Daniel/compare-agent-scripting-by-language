// Artifact cleanup planner.
//
// Pure functions in this file decide which artifacts to delete given a
// retention policy. The CLI section at the bottom is the thin wrapper that
// reads JSON, calls the pure functions, and prints a plan.
//
// Approach:
//   1. Apply max-age first — anything older than the cutoff is gone.
//   2. Then keep-latest-N per workflow — drop excess copies of the same
//      workflow, keeping the newest N.
//   3. Then max-total-size — among survivors, drop oldest until under budget.
// Each rule is additive: once an artifact is marked for deletion, it stays
// deleted. This makes the policy easy to reason about.

const DAY_MS = 24 * 60 * 60 * 1000;

export interface Artifact {
  name: string;
  sizeBytes: number;
  createdAt: string; // ISO 8601
  workflowRunId: string;
  workflowName: string;
}

export interface RetentionPolicy {
  maxAgeDays?: number;
  keepLatestPerWorkflow?: number;
  maxTotalSizeBytes?: number;
}

export interface CleanupPlan {
  toDelete: Artifact[];
  toKeep: Artifact[];
  reasons: Record<string, string>;
  summary: {
    totalArtifacts: number;
    deletedCount: number;
    retainedCount: number;
    bytesReclaimed: number;
    bytesRetained: number;
  };
}

// Core: apply all three policies and return a plan. `now` is injected for
// deterministic testing.
export function applyRetention(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  now: Date = new Date(),
): CleanupPlan {
  const reasons: Record<string, string> = {};
  const deleted = new Set<string>();

  // Stable sort: newest first. Ties broken by name so output is deterministic.
  const sorted = [...artifacts].sort((a, b) => {
    const t = Date.parse(b.createdAt) - Date.parse(a.createdAt);
    return t !== 0 ? t : a.name.localeCompare(b.name);
  });

  // Rule 1: max age.
  if (policy.maxAgeDays !== undefined) {
    const cutoff = now.getTime() - policy.maxAgeDays * DAY_MS;
    for (const a of sorted) {
      if (Date.parse(a.createdAt) < cutoff) {
        deleted.add(a.name);
        reasons[a.name] = `older than ${policy.maxAgeDays} days`;
      }
    }
  }

  // Rule 2: keep latest N per workflow (only consider not-yet-deleted).
  if (policy.keepLatestPerWorkflow !== undefined) {
    const groups = new Map<string, Artifact[]>();
    for (const a of sorted) {
      if (deleted.has(a.name)) continue;
      const g = groups.get(a.workflowName) ?? [];
      g.push(a);
      groups.set(a.workflowName, g);
    }
    for (const [wf, members] of groups) {
      // sorted is already newest-first; slice off the survivors.
      const excess = members.slice(policy.keepLatestPerWorkflow);
      for (const a of excess) {
        deleted.add(a.name);
        reasons[a.name] =
          `exceeds keep-latest-${policy.keepLatestPerWorkflow} for workflow '${wf}'`;
      }
    }
  }

  // Rule 3: max total size — evict oldest survivors until we fit.
  if (policy.maxTotalSizeBytes !== undefined) {
    const survivors = sorted.filter((a) => !deleted.has(a.name));
    let total = survivors.reduce((sum, a) => sum + a.sizeBytes, 0);
    // Walk oldest-first.
    const oldestFirst = [...survivors].reverse();
    for (const a of oldestFirst) {
      if (total <= policy.maxTotalSizeBytes) break;
      deleted.add(a.name);
      reasons[a.name] =
        `total size budget ${policy.maxTotalSizeBytes} bytes exceeded`;
      total -= a.sizeBytes;
    }
  }

  const toDelete = artifacts.filter((a) => deleted.has(a.name));
  const toKeep = artifacts.filter((a) => !deleted.has(a.name));
  const bytesReclaimed = toDelete.reduce((s, a) => s + a.sizeBytes, 0);
  const bytesRetained = toKeep.reduce((s, a) => s + a.sizeBytes, 0);

  return {
    toDelete,
    toKeep,
    reasons,
    summary: {
      totalArtifacts: artifacts.length,
      deletedCount: toDelete.length,
      retainedCount: toKeep.length,
      bytesReclaimed,
      bytesRetained,
    },
  };
}

// Render a plan as a human-readable report. Includes a DRY RUN banner when
// dryRun is true, so operators can tell whether deletions actually happened.
export function formatPlan(
  plan: CleanupPlan,
  opts: { dryRun: boolean },
): string {
  const lines: string[] = [];
  if (opts.dryRun) {
    lines.push("=== DRY RUN — no artifacts will be deleted ===");
  }
  lines.push("Artifact cleanup plan");
  lines.push("---------------------");
  lines.push(`Total artifacts: ${plan.summary.totalArtifacts}`);
  lines.push(`To delete: ${plan.summary.deletedCount}`);
  lines.push(`To retain: ${plan.summary.retainedCount}`);
  lines.push(`Bytes reclaimed: ${plan.summary.bytesReclaimed}`);
  lines.push(`Bytes retained: ${plan.summary.bytesRetained}`);
  if (plan.toDelete.length > 0) {
    lines.push("");
    lines.push("Deletions:");
    for (const a of plan.toDelete) {
      const reason = plan.reasons[a.name] ?? "policy match";
      lines.push(`  - ${a.name} (${a.sizeBytes} bytes) — ${reason}`);
    }
  }
  return lines.join("\n");
}

// Parse and validate a JSON string into an Artifact[]. We surface specific
// errors rather than letting JSON.parse / undefined-property access fail
// with cryptic messages.
export function parseArtifacts(json: string): Artifact[] {
  let raw: unknown;
  try {
    raw = JSON.parse(json);
  } catch (e) {
    throw new Error(
      `Failed to parse artifacts JSON: ${(e as Error).message}`,
    );
  }
  if (!Array.isArray(raw)) {
    throw new Error("Expected artifacts JSON to be an array");
  }
  const required = [
    "name",
    "sizeBytes",
    "createdAt",
    "workflowRunId",
    "workflowName",
  ] as const;
  return raw.map((entry, i) => {
    if (typeof entry !== "object" || entry === null) {
      throw new Error(`Artifact ${i} is not an object`);
    }
    const obj = entry as Record<string, unknown>;
    for (const key of required) {
      if (!(key in obj)) {
        throw new Error(`Artifact ${i} missing required field: ${key}`);
      }
    }
    return {
      name: String(obj.name),
      sizeBytes: Number(obj.sizeBytes),
      createdAt: String(obj.createdAt),
      workflowRunId: String(obj.workflowRunId),
      workflowName: String(obj.workflowName),
    };
  });
}

// CLI entry. Usage:
//   bun run cleanup.ts --input <file> [--policy <file>] [--dry-run]
//
// Both files are JSON. The policy file may include any subset of
// maxAgeDays / keepLatestPerWorkflow / maxTotalSizeBytes. Output goes to
// stdout. A non-zero exit code signals an error (bad input, missing file).
async function main(argv: string[]): Promise<number> {
  const args = parseArgs(argv);
  if (args.help) {
    console.log(usage());
    return 0;
  }
  if (!args.input) {
    console.error("Error: --input <path> is required");
    console.error(usage());
    return 2;
  }
  try {
    const artifactsJson = await Bun.file(args.input).text();
    const artifacts = parseArtifacts(artifactsJson);
    let policy: RetentionPolicy = {};
    if (args.policy) {
      const policyJson = await Bun.file(args.policy).text();
      policy = JSON.parse(policyJson) as RetentionPolicy;
    }
    const now = args.now ? new Date(args.now) : new Date();
    if (Number.isNaN(now.getTime())) {
      throw new Error(`Invalid --now value: ${args.now}`);
    }
    const plan = applyRetention(artifacts, policy, now);
    console.log(formatPlan(plan, { dryRun: args.dryRun }));
    // Also emit a single-line machine-readable summary that the act harness
    // can grep for. Format: SUMMARY {json}
    console.log(`SUMMARY ${JSON.stringify(plan.summary)}`);
    return 0;
  } catch (e) {
    console.error(`Error: ${(e as Error).message}`);
    return 1;
  }
}

interface ParsedArgs {
  input?: string;
  policy?: string;
  now?: string;
  dryRun: boolean;
  help: boolean;
}

function parseArgs(argv: string[]): ParsedArgs {
  const out: ParsedArgs = { dryRun: false, help: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--input" || a === "-i") out.input = argv[++i];
    else if (a === "--policy" || a === "-p") out.policy = argv[++i];
    else if (a === "--now") out.now = argv[++i];
    else if (a === "--dry-run") out.dryRun = true;
    else if (a === "--help" || a === "-h") out.help = true;
  }
  return out;
}

function usage(): string {
  return [
    "Usage: bun run cleanup.ts --input <artifacts.json> [--policy <policy.json>] [--dry-run]",
    "",
    "  --input, -i   Path to JSON file with an array of artifacts",
    "  --policy, -p  Path to JSON file with retention policy",
    "  --dry-run     Print plan with DRY RUN banner; do not actually delete",
    "  --help, -h    Show this help",
  ].join("\n");
}

// Only run when invoked directly (not when imported by tests).
if (import.meta.main) {
  process.exit(await main(Bun.argv.slice(2)));
}
