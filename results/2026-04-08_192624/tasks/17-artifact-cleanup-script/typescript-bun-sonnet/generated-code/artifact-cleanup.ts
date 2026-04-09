/**
 * Artifact Cleanup Script
 *
 * Applies configurable retention policies to a list of CI/CD artifacts,
 * determines which ones to delete, and produces a structured deletion plan.
 *
 * Retention policies (all optional, combined via union-of-deletions):
 *   - maxAgeDays:             delete artifacts older than N days
 *   - maxTotalSizeMB:         delete oldest artifacts until total size is under limit
 *   - keepLatestNPerWorkflow: keep only the N most recent artifacts per workflow run ID
 *
 * Usage:
 *   bun run artifact-cleanup.ts [--dry-run] [--policy-file policy.json] [--artifacts-file artifacts.json]
 */

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** A single CI/CD artifact with metadata. */
export interface Artifact {
  /** Human-readable name of the artifact. */
  name: string;
  /** Size in megabytes. */
  sizeMB: number;
  /** Timestamp when the artifact was created. */
  createdAt: Date;
  /** Identifier for the workflow run that produced this artifact. */
  workflowRunId: string;
}

/** Configurable retention policies. All fields are optional. */
export interface RetentionPolicy {
  /** Delete artifacts older than this many days. */
  maxAgeDays?: number;
  /** Delete oldest artifacts until the total storage is under this limit (MB). */
  maxTotalSizeMB?: number;
  /** Keep only the N most recent artifacts for each workflow run ID. */
  keepLatestNPerWorkflow?: number;
}

/** Result of applying retention policies — before summary is computed. */
interface PartitionResult {
  toDelete: Artifact[];
  toRetain: Artifact[];
}

/** Summary statistics for a deletion plan. */
export interface DeletionSummary {
  totalArtifacts: number;
  toDeleteCount: number;
  toRetainCount: number;
  spaceReclaimedMB: number;
  spaceSavedPercent: number;
}

/** Full deletion plan returned to callers and printed at runtime. */
export interface DeletionPlan {
  toDelete: Artifact[];
  toRetain: Artifact[];
  summary: DeletionSummary;
  /** When true, no actual deletions are performed. */
  dryRun: boolean;
}

/** Options for generateDeletionPlan. */
export interface PlanOptions {
  dryRun?: boolean;
}

// ---------------------------------------------------------------------------
// Core logic
// ---------------------------------------------------------------------------

/**
 * Apply all enabled retention policies to an artifact list.
 *
 * Each policy independently decides which artifacts should be deleted.
 * The final set of artifacts to delete is the UNION of all per-policy sets.
 *
 * @param artifacts - Input artifact list (order does not matter).
 * @param policy    - Retention policy configuration.
 * @param now       - Reference time for age calculations (defaults to current date).
 * @returns Partition of artifacts into toDelete / toRetain arrays.
 */
export function applyRetentionPolicies(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  now: Date = new Date()
): PartitionResult {
  // Collect names of artifacts that must be deleted by any policy.
  const deleteSet = new Set<string>();

  // --- Policy 1: max-age ---
  if (policy.maxAgeDays !== undefined) {
    const cutoffMs = policy.maxAgeDays * 24 * 60 * 60 * 1000;
    for (const artifact of artifacts) {
      const ageMs = now.getTime() - artifact.createdAt.getTime();
      if (ageMs > cutoffMs) {
        deleteSet.add(artifact.name);
      }
    }
  }

  // --- Policy 2: max total size (delete oldest first) ---
  if (policy.maxTotalSizeMB !== undefined) {
    // Sort by creation date ascending (oldest first) for greedy deletion.
    const sorted = [...artifacts].sort(
      (a, b) => a.createdAt.getTime() - b.createdAt.getTime()
    );
    let totalMB = sorted.reduce((sum, a) => sum + a.sizeMB, 0);
    for (const artifact of sorted) {
      if (totalMB <= policy.maxTotalSizeMB) break;
      deleteSet.add(artifact.name);
      totalMB -= artifact.sizeMB;
    }
  }

  // --- Policy 3: keep-latest-N per workflow ---
  if (policy.keepLatestNPerWorkflow !== undefined) {
    // Group artifacts by workflowRunId.
    const byWorkflow = new Map<string, Artifact[]>();
    for (const artifact of artifacts) {
      const group = byWorkflow.get(artifact.workflowRunId) ?? [];
      group.push(artifact);
      byWorkflow.set(artifact.workflowRunId, group);
    }
    // Within each group, sort descending (newest first) and mark excess as deleted.
    for (const [, group] of byWorkflow) {
      group.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
      const excess = group.slice(policy.keepLatestNPerWorkflow);
      for (const artifact of excess) {
        deleteSet.add(artifact.name);
      }
    }
  }

  // Partition artifacts using the accumulated delete set.
  const toDelete: Artifact[] = [];
  const toRetain: Artifact[] = [];
  for (const artifact of artifacts) {
    if (deleteSet.has(artifact.name)) {
      toDelete.push(artifact);
    } else {
      toRetain.push(artifact);
    }
  }

  return { toDelete, toRetain };
}

/**
 * Generate a full deletion plan including a summary.
 *
 * @param artifacts - Input artifact list.
 * @param policy    - Retention policy configuration.
 * @param now       - Reference time (defaults to current date).
 * @param options   - Plan options (dry-run, etc.).
 */
export function generateDeletionPlan(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  now: Date = new Date(),
  options: PlanOptions = {}
): DeletionPlan {
  const { toDelete, toRetain } = applyRetentionPolicies(artifacts, policy, now);
  const dryRun = options.dryRun ?? false;

  const spaceReclaimedMB = toDelete.reduce((sum, a) => sum + a.sizeMB, 0);
  const totalSizeMB = artifacts.reduce((sum, a) => sum + a.sizeMB, 0);
  const spaceSavedPercent =
    totalSizeMB > 0 ? (spaceReclaimedMB / totalSizeMB) * 100 : 0;

  const summary: DeletionSummary = {
    totalArtifacts: artifacts.length,
    toDeleteCount: toDelete.length,
    toRetainCount: toRetain.length,
    spaceReclaimedMB,
    spaceSavedPercent,
  };

  return { toDelete, toRetain, summary, dryRun };
}

// ---------------------------------------------------------------------------
// Pretty-print helpers
// ---------------------------------------------------------------------------

function formatMB(mb: number): string {
  return mb >= 1024
    ? `${(mb / 1024).toFixed(2)} GB`
    : `${mb.toFixed(2)} MB`;
}

function printPlan(plan: DeletionPlan): void {
  const { summary, dryRun } = plan;
  const mode = dryRun ? "[DRY RUN] " : "";

  console.log(`\n${mode}=== Artifact Deletion Plan ===`);
  console.log(`Total artifacts:    ${summary.totalArtifacts}`);
  console.log(`To delete:          ${summary.toDeleteCount}`);
  console.log(`To retain:          ${summary.toRetainCount}`);
  console.log(`Space reclaimed:    ${formatMB(summary.spaceReclaimedMB)} (${summary.spaceSavedPercent.toFixed(1)}%)`);

  if (plan.toDelete.length > 0) {
    console.log("\nArtifacts to delete:");
    for (const a of plan.toDelete) {
      console.log(`  - ${a.name} (${formatMB(a.sizeMB)}, run=${a.workflowRunId}, created=${a.createdAt.toISOString()})`);
    }
  }

  if (plan.toRetain.length > 0) {
    console.log("\nArtifacts to retain:");
    for (const a of plan.toRetain) {
      console.log(`  + ${a.name} (${formatMB(a.sizeMB)}, run=${a.workflowRunId}, created=${a.createdAt.toISOString()})`);
    }
  }

  if (dryRun) {
    console.log("\n[DRY RUN] No artifacts were actually deleted.");
  } else {
    console.log(`\nDeletion plan complete. ${summary.toDeleteCount} artifact(s) would be removed.`);
  }
}

// ---------------------------------------------------------------------------
// CLI entry point
// ---------------------------------------------------------------------------

/**
 * Demonstrate the script with built-in mock data.
 * In a real GitHub Actions workflow you would pass artifact data
 * from the GitHub API (e.g., via gh CLI) as JSON files.
 */
function runCLI(): void {
  const args = process.argv.slice(2);
  const dryRun = args.includes("--dry-run");

  // Built-in mock data for standalone execution / CI demo
  const mockArtifacts: Artifact[] = [
    { name: "build-linux-main", sizeMB: 150, createdAt: new Date("2024-01-10T00:00:00Z"), workflowRunId: "wf-build" },
    { name: "build-linux-feat", sizeMB: 145, createdAt: new Date("2024-02-01T00:00:00Z"), workflowRunId: "wf-build" },
    { name: "build-linux-release", sizeMB: 148, createdAt: new Date("2024-03-15T00:00:00Z"), workflowRunId: "wf-build" },
    { name: "test-report-run1", sizeMB: 5, createdAt: new Date("2024-04-01T00:00:00Z"), workflowRunId: "wf-test" },
    { name: "test-report-run2", sizeMB: 6, createdAt: new Date("2024-04-15T00:00:00Z"), workflowRunId: "wf-test" },
    { name: "coverage-latest", sizeMB: 12, createdAt: new Date("2024-05-20T00:00:00Z"), workflowRunId: "wf-test" },
    { name: "docker-cache", sizeMB: 800, createdAt: new Date("2024-03-01T00:00:00Z"), workflowRunId: "wf-docker" },
    { name: "storybook-preview", sizeMB: 30, createdAt: new Date("2024-05-25T00:00:00Z"), workflowRunId: "wf-docs" },
  ];

  const policy: RetentionPolicy = {
    maxAgeDays: 60,       // delete anything older than 60 days
    maxTotalSizeMB: 500,  // keep total storage under 500 MB
    keepLatestNPerWorkflow: 2, // keep only 2 most recent per workflow
  };

  const now = new Date(); // use real current time for CLI
  const plan = generateDeletionPlan(mockArtifacts, policy, now, { dryRun });

  printPlan(plan);

  // Output a machine-readable JSON summary for downstream workflow steps
  const jsonSummary = {
    dryRun: plan.dryRun,
    summary: plan.summary,
    toDeleteNames: plan.toDelete.map((a) => a.name),
    toRetainNames: plan.toRetain.map((a) => a.name),
  };
  console.log("\n--- JSON Summary ---");
  console.log(JSON.stringify(jsonSummary, null, 2));
}

// Only execute CLI when run directly (not when imported as a module in tests)
if (import.meta.main) {
  runCLI();
}
