// End-to-end test harness. For each test case:
//   1. spawn `act push --rm` against the workflow with env overrides for the
//      fixture and initial version
//   2. append the captured output to act-result.txt with a delimiter
//   3. assert act exited with code 0
//   4. assert "Job succeeded" appears in the output
//   5. assert the EXACT expected new version is present
//
// Also includes structural checks on the workflow YAML and an actionlint
// invocation. Everything runs from this single script: `node test/harness.js`.

'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync, execFileSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..');
const WORKFLOW = path.join(ROOT, '.github/workflows/semantic-version-bumper.yml');
const RESULT_FILE = path.join(ROOT, 'act-result.txt');

const cases = [
  {
    name: 'feat-only bumps minor',
    fixture: 'feat-only.log',
    initial: '1.1.0',
    expectedVersion: '1.2.0',
    expectedBump: 'minor',
  },
  {
    name: 'fix-only bumps patch',
    fixture: 'fix-only.log',
    initial: '2.3.4',
    expectedVersion: '2.3.5',
    expectedBump: 'patch',
  },
  {
    name: 'breaking change bumps major',
    fixture: 'breaking.log',
    initial: '1.9.9',
    expectedVersion: '2.0.0',
    expectedBump: 'major',
  },
];

let failed = 0;
const lines = [];
function log(s = '') { console.log(s); lines.push(s); }

function ok(cond, msg) {
  if (cond) { log(`  PASS  ${msg}`); }
  else { failed++; log(`  FAIL  ${msg}`); }
}

// -------------------- structural / static checks --------------------

log('=== Static workflow checks ===');

// Parse YAML without external deps via the always-available `python3 -c yaml`.
// This keeps the harness a single Node entry point but borrows Python's PyYAML
// for parsing — Python is required by the project's broader tooling anyway.
function parseYamlFile(p) {
  const out = execFileSync('python3', ['-c',
    'import sys,yaml,json;print(json.dumps(yaml.safe_load(open(sys.argv[1]))))', p],
    { encoding: 'utf8' });
  return JSON.parse(out);
}

let wf;
try {
  wf = parseYamlFile(WORKFLOW);
  ok(true, 'workflow YAML parses');
} catch (e) {
  ok(false, `workflow YAML parses: ${e.message}`);
}

if (wf) {
  // YAML's "on:" key is loaded by PyYAML as the boolean True, hence wf[true].
  const triggers = wf.on || wf[true] || wf['on'];
  ok(!!triggers, 'workflow declares triggers');
  ok(triggers && 'push' in triggers, 'workflow triggers on push');
  ok(triggers && 'pull_request' in triggers, 'workflow triggers on pull_request');
  ok(triggers && 'workflow_dispatch' in triggers, 'workflow supports workflow_dispatch');
  ok(wf.jobs && wf.jobs.bump, 'workflow defines bump job');
  const steps = wf.jobs && wf.jobs.bump && wf.jobs.bump.steps;
  ok(Array.isArray(steps) && steps.length >= 4, 'bump job has multiple steps');
  const usesCheckout = steps && steps.some(s => s.uses && s.uses.startsWith('actions/checkout@v4'));
  ok(usesCheckout, 'workflow uses actions/checkout@v4');
  const usesNode = steps && steps.some(s => s.uses && s.uses.startsWith('actions/setup-node@v4'));
  ok(usesNode, 'workflow uses actions/setup-node@v4');
}

// Verify referenced script files exist.
ok(fs.existsSync(path.join(ROOT, 'src/cli.js')), 'src/cli.js exists');
ok(fs.existsSync(path.join(ROOT, 'src/bumper.js')), 'src/bumper.js exists');
ok(fs.existsSync(path.join(ROOT, 'package.json')), 'package.json exists');
for (const c of cases) {
  ok(fs.existsSync(path.join(ROOT, 'fixtures', c.fixture)),
    `fixture exists: fixtures/${c.fixture}`);
}

// actionlint must pass.
const al = spawnSync('actionlint', [WORKFLOW], { encoding: 'utf8' });
ok(al.status === 0, `actionlint exit code 0 (got ${al.status})`);
if (al.status !== 0) log(al.stdout + al.stderr);

// -------------------- act runs --------------------

log('');
log('=== act runs ===');

// Reset result file at the start so the artifact is fresh per harness run.
fs.writeFileSync(RESULT_FILE, `# act-result.txt — generated ${new Date().toISOString()}\n\n`);

function runAct(c) {
  const env = {
    ...process.env,
    FIXTURE: c.fixture,
    INITIAL_VERSION: c.initial,
  };
  // --env passes vars from host into the act job container, so the workflow's
  // `env:` defaults can be overridden per case without rewriting the YAML.
  const args = [
    'push',
    '--rm',
    // The custom act image is built locally; skip forcePull so act doesn't
    // try (and fail) to fetch it from Docker Hub.
    '--pull=false',
    '--env', `FIXTURE=${c.fixture}`,
    '--env', `INITIAL_VERSION=${c.initial}`,
    '-W', WORKFLOW,
  ];
  const r = spawnSync('act', args, { cwd: ROOT, env, encoding: 'utf8', timeout: 600_000 });
  return r;
}

for (const c of cases) {
  log('');
  log(`--- Case: ${c.name} ---`);
  const r = runAct(c);
  const combined = (r.stdout || '') + (r.stderr || '');

  fs.appendFileSync(RESULT_FILE,
    `\n========== CASE: ${c.name} ==========\n` +
    `fixture=${c.fixture} initial=${c.initial} expected=${c.expectedVersion} bump=${c.expectedBump}\n` +
    `act exit code: ${r.status}\n` +
    `----- act output -----\n` +
    combined +
    `\n----- end output -----\n`);

  ok(r.status === 0, `act exit code 0 (got ${r.status})`);
  ok(/Job succeeded/.test(combined), '"Job succeeded" appears in output');
  // Exact-version assertions: look for the literal version string the script prints.
  ok(combined.includes(`version=${c.expectedVersion}`),
    `output contains exact "version=${c.expectedVersion}"`);
  ok(combined.includes(`bump=${c.expectedBump}`),
    `output contains exact "bump=${c.expectedBump}"`);
  ok(combined.includes(`Resolved new version: ${c.expectedVersion}`),
    `step printed "Resolved new version: ${c.expectedVersion}"`);
  // Sanity: the changelog dump should contain the new version header.
  ok(combined.includes(`## ${c.expectedVersion} - 2026-04-19`),
    `changelog header for ${c.expectedVersion} present`);
}

// -------------------- summary --------------------

log('');
log('=== Summary ===');
log(`failed assertions: ${failed}`);
fs.appendFileSync(RESULT_FILE, `\n========== SUMMARY ==========\nfailed assertions: ${failed}\n`);
process.exit(failed === 0 ? 0 : 1);
