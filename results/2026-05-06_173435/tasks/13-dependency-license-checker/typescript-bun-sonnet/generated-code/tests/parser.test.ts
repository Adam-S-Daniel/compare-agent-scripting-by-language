// TDD: parser tests - written BEFORE implementation (red phase)
import { describe, test, expect } from 'bun:test';
import { parsePackageJson } from '../src/parser';

describe('parsePackageJson', () => {
  test('extracts dependencies and devDependencies', () => {
    const pkg = {
      name: 'test-project',
      dependencies: {
        react: '^18.0.0',
        lodash: '4.17.21',
      },
      devDependencies: {
        typescript: '^5.0.0',
      },
    };

    const deps = parsePackageJson(JSON.stringify(pkg));
    expect(deps).toHaveLength(3);
    expect(deps).toContainEqual({ name: 'react', version: '^18.0.0' });
    expect(deps).toContainEqual({ name: 'lodash', version: '4.17.21' });
    expect(deps).toContainEqual({ name: 'typescript', version: '^5.0.0' });
  });

  test('handles package.json with only dependencies', () => {
    const pkg = { dependencies: { express: '4.18.0' } };
    const deps = parsePackageJson(JSON.stringify(pkg));
    expect(deps).toHaveLength(1);
    expect(deps[0]).toEqual({ name: 'express', version: '4.18.0' });
  });

  test('handles empty package.json (no dep sections)', () => {
    const pkg = { name: 'no-deps' };
    const deps = parsePackageJson(JSON.stringify(pkg));
    expect(deps).toHaveLength(0);
  });

  test('throws on invalid JSON', () => {
    expect(() => parsePackageJson('not valid json')).toThrow();
  });
});
