/**
 * Mock License Database
 *
 * Simulates what a real npm registry or license API would return.
 * Used both in tests and as the default lookup in the CLI for demo purposes.
 */

// Map of package name → SPDX license identifier
const MOCK_LICENSE_DB: Record<string, string> = {
  // Common MIT packages
  react: "MIT",
  "react-dom": "MIT",
  lodash: "MIT",
  axios: "MIT",
  chalk: "MIT",
  commander: "MIT",
  express: "MIT",
  "is-plain-object": "MIT",
  "js-yaml": "MIT",
  uuid: "MIT",
  zod: "MIT",

  // Apache-2.0 packages
  typescript: "Apache-2.0",
  "aws-sdk": "Apache-2.0",
  rxjs: "Apache-2.0",

  // BSD packages
  "node-fetch": "MIT",
  semver: "ISC",
  glob: "ISC",
  minimatch: "ISC",
  jest: "MIT",
  "ts-jest": "MIT",

  // GPL / denied packages (for testing)
  "gpl-library": "GPL-3.0",
  "gpl2-package": "GPL-2.0",
  "agpl-service": "AGPL-3.0",

  // Packages with no known license (returns null)
  // These are intentionally omitted so lookup returns null
};

/**
 * Look up the license for a package by name and version.
 * Returns null if the package is not in the mock database.
 */
export async function mockLicenseLookup(
  packageName: string,
  _version: string
): Promise<string | null> {
  // Simulate async network call latency
  await new Promise((resolve) => setTimeout(resolve, 0));
  return MOCK_LICENSE_DB[packageName] ?? null;
}
