/**
 * Dependency License Checker Tests
 *
 * TDD approach: write failing tests first, then implement the minimum code to pass.
 * Each test block covers one piece of functionality.
 */

import { describe, it, expect } from "bun:test";
import {
  parsePackageJson,
  checkLicenses,
  generateReport,
  type Dependency,
  type LicenseConfig,
  type ComplianceResult,
  type ComplianceReport,
} from "./licenseChecker";

// ─── Test Fixtures ────────────────────────────────────────────────────────────

const SIMPLE_PACKAGE_JSON = {
  name: "my-app",
  version: "1.0.0",
  dependencies: {
    react: "^18.0.0",
    lodash: "^4.17.21",
  },
  devDependencies: {
    typescript: "^5.0.0",
  },
};

const LICENSE_CONFIG: LicenseConfig = {
  allowList: ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC"],
  denyList: ["GPL-2.0", "GPL-3.0", "AGPL-3.0", "LGPL-2.1"],
};

// Mock license lookup: returns a license string for a given package name
// This simulates what a real registry lookup would return
const mockLicenseLookup = async (
  packageName: string,
  _version: string
): Promise<string | null> => {
  const licenses: Record<string, string> = {
    react: "MIT",
    lodash: "MIT",
    typescript: "Apache-2.0",
    "gpl-library": "GPL-3.0",
    "unknown-pkg": null as unknown as string,
  };
  return licenses[packageName] ?? null;
};

// ─── Section 1: Parsing ───────────────────────────────────────────────────────

describe("parsePackageJson", () => {
  it("extracts dependencies with versions from package.json", () => {
    const deps = parsePackageJson(SIMPLE_PACKAGE_JSON, { includeDev: false });
    expect(deps).toHaveLength(2);
    expect(deps[0]).toEqual({ name: "react", version: "^18.0.0" });
    expect(deps[1]).toEqual({ name: "lodash", version: "^4.17.21" });
  });

  it("includes devDependencies when includeDev is true", () => {
    const deps = parsePackageJson(SIMPLE_PACKAGE_JSON, { includeDev: true });
    expect(deps).toHaveLength(3);
    const names = deps.map((d) => d.name);
    expect(names).toContain("typescript");
  });

  it("returns empty array for package.json with no dependencies", () => {
    const deps = parsePackageJson({ name: "empty", version: "1.0.0" }, { includeDev: true });
    expect(deps).toHaveLength(0);
  });

  it("handles package.json string input (JSON string)", () => {
    const jsonString = JSON.stringify(SIMPLE_PACKAGE_JSON);
    const deps = parsePackageJson(jsonString, { includeDev: false });
    expect(deps).toHaveLength(2);
  });

  it("throws a meaningful error for invalid JSON string", () => {
    expect(() => parsePackageJson("not valid json", { includeDev: false })).toThrow(
      /Invalid package.json/
    );
  });
});

// ─── Section 2: License Checking ─────────────────────────────────────────────

describe("checkLicenses", () => {
  it("marks a dependency as 'approved' when its license is in the allow list", async () => {
    const deps: Dependency[] = [{ name: "react", version: "^18.0.0" }];
    const results = await checkLicenses(deps, LICENSE_CONFIG, mockLicenseLookup);
    expect(results[0].status).toBe("approved");
    expect(results[0].license).toBe("MIT");
  });

  it("marks a dependency as 'denied' when its license is in the deny list", async () => {
    const deps: Dependency[] = [{ name: "gpl-library", version: "1.0.0" }];
    const results = await checkLicenses(deps, LICENSE_CONFIG, mockLicenseLookup);
    expect(results[0].status).toBe("denied");
    expect(results[0].license).toBe("GPL-3.0");
  });

  it("marks a dependency as 'unknown' when license lookup returns null", async () => {
    const deps: Dependency[] = [{ name: "unknown-pkg", version: "1.0.0" }];
    const results = await checkLicenses(deps, LICENSE_CONFIG, mockLicenseLookup);
    expect(results[0].status).toBe("unknown");
    expect(results[0].license).toBeNull();
  });

  it("processes multiple dependencies correctly", async () => {
    const deps: Dependency[] = [
      { name: "react", version: "^18.0.0" },
      { name: "gpl-library", version: "1.0.0" },
      { name: "unknown-pkg", version: "1.0.0" },
    ];
    const results = await checkLicenses(deps, LICENSE_CONFIG, mockLicenseLookup);
    expect(results).toHaveLength(3);

    const byName = Object.fromEntries(results.map((r) => [r.dependency.name, r]));
    expect(byName["react"].status).toBe("approved");
    expect(byName["gpl-library"].status).toBe("denied");
    expect(byName["unknown-pkg"].status).toBe("unknown");
  });

  it("preserves dependency name and version in result", async () => {
    const deps: Dependency[] = [{ name: "react", version: "^18.0.0" }];
    const results = await checkLicenses(deps, LICENSE_CONFIG, mockLicenseLookup);
    expect(results[0].dependency.name).toBe("react");
    expect(results[0].dependency.version).toBe("^18.0.0");
  });
});

// ─── Section 3: Report Generation ────────────────────────────────────────────

describe("generateReport", () => {
  const sampleResults: ComplianceResult[] = [
    {
      dependency: { name: "react", version: "^18.0.0" },
      license: "MIT",
      status: "approved",
    },
    {
      dependency: { name: "gpl-library", version: "1.0.0" },
      license: "GPL-3.0",
      status: "denied",
    },
    {
      dependency: { name: "unknown-pkg", version: "1.0.0" },
      license: null,
      status: "unknown",
    },
  ];

  it("returns a report with correct summary counts", () => {
    const report = generateReport(sampleResults);
    expect(report.summary.total).toBe(3);
    expect(report.summary.approved).toBe(1);
    expect(report.summary.denied).toBe(1);
    expect(report.summary.unknown).toBe(1);
  });

  it("includes all results in the report", () => {
    const report = generateReport(sampleResults);
    expect(report.results).toHaveLength(3);
  });

  it("sets compliant to false when there are denied dependencies", () => {
    const report = generateReport(sampleResults);
    expect(report.compliant).toBe(false);
  });

  it("sets compliant to true when all dependencies are approved", () => {
    const allApproved: ComplianceResult[] = [
      { dependency: { name: "react", version: "^18.0.0" }, license: "MIT", status: "approved" },
    ];
    const report = generateReport(allApproved);
    expect(report.compliant).toBe(true);
  });

  it("sets compliant to false when there are unknown dependencies (strict mode default)", () => {
    const withUnknown: ComplianceResult[] = [
      {
        dependency: { name: "unknown-pkg", version: "1.0.0" },
        license: null,
        status: "unknown",
      },
    ];
    const report = generateReport(withUnknown);
    expect(report.compliant).toBe(false);
  });

  it("generates a markdown-formatted text report", () => {
    const report = generateReport(sampleResults);
    const text = report.toMarkdown();
    expect(text).toContain("# Dependency License Compliance Report");
    expect(text).toContain("react");
    expect(text).toContain("MIT");
    expect(text).toContain("approved");
    expect(text).toContain("denied");
    expect(text).toContain("GPL-3.0");
    expect(text).toContain("COMPLIANT: false");
  });
});
