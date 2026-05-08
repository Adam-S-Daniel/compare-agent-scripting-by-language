// Workflow tests — structure validation + act integration
// Runs alongside validator.test.ts via `bun test`.
//
// The act integration test is skipped when:
//   - ACT=true (we are already inside act — avoids infinite recursion)
//   - act binary is unavailable (e.g. plain GitHub Actions without Docker)

import { describe, it, expect, beforeAll } from 'bun:test';
import {
  existsSync,
  readFileSync,
  mkdtempSync,
  copyFileSync,
  cpSync,
  writeFileSync,
  appendFileSync,
  rmSync,
  statSync,
} from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';
import { execSync, spawnSync } from 'child_process';

const WORKFLOW_PATH = '.github/workflows/secret-rotation-validator.yml';
const PROJECT_DIR = process.cwd();

// ─── workflow structure tests ──────────────────────────────────────────────────

describe('Workflow file exists and has correct structure', () => {
  it('workflow YAML file is present', () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  it('contains push trigger', () => {
    const content = readFileSync(WORKFLOW_PATH, 'utf-8');
    expect(content).toContain('push:');
  });

  it('contains pull_request trigger', () => {
    const content = readFileSync(WORKFLOW_PATH, 'utf-8');
    expect(content).toContain('pull_request:');
  });

  it('contains schedule trigger', () => {
    const content = readFileSync(WORKFLOW_PATH, 'utf-8');
    expect(content).toContain('schedule:');
    expect(content).toContain('cron:');
  });

  it('contains workflow_dispatch trigger', () => {
    const content = readFileSync(WORKFLOW_PATH, 'utf-8');
    expect(content).toContain('workflow_dispatch:');
  });

  it('uses actions/checkout@v4', () => {
    const content = readFileSync(WORKFLOW_PATH, 'utf-8');
    expect(content).toContain('actions/checkout@v4');
  });

  it('installs Bun via oven-sh/setup-bun', () => {
    const content = readFileSync(WORKFLOW_PATH, 'utf-8');
    expect(content).toContain('oven-sh/setup-bun');
  });

  it('runs the validator script', () => {
    const content = readFileSync(WORKFLOW_PATH, 'utf-8');
    expect(content).toContain('bun run main.ts');
  });

  it('runs bun test', () => {
    const content = readFileSync(WORKFLOW_PATH, 'utf-8');
    expect(content).toContain('bun test');
  });

  it('references main.ts which exists', () => {
    expect(existsSync(join(PROJECT_DIR, 'main.ts'))).toBe(true);
  });

  it('references secrets-config.json which exists', () => {
    expect(existsSync(join(PROJECT_DIR, 'secrets-config.json'))).toBe(true);
  });
});

// ─── actionlint validation ────────────────────────────────────────────────────

describe('actionlint passes', () => {
  it('workflow file passes actionlint with exit code 0', () => {
    const result = spawnSync('actionlint', [WORKFLOW_PATH], { encoding: 'utf-8' });
    const errorMsg = result.stdout + result.stderr;
    expect(result.status).toBe(0);
    expect(errorMsg.trim()).toBe('');
  });
});

// ─── act integration test ────────────────────────────────────────────────────
// Skipped when already inside act (ACT=true) or when act is not available.

const isInAct = process.env.ACT === 'true';

let actAvailable = false;
try {
  spawnSync('act', ['--version'], { stdio: 'pipe' });
  actAvailable = true;
} catch {
  actAvailable = false;
}

const shouldRunActTest = !isInAct && actAvailable;

// Files to copy into the temp git repo for act
const PROJECT_FILES = [
  'validator.ts',
  'formatter.ts',
  'main.ts',
  'package.json',
  'tsconfig.json',
  '.github',
  'validator.test.ts',
];

// Fixture: 4 secrets with known expected counts (expired=1, warning=1, ok=2)
const FIXTURE = {
  warningWindowDays: 7,
  referenceDate: '2026-05-08',
  secrets: [
    { name: 'DB_PASSWORD', lastRotated: '2025-12-01', rotationPolicyDays: 90,  requiredByServices: ['api', 'workers'] },
    { name: 'JWT_SECRET',  lastRotated: '2026-04-14', rotationPolicyDays: 30,  requiredByServices: ['auth'] },
    { name: 'API_KEY',     lastRotated: '2026-04-16', rotationPolicyDays: 30,  requiredByServices: ['frontend'] },
    { name: 'DEPLOY_KEY',  lastRotated: '2026-01-01', rotationPolicyDays: 365, requiredByServices: ['deploy'] },
  ],
};

describe('act integration', () => {
  it.skipIf(!shouldRunActTest)(
    'workflow runs successfully via act and produces expected output',
    async () => {
      const tempDir = mkdtempSync(join(tmpdir(), 'srv-test-'));
      let actOutput = '';
      let actExitCode = 0;

      try {
        // Copy project files into the temp repo
        for (const name of PROJECT_FILES) {
          const src = join(PROJECT_DIR, name);
          if (!existsSync(src)) continue;
          const dst = join(tempDir, name);
          const isDir = statSync(src).isDirectory();
          if (isDir) {
            cpSync(src, dst, { recursive: true });
          } else {
            copyFileSync(src, dst);
          }
        }

        // Write .actrc: use local image and disable force-pull to avoid Docker Hub errors
        const actrcSrc = join(PROJECT_DIR, '.actrc');
        const actrcContent = existsSync(actrcSrc)
          ? readFileSync(actrcSrc, 'utf-8').trim() + '\n--pull=false\n'
          : '-P ubuntu-latest=act-ubuntu-pwsh:latest\n--pull=false\n';
        writeFileSync(join(tempDir, '.actrc'), actrcContent);

        // Write the deterministic test fixture
        writeFileSync(join(tempDir, 'secrets-config.json'), JSON.stringify(FIXTURE, null, 2));

        // Initialise git (act requires a valid git repo)
        execSync(
          'git init -b main && ' +
          'git config user.email "ci@test.com" && ' +
          'git config user.name "CI Test" && ' +
          'git add -A && ' +
          'git commit -m "test: secret rotation validator"',
          { cwd: tempDir, stdio: 'pipe' },
        );

        // Run act — capture stdout+stderr combined
        const result = spawnSync(
          'act', ['push', '--rm'],
          { cwd: tempDir, timeout: 300_000, encoding: 'utf-8' },
        );
        actOutput = (result.stdout ?? '') + (result.stderr ?? '');
        actExitCode = result.status ?? 1;

      } finally {
        // Append output to act-result.txt before any assertions (even on failure)
        const delimiter = '\n' + '='.repeat(70) + '\n';
        const header = 'TEST CASE: mixed secrets (expired=1, warning=1, ok=2)\n';
        appendFileSync(
          join(PROJECT_DIR, 'act-result.txt'),
          delimiter + header + delimiter + actOutput + '\n',
        );

        rmSync(tempDir, { recursive: true, force: true });
      }

      // ── assertions ──────────────────────────────────────────────────────────

      // Job must complete successfully
      expect(actExitCode).toBe(0);
      expect(actOutput).toContain('Job succeeded');

      // Exact counts from the JSON output step
      expect(actOutput).toContain('"total": 4');
      expect(actOutput).toContain('"expired": 1');
      expect(actOutput).toContain('"warning": 1');
      expect(actOutput).toContain('"ok": 2');

      // Specific secret names must appear in the correct sections
      expect(actOutput).toContain('"DB_PASSWORD"');
      expect(actOutput).toContain('"JWT_SECRET"');

      // Markdown report must appear in a later step
      expect(actOutput).toContain('Secret Rotation Report');
      expect(actOutput).toContain('DB_PASSWORD');
    },
    300_000, // 5-minute timeout for Docker startup + workflow execution
  );
});
