// Integration test: runs the workflow through act and asserts on exact output values.
// Expected aggregated results from the three fixture files:
//   Total Tests: 13  (5 node18 + 5 node20 + 3 api)
//   Passed:       9  (3 + 4 + 2)
//   Failed:       2  (1 + 0 + 1)
//   Skipped:      2  (1 + 1 + 0)
//   Flaky test:   AuthModule > should handle expired tokens

import { describe, test, expect } from 'bun:test';
import { spawnSync } from 'child_process';
import {
  mkdtempSync, mkdirSync, copyFileSync, writeFileSync,
  existsSync, appendFileSync, readdirSync, statSync,
} from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';

const PROJECT_ROOT = import.meta.dir;
const ACT_RESULT_FILE = join(PROJECT_ROOT, 'act-result.txt');

// Recursively copy a directory
function copyDir(src: string, dest: string): void {
  mkdirSync(dest, { recursive: true });
  for (const entry of readdirSync(src)) {
    const srcPath = join(src, entry);
    const destPath = join(dest, entry);
    if (statSync(srcPath).isDirectory()) {
      copyDir(srcPath, destPath);
    } else {
      copyFileSync(srcPath, destPath);
    }
  }
}

function setupTempRepo(): string {
  const tmpDir = mkdtempSync(join(tmpdir(), 'test-aggregator-act-'));

  // Copy all source + fixture + workflow files
  const filesToCopy = [
    'types.ts', 'parsers.ts', 'aggregator.ts', 'markdown.ts', 'main.ts',
    'package.json', 'tsconfig.json', 'bun.lockb',
  ];
  for (const f of filesToCopy) {
    const src = join(PROJECT_ROOT, f);
    if (existsSync(src)) copyFileSync(src, join(tmpDir, f));
  }

  copyDir(join(PROJECT_ROOT, 'fixtures'), join(tmpDir, 'fixtures'));
  copyDir(join(PROJECT_ROOT, '.github'), join(tmpDir, '.github'));

  // Copy .actrc so act uses the pre-built image
  const actrc = join(PROJECT_ROOT, '.actrc');
  if (existsSync(actrc)) copyFileSync(actrc, join(tmpDir, '.actrc'));

  // Initialise a git repo and commit everything
  spawnSync('git', ['init', '-b', 'main'], { cwd: tmpDir, encoding: 'utf8' });
  spawnSync('git', ['config', 'user.email', 'test@test.com'], { cwd: tmpDir });
  spawnSync('git', ['config', 'user.name', 'Test Runner'], { cwd: tmpDir });
  spawnSync('git', ['add', '-A'], { cwd: tmpDir });
  spawnSync('git', ['commit', '-m', 'initial'], { cwd: tmpDir, encoding: 'utf8' });

  return tmpDir;
}

describe('Act Integration', () => {
  test(
    'workflow aggregates test results and produces correct output',
    () => {
      const tmpDir = setupTempRepo();

      const result = spawnSync(
        'act',
        ['push', '--rm', '--no-cache-server'],
        {
          cwd: tmpDir,
          encoding: 'utf8',
          timeout: 180_000,
          maxBuffer: 10 * 1024 * 1024,
        },
      );

      const output = (result.stdout ?? '') + (result.stderr ?? '');

      // Save to act-result.txt (required artifact)
      appendFileSync(
        ACT_RESULT_FILE,
        `\n${'='.repeat(60)}\n` +
        `=== Test: aggregate test results (${new Date().toISOString()}) ===\n` +
        `${'='.repeat(60)}\n` +
        output +
        `\nExit code: ${result.status}\n`,
      );

      // Assert act exited successfully
      if (result.status !== 0) {
        // Print output to help diagnose failures
        console.error('act failed. Output:\n', output.slice(-3000));
      }
      expect(result.status).toBe(0);

      // Assert every job shows success
      expect(output).toContain('Job succeeded');

      // Assert exact aggregated values from the three fixture files
      expect(output).toContain('Total Tests: 13');
      expect(output).toContain('Passed: 9');
      expect(output).toContain('Failed: 2');
      expect(output).toContain('Skipped: 2');

      // Assert flaky test detection
      expect(output).toContain('should handle expired tokens');
    },
    180_000, // 3-minute timeout
  );
});
