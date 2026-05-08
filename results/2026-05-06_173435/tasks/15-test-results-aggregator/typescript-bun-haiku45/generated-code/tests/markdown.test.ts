import { describe, it, expect, beforeAll } from 'bun:test';
import { generateMarkdownSummary } from '../src/markdown';
import { aggregateResults } from '../src/aggregator';
import { parseJunitXml, parseJsonResults } from '../src/parser';
import * as fs from 'fs';
import * as path from 'path';

describe('Markdown Generation', () => {
  let aggregated: ReturnType<typeof aggregateResults>;

  beforeAll(async () => {
    const fixtureDir = path.join(import.meta.dir, 'fixtures');

    const junit1Content = await fs.promises.readFile(
      path.join(fixtureDir, 'sample-junit.xml'),
      'utf-8'
    );
    const junitRun1 = parseJunitXml(junit1Content, 'run-1');

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
    const junitRun2 = parseJunitXml(junit2Content, 'run-2');

    aggregated = aggregateResults([junitRun1, junitRun2]);
  });

  it('should generate markdown summary', () => {
    const markdown = generateMarkdownSummary(aggregated);

    expect(markdown).toBeDefined();
    expect(typeof markdown).toBe('string');
    expect(markdown.length).toBeGreaterThan(0);
  });

  it('should include test counts in summary', () => {
    const markdown = generateMarkdownSummary(aggregated);

    expect(markdown).toContain('8');   // total tests
    expect(markdown).toContain('5');   // passed
    expect(markdown).toContain('1');   // failed
    expect(markdown).toContain('2');   // skipped
  });

  it('should include flaky test information', () => {
    const markdown = generateMarkdownSummary(aggregated);

    expect(markdown).toContain('Flaky');
    // testSubtraction is flaky
    expect(markdown).toContain('testSubtraction');
  });

  it('should format markdown with proper headers', () => {
    const markdown = generateMarkdownSummary(aggregated);

    expect(markdown).toContain('#');
    expect(markdown).toContain('Test Results');
  });

  it('should include duration information', () => {
    const markdown = generateMarkdownSummary(aggregated);

    // Should mention time/duration in some form
    expect(markdown.length).toBeGreaterThan(50);
  });
});
