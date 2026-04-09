// TDD Step 2: Write failing tests for license checking logic
import { describe, expect, test } from "bun:test";
import { checkCompliance, classifyLicense } from "./checker";
import type { Dependency, LicenseConfig, LicenseLookupFn, ComplianceReport } from "./types";

// Mock license lookup that returns known licenses for test dependencies
const mockLookup: LicenseLookupFn = async (dep: Dependency): Promise<string> => {
  const licenses: Record<string, string> = {
    express: "MIT",
    lodash: "MIT",
    "gpl-lib": "GPL-3.0",
    "unknown-pkg": "UNKNOWN",
    react: "MIT",
    "agpl-lib": "AGPL-3.0",
  };
  return licenses[dep.name] ?? "UNKNOWN";
};

const config: LicenseConfig = {
  allowedLicenses: ["MIT", "Apache-2.0", "BSD-2-Clause", "ISC"],
  deniedLicenses: ["GPL-3.0", "AGPL-3.0"],
};

describe("classifyLicense", () => {
  test("returns 'approved' for allowed licenses", () => {
    expect(classifyLicense("MIT", config)).toBe("approved");
    expect(classifyLicense("Apache-2.0", config)).toBe("approved");
  });

  test("returns 'denied' for denied licenses", () => {
    expect(classifyLicense("GPL-3.0", config)).toBe("denied");
    expect(classifyLicense("AGPL-3.0", config)).toBe("denied");
  });

  test("returns 'unknown' for unrecognized licenses", () => {
    expect(classifyLicense("UNKNOWN", config)).toBe("unknown");
    expect(classifyLicense("Artistic-2.0", config)).toBe("unknown");
  });

  test("case-insensitive matching", () => {
    expect(classifyLicense("mit", config)).toBe("approved");
    expect(classifyLicense("gpl-3.0", config)).toBe("denied");
  });
});

describe("checkCompliance", () => {
  test("generates correct report for mixed dependencies", async () => {
    const deps: Dependency[] = [
      { name: "express", version: "^4.18.0" },
      { name: "gpl-lib", version: "^1.0.0" },
      { name: "unknown-pkg", version: "^2.0.0" },
    ];

    const report: ComplianceReport = await checkCompliance(deps, config, mockLookup);

    expect(report.total).toBe(3);
    expect(report.approved).toBe(1);
    expect(report.denied).toBe(1);
    expect(report.unknown).toBe(1);

    expect(report.entries).toEqual([
      { name: "express", version: "^4.18.0", license: "MIT", status: "approved" },
      { name: "gpl-lib", version: "^1.0.0", license: "GPL-3.0", status: "denied" },
      { name: "unknown-pkg", version: "^2.0.0", license: "UNKNOWN", status: "unknown" },
    ]);
  });

  test("all approved scenario", async () => {
    const deps: Dependency[] = [
      { name: "express", version: "^4.18.0" },
      { name: "lodash", version: "~4.17.21" },
      { name: "react", version: "^18.0.0" },
    ];

    const report = await checkCompliance(deps, config, mockLookup);

    expect(report.total).toBe(3);
    expect(report.approved).toBe(3);
    expect(report.denied).toBe(0);
    expect(report.unknown).toBe(0);
  });

  test("empty dependencies list", async () => {
    const report = await checkCompliance([], config, mockLookup);

    expect(report.total).toBe(0);
    expect(report.approved).toBe(0);
    expect(report.denied).toBe(0);
    expect(report.unknown).toBe(0);
    expect(report.entries).toEqual([]);
  });

  test("handles lookup errors gracefully", async () => {
    const failingLookup: LicenseLookupFn = async () => {
      throw new Error("Network error");
    };

    const deps: Dependency[] = [{ name: "express", version: "^4.18.0" }];
    const report = await checkCompliance(deps, config, failingLookup);

    // Should treat lookup failure as unknown, not crash
    expect(report.total).toBe(1);
    expect(report.unknown).toBe(1);
    expect(report.entries[0].license).toBe("LOOKUP_FAILED");
    expect(report.entries[0].status).toBe("unknown");
  });
});
