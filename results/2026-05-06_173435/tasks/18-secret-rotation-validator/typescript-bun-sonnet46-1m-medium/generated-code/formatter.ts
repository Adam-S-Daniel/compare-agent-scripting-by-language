// Output formatters — JSON and Markdown table
// GREEN: implement both formats to satisfy formatter tests

import type { RotationReport, SecretAnalysis } from './validator';

export function formatJSON(report: RotationReport): string {
  return JSON.stringify(report, null, 2);
}

function tableRow(cells: string[]): string {
  return `| ${cells.join(' | ')} |`;
}

function analysisRows(analyses: SecretAnalysis[], expired: boolean): string {
  return analyses
    .map(a => {
      const daysCol = expired
        ? String(Math.abs(a.daysUntilExpiry)) + ' days overdue'
        : String(a.daysUntilExpiry) + ' days';
      return tableRow([a.secret.name, a.expiryDate, daysCol, a.secret.requiredByServices.join(', ') || '—']);
    })
    .join('\n');
}

export function formatMarkdown(report: RotationReport): string {
  const lines: string[] = [
    '# Secret Rotation Report',
    '',
    `Generated: ${report.generatedAt}`,
    `Warning window: ${report.warningWindowDays} days`,
    '',
    '## Summary',
    '',
    tableRow(['Status', 'Count']),
    tableRow(['------', '-----']),
    tableRow(['Expired', String(report.summary.expired)]),
    tableRow(['Warning', String(report.summary.warning)]),
    tableRow(['OK',      String(report.summary.ok)]),
    tableRow(['Total',   String(report.summary.total)]),
    '',
  ];

  if (report.expired.length > 0) {
    lines.push('## Expired Secrets (Immediate Action Required)', '');
    lines.push(tableRow(['Secret', 'Expiry Date', 'Overdue', 'Required By']));
    lines.push(tableRow(['------', '-----------', '-------', '-----------']));
    lines.push(analysisRows(report.expired, true));
    lines.push('');
  }

  if (report.warning.length > 0) {
    lines.push('## Warning Secrets (Rotation Upcoming)', '');
    lines.push(tableRow(['Secret', 'Expiry Date', 'Days Left', 'Required By']));
    lines.push(tableRow(['------', '-----------', '---------', '-----------']));
    lines.push(analysisRows(report.warning, false));
    lines.push('');
  }

  if (report.ok.length > 0) {
    lines.push('## OK Secrets', '');
    lines.push(tableRow(['Secret', 'Expiry Date', 'Days Left', 'Required By']));
    lines.push(tableRow(['------', '-----------', '---------', '-----------']));
    lines.push(analysisRows(report.ok, false));
    lines.push('');
  }

  return lines.join('\n');
}
