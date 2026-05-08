// Aggregates parsed TestRuns into totals and a flaky-test list.
//
// Flaky-test definition: a test (identified by classname.name) that has at
// least one "passed" status AND at least one "failed" status across the runs.
// Skipped statuses are intentionally ignored when classifying — a single
// skip does not imply non-determinism.
import type { AggregatedResults, FlakyTest, TestRun } from "./types.ts";

interface PerTestStats {
  classname: string;
  name: string;
  passed: number;
  failed: number;
  skipped: number;
  lastFailureMessage?: string;
}

export function aggregate(runs: TestRun[]): AggregatedResults {
  let totalPassed = 0;
  let totalFailed = 0;
  let totalSkipped = 0;
  let totalDuration = 0;
  const perTest = new Map<string, PerTestStats>();

  for (const r of runs) {
    for (const suite of r.suites) {
      for (const tc of suite.cases) {
        totalDuration += tc.duration;
        const id = `${tc.classname}.${tc.name}`;
        const stats = perTest.get(id) ?? {
          classname: tc.classname,
          name: tc.name,
          passed: 0,
          failed: 0,
          skipped: 0,
        };
        if (tc.status === "passed") {
          totalPassed += 1;
          stats.passed += 1;
        } else if (tc.status === "failed") {
          totalFailed += 1;
          stats.failed += 1;
          if (tc.message) stats.lastFailureMessage = tc.message;
        } else {
          totalSkipped += 1;
          stats.skipped += 1;
        }
        perTest.set(id, stats);
      }
    }
  }

  const flakyTests: FlakyTest[] = [];
  const failingTests: AggregatedResults["failingTests"] = [];
  for (const [id, s] of perTest) {
    const total = s.passed + s.failed + s.skipped;
    if (s.passed > 0 && s.failed > 0) {
      flakyTests.push({
        id,
        classname: s.classname,
        name: s.name,
        passed: s.passed,
        failed: s.failed,
        total,
      });
    } else if (s.failed > 0 && s.passed === 0) {
      const entry: AggregatedResults["failingTests"][number] = {
        id,
        classname: s.classname,
        name: s.name,
      };
      if (s.lastFailureMessage) entry.message = s.lastFailureMessage;
      failingTests.push(entry);
    }
  }
  // Stable, alphabetic ordering — keeps the markdown deterministic for tests.
  flakyTests.sort((a, b) => a.id.localeCompare(b.id));
  failingTests.sort((a, b) => a.id.localeCompare(b.id));

  return {
    totalPassed,
    totalFailed,
    totalSkipped,
    totalTests: totalPassed + totalFailed + totalSkipped,
    totalDuration,
    runCount: runs.length,
    flakyTests,
    failingTests,
    runs,
  };
}
