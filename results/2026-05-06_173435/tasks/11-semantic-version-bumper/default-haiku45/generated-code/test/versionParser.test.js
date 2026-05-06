const { parseVersion, bumpVersion, isConventionalCommit, parseCommitType } = require('../src/versionBumper');
const fs = require('fs');
const path = require('path');

describe('Version Parser', () => {
  test('parseVersion extracts version from package.json', () => {
    const tempDir = path.join(__dirname, 'fixtures', 'test-repo-1');
    const result = parseVersion(tempDir);
    expect(result).toBe('1.0.0');
  });

  test('bumpVersion increments patch for fix commits', () => {
    const result = bumpVersion('1.0.0', [
      { type: 'fix', message: 'fix: correct bug in calculation' }
    ]);
    expect(result).toBe('1.0.1');
  });

  test('bumpVersion increments minor for feat commits', () => {
    const result = bumpVersion('1.0.0', [
      { type: 'feat', message: 'feat: add new feature' }
    ]);
    expect(result).toBe('1.1.0');
  });

  test('bumpVersion increments major for breaking changes', () => {
    const result = bumpVersion('1.0.0', [
      { type: 'feat', message: 'feat!: breaking change\n\nBREAKING CHANGE: removed old API' }
    ]);
    expect(result).toBe('2.0.0');
  });

  test('bumpVersion handles multiple commits with highest priority bump', () => {
    const result = bumpVersion('1.2.3', [
      { type: 'fix', message: 'fix: minor issue' },
      { type: 'feat', message: 'feat: new feature' },
      { type: 'fix', message: 'fix: another issue' }
    ]);
    expect(result).toBe('1.3.0');
  });

  test('isConventionalCommit identifies valid conventional commits', () => {
    expect(isConventionalCommit('feat: add new feature')).toBe(true);
    expect(isConventionalCommit('fix: correct bug')).toBe(true);
    expect(isConventionalCommit('refactor: reorganize code')).toBe(true);
    expect(isConventionalCommit('docs: update README')).toBe(false);
    expect(isConventionalCommit('random commit message')).toBe(false);
  });

  test('parseCommitType extracts commit type correctly', () => {
    expect(parseCommitType('feat: add new feature')).toBe('feat');
    expect(parseCommitType('fix: correct bug')).toBe('fix');
    expect(parseCommitType('feat!: breaking change')).toBe('feat');
    expect(parseCommitType('docs: update')).toBeNull();
  });
});
