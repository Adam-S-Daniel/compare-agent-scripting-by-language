import { describe, it, expect, beforeAll } from 'bun:test';
import { parseJunitXml, parseJsonResults } from '../src/parser';
import { TestSuite, TestCase } from '../src/types';
import * as fs from 'fs';
import * as path from 'path';

describe('JUnit XML Parser', () => {
  let sampleJunitXml: string;

  beforeAll(async () => {
    const fixtureDir = path.join(import.meta.dir, 'fixtures');
    const fixturePath = path.join(fixtureDir, 'sample-junit.xml');
    sampleJunitXml = await fs.promises.readFile(fixturePath, 'utf-8');
  });

  it('should parse a simple JUnit XML file with passing tests', async () => {
    const results = parseJunitXml(sampleJunitXml, 'run-1');

    expect(results.format).toBe('junit');
    expect(results.runId).toBe('run-1');
    expect(results.results.length).toBeGreaterThan(0);
  });

  it('should extract test counts from JUnit XML', async () => {
    const results = parseJunitXml(sampleJunitXml, 'run-1');
    const suite = results.results[0];

    expect(suite.tests).toBeGreaterThan(0);
    expect(suite.failures).toBeGreaterThanOrEqual(0);
    expect(suite.skipped).toBeGreaterThanOrEqual(0);
  });

  it('should extract individual test cases from JUnit XML', async () => {
    const results = parseJunitXml(sampleJunitXml, 'run-1');
    const suite = results.results[0];

    expect(suite.cases.length).toBe(suite.tests);
    expect(suite.cases[0].name).toBeDefined();
    expect(suite.cases[0].className).toBeDefined();
    expect(suite.cases[0].status).toMatch(/^(passed|failed|skipped)$/);
  });

  it('should assign runId to each test case', async () => {
    const results = parseJunitXml(sampleJunitXml, 'run-123');
    const suite = results.results[0];

    suite.cases.forEach(testCase => {
      expect(testCase.runId).toBe('run-123');
    });
  });
});

describe('JSON Parser', () => {
  let sampleJsonResults: string;

  beforeAll(async () => {
    const fixtureDir = path.join(import.meta.dir, 'fixtures');
    const fixturePath = path.join(fixtureDir, 'sample-results.json');
    sampleJsonResults = await fs.promises.readFile(fixturePath, 'utf-8');
  });

  it('should parse a simple JSON results file', async () => {
    const results = parseJsonResults(sampleJsonResults, 'run-2');

    expect(results.format).toBe('json');
    expect(results.runId).toBe('run-2');
    expect(results.results.length).toBeGreaterThan(0);
  });

  it('should extract test counts from JSON results', async () => {
    const results = parseJsonResults(sampleJsonResults, 'run-2');
    const suite = results.results[0];

    expect(suite.tests).toBeGreaterThan(0);
    expect(suite.failures).toBeGreaterThanOrEqual(0);
    expect(suite.skipped).toBeGreaterThanOrEqual(0);
  });

  it('should parse test cases from JSON results', async () => {
    const results = parseJsonResults(sampleJsonResults, 'run-2');
    const suite = results.results[0];

    expect(suite.cases.length).toBe(suite.tests);
    suite.cases.forEach(testCase => {
      expect(testCase.name).toBeDefined();
      expect(testCase.status).toMatch(/^(passed|failed|skipped)$/);
    });
  });
});
