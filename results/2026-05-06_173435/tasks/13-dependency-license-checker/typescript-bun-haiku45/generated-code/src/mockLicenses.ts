// Mock license database for testing
// Maps package names to their licenses

const mockLicenseDatabase: Record<string, string> = {
  // MIT licenses
  "react": "MIT",
  "typescript": "Apache-2.0",
  "lodash": "MIT",
  "express": "MIT",
  "axios": "MIT",

  // GPL licenses
  "some-gpl-package": "GPL-2.0",
  "another-gpl-lib": "GPL-3.0",

  // Commercial/Proprietary
  "proprietary-lib": "Proprietary",

  // Unknown (will return null)
  // "unknown-package" will return null
};

// Mock async license lookup function
export async function mockLicenseLookup(packageName: string): Promise<string | null> {
  return mockLicenseDatabase[packageName] ?? null;
}

// For testing purposes, allow overriding the database
export function setMockLicense(packageName: string, license: string | null): void {
  if (license === null) {
    delete mockLicenseDatabase[packageName];
  } else {
    mockLicenseDatabase[packageName] = license;
  }
}

// Reset to original state
export function resetMockLicenses(): void {
  Object.keys(mockLicenseDatabase).forEach(key => {
    delete mockLicenseDatabase[key];
  });

  mockLicenseDatabase["react"] = "MIT";
  mockLicenseDatabase["typescript"] = "Apache-2.0";
  mockLicenseDatabase["lodash"] = "MIT";
  mockLicenseDatabase["express"] = "MIT";
  mockLicenseDatabase["axios"] = "MIT";
  mockLicenseDatabase["some-gpl-package"] = "GPL-2.0";
  mockLicenseDatabase["another-gpl-lib"] = "GPL-3.0";
  mockLicenseDatabase["proprietary-lib"] = "Proprietary";
}
