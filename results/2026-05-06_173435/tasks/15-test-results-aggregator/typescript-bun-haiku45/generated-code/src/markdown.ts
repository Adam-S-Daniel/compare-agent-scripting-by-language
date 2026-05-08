import { AggregatedResults } from './types';

export function generateMarkdownSummary(aggregated: AggregatedResults): string {
  const durationSeconds = aggregated.totalDuration / 1000;
  const durationMinutes = durationSeconds / 60;

  let markdown = '# Test Results Summary\n\n';

  // Summary stats
  markdown += '## Summary\n\n';
  markdown += `| Metric | Value |\n`;
  markdown += `|--------|-------|\n`;
  markdown += `| Total Tests | ${aggregated.totalTests} |\n`;
  markdown += `| Passed | ${aggregated.totalPassed} |\n`;
  markdown += `| Failed | ${aggregated.totalFailed} |\n`;
  markdown += `| Skipped | ${aggregated.totalSkipped} |\n`;
  markdown += `| Duration | ${durationMinutes.toFixed(2)}s |\n\n`;

  // Pass rate
  const passRate = aggregated.totalTests > 0
    ? ((aggregated.totalPassed / aggregated.totalTests) * 100).toFixed(1)
    : '0.0';
  markdown += `**Pass Rate:** ${passRate}%\n\n`;

  // Status indicator
  if (aggregated.totalFailed === 0) {
    markdown += '✅ All tests passed!\n\n';
  } else {
    markdown += `❌ ${aggregated.totalFailed} test(s) failed\n\n`;
  }

  // Flaky tests
  if (aggregated.flakyTests.length > 0) {
    markdown += '## Flaky Tests\n\n';
    markdown += 'The following tests passed in some runs but failed in others:\n\n';

    for (const flaky of aggregated.flakyTests) {
      markdown += `- **${flaky.className}::${flaky.name}**\n`;
      markdown += `  - Failures: ${flaky.failureCount}, Passages: ${flaky.passageCount}\n`;
      markdown += `  - Runs affected: ${flaky.runIds.join(', ')}\n`;
    }
    markdown += '\n';
  }

  // Failed tests by suite
  if (aggregated.totalFailed > 0) {
    markdown += '## Failed Tests\n\n';
    for (const suite of aggregated.suites) {
      const failedCases = suite.cases.filter(c => c.status === 'failed');
      if (failedCases.length > 0) {
        markdown += `### ${suite.name}\n\n`;
        for (const testCase of failedCases) {
          markdown += `- **${testCase.className}::${testCase.name}**`;
          if (testCase.message) {
            markdown += ` - ${testCase.message}`;
          }
          markdown += `\n`;
        }
        markdown += '\n';
      }
    }
  }

  return markdown;
}
