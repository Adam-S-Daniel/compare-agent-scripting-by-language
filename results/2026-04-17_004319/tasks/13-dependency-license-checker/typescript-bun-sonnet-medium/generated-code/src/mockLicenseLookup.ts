// Mock license database for testing — maps package names to SPDX license identifiers.
// Real implementation would query npmjs.com/registry or a local cache.

import type { LicenseLookupFn } from "./types";

const MOCK_LICENSE_DB: Record<string, string> = {
  lodash: "MIT",
  express: "MIT",
  react: "MIT",
  "react-dom": "MIT",
  typescript: "Apache-2.0",
  axios: "MIT",
  chalk: "MIT",
  commander: "MIT",
  dotenv: "BSD-2-Clause",
  moment: "MIT",
  "js-yaml": "MIT",
  "gpl-lib": "GPL-3.0",
  "gpl2-lib": "GPL-2.0",
  "agpl-lib": "AGPL-3.0",
  "lgpl-lib": "LGPL-2.1",
};

// Returns the SPDX license string for a known package, or null if unknown.
export const mockLicenseLookup: LicenseLookupFn = (
  packageName: string
): string | null => {
  return MOCK_LICENSE_DB[packageName] ?? null;
};
