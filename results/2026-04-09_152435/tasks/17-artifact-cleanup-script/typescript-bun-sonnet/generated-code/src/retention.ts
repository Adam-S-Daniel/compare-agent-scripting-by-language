// Retention policy engine.
// Each policy function is pure and independent — applies a single rule to a list
// of artifacts and returns { toDelete, toRetain } arrays.
//
// TDD approach: tests were written first in tests/retention.test.ts,
// then this implementation was written to make them pass.

import type { Artifact, RetentionPolicy } from "./types";

// Policy 1: delete artifacts older than maxAgeDays (relative to referenceDate).
// Cutoff = referenceDate - maxAgeDays*24h. Artifacts created before cutoff are deleted.
export function applyMaxAgePolicy(
  artifacts: Artifact[],
  maxAgeDays: number,
  referenceDate: Date
): { toDelete: Artifact[]; toRetain: Artifact[] } {
  const cutoffMs = referenceDate.getTime() - maxAgeDays * 24 * 60 * 60 * 1000;

  const toDelete: Artifact[] = [];
  const toRetain: Artifact[] = [];

  for (const artifact of artifacts) {
    if (artifact.createdAt.getTime() < cutoffMs) {
      toDelete.push(artifact);
    } else {
      toRetain.push(artifact);
    }
  }

  return { toDelete, toRetain };
}

// Policy 2: keep newest artifacts that fit within maxTotalSizeBytes; delete the rest.
// Sorts newest-first, accumulates size until limit exceeded, deletes remainder.
export function applyMaxTotalSizePolicy(
  artifacts: Artifact[],
  maxTotalSizeBytes: number
): { toDelete: Artifact[]; toRetain: Artifact[] } {
  // Sort by createdAt descending (newest first) — newest artifacts are prioritized
  const sorted = [...artifacts].sort(
    (a, b) => b.createdAt.getTime() - a.createdAt.getTime()
  );

  let cumulativeSize = 0;
  const toRetain: Artifact[] = [];
  const toDelete: Artifact[] = [];

  for (const artifact of sorted) {
    if (cumulativeSize + artifact.sizeBytes <= maxTotalSizeBytes) {
      toRetain.push(artifact);
      cumulativeSize += artifact.sizeBytes;
    } else {
      toDelete.push(artifact);
    }
  }

  return { toDelete, toRetain };
}

// Policy 3: keep the N most recently created artifacts per artifact name.
// Groups by artifact.name, sorts each group newest-first, keeps top N.
export function applyKeepLatestNPolicy(
  artifacts: Artifact[],
  keepLatestN: number
): { toDelete: Artifact[]; toRetain: Artifact[] } {
  // Group artifacts by name
  const groups = new Map<string, Artifact[]>();

  for (const artifact of artifacts) {
    const group = groups.get(artifact.name) ?? [];
    group.push(artifact);
    groups.set(artifact.name, group);
  }

  const toDelete: Artifact[] = [];
  const toRetain: Artifact[] = [];

  for (const group of groups.values()) {
    // Sort group descending by creation date
    const sorted = [...group].sort(
      (a, b) => b.createdAt.getTime() - a.createdAt.getTime()
    );
    toRetain.push(...sorted.slice(0, keepLatestN));
    toDelete.push(...sorted.slice(keepLatestN));
  }

  return { toDelete, toRetain };
}

// Combined: apply all specified policies, union all "to delete" artifact IDs.
// An artifact is deleted if ANY policy marks it for deletion.
// Throws if no policy is specified — caller must provide at least one rule.
export function applyRetentionPolicies(
  artifacts: Artifact[],
  policy: RetentionPolicy,
  referenceDate: Date
): { toDelete: Artifact[]; toRetain: Artifact[] } {
  const hasPolicy =
    policy.maxAgeDays !== undefined ||
    policy.maxTotalSizeBytes !== undefined ||
    policy.keepLatestNPerWorkflow !== undefined;

  if (!hasPolicy) {
    throw new Error("At least one retention policy must be specified");
  }

  const toDeleteIds = new Set<string>();

  if (policy.maxAgeDays !== undefined) {
    const result = applyMaxAgePolicy(artifacts, policy.maxAgeDays, referenceDate);
    result.toDelete.forEach((a) => toDeleteIds.add(a.id));
  }

  if (policy.maxTotalSizeBytes !== undefined) {
    const result = applyMaxTotalSizePolicy(artifacts, policy.maxTotalSizeBytes);
    result.toDelete.forEach((a) => toDeleteIds.add(a.id));
  }

  if (policy.keepLatestNPerWorkflow !== undefined) {
    const result = applyKeepLatestNPolicy(artifacts, policy.keepLatestNPerWorkflow);
    result.toDelete.forEach((a) => toDeleteIds.add(a.id));
  }

  const toDelete = artifacts.filter((a) => toDeleteIds.has(a.id));
  const toRetain = artifacts.filter((a) => !toDeleteIds.has(a.id));

  return { toDelete, toRetain };
}
