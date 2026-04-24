// Artifact cleanup script: applies retention policies and generates a deletion plan.

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

export interface DeletionPlanSummary {
  totalArtifacts: number;
  deletedCount: number;
  retainedCount: number;
  spaceReclaimedBytes: number;
}

export interface DeletionPlan {
  dryRun: boolean;
  toDelete: Artifact[];
  toKeep: Artifact[];
  summary: DeletionPlanSummary;
}

export interface PlanOptions {
  dryRun: boolean;
  now?: Date;
}

// Collect IDs flagged for deletion by each policy rule, then partition.
export function applyRetentionPolicies(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  now: Date = new Date()
): PolicyResult {
  const deleteIds = new Set<string>();

  // Rule 1: max age
  if (policy.maxAgeDays !== undefined) {
    const maxAgeMs = policy.maxAgeDays * 24 * 60 * 60 * 1000;
    for (const a of artifacts) {
      if (now.getTime() - a.createdAt.getTime() > maxAgeMs) {
        deleteIds.add(a.id);
      }
    }
  }

  // Rule 2: max total size — delete oldest first until under limit
  if (policy.maxTotalSizeBytes !== undefined) {
    const sorted = [...artifacts].sort(
      (x, y) => x.createdAt.getTime() - y.createdAt.getTime()
    );
    let totalBytes = artifacts.reduce((sum, a) => sum + a.sizeBytes, 0);
    for (const a of sorted) {
      if (totalBytes <= policy.maxTotalSizeBytes) break;
      deleteIds.add(a.id);
      totalBytes -= a.sizeBytes;
    }
  }

  // Rule 3: keep latest N per workflow — group by workflowRunId, delete oldest beyond N
  if (policy.keepLatestNPerWorkflow !== undefined) {
    const byWorkflow = new Map<string, Artifact[]>();
    for (const a of artifacts) {
      const group = byWorkflow.get(a.workflowRunId) ?? [];
      group.push(a);
      byWorkflow.set(a.workflowRunId, group);
    }
    for (const [, group] of byWorkflow) {
      const sorted = [...group].sort(
        (x, y) => y.createdAt.getTime() - x.createdAt.getTime() // newest first
      );
      for (const a of sorted.slice(policy.keepLatestNPerWorkflow)) {
        deleteIds.add(a.id);
      }
    }
  }

  const toDelete = artifacts.filter((a) => deleteIds.has(a.id));
  const toKeep = artifacts.filter((a) => !deleteIds.has(a.id));
  return { toDelete, toKeep };
}

export function generateDeletionPlan(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  options: PlanOptions
): DeletionPlan {
  const now = options.now ?? new Date();
  const { toDelete, toKeep } = applyRetentionPolicies(artifacts, policy, now);
  const spaceReclaimedBytes = toDelete.reduce((sum, a) => sum + a.sizeBytes, 0);

  return {
    dryRun: options.dryRun,
    toDelete,
    toKeep,
    summary: {
      totalArtifacts: artifacts.length,
      deletedCount: toDelete.length,
      retainedCount: toKeep.length,
      spaceReclaimedBytes,
    },
  };
}

// Format bytes as human-readable string
function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(2)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
}

// Print a human-readable summary of the plan
function printPlan(plan: DeletionPlan): void {
  const mode = plan.dryRun ? "[DRY RUN] " : "";
  console.log(`${mode}Artifact Cleanup Plan`);
  console.log("=".repeat(40));
  console.log(`Total artifacts:   ${plan.summary.totalArtifacts}`);
  console.log(`To delete:         ${plan.summary.deletedCount}`);
  console.log(`To retain:         ${plan.summary.retainedCount}`);
  console.log(`Space reclaimed:   ${formatBytes(plan.summary.spaceReclaimedBytes)}`);
  if (plan.toDelete.length > 0) {
    console.log("\nArtifacts marked for deletion:");
    for (const a of plan.toDelete) {
      console.log(
        `  - ${a.name} (${formatBytes(a.sizeBytes)}, created ${a.createdAt.toISOString()})`
      );
    }
  }
}

// CLI entry point
if (import.meta.main) {
  // Mock data for demonstration
  const mockArtifacts: Artifact[] = [
    {
      id: "1",
      name: "build-linux-x64",
      sizeBytes: 120 * 1024 * 1024,
      createdAt: new Date("2024-01-01T00:00:00Z"),
      workflowRunId: "build-workflow",
    },
    {
      id: "2",
      name: "build-linux-arm64",
      sizeBytes: 110 * 1024 * 1024,
      createdAt: new Date("2024-01-05T00:00:00Z"),
      workflowRunId: "build-workflow",
    },
    {
      id: "3",
      name: "build-windows-x64",
      sizeBytes: 200 * 1024 * 1024,
      createdAt: new Date("2024-01-10T00:00:00Z"),
      workflowRunId: "build-workflow",
    },
    {
      id: "4",
      name: "test-results",
      sizeBytes: 5 * 1024 * 1024,
      createdAt: new Date("2024-01-14T00:00:00Z"),
      workflowRunId: "test-workflow",
    },
    {
      id: "5",
      name: "coverage-report",
      sizeBytes: 2 * 1024 * 1024,
      createdAt: new Date("2024-01-15T00:00:00Z"),
      workflowRunId: "test-workflow",
    },
  ];

  const policy: RetentionPolicy = {
    maxAgeDays: 10,
    maxTotalSizeBytes: 300 * 1024 * 1024,
    keepLatestNPerWorkflow: 2,
  };

  const dryRun = process.argv.includes("--dry-run");
  const now = new Date("2024-01-15T12:00:00Z");
  const plan = generateDeletionPlan(mockArtifacts, policy, { dryRun, now });
  printPlan(plan);

  if (!dryRun) {
    console.log("\n(In a real scenario, deletions would be executed here.)");
  }

  // Output machine-readable summary for CI parsing
  const summary = {
    totalArtifacts: plan.summary.totalArtifacts,
    deletedCount: plan.summary.deletedCount,
    retainedCount: plan.summary.retainedCount,
    spaceReclaimedBytes: plan.summary.spaceReclaimedBytes,
    dryRun: plan.dryRun,
  };
  console.log("\nSUMMARY_JSON=" + JSON.stringify(summary));
}
