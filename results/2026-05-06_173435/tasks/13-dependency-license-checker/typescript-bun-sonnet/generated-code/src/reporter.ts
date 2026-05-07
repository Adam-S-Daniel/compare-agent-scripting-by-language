import type { ComplianceReport, DependencyResult } from './types';

// Aggregates check results into a structured report with summary counts.
export function generateReport(results: DependencyResult[]): ComplianceReport {
  const summary = {
    total: results.length,
    approved: results.filter((r) => r.status === 'approved').length,
    denied: results.filter((r) => r.status === 'denied').length,
    unknown: results.filter((r) => r.status === 'unknown').length,
  };
  return { results, summary, passed: summary.denied === 0 };
}

// Formats a ComplianceReport as a human-readable text block for stdout / CI logs.
export function formatReportText(report: ComplianceReport): string {
  const lines: string[] = ['=== Compliance Report ==='];

  for (const r of report.results) {
    const dep = `${r.dependency.name}@${r.dependency.version}`;
    if (r.status === 'unknown') {
      lines.push(`${dep}: unknown`);
    } else {
      lines.push(`${dep}: ${r.status} (${r.license})`);
    }
  }

  lines.push('');
  lines.push(`Total: ${report.summary.total} | Approved: ${report.summary.approved} | Denied: ${report.summary.denied} | Unknown: ${report.summary.unknown}`);
  lines.push(`Status: ${report.passed ? 'PASSED' : 'FAILED'}`);

  return lines.join('\n');
}
