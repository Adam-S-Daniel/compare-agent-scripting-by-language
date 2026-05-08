const { updatePackageJsonVersion, readPackageJson, writePackageJson, updateChangelog } = require('../src/fileUpdater');
const fs = require('fs');
const path = require('path');
const os = require('os');

describe('File Updater', () => {
  let tempDir;

  beforeEach(() => {
    tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'versionbumper-'));
  });

  afterEach(() => {
    // Clean up temp directory
    fs.rmSync(tempDir, { recursive: true, force: true });
  });

  test('readPackageJson reads and parses package.json', () => {
    const pkgPath = path.join(tempDir, 'package.json');
    fs.writeFileSync(pkgPath, JSON.stringify({ name: 'test', version: '1.0.0' }, null, 2));

    const pkg = readPackageJson(tempDir);
    expect(pkg.name).toBe('test');
    expect(pkg.version).toBe('1.0.0');
  });

  test('writePackageJson writes package.json with updated version', () => {
    const pkgPath = path.join(tempDir, 'package.json');
    const pkg = { name: 'test', version: '1.0.0', description: 'test' };
    fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2));

    writePackageJson(tempDir, '1.1.0');

    const updated = JSON.parse(fs.readFileSync(pkgPath, 'utf-8'));
    expect(updated.version).toBe('1.1.0');
  });

  test('updatePackageJsonVersion updates version and returns success', () => {
    const pkgPath = path.join(tempDir, 'package.json');
    fs.writeFileSync(pkgPath, JSON.stringify({ name: 'test', version: '1.0.0' }, null, 2));

    const result = updatePackageJsonVersion(tempDir, '1.1.0');
    expect(result).toBe(true);

    const updated = readPackageJson(tempDir);
    expect(updated.version).toBe('1.1.0');
  });

  test('updateChangelog appends changelog entry', () => {
    const changelogPath = path.join(tempDir, 'CHANGELOG.md');
    fs.writeFileSync(changelogPath, '# Changelog\n\n');

    updateChangelog(tempDir, '## [1.1.0]\n\n### Features\n- new feature\n');

    const content = fs.readFileSync(changelogPath, 'utf-8');
    expect(content).toContain('1.1.0');
    expect(content).toContain('new feature');
  });

  test('updateChangelog creates CHANGELOG.md if it does not exist', () => {
    const changelogPath = path.join(tempDir, 'CHANGELOG.md');
    expect(fs.existsSync(changelogPath)).toBe(false);

    updateChangelog(tempDir, '## [1.0.0]\n\n### Features\n- initial release\n');

    expect(fs.existsSync(changelogPath)).toBe(true);
    const content = fs.readFileSync(changelogPath, 'utf-8');
    expect(content).toContain('1.0.0');
  });
});
