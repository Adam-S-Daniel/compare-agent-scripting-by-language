// Mock license lookup: simulates querying an external registry for license info.
// In production, this would call npm registry API or PyPI API.

import type { LicenseInfo, LicenseLookupFn } from "./types";

/** Well-known package licenses used by the mock lookup */
const MOCK_LICENSE_DB: Record<string, string> = {
  // npm packages
  express: "MIT",
  lodash: "MIT",
  react: "MIT",
  "react-dom": "MIT",
  typescript: "Apache-2.0",
  axios: "MIT",
  webpack: "MIT",
  jest: "MIT",
  chalk: "MIT",
  "left-pad": "WTFPL",
  "gpl-crypto": "GPL-3.0",
  "agpl-server": "AGPL-3.0",
  // Python packages
  requests: "Apache-2.0",
  flask: "BSD-3-Clause",
  django: "BSD-3-Clause",
  numpy: "BSD-3-Clause",
  pandas: "BSD-3-Clause",
  "gpl-tool": "GPL-3.0",
};

/** Mock license lookup function.
 *  Returns the license from MOCK_LICENSE_DB or null if not found. */
export const mockLicenseLookup: LicenseLookupFn = async (
  name: string,
  version: string
): Promise<LicenseInfo> => {
  const license = MOCK_LICENSE_DB[name] ?? null;
  return { name, version, license };
};

/** Create a custom mock lookup from a mapping */
export function createMockLookup(
  mapping: Record<string, string>
): LicenseLookupFn {
  return async (name: string, version: string): Promise<LicenseInfo> => {
    const license = mapping[name] ?? null;
    return { name, version, license };
  };
}
