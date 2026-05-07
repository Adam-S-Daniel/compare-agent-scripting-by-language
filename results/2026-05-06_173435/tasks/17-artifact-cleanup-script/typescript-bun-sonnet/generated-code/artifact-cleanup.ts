// Artifact Cleanup Script
// Applies retention policies to a list of artifacts and generates a deletion plan.

import { readFileSync } from "fs";

// ── Types ─────────────────────────────────────────────────────────────────────

export interface Artifact {
  name: string;
  size: number;        // bytes
  createdAt: Date;
  workflowRunId: string;
}

export interface RetentionPolicy {
  maxAgeDays?: number;        // delete artifacts older than N days
  maxTotalSizeBytes?: number; // delete oldest until total ≤ this
  keepLatestN?: number;       // keep only N newest per workflowRunId
}

export interface DeletionSummary {
  totalArtifacts: number;
  artifactsDeleted: number;
  artifactsRetained: number;
  spaceReclaimed: number; // bytes
}

export interface DeletionPlan {
  toDelete: Artifact[];
  toRetain: Artifact[];
  summary: DeletionSummary;
  dryRun: boolean;
}

interface PolicyResult {
  toDelete: Artifact[];
  toRetain: Artifact[];
}

// ── Policy functions ──────────────────────────────────────────────────────────

/** Marks artifacts as to-delete if they are strictly older than maxAgeDays. */
export function applyMaxAge(
  artifacts: Artifact[],
  maxAgeDays: number | undefined,
  now: Date
): PolicyResult {
  if (maxAgeDays === undefined) {
    return { toDelete: [], toRetain: [...artifacts] };
  }
  const toDelete: Artifact[] = [];
  const toRetain: Artifact[] = [];
  for (const artifact of artifacts) {
    const ageDays = (now.getTime() - artifact.createdAt.getTime()) / (1000 * 60 * 60 * 24);
    if (ageDays > maxAgeDays) {
      toDelete.push(artifact);
    } else {
      toRetain.push(artifact);
    }
  }
  return { toDelete, toRetain };
}

/** Within each workflowRunId group, keeps only the N most recent artifacts. */
export function applyKeepLatestN(
  artifacts: Artifact[],
  keepLatestN: number | undefined
): PolicyResult {
  if (keepLatestN === undefined) {
    return { toDelete: [], toRetain: [...artifacts] };
  }

  // Group by workflowRunId
  const groups = new Map<string, Artifact[]>();
  for (const artifact of artifacts) {
    const group = groups.get(artifact.workflowRunId) ?? [];
    group.push(artifact);
    groups.set(artifact.workflowRunId, group);
  }

  const toDelete: Artifact[] = [];
  const toRetain: Artifact[] = [];

  for (const group of groups.values()) {
    // Sort newest first
    const sorted = group.slice().sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
    toRetain.push(...sorted.slice(0, keepLatestN));
    toDelete.push(...sorted.slice(keepLatestN));
  }

  return { toDelete, toRetain };
}

/** Deletes oldest artifacts (by createdAt) until total size ≤ maxTotalSizeBytes. */
export function applyMaxTotalSize(
  artifacts: Artifact[],
  maxTotalSizeBytes: number | undefined
): PolicyResult {
  if (maxTotalSizeBytes === undefined) {
    return { toDelete: [], toRetain: [...artifacts] };
  }

  const totalSize = artifacts.reduce((sum, a) => sum + a.size, 0);
  if (totalSize <= maxTotalSizeBytes) {
    return { toDelete: [], toRetain: [...artifacts] };
  }

  // Sort oldest first — those are deleted first
  const sorted = artifacts.slice().sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
  const toDelete: Artifact[] = [];
  let remaining = totalSize;

  for (const artifact of sorted) {
    if (remaining <= maxTotalSizeBytes) break;
    toDelete.push(artifact);
    remaining -= artifact.size;
  }

  const deleteSet = new Set(toDelete);
  const toRetain = artifacts.filter((a) => !deleteSet.has(a));
  return { toDelete, toRetain };
}

// ── Combine all policies ──────────────────────────────────────────────────────

/** Applies all retention policies and returns a deduplicated deletion plan. */
export function applyRetentionPolicies(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  options: { now?: Date; dryRun?: boolean } = {}
): DeletionPlan {
  const now = options.now ?? new Date();
  const dryRun = options.dryRun ?? false;

  const ageResult = applyMaxAge(artifacts, policy.maxAgeDays, now);
  const sizeResult = applyMaxTotalSize(artifacts, policy.maxTotalSizeBytes);
  const latestResult = applyKeepLatestN(artifacts, policy.keepLatestN);

  // Union of all artifacts flagged for deletion (deduplicated by reference)
  const deleteSet = new Set<Artifact>([
    ...ageResult.toDelete,
    ...sizeResult.toDelete,
    ...latestResult.toDelete,
  ]);

  const toDelete = artifacts.filter((a) => deleteSet.has(a));
  const toRetain = artifacts.filter((a) => !deleteSet.has(a));
  const spaceReclaimed = toDelete.reduce((sum, a) => sum + a.size, 0);

  return {
    toDelete,
    toRetain,
    dryRun,
    summary: {
      totalArtifacts: artifacts.length,
      artifactsDeleted: toDelete.length,
      artifactsRetained: toRetain.length,
      spaceReclaimed,
    },
  };
}

// ── Formatting ────────────────────────────────────────────────────────────────

function fmtDate(d: Date): string {
  return d.toISOString().split("T")[0];
}

function fmtBytes(n: number): string {
  const mb = n / (1024 * 1024);
  return `${n} bytes (${mb.toFixed(2)} MB)`;
}

/** Formats a deletion plan as a human-readable string. */
export function formatDeletionPlan(plan: DeletionPlan): string {
  const lines: string[] = [];
  lines.push("=== ARTIFACT CLEANUP PLAN ===");
  if (plan.dryRun) {
    lines.push("Mode: DRY RUN (no changes will be made)");
  } else {
    lines.push("Mode: LIVE (deletions would be executed)");
  }
  lines.push("");

  lines.push(`ARTIFACTS TO DELETE (${plan.toDelete.length}):`);
  if (plan.toDelete.length === 0) {
    lines.push("  (none)");
  }
  for (const a of plan.toDelete) {
    lines.push(`  - ${a.name} (${a.size} bytes, ${fmtDate(a.createdAt)}, ${a.workflowRunId})`);
  }
  lines.push("");

  lines.push(`ARTIFACTS TO RETAIN (${plan.toRetain.length}):`);
  if (plan.toRetain.length === 0) {
    lines.push("  (none)");
  }
  for (const a of plan.toRetain) {
    lines.push(`  - ${a.name} (${a.size} bytes, ${fmtDate(a.createdAt)}, ${a.workflowRunId})`);
  }
  lines.push("");

  lines.push("SUMMARY:");
  lines.push(`  Total artifacts:    ${plan.summary.totalArtifacts}`);
  lines.push(`  Artifacts deleted:  ${plan.summary.artifactsDeleted}`);
  lines.push(`  Artifacts retained: ${plan.summary.artifactsRetained}`);
  lines.push(`  Space reclaimed:    ${fmtBytes(plan.summary.spaceReclaimed)}`);
  lines.push("");

  return lines.join("\n");
}

// ── Fixture format ────────────────────────────────────────────────────────────

interface FixtureFile {
  referenceDate?: string;
  policy: RetentionPolicy;
  artifacts: Array<{
    name: string;
    size: number;
    createdAt: string;
    workflowRunId: string;
  }>;
}

function loadFixture(filePath: string): { artifacts: Artifact[]; policy: RetentionPolicy; now: Date } {
  let raw: FixtureFile;
  try {
    raw = JSON.parse(readFileSync(filePath, "utf8")) as FixtureFile;
  } catch (e) {
    throw new Error(`Failed to read fixture file '${filePath}': ${(e as Error).message}`);
  }

  const now = raw.referenceDate ? new Date(raw.referenceDate) : new Date();

  const artifacts: Artifact[] = raw.artifacts.map((a) => {
    const createdAt = new Date(a.createdAt);
    if (isNaN(createdAt.getTime())) {
      throw new Error(`Invalid createdAt '${a.createdAt}' for artifact '${a.name}'`);
    }
    return { name: a.name, size: a.size, createdAt, workflowRunId: a.workflowRunId };
  });

  return { artifacts, policy: raw.policy, now };
}

// ── CLI entrypoint ────────────────────────────────────────────────────────────

if (import.meta.main) {
  const args = process.argv.slice(2);
  const dryRun = args.includes("--dry-run");
  const fixturesIdx = args.indexOf("--fixtures");

  if (fixturesIdx === -1 || !args[fixturesIdx + 1]) {
    console.error("Usage: bun run artifact-cleanup.ts --fixtures <file.json> [--dry-run]");
    process.exit(1);
  }

  const fixturePath = args[fixturesIdx + 1];

  try {
    const { artifacts, policy, now } = loadFixture(fixturePath);
    const plan = applyRetentionPolicies(artifacts, policy, { now, dryRun });
    process.stdout.write(formatDeletionPlan(plan));
  } catch (e) {
    console.error(`Error: ${(e as Error).message}`);
    process.exit(1);
  }
}
