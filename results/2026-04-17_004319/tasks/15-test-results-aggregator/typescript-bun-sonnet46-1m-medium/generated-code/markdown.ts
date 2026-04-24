// Generates a GitHub Actions job summary (Markdown) from AggregatedResults.
// The plain-text lines beginning "Total Tests:", "Passed:", etc. are used by
// the integration test harness for exact-value assertions.

import type { AggregatedResults } from './types';

function formatDuration(seconds: number): string {
  return `${seconds.toFixed(2)}s`;
}

export function generateMarkdown(results: AggregatedResults): string {
  const { totalTests, passed, failed, skipped, duration, flakyTests, suites } = results;

  const lines: string[] = [];

  lines.push('## Test Results Summary');
  lines.push('');
  lines.push('| Metric | Value |');
  lines.push('|--------|-------|');
  lines.push(`| Total Tests | ${totalTests} |`);
  lines.push(`| Passed | ${passed} |`);
  lines.push(`| Failed | ${failed} |`);
  lines.push(`| Skipped | ${skipped} |`);
  lines.push(`| Duration | ${formatDuration(duration)} |`);
  lines.push(`| Suites | ${results.totalSuites} |`);
  lines.push('');

  if (flakyTests.length > 0) {
    lines.push('### Flaky Tests');
    lines.push('');
    lines.push('| Test | Suite | Passes | Failures |');
    lines.push('|------|-------|--------|----------|');
    for (const f of flakyTests) {
      lines.push(`| ${f.testName} | ${f.suiteName} | ${f.passCount} | ${f.failCount} |`);
    }
    lines.push('');
  }

  if (failed > 0) {
    lines.push('### Failed Tests');
    lines.push('');
    for (const suite of suites) {
      const failures = suite.results.filter(r => r.status === 'failed');
      for (const f of failures) {
        lines.push(`- **${f.suiteName} > ${f.testName}**`);
        if (f.errorMessage) {
          lines.push(`  - ${f.errorMessage}`);
        }
      }
    }
    lines.push('');
  }

  // Plain-text summary lines — used for exact-value assertions in act output
  lines.push('<!-- summary-start -->');
  lines.push(`Total Tests: ${totalTests}`);
  lines.push(`Passed: ${passed}`);
  lines.push(`Failed: ${failed}`);
  lines.push(`Skipped: ${skipped}`);
  lines.push(`Duration: ${formatDuration(duration)}`);
  if (flakyTests.length > 0) {
    lines.push(`Flaky Tests (${flakyTests.length}):`);
    for (const f of flakyTests) {
      lines.push(`  - ${f.suiteName} > ${f.testName}`);
    }
  } else {
    lines.push('Flaky Tests (0): none');
  }
  lines.push('<!-- summary-end -->');

  return lines.join('\n');
}
