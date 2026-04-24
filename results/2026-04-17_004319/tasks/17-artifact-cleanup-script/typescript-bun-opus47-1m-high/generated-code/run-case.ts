#!/usr/bin/env bun
// Reads a test case bundle (artifacts + policy + now + dryRun) from a JSON
// file and runs the cleanup. Used by the GitHub Actions workflow so each run
// can point at a different fixture without rewriting the workflow file.

import { planCleanup, formatPlanSummary, type Artifact, type RetentionPolicy } from "./cleanup";

interface TestCase {
  name: string;
  artifacts: Artifact[];
  policy: RetentionPolicy;
  now: string;
  dryRun?: boolean;
}

const casePath = Bun.argv[2];
if (!casePath) {
  console.error("usage: run-case.ts <case.json>");
  process.exit(2);
}

let raw: string;
try {
  raw = await Bun.file(casePath).text();
} catch (e) {
  console.error(`error: failed to read case file ${casePath}: ${(e as Error).message}`);
  process.exit(1);
}

let tc: TestCase;
try {
  tc = JSON.parse(raw);
} catch (e) {
  console.error(`error: invalid JSON in ${casePath}: ${(e as Error).message}`);
  process.exit(1);
}

const now = Date.parse(tc.now);
if (Number.isNaN(now)) {
  console.error(`error: invalid 'now' timestamp: ${tc.now}`);
  process.exit(1);
}

try {
  const plan = planCleanup(tc.artifacts, tc.policy, now, { dryRun: tc.dryRun ?? false });
  console.log(`=== case: ${tc.name} ===`);
  console.log(formatPlanSummary(plan));
  // Machine-readable line the harness can parse exactly.
  console.log(
    "RESULT_JSON=" +
      JSON.stringify({
        deletedCount: plan.summary.deletedCount,
        retainedCount: plan.summary.retainedCount,
        bytesReclaimed: plan.summary.bytesReclaimed,
        totalArtifacts: plan.summary.totalArtifacts,
        dryRun: plan.dryRun,
        deletedIds: plan.toDelete.map((a) => a.id).sort(),
      })
  );
  process.exit(0);
} catch (e) {
  console.error(`error: ${(e as Error).message}`);
  process.exit(1);
}
