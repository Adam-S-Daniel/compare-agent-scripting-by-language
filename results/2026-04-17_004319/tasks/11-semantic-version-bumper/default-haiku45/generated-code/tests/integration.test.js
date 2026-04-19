const fs = require('fs');
const path = require('path');
const {
  readVersionFromPackageJson,
  writeVersionToPackageJson,
  generateChangelogEntry,
  getCommitsSinceTag,
} = require('../src/file-handler');

describe('File Handler Integration', () => {
  const testDir = path.join(__dirname, 'temp');
  const packageJsonPath = path.join(testDir, 'package.json');

  beforeEach(() => {
    if (fs.existsSync(testDir)) {
      fs.rmSync(testDir, { recursive: true });
    }
    fs.mkdirSync(testDir, { recursive: true });
  });

  afterEach(() => {
    if (fs.existsSync(testDir)) {
      fs.rmSync(testDir, { recursive: true });
    }
  });

  describe('readVersionFromPackageJson', () => {
    test('should read version from package.json', () => {
      const pkg = { name: 'test', version: '1.2.3' };
      fs.writeFileSync(packageJsonPath, JSON.stringify(pkg));

      const version = readVersionFromPackageJson(packageJsonPath);
      expect(version).toBe('1.2.3');
    });

    test('should throw if package.json does not exist', () => {
      expect(() => readVersionFromPackageJson(packageJsonPath)).toThrow();
    });

    test('should throw if package.json has no version field', () => {
      const pkg = { name: 'test' };
      fs.writeFileSync(packageJsonPath, JSON.stringify(pkg));

      expect(() => readVersionFromPackageJson(packageJsonPath)).toThrow();
    });
  });

  describe('writeVersionToPackageJson', () => {
    test('should update version in package.json', () => {
      const pkg = { name: 'test', version: '1.2.3' };
      fs.writeFileSync(packageJsonPath, JSON.stringify(pkg));

      writeVersionToPackageJson(packageJsonPath, '2.0.0');

      const updated = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
      expect(updated.version).toBe('2.0.0');
    });

    test('should preserve other fields in package.json', () => {
      const pkg = { name: 'test', version: '1.2.3', scripts: { test: 'jest' } };
      fs.writeFileSync(packageJsonPath, JSON.stringify(pkg));

      writeVersionToPackageJson(packageJsonPath, '2.0.0');

      const updated = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
      expect(updated.name).toBe('test');
      expect(updated.scripts.test).toBe('jest');
    });
  });

  describe('generateChangelogEntry', () => {
    test('should generate changelog entry from commits', () => {
      const commits = [
        { hash: 'abc123', message: 'feat: add new feature' },
        { hash: 'def456', message: 'fix: bug fix' },
      ];

      const entry = generateChangelogEntry('2.0.0', commits, new Date('2026-04-18'));
      expect(entry).toContain('## [2.0.0]');
      expect(entry).toContain('2026-04-18');
      expect(entry).toContain('add new feature');
      expect(entry).toContain('bug fix');
    });

    test('should format commits by type', () => {
      const commits = [
        { hash: 'abc123', message: 'feat: new feature' },
        { hash: 'def456', message: 'fix: bug' },
      ];

      const entry = generateChangelogEntry('1.1.0', commits);
      expect(entry).toContain('### Features');
      expect(entry).toContain('### Bug Fixes');
    });
  });

  describe('getCommitsSinceTag', () => {
    test('should parse commits from fixture', () => {
      const fixtureDir = path.join(__dirname, 'fixtures');
      fs.mkdirSync(fixtureDir, { recursive: true });

      const commitLog = `abc1234 feat: add feature
def5678 fix: bug fix
ghi9012 chore: cleanup`;

      fs.writeFileSync(path.join(fixtureDir, 'commits.txt'), commitLog);

      const commits = getCommitsSinceTag(path.join(fixtureDir, 'commits.txt'));
      expect(commits).toHaveLength(3);
      expect(commits[0].hash).toBe('abc1234');
      expect(commits[0].message).toBe('feat: add feature');
      expect(commits[1].message).toBe('fix: bug fix');

      fs.rmSync(fixtureDir, { recursive: true });
    });
  });
});
