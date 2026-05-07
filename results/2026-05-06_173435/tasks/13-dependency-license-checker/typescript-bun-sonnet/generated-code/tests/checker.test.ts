// TDD: checker + license-lookup tests - written BEFORE implementation (red phase)
import { describe, test, expect } from 'bun:test';
import { createMockLicenseLookup } from '../src/license-lookup';
import { checkLicense, checkDependencies } from '../src/checker';
import type { Dependency, LicenseConfig } from '../src/types';

const config: LicenseConfig = {
  allowList: ['MIT', 'Apache-2.0', 'BSD-3-Clause', 'ISC'],
  denyList: ['GPL-3.0', 'GPL-2.0', 'AGPL-3.0', 'LGPL-2.1'],
};

describe('createMockLicenseLookup', () => {
  test('returns license from mock database', async () => {
    const lookup = createMockLicenseLookup({ react: 'MIT', lodash: 'MIT' });
    expect(await lookup('react', '18.0.0')).toBe('MIT');
    expect(await lookup('lodash', '4.17.21')).toBe('MIT');
  });

  test('returns null for unknown packages', async () => {
    const lookup = createMockLicenseLookup({ react: 'MIT' });
    expect(await lookup('mystery-pkg', '1.0.0')).toBeNull();
  });
});

describe('checkLicense', () => {
  test('returns approved for license on allow-list', () => {
    expect(checkLicense('MIT', config)).toBe('approved');
    expect(checkLicense('Apache-2.0', config)).toBe('approved');
  });

  test('returns denied for license on deny-list', () => {
    expect(checkLicense('GPL-3.0', config)).toBe('denied');
    expect(checkLicense('AGPL-3.0', config)).toBe('denied');
  });

  test('returns unknown for license not in either list', () => {
    expect(checkLicense('WTFPL', config)).toBe('unknown');
  });

  test('returns unknown for null license (not found in lookup)', () => {
    expect(checkLicense(null, config)).toBe('unknown');
  });
});

describe('checkDependencies', () => {
  test('returns results for each dependency with correct status', async () => {
    const deps: Dependency[] = [
      { name: 'react', version: '^18.0.0' },
      { name: 'gpl-lib', version: '1.0.0' },
      { name: 'mystery-pkg', version: '2.0.0' },
    ];
    const lookup = createMockLicenseLookup({ react: 'MIT', 'gpl-lib': 'GPL-3.0' });

    const results = await checkDependencies(deps, config, lookup);

    expect(results).toHaveLength(3);
    expect(results[0]).toMatchObject({ dependency: deps[0], license: 'MIT', status: 'approved' });
    expect(results[1]).toMatchObject({ dependency: deps[1], license: 'GPL-3.0', status: 'denied' });
    expect(results[2]).toMatchObject({ dependency: deps[2], license: null, status: 'unknown' });
  });
});
