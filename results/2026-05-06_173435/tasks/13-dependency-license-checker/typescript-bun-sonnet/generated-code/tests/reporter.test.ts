// TDD: reporter tests - written BEFORE implementation (red phase)
import { describe, test, expect } from 'bun:test';
import { generateReport, formatReportText } from '../src/reporter';
import type { DependencyResult } from '../src/types';

const results: DependencyResult[] = [
  { dependency: { name: 'react', version: '^18.0.0' }, license: 'MIT', status: 'approved' },
  { dependency: { name: 'lodash', version: '4.17.21' }, license: 'MIT', status: 'approved' },
  { dependency: { name: 'gpl-lib', version: '1.0.0' }, license: 'GPL-3.0', status: 'denied' },
  { dependency: { name: 'mystery-pkg', version: '2.0.0' }, license: null, status: 'unknown' },
];

describe('generateReport', () => {
  test('computes correct summary counts', () => {
    const report = generateReport(results);
    expect(report.summary.total).toBe(4);
    expect(report.summary.approved).toBe(2);
    expect(report.summary.denied).toBe(1);
    expect(report.summary.unknown).toBe(1);
  });

  test('passed is false when any dependency is denied', () => {
    const report = generateReport(results);
    expect(report.passed).toBe(false);
  });

  test('passed is true when no dependencies are denied', () => {
    const onlyApproved: DependencyResult[] = [
      { dependency: { name: 'react', version: '^18.0.0' }, license: 'MIT', status: 'approved' },
    ];
    const report = generateReport(onlyApproved);
    expect(report.passed).toBe(true);
  });

  test('includes all result entries', () => {
    const report = generateReport(results);
    expect(report.results).toHaveLength(4);
  });
});

describe('formatReportText', () => {
  test('contains status header line', () => {
    const report = generateReport(results);
    const text = formatReportText(report);
    expect(text).toContain('=== Compliance Report ===');
    expect(text).toContain('Status: FAILED');
  });

  test('lists each dependency with its status and license', () => {
    const report = generateReport(results);
    const text = formatReportText(report);
    expect(text).toContain('react@^18.0.0: approved (MIT)');
    expect(text).toContain('lodash@4.17.21: approved (MIT)');
    expect(text).toContain('gpl-lib@1.0.0: denied (GPL-3.0)');
    expect(text).toContain('mystery-pkg@2.0.0: unknown');
  });

  test('summary line contains exact counts', () => {
    const report = generateReport(results);
    const text = formatReportText(report);
    expect(text).toContain('Total: 4');
    expect(text).toContain('Approved: 2');
    expect(text).toContain('Denied: 1');
    expect(text).toContain('Unknown: 1');
  });

  test('Status: PASSED when no denied licenses', () => {
    const onlyApproved: DependencyResult[] = [
      { dependency: { name: 'react', version: '^18.0.0' }, license: 'MIT', status: 'approved' },
    ];
    const text = formatReportText(generateReport(onlyApproved));
    expect(text).toContain('Status: PASSED');
  });
});
