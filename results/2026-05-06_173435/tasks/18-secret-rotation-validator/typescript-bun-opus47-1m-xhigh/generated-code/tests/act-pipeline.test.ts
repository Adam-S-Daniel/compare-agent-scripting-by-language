// End-to-end pipeline tests.
//
// Each test:
//   1. Creates a fresh temp git repo seeded with the project files plus the
//      test case's fixture data and (optional) test-config.json
//   2. Runs `act push --rm` in that repo
//   3. Captures act's output and appends it to act-result.txt with a banner
//   4. Asserts the workflow exited cleanly, the job reported success, and
//      the validator's output matches the *exact* values we expect for the
//      input, not just "something was printed"
//
// Runs are sequential — act spins up a Docker container per case and we want
// the act-result.txt entries written deterministically, in order.
//
// We intentionally keep this to 3 cases to respect the 3-run budget on `act`.

import { afterAll, beforeAll, describe, expect, test } from 'bun:test';
import {
  appendFileSync,
  copyFileSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const PROJECT_ROOT = process.cwd();
const ACT_RESULT_FILE = join(PROJECT_ROOT, 'act-result.txt');

// Files that must be copied into every per-case temp repo. Anything here has
// to actually exist in the project root or setupRepo will throw.
const PROJECT_FILES = ['validator.ts', 'ci-run.ts', 'package.json', 'tsconfig.json', '.actrc'];

interface SecretFixture {
  name: string;
  lastRotated: string;
  rotationPolicyDays: number;
  requiredBy: string[];
}

interface TestConfig {
  warningDays?: number;
  format?: 'markdown' | 'json';
  now?: string;
  secretsPath?: string;
}

interface CaseSpec {
  caseName: string;
  description: string;
  secrets: SecretFixture[];
  config: TestConfig;
}

interface ActResult {
  exitCode: number;
  stdout: string;
  stderr: string;
}

// Reset act-result.txt at the very start of the suite so repeated `bun test`
// runs don't accumulate stale output.
beforeAll(() => {
  writeFileSync(ACT_RESULT_FILE, `# act-result.txt — generated ${new Date().toISOString()}\n`);
});

afterAll(() => {
  // Leave act-result.txt in place — it is a required artifact.
});

function setupRepo(spec: CaseSpec): string {
  const dir = mkdtempSync(join(tmpdir(), 'secret-rotation-act-'));
  for (const f of PROJECT_FILES) {
    const src = join(PROJECT_ROOT, f);
    if (!existsSync(src)) throw new Error(`Project file missing: ${f}`);
    copyFileSync(src, join(dir, f));
  }

  // Replicate the workflow into the temp repo. act discovers workflows under
  // .github/workflows in the working directory by default.
  mkdirSync(join(dir, '.github', 'workflows'), { recursive: true });
  copyFileSync(
    join(PROJECT_ROOT, '.github', 'workflows', 'secret-rotation-validator.yml'),
    join(dir, '.github', 'workflows', 'secret-rotation-validator.yml'),
  );

  // Per-case fixture data.
  mkdirSync(join(dir, 'fixtures'), { recursive: true });
  writeFileSync(join(dir, 'fixtures', 'secrets.json'), JSON.stringify(spec.secrets, null, 2));

  // Per-case knobs read by ci-run.ts.
  writeFileSync(join(dir, 'test-config.json'), JSON.stringify(spec.config, null, 2));

  // act needs a git repo for $GITHUB_SHA / $GITHUB_REF context. A single
  // local commit is enough; we never push.
  const sh = (cmd: string, args: string[]): void => {
    const r = spawnSync(cmd, args, { cwd: dir, encoding: 'utf8' });
    if (r.status !== 0) {
      throw new Error(`${cmd} ${args.join(' ')} failed in ${dir}: ${r.stderr}`);
    }
  };
  sh('git', ['init', '--quiet', '-b', 'main']);
  sh('git', ['config', 'user.email', 'test@example.com']);
  sh('git', ['config', 'user.name', 'Test Runner']);
  sh('git', ['config', 'commit.gpgsign', 'false']);
  sh('git', ['add', '-A']);
  sh('git', ['commit', '--quiet', '-m', `seed ${spec.caseName}`]);

  return dir;
}

function runAct(repo: string): ActResult {
  // --rm removes the container after the run; we don't need it for diagnosis
  // because we capture stdout/stderr explicitly here.
  // --pull=false: the act-ubuntu-pwsh image is built locally and is NOT
  // available in any registry. Without this, act tries to pull and fails.
  const r = spawnSync('act', ['push', '--rm', '--pull=false'], {
    cwd: repo,
    encoding: 'utf8',
    maxBuffer: 100 * 1024 * 1024,
  });
  return {
    exitCode: r.status ?? -1,
    stdout: r.stdout ?? '',
    stderr: r.stderr ?? '',
  };
}

function appendActResult(spec: CaseSpec, repo: string, res: ActResult): void {
  const banner = `\n${'='.repeat(80)}\nTEST CASE: ${spec.caseName}\n${spec.description}\nrepo: ${repo}\nexit: ${res.exitCode}\n${'='.repeat(80)}\n`;
  appendFileSync(ACT_RESULT_FILE, banner);
  appendFileSync(ACT_RESULT_FILE, '--- STDOUT ---\n');
  appendFileSync(ACT_RESULT_FILE, res.stdout);
  appendFileSync(ACT_RESULT_FILE, '\n--- STDERR ---\n');
  appendFileSync(ACT_RESULT_FILE, res.stderr);
  appendFileSync(ACT_RESULT_FILE, '\n');
}

// Strip ANSI color codes that some act builds emit even when stdout isn't a TTY.
function stripAnsi(s: string): string {
  // eslint-disable-next-line no-control-regex
  return s.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '');
}

// Pull the validator's stdout out of act's interleaved log output by looking
// for the markers ci-run.ts wraps it in. Each act log line that originates
// from a `run:` step is prefixed with `[<workflow>/<job>]   | <content>`.
function extractValidatorOutput(actStdout: string): string {
  const cleaned = stripAnsi(actStdout);
  const lines = cleaned.split('\n');
  const collected: string[] = [];
  let inOutput = false;
  for (const line of lines) {
    const match = line.match(/^\[[^\]]+\]\s+\|\s?(.*)$/);
    const content = match ? match[1]! : null;
    if (content === '===VALIDATOR-OUTPUT-START===') {
      inOutput = true;
      continue;
    }
    if (content === '===VALIDATOR-OUTPUT-END===') {
      inOutput = false;
      continue;
    }
    if (inOutput && content !== null) collected.push(content);
  }
  return collected.join('\n');
}

function assertJobSucceeded(actStdout: string): void {
  // act prints "Job succeeded" once per successful job. Strip ANSI first
  // because some builds wrap that string in color codes.
  expect(stripAnsi(actStdout)).toMatch(/Job succeeded/);
}

const cases: CaseSpec[] = [
  {
    caseName: 'all-ok-json',
    description:
      'All secrets are well within their rotation windows. JSON output should report 0 expired, 0 warning, 2 ok.',
    secrets: [
      // 1 day since rotation, 90-day policy → 89 days until expiry → ok.
      {
        name: 'db-password',
        lastRotated: '2026-05-07',
        rotationPolicyDays: 90,
        requiredBy: ['api', 'worker'],
      },
      // 7 days since rotation, 365-day policy → 358 days until expiry → ok.
      {
        name: 'api-token',
        lastRotated: '2026-05-01',
        rotationPolicyDays: 365,
        requiredBy: ['api'],
      },
    ],
    config: {
      warningDays: 14,
      format: 'json',
      now: '2026-05-08T00:00:00Z',
    },
  },
  {
    caseName: 'mixed-markdown',
    description:
      'Mix of expired (2), warning (1), and ok (1) secrets rendered as markdown. Verifies counts, sort order, and exact row content.',
    secrets: [
      // Expired by 70 days.
      {
        name: 'expired-key',
        lastRotated: '2026-01-28',
        rotationPolicyDays: 30,
        requiredBy: ['api', 'worker'],
      },
      // Expired by 1 day (boundary).
      {
        name: 'barely-expired',
        lastRotated: '2026-04-07',
        rotationPolicyDays: 30,
        requiredBy: ['scheduler'],
      },
      // 10 days until expiry, within 14-day warning window.
      {
        name: 'warning-key',
        lastRotated: '2026-02-17',
        rotationPolicyDays: 90,
        requiredBy: ['api'],
      },
      // 364 days until expiry, comfortably ok.
      {
        name: 'ok-key',
        lastRotated: '2026-05-07',
        rotationPolicyDays: 365,
        requiredBy: ['frontend'],
      },
    ],
    config: {
      warningDays: 14,
      format: 'markdown',
      now: '2026-05-08T00:00:00Z',
    },
  },
  {
    caseName: 'all-expired-json-services',
    description:
      'Two expired secrets with multi-service requiredBy lists, JSON output, narrow 7-day warning window.',
    secrets: [
      {
        name: 'alpha-secret',
        lastRotated: '2026-04-01',
        rotationPolicyDays: 30,
        requiredBy: ['api', 'worker', 'scheduler'],
      },
      {
        name: 'beta-secret',
        lastRotated: '2025-12-01',
        rotationPolicyDays: 60,
        requiredBy: ['billing'],
      },
    ],
    config: {
      warningDays: 7,
      format: 'json',
      now: '2026-05-08T00:00:00Z',
    },
  },
];

describe('end-to-end pipeline via act', () => {
  for (const spec of cases) {
    test(
      `act push -- ${spec.caseName}`,
      () => {
        const repo = setupRepo(spec);
        let res: ActResult;
        try {
          res = runAct(repo);
        } finally {
          // Even on failure we want the repo gone — act-result.txt has all the
          // diagnostics we need.
        }
        appendActResult(spec, repo, res);

        try {
          expect(res.exitCode).toBe(0);
          assertJobSucceeded(res.stdout);

          const validatorOutput = extractValidatorOutput(res.stdout);
          if (spec.config.format === 'json') {
            assertJsonCase(spec, validatorOutput);
          } else {
            assertMarkdownCase(spec, validatorOutput);
          }
        } finally {
          rmSync(repo, { recursive: true, force: true });
        }
      },
      300_000,
    );
  }
});

function assertJsonCase(spec: CaseSpec, output: string): void {
  let parsed: {
    generatedAt: string;
    warningWindowDays: number;
    totals: { expired: number; warning: number; ok: number };
    expired: Array<{ name: string; daysUntilExpiry: number; requiredBy: string[]; status: string }>;
    warning: Array<{ name: string; daysUntilExpiry: number; status: string }>;
    ok: Array<{ name: string; daysUntilExpiry: number; status: string }>;
  };
  try {
    parsed = JSON.parse(output);
  } catch (e) {
    throw new Error(`Failed to parse JSON output for ${spec.caseName}: ${(e as Error).message}\nRaw output:\n${output}`);
  }

  if (spec.caseName === 'all-ok-json') {
    expect(parsed.warningWindowDays).toBe(14);
    expect(parsed.totals).toEqual({ expired: 0, warning: 0, ok: 2 });
    expect(parsed.expired).toEqual([]);
    expect(parsed.warning).toEqual([]);
    expect(parsed.ok).toHaveLength(2);
    // ok sorted by daysUntilExpiry ASC: db-password (89) before api-token (358).
    expect(parsed.ok[0]!.name).toBe('db-password');
    expect(parsed.ok[0]!.daysUntilExpiry).toBe(89);
    expect(parsed.ok[0]!.status).toBe('ok');
    expect(parsed.ok[1]!.name).toBe('api-token');
    expect(parsed.ok[1]!.daysUntilExpiry).toBe(358);
    expect(parsed.generatedAt).toBe('2026-05-08T00:00:00.000Z');
    return;
  }

  if (spec.caseName === 'all-expired-json-services') {
    expect(parsed.warningWindowDays).toBe(7);
    expect(parsed.totals).toEqual({ expired: 2, warning: 0, ok: 0 });
    expect(parsed.warning).toEqual([]);
    expect(parsed.ok).toEqual([]);
    expect(parsed.expired).toHaveLength(2);
    // Sorted by daysUntilExpiry ASC: beta-secret (-98) before alpha-secret (-7).
    expect(parsed.expired[0]!.name).toBe('beta-secret');
    expect(parsed.expired[0]!.daysUntilExpiry).toBe(-98);
    expect(parsed.expired[0]!.status).toBe('expired');
    expect(parsed.expired[0]!.requiredBy).toEqual(['billing']);
    expect(parsed.expired[1]!.name).toBe('alpha-secret');
    expect(parsed.expired[1]!.daysUntilExpiry).toBe(-7);
    expect(parsed.expired[1]!.requiredBy).toEqual(['api', 'worker', 'scheduler']);
    return;
  }

  throw new Error(`No JSON assertions defined for case ${spec.caseName}`);
}

function assertMarkdownCase(spec: CaseSpec, output: string): void {
  if (spec.caseName !== 'mixed-markdown') {
    throw new Error(`No markdown assertions defined for case ${spec.caseName}`);
  }
  // Header + summary row counts.
  expect(output).toContain('# Secret Rotation Report');
  expect(output).toContain('- Warning window: 14 days');
  expect(output).toContain('| Expired | 2 |');
  expect(output).toContain('| Warning | 1 |');
  expect(output).toContain('| OK | 1 |');
  // Section headers.
  expect(output).toContain('## Expired (2)');
  expect(output).toContain('## Warning (1)');
  expect(output).toContain('## OK (1)');
  // Exact rows — verifies sort order, computed days, and service formatting.
  expect(output).toContain('| expired-key | 2026-01-28 | 30 | 70 | api, worker |');
  expect(output).toContain('| barely-expired | 2026-04-07 | 30 | 1 | scheduler |');
  expect(output).toContain('| warning-key | 2026-02-17 | 90 | 10 | api |');
  expect(output).toContain('| ok-key | 2026-05-07 | 365 | 364 | frontend |');
  // expired-key (-70) should appear above barely-expired (-1) in the expired
  // table; verify by index in the rendered string.
  const expiredKeyIdx = output.indexOf('| expired-key |');
  const barelyIdx = output.indexOf('| barely-expired |');
  expect(expiredKeyIdx).toBeGreaterThan(-1);
  expect(barelyIdx).toBeGreaterThan(-1);
  expect(expiredKeyIdx).toBeLessThan(barelyIdx);
}
