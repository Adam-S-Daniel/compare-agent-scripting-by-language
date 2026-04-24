// TDD: Dependency License Checker Tests
// Red/green cycle: tests written first, implementation follows.

import { describe, it, expect } from "bun:test";
import { parseDependencies } from "../src/parser";
import { checkLicenses } from "../src/licenseChecker";
import { generateReport } from "../src/reporter";
import { mockLicenseLookup } from "../src/mockLicenseLookup";
import type {
  Dependency,
  LicenseConfig,
  CheckResult,
  ComplianceReport,
} from "../src/types";

// --- RED: parseDependencies ---

describe("parseDependencies", () => {
  it("extracts dependencies from package.json content", () => {
    const pkg = {
      dependencies: {
        lodash: "^4.17.21",
        express: "^4.18.2",
      },
      devDependencies: {
        typescript: "^5.0.0",
      },
    };
    const result = parseDependencies(JSON.stringify(pkg));
    expect(result).toHaveLength(3);
    expect(result).toContainEqual({ name: "lodash", version: "4.17.21" });
    expect(result).toContainEqual({ name: "express", version: "4.18.2" });
    expect(result).toContainEqual({ name: "typescript", version: "5.0.0" });
  });

  it("strips semver range prefixes (^, ~, >=, etc.)", () => {
    const pkg = {
      dependencies: {
        "pkg-a": "~1.2.3",
        "pkg-b": ">=2.0.0",
        "pkg-c": "=3.0.0",
        "pkg-d": "4.0.0",
      },
    };
    const result = parseDependencies(JSON.stringify(pkg));
    expect(result).toContainEqual({ name: "pkg-a", version: "1.2.3" });
    expect(result).toContainEqual({ name: "pkg-b", version: "2.0.0" });
    expect(result).toContainEqual({ name: "pkg-c", version: "3.0.0" });
    expect(result).toContainEqual({ name: "pkg-d", version: "4.0.0" });
  });

  it("returns empty array for manifest with no dependencies", () => {
    const pkg = { name: "empty-app", version: "1.0.0" };
    const result = parseDependencies(JSON.stringify(pkg));
    expect(result).toHaveLength(0);
  });

  it("throws on invalid JSON", () => {
    expect(() => parseDependencies("not json")).toThrow(
      "Failed to parse dependency manifest"
    );
  });
});

// --- RED: mockLicenseLookup ---

describe("mockLicenseLookup", () => {
  it("returns known license for lodash", () => {
    expect(mockLicenseLookup("lodash")).toBe("MIT");
  });

  it("returns null for unknown package", () => {
    expect(mockLicenseLookup("totally-unknown-package-xyz")).toBeNull();
  });
});

// --- RED: checkLicenses ---

describe("checkLicenses", () => {
  const config: LicenseConfig = {
    allowList: ["MIT", "Apache-2.0", "ISC"],
    denyList: ["GPL-2.0", "GPL-3.0"],
  };

  it("marks MIT license as approved", () => {
    const deps: Dependency[] = [{ name: "lodash", version: "4.17.21" }];
    const results = checkLicenses(deps, config, mockLicenseLookup);
    expect(results[0].status).toBe("approved");
    expect(results[0].license).toBe("MIT");
  });

  it("marks GPL license as denied", () => {
    const deps: Dependency[] = [{ name: "gpl-lib", version: "1.0.0" }];
    const results = checkLicenses(deps, config, mockLicenseLookup);
    expect(results[0].status).toBe("denied");
    expect(results[0].license).toBe("GPL-3.0");
  });

  it("marks unknown package as unknown", () => {
    const deps: Dependency[] = [{ name: "unknown-pkg", version: "2.0.0" }];
    const results = checkLicenses(deps, config, mockLicenseLookup);
    expect(results[0].status).toBe("unknown");
    expect(results[0].license).toBe("UNKNOWN");
  });

  it("processes multiple dependencies correctly", () => {
    const deps: Dependency[] = [
      { name: "lodash", version: "4.17.21" },
      { name: "gpl-lib", version: "1.0.0" },
      { name: "unknown-pkg", version: "2.0.0" },
    ];
    const results = checkLicenses(deps, config, mockLicenseLookup);
    const byName = Object.fromEntries(results.map((r) => [r.name, r]));
    expect(byName["lodash"].status).toBe("approved");
    expect(byName["gpl-lib"].status).toBe("denied");
    expect(byName["unknown-pkg"].status).toBe("unknown");
  });
});

// --- RED: generateReport ---

describe("generateReport", () => {
  const results: CheckResult[] = [
    { name: "lodash", version: "4.17.21", license: "MIT", status: "approved" },
    {
      name: "gpl-lib",
      version: "1.0.0",
      license: "GPL-3.0",
      status: "denied",
    },
    {
      name: "unknown-pkg",
      version: "2.0.0",
      license: "UNKNOWN",
      status: "unknown",
    },
  ];

  it("generates report containing each dependency line", () => {
    const report = generateReport(results);
    expect(report).toContain("lodash@4.17.21: MIT (approved)");
    expect(report).toContain("gpl-lib@1.0.0: GPL-3.0 (denied)");
    expect(report).toContain("unknown-pkg@2.0.0: UNKNOWN (unknown)");
  });

  it("includes summary counts", () => {
    const report = generateReport(results);
    expect(report).toContain("Approved: 1");
    expect(report).toContain("Denied: 1");
    expect(report).toContain("Unknown: 1");
    expect(report).toContain("Total: 3");
  });

  it("shows FAILED status when denied packages exist", () => {
    const report = generateReport(results);
    expect(report).toContain("Status: FAILED");
  });

  it("shows PASSED status when no denied packages", () => {
    const allGood: CheckResult[] = [
      {
        name: "lodash",
        version: "4.17.21",
        license: "MIT",
        status: "approved",
      },
    ];
    const report = generateReport(allGood);
    expect(report).toContain("Status: PASSED");
  });
});
