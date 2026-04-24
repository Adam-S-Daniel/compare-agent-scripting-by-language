// Artifact Cleanup Script
// Applies retention policies to a list of artifacts and generates a deletion plan.
// Supports: max age, max total size, keep-latest-N per workflow, dry-run mode.

import * as fs from "fs";
import * as path from "path";

// --- Types ---

export interface Artifact {
  name: string;
  size: number; // bytes
  createdAt: Date;
  workflowRunId: string;
}

// Raw artifact as read from JSON (dates are strings)
interface ArtifactJSON {
  name: string;
  size: number;
  createdAt: string;
  workflowRunId: string;
}

export interface RetentionPolicy {
  maxAgeDays?: number;
  maxTotalSizeBytes?: number;
  keepLatestNPerWorkflow?: number;
}

export interface DeletionPlan {
  toDelete: Artifact[];
  toKeep: Artifact[];
  totalSpaceReclaimed: number;
  summary: {
    totalArtifacts: number;
    artifactsToDelete: number;
    artifactsToKeep: number;
    spaceReclaimedBytes: number;
    spaceReclaimedMB: number;
    dryRun: boolean;
  };
}

// --- Core logic ---

export function applyRetentionPolicies(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  dryRun: boolean = false,
  now: Date = new Date()
): DeletionPlan {
  // Use a Set of artifact names to track which are marked for deletion.
  // Names are assumed unique in the input list.
  const toDeleteNames = new Set<string>();

  // 1. Age policy: delete artifacts older than maxAgeDays
  if (policy.maxAgeDays !== undefined) {
    const cutoffMs = now.getTime() - policy.maxAgeDays * 24 * 60 * 60 * 1000;
    for (const artifact of artifacts) {
      if (artifact.createdAt.getTime() < cutoffMs) {
        toDeleteNames.add(artifact.name);
      }
    }
  }

  // 2. Keep-latest-N per workflow: for each workflowRunId, keep only the N newest
  if (policy.keepLatestNPerWorkflow !== undefined) {
    const byWorkflow = new Map<string, Artifact[]>();
    for (const artifact of artifacts) {
      const group = byWorkflow.get(artifact.workflowRunId) ?? [];
      group.push(artifact);
      byWorkflow.set(artifact.workflowRunId, group);
    }

    for (const [, group] of byWorkflow) {
      // Sort descending by creation date — newest first
      const sorted = [...group].sort(
        (a, b) => b.createdAt.getTime() - a.createdAt.getTime()
      );
      // Everything beyond index N-1 is excess
      for (let i = policy.keepLatestNPerWorkflow; i < sorted.length; i++) {
        toDeleteNames.add(sorted[i].name);
      }
    }
  }

  // 3. Max total size: after the above deletions, if remaining size still exceeds
  //    the budget, delete oldest remaining artifacts until under budget.
  if (policy.maxTotalSizeBytes !== undefined) {
    const remaining = artifacts.filter((a) => !toDeleteNames.has(a.name));
    const totalSize = remaining.reduce((sum, a) => sum + a.size, 0);

    if (totalSize > policy.maxTotalSizeBytes) {
      // Oldest first — we delete from the oldest end to preserve recent artifacts
      const sorted = [...remaining].sort(
        (a, b) => a.createdAt.getTime() - b.createdAt.getTime()
      );
      let currentSize = totalSize;
      for (const artifact of sorted) {
        if (currentSize <= policy.maxTotalSizeBytes) break;
        toDeleteNames.add(artifact.name);
        currentSize -= artifact.size;
      }
    }
  }

  const toDelete = artifacts.filter((a) => toDeleteNames.has(a.name));
  const toKeep = artifacts.filter((a) => !toDeleteNames.has(a.name));
  const totalSpaceReclaimed = toDelete.reduce((sum, a) => sum + a.size, 0);
  const spaceReclaimedMB =
    Math.round((totalSpaceReclaimed / (1024 * 1024)) * 100) / 100;

  return {
    toDelete,
    toKeep,
    totalSpaceReclaimed,
    summary: {
      totalArtifacts: artifacts.length,
      artifactsToDelete: toDelete.length,
      artifactsToKeep: toKeep.length,
      spaceReclaimedBytes: totalSpaceReclaimed,
      spaceReclaimedMB,
      dryRun,
    },
  };
}

export function formatDeletionPlan(plan: DeletionPlan): string {
  const { summary } = plan;
  const lines: string[] = [];

  lines.push("=== Artifact Cleanup Plan ===");
  if (summary.dryRun) {
    lines.push("[DRY RUN] No artifacts will actually be deleted");
  }
  lines.push("");
  lines.push(`Total artifacts: ${summary.totalArtifacts}`);
  lines.push(`Artifacts to delete: ${summary.artifactsToDelete}`);
  lines.push(`Artifacts to keep: ${summary.artifactsToKeep}`);
  lines.push(
    `Space to reclaim: ${summary.spaceReclaimedMB.toFixed(2)} MB (${summary.spaceReclaimedBytes} bytes)`
  );
  lines.push("");

  if (plan.toDelete.length > 0) {
    lines.push("Artifacts marked for deletion:");
    for (const a of plan.toDelete) {
      const mb = (a.size / (1024 * 1024)).toFixed(2);
      lines.push(
        `  - ${a.name} | ${mb} MB | workflow: ${a.workflowRunId} | created: ${a.createdAt.toISOString()}`
      );
    }
  } else {
    lines.push("No artifacts to delete.");
  }

  if (plan.toKeep.length > 0) {
    lines.push("");
    lines.push("Artifacts retained:");
    for (const a of plan.toKeep) {
      const mb = (a.size / (1024 * 1024)).toFixed(2);
      lines.push(`  - ${a.name} | ${mb} MB | workflow: ${a.workflowRunId}`);
    }
  }

  return lines.join("\n");
}

// --- JSON deserialization helper ---

export function parseArtifacts(raw: ArtifactJSON[]): Artifact[] {
  return raw.map((r) => ({
    name: r.name,
    size: r.size,
    createdAt: new Date(r.createdAt),
    workflowRunId: r.workflowRunId,
  }));
}

// --- CLI entry point ---

if (import.meta.main) {
  const args = process.argv.slice(2);

  function getFlag(flag: string): string | undefined {
    const idx = args.indexOf(flag);
    return idx !== -1 ? args[idx + 1] : undefined;
  }

  const fixturesFile = getFlag("--fixtures");
  const policyFile = getFlag("--policy");
  const dryRun = args.includes("--dry-run");

  if (!fixturesFile || !policyFile) {
    console.error(
      "Usage: bun run artifact-cleanup.ts --fixtures <file> --policy <file> [--dry-run]"
    );
    process.exit(1);
  }

  // Resolve paths relative to CWD
  const fixturesPath = path.resolve(process.cwd(), fixturesFile);
  const policyPath = path.resolve(process.cwd(), policyFile);

  if (!fs.existsSync(fixturesPath)) {
    console.error(`Error: fixtures file not found: ${fixturesPath}`);
    process.exit(1);
  }
  if (!fs.existsSync(policyPath)) {
    console.error(`Error: policy file not found: ${policyPath}`);
    process.exit(1);
  }

  let rawArtifacts: ArtifactJSON[];
  let policy: RetentionPolicy;

  try {
    rawArtifacts = JSON.parse(fs.readFileSync(fixturesPath, "utf-8"));
  } catch (e) {
    console.error(`Error: failed to parse fixtures file: ${(e as Error).message}`);
    process.exit(1);
  }

  try {
    policy = JSON.parse(fs.readFileSync(policyPath, "utf-8"));
  } catch (e) {
    console.error(`Error: failed to parse policy file: ${(e as Error).message}`);
    process.exit(1);
  }

  const artifacts = parseArtifacts(rawArtifacts);
  const plan = applyRetentionPolicies(artifacts, policy, dryRun);
  const output = formatDeletionPlan(plan);

  console.log(output);
  console.log("");
  console.log("JSON Summary:");
  console.log(JSON.stringify(plan.summary, null, 2));
}
