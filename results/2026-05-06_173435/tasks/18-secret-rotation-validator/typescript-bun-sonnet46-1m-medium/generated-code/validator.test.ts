// Secret Rotation Validator — Test Suite
// TDD approach: each describe block follows RED → GREEN → REFACTOR
// RED: tests are written first against the interface; they fail until implementation exists.
// GREEN: implement minimum code in validator.ts / formatter.ts to pass.

import { describe, it, expect } from 'bun:test';
import {
  daysUntilExpiry,
  getExpiryDate,
  analyzeSecret,
  generateReport,
} from './validator';
import { formatJSON, formatMarkdown } from './formatter';
import type { Secret, ValidatorConfig } from './validator';

// ─── RED #1: pure date-math helpers ───────────────────────────────────────────

describe('daysUntilExpiry', () => {
  it('returns negative value for an already-expired secret', () => {
    // lastRotated=2025-12-01, policy=90 days → expires 2026-03-01
    // reference=2026-05-08 → 68 days past expiry → -68
    const days = daysUntilExpiry('2025-12-01', 90, new Date('2026-05-08'));
    expect(days).toBe(-68);
  });

  it('returns 0 for a secret expiring exactly today', () => {
    // 2026-04-08 + 30 = 2026-05-08 (reference date)
    const days = daysUntilExpiry('2026-04-08', 30, new Date('2026-05-08'));
    expect(days).toBe(0);
  });

  it('returns positive value for a secret that still has time', () => {
    // 2026-04-16 + 30 = 2026-05-16; from 2026-05-08 = 8 days remaining
    const days = daysUntilExpiry('2026-04-16', 30, new Date('2026-05-08'));
    expect(days).toBe(8);
  });
});

describe('getExpiryDate', () => {
  it('computes expiry date for a 90-day policy', () => {
    // 2025-12-01 + 90 days = 2026-03-01
    expect(getExpiryDate('2025-12-01', 90)).toBe('2026-03-01');
  });

  it('computes expiry date for a 30-day policy', () => {
    // 2026-04-14 + 30 = 2026-05-14
    expect(getExpiryDate('2026-04-14', 30)).toBe('2026-05-14');
  });
});

// ─── RED #2: single-secret urgency classification ──────────────────────────────

describe('analyzeSecret', () => {
  const refDate = new Date('2026-05-08');
  const warningDays = 7;

  it('classifies an overdue secret as expired', () => {
    const secret: Secret = {
      name: 'DB_PASSWORD',
      lastRotated: '2025-12-01',
      rotationPolicyDays: 90,
      requiredByServices: ['api', 'workers'],
    };
    const result = analyzeSecret(secret, warningDays, refDate);
    expect(result.urgency).toBe('expired');
    expect(result.daysUntilExpiry).toBe(-68);
    expect(result.expiryDate).toBe('2026-03-01');
    expect(result.secret).toBe(secret);
  });

  it('classifies a secret within the warning window as warning', () => {
    const secret: Secret = {
      name: 'JWT_SECRET',
      lastRotated: '2026-04-14',
      rotationPolicyDays: 30,
      requiredByServices: ['auth'],
    };
    const result = analyzeSecret(secret, warningDays, refDate);
    expect(result.urgency).toBe('warning');
    expect(result.daysUntilExpiry).toBe(6);
  });

  it('classifies a secret exactly at the warning boundary as warning', () => {
    // 2026-04-15 + 30 = 2026-05-15; from 2026-05-08 = 7 days (== warningDays)
    const secret: Secret = {
      name: 'BOUNDARY',
      lastRotated: '2026-04-15',
      rotationPolicyDays: 30,
      requiredByServices: [],
    };
    const result = analyzeSecret(secret, warningDays, refDate);
    expect(result.urgency).toBe('warning');
    expect(result.daysUntilExpiry).toBe(7);
  });

  it('classifies a secret beyond the warning window as ok', () => {
    const secret: Secret = {
      name: 'API_KEY',
      lastRotated: '2026-04-16',
      rotationPolicyDays: 30,
      requiredByServices: ['frontend'],
    };
    const result = analyzeSecret(secret, warningDays, refDate);
    expect(result.urgency).toBe('ok');
    expect(result.daysUntilExpiry).toBe(8);
  });
});

// ─── RED #3: full report generation ───────────────────────────────────────────

const FIXTURE_CONFIG: ValidatorConfig = {
  warningWindowDays: 7,
  referenceDate: '2026-05-08',
  secrets: [
    { name: 'DB_PASSWORD',  lastRotated: '2025-12-01', rotationPolicyDays: 90,  requiredByServices: ['api', 'workers'] },
    { name: 'JWT_SECRET',   lastRotated: '2026-04-14', rotationPolicyDays: 30,  requiredByServices: ['auth'] },
    { name: 'API_KEY',      lastRotated: '2026-04-16', rotationPolicyDays: 30,  requiredByServices: ['frontend'] },
    { name: 'DEPLOY_KEY',   lastRotated: '2026-01-01', rotationPolicyDays: 365, requiredByServices: ['deploy'] },
  ],
};

describe('generateReport', () => {
  it('produces correct summary counts for mixed fixture', () => {
    const report = generateReport(FIXTURE_CONFIG);
    expect(report.summary.total).toBe(4);
    expect(report.summary.expired).toBe(1);
    expect(report.summary.warning).toBe(1);
    expect(report.summary.ok).toBe(2);
  });

  it('places each secret in the correct urgency bucket', () => {
    const report = generateReport(FIXTURE_CONFIG);

    expect(report.expired.length).toBe(1);
    expect(report.expired[0].secret.name).toBe('DB_PASSWORD');

    expect(report.warning.length).toBe(1);
    expect(report.warning[0].secret.name).toBe('JWT_SECRET');

    expect(report.ok.length).toBe(2);
    const okNames = report.ok.map(a => a.secret.name);
    expect(okNames).toContain('API_KEY');
    expect(okNames).toContain('DEPLOY_KEY');
  });

  it('uses today when referenceDate is omitted', () => {
    // A secret last rotated in 2020 with a 1-day policy is definitely expired
    const config: ValidatorConfig = {
      warningWindowDays: 7,
      secrets: [{ name: 'OLD', lastRotated: '2020-01-01', rotationPolicyDays: 1, requiredByServices: [] }],
    };
    const report = generateReport(config);
    expect(report.summary.expired).toBe(1);
  });

  it('throws a meaningful error when secrets is missing', () => {
    expect(() =>
      generateReport({ secrets: null as unknown as Secret[], warningWindowDays: 7 })
    ).toThrow('secrets');
  });

  it('throws a meaningful error when warningWindowDays is negative', () => {
    expect(() =>
      generateReport({ secrets: [], warningWindowDays: -1 })
    ).toThrow('warningWindowDays');
  });
});

// ─── RED #4: output formatters ────────────────────────────────────────────────

describe('formatJSON', () => {
  it('serialises the report to valid, parseable JSON', () => {
    const report = generateReport(FIXTURE_CONFIG);
    const json = formatJSON(report);
    const parsed = JSON.parse(json);
    expect(parsed.summary.total).toBe(4);
    expect(parsed.summary.expired).toBe(1);
    expect(parsed.expired[0].secret.name).toBe('DB_PASSWORD');
  });

  it('includes all top-level fields', () => {
    const report = generateReport(FIXTURE_CONFIG);
    const parsed = JSON.parse(formatJSON(report));
    expect(typeof parsed.generatedAt).toBe('string');
    expect(typeof parsed.warningWindowDays).toBe('number');
    expect(Array.isArray(parsed.expired)).toBe(true);
    expect(Array.isArray(parsed.warning)).toBe(true);
    expect(Array.isArray(parsed.ok)).toBe(true);
  });
});

describe('formatMarkdown', () => {
  it('produces a markdown report with the correct heading', () => {
    const report = generateReport(FIXTURE_CONFIG);
    const md = formatMarkdown(report);
    expect(md).toContain('# Secret Rotation Report');
  });

  it('includes an Expired section with the correct secret name', () => {
    const report = generateReport(FIXTURE_CONFIG);
    const md = formatMarkdown(report);
    expect(md).toContain('Expired');
    expect(md).toContain('DB_PASSWORD');
  });

  it('includes a Warning section with the correct secret name', () => {
    const report = generateReport(FIXTURE_CONFIG);
    const md = formatMarkdown(report);
    expect(md).toContain('Warning');
    expect(md).toContain('JWT_SECRET');
  });

  it('includes an OK section when there are healthy secrets', () => {
    const report = generateReport(FIXTURE_CONFIG);
    const md = formatMarkdown(report);
    expect(md).toContain('OK');
    expect(md).toContain('API_KEY');
  });

  it('omits empty sections', () => {
    const allOkConfig: ValidatorConfig = {
      warningWindowDays: 7,
      referenceDate: '2026-05-08',
      secrets: [
        { name: 'FRESH', lastRotated: '2026-05-01', rotationPolicyDays: 90, requiredByServices: [] },
      ],
    };
    const report = generateReport(allOkConfig);
    const md = formatMarkdown(report);
    expect(md).not.toContain('Expired Secrets');
    expect(md).not.toContain('Warning Secrets');
  });
});
