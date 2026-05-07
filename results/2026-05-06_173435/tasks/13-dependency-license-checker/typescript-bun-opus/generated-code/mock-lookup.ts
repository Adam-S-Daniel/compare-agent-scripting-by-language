import type { LicenseLookup } from "./types";

export function createMockLookup(
  licenseMap: Record<string, string | null>
): LicenseLookup {
  return async (name: string, _version: string): Promise<string | null> => {
    if (name in licenseMap) {
      return licenseMap[name];
    }
    return null;
  };
}
