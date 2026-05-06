const { parseGitLog, formatChangelog } = require('../src/gitLog');

describe('Git Log Parser', () => {
  test('parseGitLog extracts commits from raw git log', () => {
    const gitLog = `feat(auth): add login form
fix: correct validation logic
feat!: redesign API endpoints`;

    const commits = parseGitLog(gitLog);
    expect(commits.length).toBe(3);
    expect(commits[0].type).toBe('feat');
    expect(commits[0].scope).toBe('auth');
    expect(commits[0].message).toBe('feat(auth): add login form');
    expect(commits[1].type).toBe('fix');
    expect(commits[1].message).toBe('fix: correct validation logic');
    expect(commits[2].hasBreaking).toBe(true);
  });

  test('parseGitLog handles commits without scope', () => {
    const gitLog = 'fix: simple fix message';
    const commits = parseGitLog(gitLog);
    expect(commits[0].scope).toBeNull();
  });

  test('parseGitLog detects breaking changes', () => {
    const gitLog = `feat!: breaking change

BREAKING CHANGE: removed old function`;
    const commits = parseGitLog(gitLog);
    expect(commits[0].hasBreaking).toBe(true);
  });

  test('formatChangelog generates changelog entry', () => {
    const commits = [
      { type: 'feat', scope: 'auth', description: 'add login form', hasBreaking: false },
      { type: 'feat', scope: null, description: 'new dashboard', hasBreaking: false },
      { type: 'fix', scope: 'api', description: 'correct endpoint', hasBreaking: false },
    ];

    const changelog = formatChangelog('1.1.0', commits);
    expect(changelog).toContain('1.1.0');
    expect(changelog).toContain('Features');
    expect(changelog).toContain('add login form');
    expect(changelog).toContain('Bug Fixes');
    expect(changelog).toContain('correct endpoint');
  });

  test('formatChangelog notes breaking changes', () => {
    const commits = [
      { type: 'feat', scope: null, description: 'redesigned API', hasBreaking: true }
    ];

    const changelog = formatChangelog('2.0.0', commits);
    expect(changelog).toContain('BREAKING CHANGES');
    expect(changelog).toContain('redesigned API');
  });
});
