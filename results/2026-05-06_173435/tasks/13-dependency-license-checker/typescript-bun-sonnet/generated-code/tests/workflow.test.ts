// Workflow structure tests + act integration tests.
// These run via `bun test` and orchestrate act runs, writing output to act-result.txt.
import { describe, test, expect, beforeAll } from 'bun:test';
import { spawnSync } from 'child_process';
import { mkdtempSync, mkdirSync, cpSync, writeFileSync, existsSync, appendFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';

const PROJECT_ROOT = join(import.meta.dir, '..');
const WORKFLOW_PATH = join(PROJECT_ROOT, '.github/workflows/dependency-license-checker.yml');
const ACT_RESULT_FILE = join(PROJECT_ROOT, 'act-result.txt');

// ── Workflow Structure Tests ─────────────────────────────────────────────────

describe('Workflow Structure', () => {
  test('workflow file exists', () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test('workflow references checkout action', async () => {
    const content = await Bun.file(WORKFLOW_PATH).text();
    expect(content).toContain('actions/checkout@v4');
  });

  test('workflow has push trigger', async () => {
    const content = await Bun.file(WORKFLOW_PATH).text();
    expect(content).toContain('push');
  });

  test('workflow has check-licenses job', async () => {
    const content = await Bun.file(WORKFLOW_PATH).text();
    expect(content).toContain('check-licenses');
  });

  test('workflow references src/index.ts', async () => {
    const content = await Bun.file(WORKFLOW_PATH).text();
    expect(content).toContain('src/index.ts');
  });

  test('script file src/index.ts exists', () => {
    expect(existsSync(join(PROJECT_ROOT, 'src/index.ts'))).toBe(true);
  });

  test('fixture files exist', () => {
    expect(existsSync(join(PROJECT_ROOT, 'fixtures/package.json'))).toBe(true);
    expect(existsSync(join(PROJECT_ROOT, 'fixtures/license-config.json'))).toBe(true);
    expect(existsSync(join(PROJECT_ROOT, 'fixtures/mock-db.json'))).toBe(true);
  });

  test('actionlint passes', () => {
    const result = spawnSync('actionlint', [WORKFLOW_PATH], {
      encoding: 'utf-8',
    });
    if (result.status !== 0) {
      console.error('actionlint output:', result.stdout + result.stderr);
    }
    expect(result.status).toBe(0);
  });
});

// ── Act Integration Tests ────────────────────────────────────────────────────

// Helpers to set up a disposable git repo for act runs
function setupTempRepo(): string {
  const tmpDir = mkdtempSync(join(tmpdir(), 'license-checker-act-'));

  // Copy project files excluding .git, node_modules, and the result file itself
  cpSync(PROJECT_ROOT, tmpDir, {
    recursive: true,
    filter: (src: string) => {
      const rel = src.slice(PROJECT_ROOT.length);
      return (
        !rel.startsWith('/.git/') &&
        rel !== '/.git' &&
        !rel.startsWith('/node_modules') &&
        rel !== '/act-result.txt'
      );
    },
  });

  // Initialise a minimal git repo so act can run
  spawnSync('git', ['init'], { cwd: tmpDir });
  spawnSync('git', ['config', 'user.email', 'test@test.com'], { cwd: tmpDir });
  spawnSync('git', ['config', 'user.name', 'Test'], { cwd: tmpDir });
  spawnSync('git', ['add', '-A'], { cwd: tmpDir });
  spawnSync('git', ['commit', '-m', 'ci: test run'], { cwd: tmpDir });

  return tmpDir;
}

function appendActResult(label: string, exitCode: number | null, output: string): void {
  const delimiter = '='.repeat(60);
  appendFileSync(
    ACT_RESULT_FILE,
    `\n${delimiter}\n=== Test Case: ${label} ===\nExit code: ${exitCode}\nOutput:\n${output}\n${delimiter}\n`,
  );
}

// Timeout: act + Docker startup can take up to 3 minutes
const ACT_TIMEOUT_MS = 300_000;

describe('Act Integration', () => {
  // Initialise the result file once before any act tests run
  beforeAll(() => {
    writeFileSync(ACT_RESULT_FILE, `act-result.txt — Dependency License Checker\nGenerated: ${new Date().toISOString()}\n`);
  });

  test(
    'workflow runs with mixed fixtures and outputs correct compliance report',
    () => {
      const tmpDir = setupTempRepo();

      const proc = spawnSync('act', ['push', '--rm', '--pull=false'], {
        cwd: tmpDir,
        encoding: 'utf-8',
        timeout: ACT_TIMEOUT_MS,
        env: { ...process.env, HOME: process.env.HOME },
      });

      const output = (proc.stdout ?? '') + (proc.stderr ?? '');
      appendActResult('Mixed fixtures (approved + denied + unknown)', proc.status, output);

      // Job must succeed
      expect(proc.status).toBe(0);
      expect(output).toContain('Job succeeded');

      // Exact dependency status lines
      expect(output).toContain('react@^18.0.0: approved (MIT)');
      expect(output).toContain('lodash@4.17.21: approved (MIT)');
      expect(output).toContain('gpl-lib@1.0.0: denied (GPL-3.0)');
      expect(output).toContain('mystery-pkg@2.0.0: unknown');
      expect(output).toContain('typescript@^5.0.0: approved (Apache-2.0)');

      // Exact summary counts
      expect(output).toContain('Total: 5');
      expect(output).toContain('Approved: 3');
      expect(output).toContain('Denied: 1');
      expect(output).toContain('Unknown: 1');
      expect(output).toContain('Status: FAILED');
    },
    { timeout: ACT_TIMEOUT_MS },
  );

  test(
    'workflow runs with all-approved fixtures and reports PASSED',
    () => {
      const tmpDir = setupTempRepo();

      // Override the fixture files to contain only approved licenses
      writeFileSync(
        join(tmpDir, 'fixtures/package.json'),
        JSON.stringify({
          name: 'all-approved-project',
          dependencies: { express: '4.18.0', axios: '1.6.0' },
        }),
      );
      writeFileSync(
        join(tmpDir, 'fixtures/mock-db.json'),
        JSON.stringify({ express: 'MIT', axios: 'MIT' }),
      );

      // Recommit the updated fixtures
      spawnSync('git', ['add', '-A'], { cwd: tmpDir });
      spawnSync('git', ['commit', '-m', 'ci: all-approved fixture'], { cwd: tmpDir });

      const proc = spawnSync('act', ['push', '--rm', '--pull=false'], {
        cwd: tmpDir,
        encoding: 'utf-8',
        timeout: ACT_TIMEOUT_MS,
        env: { ...process.env, HOME: process.env.HOME },
      });

      const output = (proc.stdout ?? '') + (proc.stderr ?? '');
      appendActResult('All-approved fixtures', proc.status, output);

      expect(proc.status).toBe(0);
      expect(output).toContain('Job succeeded');
      expect(output).toContain('express@4.18.0: approved (MIT)');
      expect(output).toContain('axios@1.6.0: approved (MIT)');
      expect(output).toContain('Approved: 2');
      expect(output).toContain('Denied: 0');
      expect(output).toContain('Status: PASSED');
    },
    { timeout: ACT_TIMEOUT_MS },
  );
});
