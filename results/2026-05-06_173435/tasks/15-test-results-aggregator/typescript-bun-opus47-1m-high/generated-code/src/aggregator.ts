// Aggregation: combine many parsed test suites (one per matrix run)
// into single totals + a flaky-test list.
//
// "Flaky" definition for this project: a test (keyed by classname+name)
// that produced both a `passed` and a `failed` outcome across runs.
// Skipped runs are not counted toward the flake decision — a skipped
// test didn't actually execute, so it can't be evidence either way.

import type { AggregatedResults, FlakyTest, TestSuite } from "./types.ts";

interface RunCounts {
  passed: number;
  failed: number;
  skipped: number;
  classname: string | undefined;
}

export function aggregate(suites: TestSuite[]): AggregatedResults {
  let totalTests = 0;
  let passed = 0;
  let failed = 0;
  let skipped = 0;
  let totalDuration = 0;

  // Key tests by `${classname}::${name}` so two unrelated tests with the
  // same `name` in different classes don't collide.
  const perTest = new Map<string, RunCounts>();
  const sources = new Set<string>();

  for (const s of suites) {
    sources.add(s.source);
    for (const c of s.cases) {
      totalTests++;
      totalDuration += c.duration;
      const key = `${c.classname ?? ""}::${c.name}`;
      const cur =
        perTest.get(key) ??
        ({ passed: 0, failed: 0, skipped: 0, classname: c.classname } as RunCounts);
      if (c.status === "passed") {
        passed++;
        cur.passed++;
      } else if (c.status === "failed") {
        failed++;
        cur.failed++;
      } else {
        skipped++;
        cur.skipped++;
      }
      perTest.set(key, cur);
    }
  }

  const flaky: FlakyTest[] = [];
  for (const [key, counts] of perTest) {
    if (counts.passed > 0 && counts.failed > 0) {
      const name = key.slice(key.indexOf("::") + 2);
      flaky.push({
        name,
        classname: counts.classname,
        passCount: counts.passed,
        failCount: counts.failed,
        totalRuns: counts.passed + counts.failed,
      });
    }
  }
  // Highest failure count first (most disruptive), then alphabetical.
  flaky.sort((a, b) => b.failCount - a.failCount || a.name.localeCompare(b.name));

  return {
    totalTests,
    passed,
    failed,
    skipped,
    totalDuration,
    fileCount: sources.size,
    flaky,
    suites,
  };
}
