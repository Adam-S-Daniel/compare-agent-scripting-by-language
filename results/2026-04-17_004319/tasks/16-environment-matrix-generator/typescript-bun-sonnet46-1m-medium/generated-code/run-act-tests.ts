// Test harness: sets up a temp git repo with all project files, runs act push --rm once,
// captures the full output to act-result.txt, then asserts on exact expected values.

import { mkdtempSync, mkdirSync, cpSync, writeFileSync, appendFileSync, existsSync, rmSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';

const PROJECT = import.meta.dir;
const ACT_RESULT = join(PROJECT, 'act-result.txt');

// Initialise the output file.
writeFileSync(ACT_RESULT, '');

function log(msg: string): void {
  console.log(msg);
  appendFileSync(ACT_RESULT, msg + '\n');
}

function assert(condition: boolean, message: string): void {
  if (!condition) {
    const msg = `FAIL: ${message}`;
    log(msg);
    process.exit(1);
  }
  log(`PASS: ${message}`);
}

// ─── Set up temp git repo ────────────────────────────────────────────────────

const tmpDir = mkdtempSync(join(tmpdir(), 'matrix-gen-act-'));
log(`=== Temp repo: ${tmpDir} ===`);

try {
  // Copy source files into temp repo.
  const filesToCopy = [
    'matrix-generator.ts',
    'generate-matrix.ts',
    'matrix-generator.test.ts',
    'fixtures',
    '.github',
  ];

  for (const f of filesToCopy) {
    const src = join(PROJECT, f);
    if (existsSync(src)) {
      cpSync(src, join(tmpDir, f), { recursive: true });
    }
  }

  // Copy .actrc so act uses the correct container image.
  const actrc = join(PROJECT, '.actrc');
  if (existsSync(actrc)) {
    cpSync(actrc, join(tmpDir, '.actrc'));
  }

  // Initialise git repo and commit all files.
  const git = (cmd: string) =>
    Bun.spawnSync(['bash', '-c', `cd "${tmpDir}" && ${cmd}`], {
      stdout: 'pipe',
      stderr: 'pipe',
    });

  git('git init');
  git('git config user.email "test@example.com"');
  git('git config user.name "Test"');
  git('git add -A');
  git('git commit -m "test: run act"');

  // ─── Run act push --rm ─────────────────────────────────────────────────────

  log('\n========== ACT RUN START ==========\n');

  const actResult = Bun.spawnSync(
    ['act', 'push', '--rm', '--pull=false'],
    {
      cwd: tmpDir,
      stdout: 'pipe',
      stderr: 'pipe',
      // Allow up to 5 minutes.
      timeout: 300_000,
    }
  );

  const stdout = new TextDecoder().decode(actResult.stdout);
  const stderr = new TextDecoder().decode(actResult.stderr);
  const combined = stdout + stderr;
  const exitCode = actResult.exitCode ?? 1;

  appendFileSync(ACT_RESULT, combined);
  log(`\nACT EXIT CODE: ${exitCode}`);
  log('\n========== ACT RUN END ==========\n');

  // ─── Assertions ────────────────────────────────────────────────────────────

  assert(exitCode === 0, `act push exited with code 0 (got ${exitCode})`);

  // Every job must succeed.
  assert(combined.includes('Job succeeded'), 'act output contains "Job succeeded"');

  // Fixture: simple → 4 combinations
  assert(combined.includes('"totalCombinations": 4'), 'simple fixture: totalCombinations = 4');

  // Fixture: with-exclude → 3 combinations
  assert(combined.includes('"totalCombinations": 3'), 'with-exclude fixture: totalCombinations = 3');

  // Fixture: with-include → 2 combinations
  assert(combined.includes('"totalCombinations": 2'), 'with-include fixture: totalCombinations = 2');

  // Fixture: max-size-exceeded → error message
  assert(
    combined.includes('exceeds maximum'),
    'max-size-exceeded fixture: error contains "exceeds maximum"'
  );

  // Fixture: full-config → max-parallel: 4, fail-fast: false
  assert(combined.includes('"max-parallel": 4'), 'full-config fixture: max-parallel = 4');
  assert(combined.includes('"fail-fast": false'), 'full-config fixture: fail-fast = false');

  log('\n=== All act assertions passed! ===\n');

} finally {
  rmSync(tmpDir, { recursive: true, force: true });
}
