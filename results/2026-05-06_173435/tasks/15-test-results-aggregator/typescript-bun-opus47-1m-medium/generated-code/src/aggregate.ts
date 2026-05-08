import type { AggregatedResults, RunResult, TestCase } from "./types";

// Fold per-run results into matrix-build-style totals, plus pull out failures
// and identify flaky tests (any test that both passed AND failed across runs).
export function aggregate(runs: RunResult[]): AggregatedResults {
  let passed = 0;
  let failed = 0;
  let skipped = 0;
  let durationMs = 0;
  const failures: TestCase[] = [];
  // key = "suite::name", value = counters for flaky detection
  const byTest = new Map<string, { suite: string; name: string; passes: number; failures: number }>();

  for (const run of runs) {
    for (const c of run.cases) {
      durationMs += c.durationMs;
      const key = `${c.suite}::${c.name}`;
      const entry = byTest.get(key) ?? { suite: c.suite, name: c.name, passes: 0, failures: 0 };
      if (c.status === "passed") {
        passed++;
        entry.passes++;
      } else if (c.status === "failed") {
        failed++;
        entry.failures++;
        failures.push(c);
      } else {
        skipped++;
      }
      byTest.set(key, entry);
    }
  }

  const flaky = [...byTest.values()].filter((e) => e.passes > 0 && e.failures > 0);
  return {
    totals: { passed, failed, skipped, total: passed + failed + skipped, durationMs },
    flaky,
    failures,
    runs,
  };
}
