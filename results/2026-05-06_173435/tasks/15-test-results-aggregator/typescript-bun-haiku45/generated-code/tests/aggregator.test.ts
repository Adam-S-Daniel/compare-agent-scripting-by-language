import { describe, it, expect, beforeAll } from 'bun:test';
import { aggregateResults, identifyFlakyTests } from '../src/aggregator';
import { parseJunitXml, parseJsonResults } from '../src/parser';
import * as fs from 'fs';
import * as path from 'path';

describe('Results Aggregation', () => {
  let junitRun1: ReturnType<typeof parseJunitXml>;
  let junitRun2: ReturnType<typeof parseJunitXml>;
  let jsonRun: ReturnType<typeof parseJsonResults>;

  beforeAll(async () => {
    const fixtureDir = path.join(import.meta.dir, 'fixtures');

    // Create an additional run with one test failing
    const junit1Content = await fs.promises.readFile(
      path.join(fixtureDir, 'sample-junit.xml'),
      'utf-8'
    );
    junitRun1 = parseJunitXml(junit1Content, 'run-1');

    // Create a second run where testSubtraction passes (for flakiness testing)
    const junit2Content = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="ExampleSuite" tests="4" failures="0" skipped="1" time="2.5">
    <testcase classname="com.example.MathTest" name="testAddition" time="0.5"/>
    <testcase classname="com.example.MathTest" name="testSubtraction" time="0.6"/>
    <testcase classname="com.example.StringTest" name="testConcat" time="0.4"/>
    <testcase classname="com.example.StringTest" name="testTrim" time="0.5">
      <skipped message="Test skipped for investigation"/>
    </testcase>
  </testsuite>
</testsuites>`;
    junitRun2 = parseJunitXml(junit2Content, 'run-2');

    const jsonContent = await fs.promises.readFile(
      path.join(fixtureDir, 'sample-results.json'),
      'utf-8'
    );
    jsonRun = parseJsonResults(jsonContent, 'run-3');
  });

  it('should aggregate multiple test result files', () => {
    const aggregated = aggregateResults([junitRun1, junitRun2]);

    // Each run keeps its own suite for proper flakiness detection
    expect(aggregated.suites.length).toBe(2);
    expect(aggregated.totalTests).toBe(8); // 4 tests per run x 2 runs
  });

  it('should calculate total passed tests', () => {
    const aggregated = aggregateResults([junitRun1, junitRun2]);

    // Run 1: 2 passed, Run 2: 3 passed
    expect(aggregated.totalPassed).toBe(5);
  });

  it('should calculate total failed tests', () => {
    const aggregated = aggregateResults([junitRun1, junitRun2]);

    // Run 1: 1 failed, Run 2: 0 failed
    expect(aggregated.totalFailed).toBe(1);
  });

  it('should calculate total skipped tests', () => {
    const aggregated = aggregateResults([junitRun1, junitRun2]);

    // Run 1: 1 skipped, Run 2: 1 skipped
    expect(aggregated.totalSkipped).toBe(2);
  });

  it('should sum duration across all test cases', () => {
    const aggregated = aggregateResults([junitRun1, junitRun2]);

    expect(aggregated.totalDuration).toBeGreaterThan(0);
  });

  it('should aggregate different result formats together', () => {
    const aggregated = aggregateResults([junitRun1, jsonRun]);

    expect(aggregated.suites.length).toBe(2);
    expect(aggregated.totalTests).toBeGreaterThan(0);
  });

  it('should identify flaky tests that pass in some runs and fail in others', () => {
    const aggregated = aggregateResults([junitRun1, junitRun2]);
    const flaky = identifyFlakyTests(aggregated);

    expect(flaky.length).toBeGreaterThan(0);

    // testSubtraction should be flaky: failed in run-1, passed in run-2
    const testSubtractionFlaky = flaky.find(
      t => t.name === 'testSubtraction' && t.className === 'com.example.MathTest'
    );
    expect(testSubtractionFlaky).toBeDefined();
    expect(testSubtractionFlaky!.failureCount).toBe(1);
    expect(testSubtractionFlaky!.passageCount).toBe(1);
  });

  it('should track which runs each flaky test occurred in', () => {
    const aggregated = aggregateResults([junitRun1, junitRun2]);
    const flaky = identifyFlakyTests(aggregated);

    const testSubtractionFlaky = flaky.find(
      t => t.name === 'testSubtraction' && t.className === 'com.example.MathTest'
    );
    expect(testSubtractionFlaky!.runIds).toContain('run-1');
    expect(testSubtractionFlaky!.runIds).toContain('run-2');
  });

  it('should not mark consistently passing or failing tests as flaky', () => {
    const aggregated = aggregateResults([junitRun1, junitRun2]);
    const flaky = identifyFlakyTests(aggregated);

    // testAddition always passes, should not be flaky
    const testAdditionFlaky = flaky.find(
      t => t.name === 'testAddition' && t.className === 'com.example.MathTest'
    );
    expect(testAdditionFlaky).toBeUndefined();
  });
});
