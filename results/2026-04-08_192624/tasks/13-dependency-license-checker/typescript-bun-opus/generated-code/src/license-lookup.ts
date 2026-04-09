// Mock license lookup — simulates querying a registry for license info.
// In production this would call npm registry, PyPI, etc.
import type { Dependency, LicenseLookupFn } from "./types";

/** Well-known licenses for common packages, used for mock/testing */
const MOCK_LICENSES: Record<string, string> = {
  express: "MIT",
  lodash: "MIT",
  react: "MIT",
  "react-dom": "MIT",
  typescript: "Apache-2.0",
  axios: "MIT",
  webpack: "MIT",
  jest: "MIT",
  mocha: "MIT",
  "gpl-lib": "GPL-3.0",
  "agpl-lib": "AGPL-3.0",
  "mystery-pkg": "UNKNOWN",
  flask: "BSD-3-Clause",
  requests: "Apache-2.0",
  numpy: "BSD-3-Clause",
  django: "BSD-3-Clause",
  "gpl-tool": "GPL-3.0",
};

/**
 * Create a mock license lookup function with optional overrides.
 * Returns "UNKNOWN" for packages not in the map.
 */
export function createMockLookup(overrides?: Record<string, string>): LicenseLookupFn {
  const licenses = { ...MOCK_LICENSES, ...overrides };
  return async (dep: Dependency): Promise<string> => {
    return licenses[dep.name] ?? "UNKNOWN";
  };
}
