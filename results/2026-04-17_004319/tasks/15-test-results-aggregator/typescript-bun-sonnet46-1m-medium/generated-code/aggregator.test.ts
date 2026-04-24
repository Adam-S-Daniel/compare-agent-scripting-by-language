// Test suite following red/green TDD:
// 1. JUnit XML parsing
// 2. JSON parsing
// 3. Aggregation (totals)
// 4. Flaky test detection
// 5. Markdown generation
// 6. Workflow structure validation

import { describe, test, expect, beforeAll } from 'bun:test';
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import { spawnSync } from 'child_process';

import { parseJUnitXML, parseJSONResults } from './parsers';
import { aggregateResults } from './aggregator';
import { generateMarkdown } from './markdown';
import type { TestSuite, AggregatedResults } from './types';

const FIXTURES_DIR = join(import.meta.dir, 'fixtures');
const WORKFLOW_FILE = join(import.meta.dir, '.github', 'workflows', 'test-results-aggregator.yml');

// ─── JUnit XML Parsing ───────────────────────────────────────────────────────

describe('JUnit XML Parser', () => {
  let node18Suite: TestSuite[];

  beforeAll(() => {
    const xml = readFileSync(join(FIXTURES_DIR, 'junit-node18.xml'), 'utf8');
    node18Suite = parseJUnitXML(xml, 'junit-node18.xml');
  });

  test('parses the suite name', () => {
    expect(node18Suite).toHaveLength(1);
    expect(node18Suite[0].name).toBe('AuthModule');
  });

  test('parses the suite duration', () => {
    expect(node18Suite[0].duration).toBe(1.5);
  });

  test('parses 5 test results', () => {
    expect(node18Suite[0].results).toHaveLength(5);
  });

  test('identifies passed tests', () => {
    const passed = node18Suite[0].results.filter(r => r.status === 'passed');
    expect(passed).toHaveLength(3);
  });

  test('identifies the failed test', () => {
    const failed = node18Suite[0].results.filter(r => r.status === 'failed');
    expect(failed).toHaveLength(1);
    expect(failed[0].testName).toBe('should handle expired tokens');
    expect(failed[0].errorMessage).toBeDefined();
  });

  test('identifies the skipped test', () => {
    const skipped = node18Suite[0].results.filter(r => r.status === 'skipped');
    expect(skipped).toHaveLength(1);
    expect(skipped[0].testName).toBe('should logout');
  });

  test('attaches source filename to each result', () => {
    expect(node18Suite[0].results[0].source).toBe('junit-node18.xml');
  });

  test('parses node20 with 0 failures', () => {
    const xml = readFileSync(join(FIXTURES_DIR, 'junit-node20.xml'), 'utf8');
    const suites = parseJUnitXML(xml, 'junit-node20.xml');
    const failed = suites[0].results.filter(r => r.status === 'failed');
    expect(failed).toHaveLength(0);
  });
});

// ─── JSON Parsing ────────────────────────────────────────────────────────────

describe('JSON Parser', () => {
  let suite: TestSuite[];

  beforeAll(() => {
    const json = readFileSync(join(FIXTURES_DIR, 'results-api.json'), 'utf8');
    suite = parseJSONResults(json, 'results-api.json');
  });

  test('parses the suite name', () => {
    expect(suite).toHaveLength(1);
    expect(suite[0].name).toBe('ApiModule');
  });

  test('parses 3 test results', () => {
    expect(suite[0].results).toHaveLength(3);
  });

  test('identifies 2 passed tests', () => {
    const passed = suite[0].results.filter(r => r.status === 'passed');
    expect(passed).toHaveLength(2);
  });

  test('identifies 1 failed test with error message', () => {
    const failed = suite[0].results.filter(r => r.status === 'failed');
    expect(failed).toHaveLength(1);
    expect(failed[0].testName).toBe('should delete user');
    expect(failed[0].errorMessage).toBe('404 Not Found');
  });

  test('parses suite duration', () => {
    expect(suite[0].duration).toBe(0.65);
  });
});

// ─── Aggregation ─────────────────────────────────────────────────────────────

describe('Result Aggregation', () => {
  let aggregated: AggregatedResults;

  beforeAll(() => {
    const xml18 = readFileSync(join(FIXTURES_DIR, 'junit-node18.xml'), 'utf8');
    const xml20 = readFileSync(join(FIXTURES_DIR, 'junit-node20.xml'), 'utf8');
    const json = readFileSync(join(FIXTURES_DIR, 'results-api.json'), 'utf8');

    const suites = [
      ...parseJUnitXML(xml18, 'junit-node18.xml'),
      ...parseJUnitXML(xml20, 'junit-node20.xml'),
      ...parseJSONResults(json, 'results-api.json'),
    ];
    aggregated = aggregateResults(suites);
  });

  test('counts total suites', () => {
    expect(aggregated.totalSuites).toBe(3);
  });

  test('counts total tests: 13', () => {
    expect(aggregated.totalTests).toBe(13);
  });

  test('counts passed tests: 9', () => {
    expect(aggregated.passed).toBe(9);
  });

  test('counts failed tests: 2', () => {
    expect(aggregated.failed).toBe(2);
  });

  test('counts skipped tests: 2', () => {
    expect(aggregated.skipped).toBe(2);
  });

  test('sums total duration: 3.35s', () => {
    expect(aggregated.duration).toBeCloseTo(3.35, 2);
  });
});

// ─── Flaky Test Detection ─────────────────────────────────────────────────────

describe('Flaky Test Detection', () => {
  let aggregated: AggregatedResults;

  beforeAll(() => {
    const xml18 = readFileSync(join(FIXTURES_DIR, 'junit-node18.xml'), 'utf8');
    const xml20 = readFileSync(join(FIXTURES_DIR, 'junit-node20.xml'), 'utf8');
    const suites = [
      ...parseJUnitXML(xml18, 'junit-node18.xml'),
      ...parseJUnitXML(xml20, 'junit-node20.xml'),
    ];
    aggregated = aggregateResults(suites);
  });

  test('detects 1 flaky test', () => {
    expect(aggregated.flakyTests).toHaveLength(1);
  });

  test('identifies the correct flaky test', () => {
    const flaky = aggregated.flakyTests[0];
    expect(flaky.testName).toBe('should handle expired tokens');
    expect(flaky.suiteName).toBe('AuthModule');
    expect(flaky.passCount).toBe(1);
    expect(flaky.failCount).toBe(1);
  });

  test('non-flaky tests are not in flaky list', () => {
    const names = aggregated.flakyTests.map(f => f.testName);
    expect(names).not.toContain('should login successfully');
  });
});

// ─── Markdown Generation ─────────────────────────────────────────────────────

describe('Markdown Generation', () => {
  let markdown: string;
  let aggregated: AggregatedResults;

  beforeAll(() => {
    const xml18 = readFileSync(join(FIXTURES_DIR, 'junit-node18.xml'), 'utf8');
    const xml20 = readFileSync(join(FIXTURES_DIR, 'junit-node20.xml'), 'utf8');
    const json = readFileSync(join(FIXTURES_DIR, 'results-api.json'), 'utf8');

    const suites = [
      ...parseJUnitXML(xml18, 'junit-node18.xml'),
      ...parseJUnitXML(xml20, 'junit-node20.xml'),
      ...parseJSONResults(json, 'results-api.json'),
    ];
    aggregated = aggregateResults(suites);
    markdown = generateMarkdown(aggregated);
  });

  test('contains heading', () => {
    expect(markdown).toContain('## Test Results Summary');
  });

  test('contains total tests count', () => {
    expect(markdown).toContain('13');
  });

  test('contains passed count', () => {
    expect(markdown).toContain('9');
  });

  test('contains failed count', () => {
    expect(markdown).toContain('2');
  });

  test('contains flaky test name', () => {
    expect(markdown).toContain('should handle expired tokens');
  });
});

// ─── Workflow Structure Tests ────────────────────────────────────────────────

describe('Workflow Structure', () => {
  test('workflow file exists', () => {
    expect(existsSync(WORKFLOW_FILE)).toBe(true);
  });

  test('workflow references main.ts', () => {
    const content = readFileSync(WORKFLOW_FILE, 'utf8');
    expect(content).toContain('main.ts');
  });

  test('workflow has push trigger', () => {
    const content = readFileSync(WORKFLOW_FILE, 'utf8');
    expect(content).toContain('push:');
  });

  test('workflow uses actions/checkout@v4', () => {
    const content = readFileSync(WORKFLOW_FILE, 'utf8');
    expect(content).toContain('actions/checkout@v4');
  });

  test('workflow uses setup-bun', () => {
    const content = readFileSync(WORKFLOW_FILE, 'utf8');
    expect(content).toContain('setup-bun');
  });

  test('main.ts exists', () => {
    expect(existsSync(join(import.meta.dir, 'main.ts'))).toBe(true);
  });

  test('fixtures directory exists', () => {
    expect(existsSync(FIXTURES_DIR)).toBe(true);
  });

  test('actionlint passes on workflow file', () => {
    const result = spawnSync('actionlint', [WORKFLOW_FILE], { encoding: 'utf8' });
    if (result.error) {
      throw new Error(`actionlint not found: ${result.error.message}`);
    }
    expect(result.stdout + result.stderr).toBe('');
    expect(result.status).toBe(0);
  });
});
