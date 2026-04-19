const {
  parseVersion,
  determineVersionBump,
  bumpVersion,
} = require('../src/semantic-version-bumper');

describe('Semantic Version Bumper', () => {
  describe('parseVersion', () => {
    test('should parse a valid semantic version string', () => {
      const result = parseVersion('1.2.3');
      expect(result).toEqual({ major: 1, minor: 2, patch: 3 });
    });

    test('should parse version with leading v', () => {
      const result = parseVersion('v1.2.3');
      expect(result).toEqual({ major: 1, minor: 2, patch: 3 });
    });

    test('should throw on invalid version format', () => {
      expect(() => parseVersion('invalid')).toThrow();
    });
  });

  describe('determineVersionBump', () => {
    test('should return major for breaking change', () => {
      const commits = [
        { message: 'feat!: breaking change' },
        { message: 'feat: normal feature' },
      ];
      const bump = determineVersionBump(commits);
      expect(bump).toBe('major');
    });

    test('should return minor for feat without breaking', () => {
      const commits = [{ message: 'feat: new feature' }];
      const bump = determineVersionBump(commits);
      expect(bump).toBe('minor');
    });

    test('should return patch for fix', () => {
      const commits = [{ message: 'fix: bug fix' }];
      const bump = determineVersionBump(commits);
      expect(bump).toBe('patch');
    });

    test('should return none for non-conventional commits', () => {
      const commits = [{ message: 'chore: cleanup' }];
      const bump = determineVersionBump(commits);
      expect(bump).toBe('none');
    });

    test('should prioritize major over minor and patch', () => {
      const commits = [
        { message: 'feat!: breaking' },
        { message: 'feat: feature' },
        { message: 'fix: bugfix' },
      ];
      const bump = determineVersionBump(commits);
      expect(bump).toBe('major');
    });

    test('should prioritize minor over patch', () => {
      const commits = [
        { message: 'feat: feature' },
        { message: 'fix: bugfix' },
      ];
      const bump = determineVersionBump(commits);
      expect(bump).toBe('minor');
    });
  });

  describe('bumpVersion', () => {
    test('should bump major version', () => {
      const result = bumpVersion('1.2.3', 'major');
      expect(result).toBe('2.0.0');
    });

    test('should bump minor version', () => {
      const result = bumpVersion('1.2.3', 'minor');
      expect(result).toBe('1.3.0');
    });

    test('should bump patch version', () => {
      const result = bumpVersion('1.2.3', 'patch');
      expect(result).toBe('1.2.4');
    });

    test('should not bump for none', () => {
      const result = bumpVersion('1.2.3', 'none');
      expect(result).toBe('1.2.3');
    });
  });
});
