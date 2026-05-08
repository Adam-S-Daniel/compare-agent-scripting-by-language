import type { LicenseLookupFn } from './types';

// Creates a mock license lookup function backed by an in-memory database.
// The db maps package names to SPDX license identifiers.
// Returns null when the package is not found (simulates "not in registry").
export function createMockLicenseLookup(db: Record<string, string>): LicenseLookupFn {
  return async (name: string, _version: string): Promise<string | null> => {
    return db[name] ?? null;
  };
}
