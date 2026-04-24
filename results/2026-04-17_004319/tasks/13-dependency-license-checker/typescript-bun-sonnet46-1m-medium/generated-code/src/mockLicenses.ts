// Mock license database for testing — simulates a real license registry lookup.
// In production this would call something like the npm registry or a license API.

export const MOCK_LICENSE_DB: Record<string, string> = {
  react: "MIT",
  "react-dom": "MIT",
  lodash: "MIT",
  axios: "MIT",
  express: "MIT",
  typescript: "Apache-2.0",
  webpack: "MIT",
  "babel-core": "MIT",
  "gpl-pkg": "GPL-3.0",
  "gpl-lib": "GPL-2.0",
  "lgpl-package": "LGPL-2.1",
};

export function lookupLicense(packageName: string): string | null {
  return MOCK_LICENSE_DB[packageName] ?? null;
}
