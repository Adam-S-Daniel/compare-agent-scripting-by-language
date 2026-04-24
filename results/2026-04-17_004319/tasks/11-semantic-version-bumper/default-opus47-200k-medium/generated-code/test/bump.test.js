// TDD tests for the semantic version bumper.
// Uses Node's built-in test runner (node --test).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');

const {
  parseCommits,
  determineBump,
  bumpVersion,
  generateChangelog,
  run,
} = require('../bump.js');

test('parseCommits extracts conventional commit types', () => {
  const log = [
    'feat: add login',
    'fix: handle null user',
    'chore: bump deps',
  ].join('\n');
  const commits = parseCommits(log);
  assert.equal(commits.length, 3);
  assert.equal(commits[0].type, 'feat');
  assert.equal(commits[0].subject, 'add login');
  assert.equal(commits[1].type, 'fix');
  assert.equal(commits[2].type, 'chore');
});

test('parseCommits detects breaking via ! suffix and BREAKING CHANGE footer', () => {
  const log = [
    'feat!: redesign API',
    'fix: small bug\n\nBREAKING CHANGE: removes old endpoint',
  ].join('\n---COMMIT---\n');
  const commits = parseCommits(log, '---COMMIT---');
  assert.equal(commits[0].breaking, true);
  assert.equal(commits[1].breaking, true);
});

test('determineBump returns "none" for empty or non-release commits', () => {
  assert.equal(determineBump([]), 'none');
  assert.equal(determineBump([{ type: 'chore', breaking: false }]), 'none');
});

test('determineBump returns patch for fix, minor for feat, major for breaking', () => {
  assert.equal(determineBump([{ type: 'fix', breaking: false }]), 'patch');
  assert.equal(determineBump([{ type: 'feat', breaking: false }]), 'minor');
  assert.equal(
    determineBump([
      { type: 'fix', breaking: false },
      { type: 'feat', breaking: false },
    ]),
    'minor'
  );
  assert.equal(
    determineBump([{ type: 'feat', breaking: true }]),
    'major'
  );
});

test('bumpVersion increments correct component', () => {
  assert.equal(bumpVersion('1.2.3', 'patch'), '1.2.4');
  assert.equal(bumpVersion('1.2.3', 'minor'), '1.3.0');
  assert.equal(bumpVersion('1.2.3', 'major'), '2.0.0');
  assert.equal(bumpVersion('1.2.3', 'none'), '1.2.3');
});

test('bumpVersion rejects invalid versions with clear error', () => {
  assert.throws(() => bumpVersion('not-a-version', 'patch'), /Invalid semantic version/);
});

test('generateChangelog groups commits by type under new version heading', () => {
  const commits = [
    { type: 'feat', subject: 'add X', breaking: false },
    { type: 'fix', subject: 'correct Y', breaking: false },
    { type: 'feat', subject: 'replace Z', breaking: true },
  ];
  const md = generateChangelog('2.0.0', commits);
  assert.match(md, /## 2\.0\.0/);
  assert.match(md, /BREAKING CHANGES/);
  assert.match(md, /replace Z/);
  assert.match(md, /Features/);
  assert.match(md, /add X/);
  assert.match(md, /Bug Fixes/);
  assert.match(md, /correct Y/);
});

test('run() end-to-end updates package.json version and writes changelog', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'bump-'));
  const pkgPath = path.join(dir, 'package.json');
  const fixturePath = path.join(dir, 'commits.txt');
  const changelogPath = path.join(dir, 'CHANGELOG.md');
  fs.writeFileSync(pkgPath, JSON.stringify({ name: 'app', version: '1.1.0' }, null, 2));
  fs.writeFileSync(fixturePath, 'feat: add login\nfix: typo');

  const result = run({
    versionFile: pkgPath,
    commitsFile: fixturePath,
    changelogFile: changelogPath,
  });

  assert.equal(result.newVersion, '1.2.0');
  const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
  assert.equal(pkg.version, '1.2.0');
  const changelog = fs.readFileSync(changelogPath, 'utf8');
  assert.match(changelog, /## 1\.2\.0/);
  assert.match(changelog, /add login/);
});

test('run() reads plain-text version files', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'bump-'));
  const versionFile = path.join(dir, 'VERSION');
  const fixturePath = path.join(dir, 'commits.txt');
  fs.writeFileSync(versionFile, '0.1.0\n');
  fs.writeFileSync(fixturePath, 'fix!: breaking fix');

  const result = run({
    versionFile,
    commitsFile: fixturePath,
    changelogFile: path.join(dir, 'CHANGELOG.md'),
  });

  assert.equal(result.newVersion, '1.0.0');
  assert.equal(fs.readFileSync(versionFile, 'utf8').trim(), '1.0.0');
});

test('run() throws a meaningful error when commits file is missing', () => {
  assert.throws(
    () =>
      run({
        versionFile: '/nonexistent/pkg.json',
        commitsFile: '/nonexistent/commits.txt',
        changelogFile: '/tmp/changelog.md',
      }),
    /Commits file not found/
  );
});
