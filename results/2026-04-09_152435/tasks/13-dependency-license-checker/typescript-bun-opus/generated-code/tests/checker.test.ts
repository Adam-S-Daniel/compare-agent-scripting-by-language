// TDD: Tests for license checking and compliance report generation
// Red phase: write failing tests, then implement

import { describe, test, expect } from "bun:test";
import { checkCompliance, classifyLicense } from "../src/checker";
import type { Dependency, LicenseConfig, LicenseInfo, LicenseLookupFn } from "../src/types";

// Mock license lookup: returns predefined licenses for known packages
function createMockLookup(mapping: Record<string, string>): LicenseLookupFn {
  return async (name: string, version: string): Promise<LicenseInfo> => {
    const license = mapping[name] ?? null;
    return { name, version, license };
  };
}

describe("classifyLicense", () => {
  const config: LicenseConfig = {
    allowList: ["MIT", "Apache-2.0", "BSD-3-Clause"],
    denyList: ["GPL-3.0", "AGPL-3.0"],
  };

  test("returns 'approved' for allowed licenses", () => {
    expect(classifyLicense("MIT", config)).toBe("approved");
    expect(classifyLicense("Apache-2.0", config)).toBe("approved");
  });

  test("returns 'denied' for denied licenses", () => {
    expect(classifyLicense("GPL-3.0", config)).toBe("denied");
    expect(classifyLicense("AGPL-3.0", config)).toBe("denied");
  });

  test("returns 'unknown' for licenses not in either list", () => {
    expect(classifyLicense("ISC", config)).toBe("unknown");
    expect(classifyLicense("MPL-2.0", config)).toBe("unknown");
  });

  test("returns 'unknown' when license is null", () => {
    expect(classifyLicense(null, config)).toBe("unknown");
  });

  test("matching is case-insensitive", () => {
    expect(classifyLicense("mit", config)).toBe("approved");
    expect(classifyLicense("gpl-3.0", config)).toBe("denied");
  });
});

describe("checkCompliance", () => {
  const config: LicenseConfig = {
    allowList: ["MIT", "Apache-2.0"],
    denyList: ["GPL-3.0"],
  };

  const mockLookup = createMockLookup({
    express: "MIT",
    lodash: "MIT",
    "gpl-lib": "GPL-3.0",
    "mystery-pkg": "WTFPL",
  });

  test("generates compliance report with correct statuses", async () => {
    const deps: Dependency[] = [
      { name: "express", version: "^4.18.0" },
      { name: "lodash", version: "^4.17.21" },
      { name: "gpl-lib", version: "^1.0.0" },
      { name: "mystery-pkg", version: "^2.0.0" },
    ];

    const report = await checkCompliance(deps, config, mockLookup);

    expect(report.entries).toEqual([
      { name: "express", version: "^4.18.0", license: "MIT", status: "approved" },
      { name: "lodash", version: "^4.17.21", license: "MIT", status: "approved" },
      { name: "gpl-lib", version: "^1.0.0", license: "GPL-3.0", status: "denied" },
      { name: "mystery-pkg", version: "^2.0.0", license: "WTFPL", status: "unknown" },
    ]);

    expect(report.summary).toEqual({
      total: 4,
      approved: 2,
      denied: 1,
      unknown: 1,
    });
  });

  test("handles empty dependency list", async () => {
    const report = await checkCompliance([], config, mockLookup);
    expect(report.entries).toEqual([]);
    expect(report.summary).toEqual({ total: 0, approved: 0, denied: 0, unknown: 0 });
  });

  test("handles lookup failure (null license)", async () => {
    const failLookup: LicenseLookupFn = async (name, version) => ({
      name,
      version,
      license: null,
    });

    const deps: Dependency[] = [{ name: "unknown-pkg", version: "1.0.0" }];
    const report = await checkCompliance(deps, config, failLookup);

    expect(report.entries[0].status).toBe("unknown");
    expect(report.entries[0].license).toBeNull();
  });
});
