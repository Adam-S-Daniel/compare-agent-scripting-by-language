// TDD test suite for the semantic version bumper.
//
// Approach: each section follows red/green/refactor — a failing test was
// written first, then the minimum code in src/bumper.js to make it pass.
// Tests are organized bottom-up: parsing primitives, then bump decision,
// then version arithmetic, then changelog rendering, then the CLI.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const {
  parseCommit,
  determineBump,
  bumpVersion,
  renderChangelog,
  readVersion,
  writeVersion,
} = require('../src/bumper');

// ---------- parseCommit ----------

test('parseCommit: feat with scope', () => {
  const c = parseCommit('feat(parser): add new tokenizer');
  assert.equal(c.type, 'feat');
  assert.equal(c.scope, 'parser');
  assert.equal(c.breaking, false);
  assert.equal(c.description, 'add new tokenizer');
});

test('parseCommit: fix without scope', () => {
  const c = parseCommit('fix: handle null input');
  assert.equal(c.type, 'fix');
  assert.equal(c.scope, null);
  assert.equal(c.breaking, false);
  assert.equal(c.description, 'handle null input');
});

test('parseCommit: breaking change via "!"', () => {
  const c = parseCommit('feat!: drop node 14 support');
  assert.equal(c.type, 'feat');
  assert.equal(c.breaking, true);
});

test('parseCommit: breaking change via BREAKING CHANGE footer', () => {
  const msg = 'feat: rework api\n\nBREAKING CHANGE: removed legacy endpoints';
  const c = parseCommit(msg);
  assert.equal(c.breaking, true);
});

test('parseCommit: non-conventional message returns null type', () => {
  const c = parseCommit('just a random message');
  assert.equal(c.type, null);
  assert.equal(c.description, 'just a random message');
});

test('parseCommit: empty input throws meaningful error', () => {
  assert.throws(() => parseCommit(''), /empty commit message/i);
  assert.throws(() => parseCommit(null), /empty commit message/i);
});

// ---------- determineBump ----------

test('determineBump: any breaking → major', () => {
  const commits = [
    parseCommit('fix: small'),
    parseCommit('feat!: huge'),
  ];
  assert.equal(determineBump(commits), 'major');
});

test('determineBump: any feat (no breaking) → minor', () => {
  const commits = [parseCommit('fix: a'), parseCommit('feat: b')];
  assert.equal(determineBump(commits), 'minor');
});

test('determineBump: only fixes → patch', () => {
  const commits = [parseCommit('fix: a'), parseCommit('fix: b')];
  assert.equal(determineBump(commits), 'patch');
});

test('determineBump: chore/docs only → null (no release)', () => {
  const commits = [parseCommit('chore: tidy'), parseCommit('docs: update')];
  assert.equal(determineBump(commits), null);
});

test('determineBump: empty list → null', () => {
  assert.equal(determineBump([]), null);
});

// ---------- bumpVersion ----------

test('bumpVersion: major resets minor and patch', () => {
  assert.equal(bumpVersion('1.2.3', 'major'), '2.0.0');
});

test('bumpVersion: minor resets patch', () => {
  assert.equal(bumpVersion('1.2.3', 'minor'), '1.3.0');
});

test('bumpVersion: patch increments patch', () => {
  assert.equal(bumpVersion('1.2.3', 'patch'), '1.2.4');
});

test('bumpVersion: invalid version string throws', () => {
  assert.throws(() => bumpVersion('not-a-version', 'patch'), /invalid semver/i);
});

test('bumpVersion: invalid bump type throws', () => {
  assert.throws(() => bumpVersion('1.0.0', 'wat'), /invalid bump type/i);
});

// ---------- renderChangelog ----------

test('renderChangelog: groups commits by section', () => {
  const commits = [
    parseCommit('feat(api): add endpoint'),
    parseCommit('fix: null guard'),
    parseCommit('feat!: remove legacy'),
    parseCommit('chore: lint'),
  ];
  const md = renderChangelog('2.0.0', '2026-04-19', commits);
  assert.match(md, /## 2\.0\.0 - 2026-04-19/);
  assert.match(md, /### Breaking Changes/);
  assert.match(md, /remove legacy/);
  assert.match(md, /### Features/);
  assert.match(md, /add endpoint/);
  assert.match(md, /### Bug Fixes/);
  assert.match(md, /null guard/);
  // chore commits are skipped
  assert.doesNotMatch(md, /lint/);
});

// ---------- readVersion / writeVersion (file IO) ----------

test('readVersion: from package.json', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'svb-'));
  const pkg = path.join(dir, 'package.json');
  fs.writeFileSync(pkg, JSON.stringify({ name: 'x', version: '0.4.1' }));
  assert.equal(readVersion(pkg), '0.4.1');
});

test('readVersion: from plain VERSION file', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'svb-'));
  const file = path.join(dir, 'VERSION');
  fs.writeFileSync(file, '3.2.1\n');
  assert.equal(readVersion(file), '3.2.1');
});

test('readVersion: missing file throws meaningful error', () => {
  assert.throws(() => readVersion('/no/such/path'), /could not read version/i);
});

test('writeVersion: updates package.json preserving other fields', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'svb-'));
  const pkg = path.join(dir, 'package.json');
  fs.writeFileSync(pkg, JSON.stringify({ name: 'x', version: '0.0.1', other: 42 }, null, 2));
  writeVersion(pkg, '0.0.2');
  const updated = JSON.parse(fs.readFileSync(pkg, 'utf8'));
  assert.equal(updated.version, '0.0.2');
  assert.equal(updated.other, 42);
});

test('writeVersion: updates plain VERSION file', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'svb-'));
  const file = path.join(dir, 'VERSION');
  fs.writeFileSync(file, '0.0.1\n');
  writeVersion(file, '0.0.2');
  assert.equal(fs.readFileSync(file, 'utf8').trim(), '0.0.2');
});

// ---------- CLI integration ----------

test('CLI: bumps minor for feat, writes file, prints version', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'svb-cli-'));
  const pkg = path.join(dir, 'package.json');
  const log = path.join(dir, 'commits.log');
  const changelog = path.join(dir, 'CHANGELOG.md');
  fs.writeFileSync(pkg, JSON.stringify({ name: 'demo', version: '1.1.0' }, null, 2));
  fs.writeFileSync(log, 'feat: add cool thing\nfix: small bug\n');

  const cli = path.resolve(__dirname, '..', 'src', 'cli.js');
  const out = execFileSync('node', [cli,
    '--version-file', pkg,
    '--commits-file', log,
    '--changelog', changelog,
    '--date', '2026-04-19',
  ], { encoding: 'utf8' });

  assert.match(out, /1\.2\.0/);
  const newPkg = JSON.parse(fs.readFileSync(pkg, 'utf8'));
  assert.equal(newPkg.version, '1.2.0');
  const cl = fs.readFileSync(changelog, 'utf8');
  assert.match(cl, /## 1\.2\.0 - 2026-04-19/);
  assert.match(cl, /add cool thing/);
});

test('CLI: no-release commits exit with code 0 and message', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'svb-cli-'));
  const pkg = path.join(dir, 'package.json');
  const log = path.join(dir, 'commits.log');
  fs.writeFileSync(pkg, JSON.stringify({ name: 'demo', version: '1.0.0' }, null, 2));
  fs.writeFileSync(log, 'chore: tidy\ndocs: typo\n');

  const cli = path.resolve(__dirname, '..', 'src', 'cli.js');
  const out = execFileSync('node', [cli,
    '--version-file', pkg,
    '--commits-file', log,
  ], { encoding: 'utf8' });

  assert.match(out, /no release/i);
  // version file untouched
  const newPkg = JSON.parse(fs.readFileSync(pkg, 'utf8'));
  assert.equal(newPkg.version, '1.0.0');
});

test('CLI: missing version file exits non-zero with helpful message', () => {
  const cli = path.resolve(__dirname, '..', 'src', 'cli.js');
  let err;
  try {
    execFileSync('node', [cli,
      '--version-file', '/no/such/file.json',
      '--commits-file', '/dev/null',
    ], { encoding: 'utf8', stdio: 'pipe' });
  } catch (e) { err = e; }
  assert.ok(err, 'expected non-zero exit');
  assert.match(err.stderr || '', /could not read version/i);
});
