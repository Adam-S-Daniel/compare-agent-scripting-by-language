// Workflow-level tests: structure checks + act-based end-to-end.
// Each test case copies the project into a scratch git repo, runs
// `act push --rm` with a different FIXTURE_FILE, appends the output to
// act-result.txt, and asserts on the exact new version.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { execSync, spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');

const ROOT = path.resolve(__dirname, '..');
const WORKFLOW = path.join(ROOT, '.github', 'workflows', 'semantic-version-bumper.yml');
const ACT_RESULT = path.join(ROOT, 'act-result.txt');

function resetActResult() {
  fs.writeFileSync(ACT_RESULT, '');
}

// --- Structural / static checks ---

test('workflow file exists and actionlint passes', () => {
  assert.ok(fs.existsSync(WORKFLOW), 'workflow file missing');
  const r = spawnSync('actionlint', [WORKFLOW], { encoding: 'utf8' });
  assert.equal(r.status, 0, `actionlint failed: ${r.stdout}${r.stderr}`);
});

test('workflow YAML has expected triggers, jobs, steps, and script refs', () => {
  const raw = fs.readFileSync(WORKFLOW, 'utf8');
  // Light-touch structural assertions without pulling in a YAML dep.
  assert.match(raw, /^name:\s*semantic-version-bumper/m);
  assert.match(raw, /^on:/m);
  assert.match(raw, /^\s{2}push:/m);
  assert.match(raw, /^\s{2}pull_request:/m);
  assert.match(raw, /^\s{2}workflow_dispatch:/m);
  assert.match(raw, /jobs:/);
  assert.match(raw, /test-and-bump:/);
  assert.match(raw, /actions\/checkout@v4/);
  assert.match(raw, /node --test test\/bump\.test\.js/);
  assert.match(raw, /node bump\.js/);
  // Referenced files must exist on disk.
  assert.ok(fs.existsSync(path.join(ROOT, 'bump.js')));
  assert.ok(fs.existsSync(path.join(ROOT, 'test')));
  assert.ok(fs.existsSync(path.join(ROOT, 'fixtures', 'feat-commits.txt')));
  assert.ok(fs.existsSync(path.join(ROOT, 'fixtures', 'fix-commits.txt')));
  assert.ok(fs.existsSync(path.join(ROOT, 'fixtures', 'breaking-commits.txt')));
});

// --- act-driven end-to-end ---

function makeScratchRepo() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'svb-act-'));
  // Copy project files (avoid node_modules, .git, act-result.txt, hidden caches).
  const exclude = new Set(['node_modules', '.git', 'act-result.txt', 'test-harness']);
  for (const entry of fs.readdirSync(ROOT)) {
    if (exclude.has(entry)) continue;
    const src = path.join(ROOT, entry);
    const dst = path.join(dir, entry);
    fs.cpSync(src, dst, { recursive: true });
  }
  // Ensure .actrc is inherited so the custom container is used.
  if (fs.existsSync(path.join(ROOT, '.actrc'))) {
    fs.copyFileSync(path.join(ROOT, '.actrc'), path.join(dir, '.actrc'));
  }
  execSync('git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -q -m init', {
    cwd: dir,
    stdio: 'ignore',
  });
  return dir;
}

function runAct(fixture) {
  const dir = makeScratchRepo();
  const r = spawnSync(
    'act',
    ['push', '--rm', '--pull=false', '--env', `FIXTURE_FILE=${fixture}`],
    { cwd: dir, encoding: 'utf8', timeout: 10 * 60_000 }
  );
  const combined =
    `\n===== act run: fixture=${fixture} exit=${r.status} =====\n` +
    (r.stdout || '') +
    (r.stderr || '') +
    `\n===== end fixture=${fixture} =====\n`;
  fs.appendFileSync(ACT_RESULT, combined);
  return { status: r.status, output: r.stdout + r.stderr };
}

const CASES = [
  { fixture: 'feat-commits.txt',     expected: '1.2.0' }, // 1.1.0 + feat -> minor
  { fixture: 'fix-commits.txt',      expected: '1.1.1' }, // 1.1.0 + fix  -> patch
  { fixture: 'breaking-commits.txt', expected: '2.0.0' }, // 1.1.0 + !    -> major
];

test('act end-to-end: each fixture produces the exact expected new version', { timeout: 30 * 60_000 }, () => {
  resetActResult();
  for (const c of CASES) {
    const { status, output } = runAct(c.fixture);
    assert.equal(status, 0, `act exited non-zero for ${c.fixture}:\n${output.slice(-2000)}`);
    assert.match(
      output,
      new RegExp(`NEW_VERSION=${c.expected.replace(/\./g, '\\.')}`),
      `expected NEW_VERSION=${c.expected} for ${c.fixture}`
    );
    assert.match(output, /Job succeeded/, `job did not succeed for ${c.fixture}`);
  }
  assert.ok(fs.existsSync(ACT_RESULT) && fs.statSync(ACT_RESULT).size > 0);
});
