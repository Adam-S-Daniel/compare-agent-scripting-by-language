// Artifact cleanup planner.
//
// Applies a set of retention policies to a list of artifacts and produces a
// deletion plan. Policies are applied in order:
//   1. maxAgeDays           — delete artifacts older than N days.
//   2. keepLatestPerWorkflow — keep only the newest N artifacts per workflow run ID.
//   3. maxTotalSizeBytes    — if retained set still exceeds budget, delete
//                              oldest retained artifacts until under budget.
//
// The planner never mutates input and is pure: same input -> same plan.

export interface Artifact {
  id: string;
  name: string;
  sizeBytes: number;
  createdAt: string; // ISO-8601
  workflowRunId: string;
}

export interface Policy {
  maxAgeDays?: number;
  keepLatestPerWorkflow?: number;
  maxTotalSizeBytes?: number;
}

export interface PlanSummary {
  totalArtifacts: number;
  deletedCount: number;
  retainedCount: number;
  bytesReclaimed: number;
  bytesRetained: number;
}

export interface CleanupPlan {
  deleted: Artifact[];
  retained: Artifact[];
  reasons: Record<string, string[]>;
  summary: PlanSummary;
}

function validate(artifacts: Artifact[]): void {
  for (const a of artifacts) {
    if (a.sizeBytes < 0) {
      throw new Error(`artifact ${a.id}: sizeBytes must be >= 0`);
    }
    const t = Date.parse(a.createdAt);
    if (Number.isNaN(t)) {
      throw new Error(`artifact ${a.id}: createdAt is not a valid date`);
    }
  }
}

function addReason(
  reasons: Record<string, string[]>,
  id: string,
  reason: string,
): void {
  (reasons[id] ??= []).push(reason);
}

export function planCleanup(
  artifacts: Artifact[],
  policy: Policy,
  nowMs: number = Date.now(),
): CleanupPlan {
  validate(artifacts);

  const reasons: Record<string, string[]> = {};
  const deletedIds = new Set<string>();

  // Policy 1: max age.
  if (policy.maxAgeDays !== undefined) {
    const cutoff = nowMs - policy.maxAgeDays * 86_400_000;
    for (const a of artifacts) {
      if (Date.parse(a.createdAt) < cutoff) {
        deletedIds.add(a.id);
        addReason(reasons, a.id, `age>${policy.maxAgeDays}d`);
      }
    }
  }

  // Policy 2: keep latest N per workflow.
  if (policy.keepLatestPerWorkflow !== undefined) {
    const byWorkflow = new Map<string, Artifact[]>();
    for (const a of artifacts) {
      if (deletedIds.has(a.id)) continue;
      const list = byWorkflow.get(a.workflowRunId) ?? [];
      list.push(a);
      byWorkflow.set(a.workflowRunId, list);
    }
    for (const list of byWorkflow.values()) {
      // Newest first.
      list.sort(
        (x, y) => Date.parse(y.createdAt) - Date.parse(x.createdAt),
      );
      for (const extra of list.slice(policy.keepLatestPerWorkflow)) {
        deletedIds.add(extra.id);
        addReason(
          reasons,
          extra.id,
          `keep-latest-${policy.keepLatestPerWorkflow}`,
        );
      }
    }
  }

  // Policy 3: max total size — delete oldest retained until under budget.
  if (policy.maxTotalSizeBytes !== undefined) {
    const retained = artifacts
      .filter((a) => !deletedIds.has(a.id))
      .sort((x, y) => Date.parse(x.createdAt) - Date.parse(y.createdAt)); // oldest first
    let total = retained.reduce((s, a) => s + a.sizeBytes, 0);
    for (const a of retained) {
      if (total <= policy.maxTotalSizeBytes) break;
      deletedIds.add(a.id);
      addReason(reasons, a.id, `size-budget`);
      total -= a.sizeBytes;
    }
  }

  const deleted = artifacts.filter((a) => deletedIds.has(a.id));
  const retained = artifacts.filter((a) => !deletedIds.has(a.id));
  const bytesReclaimed = deleted.reduce((s, a) => s + a.sizeBytes, 0);
  const bytesRetained = retained.reduce((s, a) => s + a.sizeBytes, 0);

  return {
    deleted,
    retained,
    reasons,
    summary: {
      totalArtifacts: artifacts.length,
      deletedCount: deleted.length,
      retainedCount: retained.length,
      bytesReclaimed,
      bytesRetained,
    },
  };
}

export function formatSummary(plan: CleanupPlan, dryRun: boolean): string {
  const header = dryRun ? "DRY-RUN: no artifacts will be removed" : "EXECUTING cleanup";
  const s = plan.summary;
  return [
    header,
    `Total artifacts: ${s.totalArtifacts}`,
    `Deleted: ${s.deletedCount}`,
    `Retained: ${s.retainedCount}`,
    `Bytes reclaimed: ${s.bytesReclaimed}`,
    `Bytes retained: ${s.bytesRetained}`,
  ].join("\n");
}

// CLI entrypoint — reads fixture JSON and policy from argv / env and prints
// a plan. Invoked by the GitHub Actions workflow.
//   Usage: bun run cleanup.ts <fixture.json> [--dry-run] [--policy <json>]
async function main(): Promise<void> {
  const args = process.argv.slice(2);
  if (args.length === 0) {
    console.error("usage: bun run cleanup.ts <fixture.json> [--dry-run] [--policy <json>] [--now <iso>]");
    process.exit(2);
  }
  const fixturePath = args[0]!;
  const dryRun = args.includes("--dry-run");
  let policy: Policy = {};
  const pIdx = args.indexOf("--policy");
  if (pIdx >= 0 && args[pIdx + 1]) {
    policy = JSON.parse(args[pIdx + 1]!) as Policy;
  }
  let nowMs = Date.now();
  const nIdx = args.indexOf("--now");
  if (nIdx >= 0 && args[nIdx + 1]) {
    const parsed = Date.parse(args[nIdx + 1]!);
    if (Number.isNaN(parsed)) throw new Error(`invalid --now: ${args[nIdx + 1]}`);
    nowMs = parsed;
  }

  const file = Bun.file(fixturePath);
  if (!(await file.exists())) {
    throw new Error(`fixture not found: ${fixturePath}`);
  }
  const artifacts = (await file.json()) as Artifact[];
  const plan = planCleanup(artifacts, policy, nowMs);

  console.log(formatSummary(plan, dryRun));
  console.log("---");
  console.log(
    JSON.stringify(
      {
        deletedIds: plan.deleted.map((a) => a.id),
        retainedIds: plan.retained.map((a) => a.id),
        summary: plan.summary,
        reasons: plan.reasons,
      },
      null,
      2,
    ),
  );
}

if (import.meta.main) {
  main().catch((e) => {
    console.error(`error: ${(e as Error).message}`);
    process.exit(1);
  });
}
