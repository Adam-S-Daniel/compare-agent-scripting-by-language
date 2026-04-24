// Aggregate parsed reports into totals, failures, and flaky-test findings.
// Each input report represents one run in a matrix build. A test is identified
// across runs by `${classname} :: ${name}`; flakiness = at least one passed AND
// at least one failed outcome for the same identity.
import type {
  AggregateResult,
  AggregateTotals,
  FlakyTest,
  ParsedReport,
} from "./types";

function testId(classname: string, name: string): string {
  return `${classname} :: ${name}`;
}

export function aggregate(reports: ParsedReport[]): AggregateResult {
  const totals: AggregateTotals = {
    total: 0,
    passed: 0,
    failed: 0,
    skipped: 0,
    duration: 0,
    fileCount: reports.length,
  };

  // Per-test-identity counters across runs.
  const perTest = new Map<
    string,
    { classname: string; name: string; passed: number; failed: number; total: number }
  >();
  const failures: Array<{ id: string; message: string }> = [];

  for (const r of reports) {
    for (const suite of r.suites) {
      for (const t of suite.tests) {
        totals.total += 1;
        totals.duration += t.duration || 0;
        if (t.status === "passed") totals.passed += 1;
        else if (t.status === "failed") totals.failed += 1;
        else totals.skipped += 1;

        const id = testId(t.classname, t.name);
        let entry = perTest.get(id);
        if (!entry) {
          entry = { classname: t.classname, name: t.name, passed: 0, failed: 0, total: 0 };
          perTest.set(id, entry);
        }
        entry.total += 1;
        if (t.status === "passed") entry.passed += 1;
        else if (t.status === "failed") entry.failed += 1;

        if (t.status === "failed") {
          failures.push({ id, message: t.failureMessage ?? "(no message)" });
        }
      }
    }
  }

  const flaky: FlakyTest[] = [];
  for (const [id, e] of perTest.entries()) {
    if (e.passed > 0 && e.failed > 0) {
      flaky.push({
        id,
        classname: e.classname,
        name: e.name,
        passedRuns: e.passed,
        failedRuns: e.failed,
        totalRuns: e.total,
      });
    }
  }
  // Sort flaky tests by id for deterministic output.
  flaky.sort((a, b) => a.id.localeCompare(b.id));

  return { totals, flaky, failures };
}
