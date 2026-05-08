import { AggregatedResults, FlakyTest, ParsedResults } from './types';

// Aggregate results from multiple test runs
export function aggregateResults(parsedResults: ParsedResults[]): AggregatedResults {
  let totalTests = 0;
  let totalPassed = 0;
  let totalFailed = 0;
  let totalSkipped = 0;
  let totalDuration = 0;
  const suites = parsedResults.flatMap(pr => pr.results);

  // Count test outcomes
  for (const suite of suites) {
    totalTests += suite.tests;
    for (const testCase of suite.cases) {
      if (testCase.status === 'passed') {
        totalPassed++;
      } else if (testCase.status === 'failed') {
        totalFailed++;
      } else if (testCase.status === 'skipped') {
        totalSkipped++;
      }
      totalDuration += testCase.duration;
    }
  }

  const flakyTests = identifyFlakyTests({
    totalTests,
    totalPassed,
    totalFailed,
    totalSkipped,
    totalDuration,
    suites,
    flakyTests: [],
  });

  return {
    totalTests,
    totalPassed,
    totalFailed,
    totalSkipped,
    totalDuration,
    suites,
    flakyTests,
  };
}

// Identify flaky tests: tests that pass in some runs and fail in others
export function identifyFlakyTests(aggregated: AggregatedResults): FlakyTest[] {
  // Map test identity to its outcomes across all runs
  const testOutcomes: Map<
    string,
    { statuses: Set<string>; runIds: Set<string> }
  > = new Map();

  for (const suite of aggregated.suites) {
    for (const testCase of suite.cases) {
      const testKey = `${testCase.className}::${testCase.name}`;

      if (!testOutcomes.has(testKey)) {
        testOutcomes.set(testKey, {
          statuses: new Set(),
          runIds: new Set(),
        });
      }

      const outcome = testOutcomes.get(testKey)!;
      outcome.statuses.add(testCase.status);
      if (testCase.runId) {
        outcome.runIds.add(testCase.runId);
      }
    }
  }

  // A test is flaky if it has both passed and failed statuses
  const flaky: FlakyTest[] = [];

  for (const [testKey, outcome] of testOutcomes) {
    if (
      outcome.statuses.has('passed') &&
      outcome.statuses.has('failed')
    ) {
      const [className, testName] = testKey.split('::');

      // Count failures and passages
      let failureCount = 0;
      let passageCount = 0;

      for (const suite of aggregated.suites) {
        for (const testCase of suite.cases) {
          if (
            testCase.className === className &&
            testCase.name === testName
          ) {
            if (testCase.status === 'failed') {
              failureCount++;
            } else if (testCase.status === 'passed') {
              passageCount++;
            }
          }
        }
      }

      flaky.push({
        name: testName,
        className,
        failureCount,
        passageCount,
        runIds: Array.from(outcome.runIds),
      });
    }
  }

  return flaky;
}
