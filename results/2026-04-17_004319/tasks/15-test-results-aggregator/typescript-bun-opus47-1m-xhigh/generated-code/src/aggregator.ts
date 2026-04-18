// Aggregate N run reports into a single rolled-up report.
//
// "Flaky" = the same test name has at least one pass AND at least one fail
// across the supplied runs. A test that always fails isn't flaky — it's
// broken — so we track those separately in `consistentlyFailing`. Skipped
// outcomes are ignored when classifying flakiness because a skip is not a
// signal about correctness.

import type {
  AggregatedReport,
  AggregatedTotals,
  FlakyTest,
  RunReport,
  TestResult,
} from "./types.ts";

interface Bucket {
  passCount: number;
  failCount: number;
  skipCount: number;
  failedIn: string[];
}

export function aggregate(runs: RunReport[]): AggregatedReport {
  const totals: AggregatedTotals = {
    total: 0,
    passed: 0,
    failed: 0,
    skipped: 0,
    durationMs: 0,
  };

  // Group results by test name so we can classify each test across all runs.
  const buckets = new Map<string, Bucket>();

  for (const run of runs) {
    for (const t of run.tests) {
      totals.total += 1;
      totals.durationMs += t.durationMs;
      if (t.status === "passed") totals.passed += 1;
      else if (t.status === "failed") totals.failed += 1;
      else totals.skipped += 1;

      let bucket = buckets.get(t.name);
      if (!bucket) {
        bucket = { passCount: 0, failCount: 0, skipCount: 0, failedIn: [] };
        buckets.set(t.name, bucket);
      }
      if (t.status === "passed") bucket.passCount += 1;
      else if (t.status === "failed") {
        bucket.failCount += 1;
        bucket.failedIn.push(run.source);
      } else bucket.skipCount += 1;
    }
  }

  const flaky: FlakyTest[] = [];
  const consistentlyFailing: string[] = [];
  for (const [name, b] of buckets) {
    if (b.failCount > 0 && b.passCount > 0) {
      flaky.push({ name, passCount: b.passCount, failCount: b.failCount, failedIn: b.failedIn });
    } else if (b.failCount > 0 && b.passCount === 0) {
      consistentlyFailing.push(name);
    }
  }
  // Stable output: sort by name for deterministic markdown summaries.
  flaky.sort((a, b) => a.name.localeCompare(b.name));
  consistentlyFailing.sort();

  return { runs, totals, flaky, consistentlyFailing };
}

/** Convenience: build the aggregate straight from a list of TestResult sets. */
export function aggregateFromTests(
  sources: Array<{ source: string; tests: TestResult[] }>,
): AggregatedReport {
  return aggregate(sources.map((s) => ({ source: s.source, tests: s.tests })));
}
