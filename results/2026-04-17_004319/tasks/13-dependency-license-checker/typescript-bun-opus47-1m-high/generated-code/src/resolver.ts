// A LicenseResolver looks up the SPDX licence identifier for a given
// package name. The interface is async so callers can't tell whether the
// licence came from a cache, a local database, or a network registry.
// Returns `null` when the licence is not known.

export type LicenseResolver = (packageName: string) => Promise<string | null>;

export function createMockResolver(database: Record<string, string>): LicenseResolver {
  // Clone so later mutations to the caller's object don't leak into the resolver.
  const snapshot: Record<string, string> = { ...database };
  return async (packageName: string): Promise<string | null> => {
    return Object.prototype.hasOwnProperty.call(snapshot, packageName)
      ? snapshot[packageName]!
      : null;
  };
}
