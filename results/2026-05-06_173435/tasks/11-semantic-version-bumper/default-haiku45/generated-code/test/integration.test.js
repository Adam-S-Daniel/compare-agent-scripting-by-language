const { bumpVersionAndGenerateChangelog } = require('../src/index');
const fs = require('fs');
const path = require('path');
const os = require('os');

describe('Integration Tests', () => {
  let tempDir;

  beforeEach(() => {
    tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'versionbumper-integration-'));
    // Create a basic package.json
    const pkgPath = path.join(tempDir, 'package.json');
    fs.writeFileSync(pkgPath, JSON.stringify({ name: 'test-app', version: '1.0.0' }, null, 2));
  });

  afterEach(() => {
    fs.rmSync(tempDir, { recursive: true, force: true });
  });

  test('bumpVersionAndGenerateChangelog handles feature commits', async () => {
    const gitLog = 'feat(ui): add dark mode support\nfix: correct spacing issue';
    const result = await bumpVersionAndGenerateChangelog(tempDir, gitLog);

    expect(result.oldVersion).toBe('1.0.0');
    expect(result.newVersion).toBe('1.1.0');
    expect(result.changelog).toContain('1.1.0');
    expect(result.changelog).toContain('add dark mode support');
    expect(result.changelog).toContain('correct spacing issue');

    // Verify package.json was updated
    const pkg = JSON.parse(fs.readFileSync(path.join(tempDir, 'package.json'), 'utf-8'));
    expect(pkg.version).toBe('1.1.0');
  });

  test('bumpVersionAndGenerateChangelog handles breaking changes', async () => {
    const gitLog = 'feat!: redesign API structure\n\nBREAKING CHANGE: old endpoints removed';
    const result = await bumpVersionAndGenerateChangelog(tempDir, gitLog);

    expect(result.oldVersion).toBe('1.0.0');
    expect(result.newVersion).toBe('2.0.0');
    expect(result.changelog).toContain('BREAKING CHANGES');
  });

  test('bumpVersionAndGenerateChangelog ignores non-conventional commits', async () => {
    const gitLog = 'chore: update dependencies\ndocs: add README';
    const result = await bumpVersionAndGenerateChangelog(tempDir, gitLog);

    // No changes should occur
    expect(result.oldVersion).toBe('1.0.0');
    expect(result.newVersion).toBe('1.0.0');
    expect(result.changelog).toBe('');
  });

  test('bumpVersionAndGenerateChangelog returns structured result', async () => {
    const gitLog = 'fix: correct calculation bug';
    const result = await bumpVersionAndGenerateChangelog(tempDir, gitLog);

    expect(result).toHaveProperty('oldVersion');
    expect(result).toHaveProperty('newVersion');
    expect(result).toHaveProperty('changelog');
  });
});
