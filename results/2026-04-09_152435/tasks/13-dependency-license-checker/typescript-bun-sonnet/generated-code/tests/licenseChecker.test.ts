// TDD: Write failing tests first, then implement to make them pass.
// This file covers the core license checker logic.

import { describe, test, expect } from "bun:test";
import {
  parsePackageJson,
  checkLicense,
  generateReport,
  formatReport,
} from "../src/licenseChecker";
import type { LicenseConfig, LicenseLookupFn } from "../src/types";

// --- RED PHASE: These tests fail until src/licenseChecker.ts is implemented ---

describe("parsePackageJson", () => {
  test("extracts dependencies from a package.json string", () => {
    const content = JSON.stringify({
      name: "test-app",
      version: "1.0.0",
      dependencies: {
        react: "^18.0.0",
        lodash: "^4.17.21",
      },
    });
    const deps = parsePackageJson(content);
    expect(deps).toEqual([
      { name: "react", version: "^18.0.0" },
      { name: "lodash", version: "^4.17.21" },
    ]);
  });

  test("returns empty array when there are no dependencies", () => {
    const content = JSON.stringify({ name: "empty-app", version: "1.0.0" });
    const deps = parsePackageJson(content);
    expect(deps).toEqual([]);
  });

  test("handles package with only devDependencies (ignored by default)", () => {
    const content = JSON.stringify({
      devDependencies: { typescript: "^5.0.0" },
    });
    const deps = parsePackageJson(content);
    expect(deps).toEqual([]);
  });

  test("throws a meaningful error on invalid JSON", () => {
    expect(() => parsePackageJson("not-valid-json")).toThrow(
      "Failed to parse manifest"
    );
  });
});

describe("checkLicense", () => {
  const config: LicenseConfig = {
    allowList: ["MIT", "Apache-2.0", "ISC"],
    denyList: ["GPL-2.0", "GPL-3.0"],
  };

  test("returns 'approved' for a license on the allow list", () => {
    expect(checkLicense("MIT", config)).toBe("approved");
  });

  test("matching is case-insensitive", () => {
    expect(checkLicense("mit", config)).toBe("approved");
    expect(checkLicense("APACHE-2.0", config)).toBe("approved");
  });

  test("returns 'denied' for a license on the deny list", () => {
    expect(checkLicense("GPL-3.0", config)).toBe("denied");
  });

  test("deny list takes precedence over allow list when both match", () => {
    const conflictConfig: LicenseConfig = {
      allowList: ["GPL-3.0"],
      denyList: ["GPL-3.0"],
    };
    expect(checkLicense("GPL-3.0", conflictConfig)).toBe("denied");
  });

  test("returns 'unknown' for a license not in either list", () => {
    expect(checkLicense("CDDL-1.0", config)).toBe("unknown");
  });

  test("returns 'unknown' when license is null", () => {
    expect(checkLicense(null, config)).toBe("unknown");
  });
});

describe("generateReport", () => {
  const config: LicenseConfig = {
    allowList: ["MIT", "Apache-2.0"],
    denyList: ["GPL-3.0"],
  };

  // Mock lookup: returns licenses based on package name
  const mockLookup: LicenseLookupFn = async (name: string) => {
    const db: Record<string, string> = {
      react: "MIT",
      express: "MIT",
      "gpl-package": "GPL-3.0",
    };
    return db[name] ?? null;
  };

  test("generates report entries with correct status for each dependency", async () => {
    const deps = [
      { name: "react", version: "^18.0.0" },
      { name: "gpl-package", version: "^1.0.0" },
      { name: "unknown-pkg", version: "^2.0.0" },
    ];
    const report = await generateReport(deps, config, mockLookup);

    expect(report.dependencies).toHaveLength(3);
    expect(report.dependencies[0]).toEqual({
      name: "react",
      version: "^18.0.0",
      license: "MIT",
      status: "approved",
    });
    expect(report.dependencies[1]).toEqual({
      name: "gpl-package",
      version: "^1.0.0",
      license: "GPL-3.0",
      status: "denied",
    });
    expect(report.dependencies[2]).toEqual({
      name: "unknown-pkg",
      version: "^2.0.0",
      license: null,
      status: "unknown",
    });
  });

  test("summary counts are correct", async () => {
    const deps = [
      { name: "react", version: "^18.0.0" },
      { name: "gpl-package", version: "^1.0.0" },
      { name: "unknown-pkg", version: "^2.0.0" },
    ];
    const report = await generateReport(deps, config, mockLookup);
    expect(report.summary.total).toBe(3);
    expect(report.summary.approved).toBe(1);
    expect(report.summary.denied).toBe(1);
    expect(report.summary.unknown).toBe(1);
  });

  test("compliant is false when there are denied licenses", async () => {
    const deps = [{ name: "gpl-package", version: "^1.0.0" }];
    const report = await generateReport(deps, config, mockLookup);
    expect(report.compliant).toBe(false);
  });

  test("compliant is true when no denied licenses", async () => {
    const deps = [{ name: "react", version: "^18.0.0" }];
    const report = await generateReport(deps, config, mockLookup);
    expect(report.compliant).toBe(true);
  });

  test("compliant is true for empty dependencies", async () => {
    const report = await generateReport([], config, mockLookup);
    expect(report.dependencies).toHaveLength(0);
    expect(report.compliant).toBe(true);
    expect(report.summary.total).toBe(0);
  });
});

describe("formatReport", () => {
  const config: LicenseConfig = {
    allowList: ["MIT"],
    denyList: ["GPL-3.0"],
  };

  test("output contains expected summary fields", async () => {
    const deps = [
      { name: "react", version: "^18.0.0" },
      { name: "gpl-package", version: "^1.0.0" },
      { name: "unknown-pkg", version: "^2.0.0" },
    ];
    const mockLookup: LicenseLookupFn = async (name) => {
      if (name === "react") return "MIT";
      if (name === "gpl-package") return "GPL-3.0";
      return null;
    };
    const report = await generateReport(deps, config, mockLookup);
    const formatted = formatReport(report);

    expect(formatted).toContain("Total: 3");
    expect(formatted).toContain("Approved: 1");
    expect(formatted).toContain("Denied: 1");
    expect(formatted).toContain("Unknown: 1");
    expect(formatted).toContain("Status: NON-COMPLIANT");
    expect(formatted).toContain("react");
    expect(formatted).toContain("gpl-package");
  });

  test("output shows COMPLIANT when no denied licenses", async () => {
    const deps = [{ name: "react", version: "^18.0.0" }];
    const mockLookup: LicenseLookupFn = async () => "MIT";
    const report = await generateReport(deps, config, mockLookup);
    const formatted = formatReport(report);
    expect(formatted).toContain("Status: COMPLIANT");
  });
});
