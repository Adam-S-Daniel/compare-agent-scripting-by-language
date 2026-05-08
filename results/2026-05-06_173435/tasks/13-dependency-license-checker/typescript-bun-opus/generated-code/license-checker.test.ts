import { describe, test, expect } from "bun:test";
import { parsePackageJson, parseRequirementsTxt } from "./parser";
import { checkLicenses } from "./checker";
import { generateReport } from "./reporter";
import { createMockLookup } from "./mock-lookup";
import type { LicenseConfig, Dependency } from "./types";

// -- Parser tests --

describe("parsePackageJson", () => {
  test("extracts dependencies and devDependencies", () => {
    const pkg = JSON.stringify({
      name: "my-app",
      dependencies: { lodash: "^4.17.21", express: "~4.18.2" },
      devDependencies: { typescript: "^5.0.0" },
    });
    const deps = parsePackageJson(pkg);
    expect(deps).toEqual([
      { name: "lodash", version: "^4.17.21" },
      { name: "express", version: "~4.18.2" },
      { name: "typescript", version: "^5.0.0" },
    ]);
  });

  test("handles package.json with no dependencies", () => {
    const pkg = JSON.stringify({ name: "empty-app" });
    const deps = parsePackageJson(pkg);
    expect(deps).toEqual([]);
  });

  test("handles only devDependencies", () => {
    const pkg = JSON.stringify({ devDependencies: { jest: "^29.0.0" } });
    const deps = parsePackageJson(pkg);
    expect(deps).toEqual([{ name: "jest", version: "^29.0.0" }]);
  });

  test("throws on invalid JSON", () => {
    expect(() => parsePackageJson("not json")).toThrow("Invalid package.json");
  });
});

describe("parseRequirementsTxt", () => {
  test("parses pinned versions", () => {
    const content = "requests==2.31.0\nflask==3.0.0\n";
    const deps = parseRequirementsTxt(content);
    expect(deps).toEqual([
      { name: "requests", version: "2.31.0" },
      { name: "flask", version: "3.0.0" },
    ]);
  });

  test("handles comments and blank lines", () => {
    const content = "# comment\nrequests==2.31.0\n\n# another\nflask>=3.0.0\n";
    const deps = parseRequirementsTxt(content);
    expect(deps.length).toBe(2);
    expect(deps[0]).toEqual({ name: "requests", version: "2.31.0" });
    expect(deps[1]).toEqual({ name: "flask", version: ">=3.0.0" });
  });

  test("handles version specifiers (>=, <=, ~=, !=)", () => {
    const content = "numpy>=1.24.0\npandas~=2.0\nscipy!=1.10.0\n";
    const deps = parseRequirementsTxt(content);
    expect(deps).toEqual([
      { name: "numpy", version: ">=1.24.0" },
      { name: "pandas", version: "~=2.0" },
      { name: "scipy", version: "!=1.10.0" },
    ]);
  });

  test("handles packages without version", () => {
    const content = "requests\nflask\n";
    const deps = parseRequirementsTxt(content);
    expect(deps).toEqual([
      { name: "requests", version: "*" },
      { name: "flask", version: "*" },
    ]);
  });

  test("returns empty for empty input", () => {
    expect(parseRequirementsTxt("")).toEqual([]);
    expect(parseRequirementsTxt("  \n\n  ")).toEqual([]);
  });
});

// -- Mock lookup tests --

describe("createMockLookup", () => {
  test("returns known license for mapped dependency", async () => {
    const lookup = createMockLookup({ lodash: "MIT", express: "MIT" });
    expect(await lookup("lodash", "4.17.21")).toBe("MIT");
    expect(await lookup("express", "4.18.2")).toBe("MIT");
  });

  test("returns null for unknown dependency", async () => {
    const lookup = createMockLookup({ lodash: "MIT" });
    expect(await lookup("unknown-pkg", "1.0.0")).toBeNull();
  });
});

// -- Checker tests --

describe("checkLicenses", () => {
  const config: LicenseConfig = {
    allowList: ["MIT", "Apache-2.0", "BSD-3-Clause"],
    denyList: ["GPL-3.0", "AGPL-3.0"],
  };

  const mockLookup = createMockLookup({
    lodash: "MIT",
    express: "MIT",
    "gpl-lib": "GPL-3.0",
    "mystery-pkg": null,
  });

  test("approves dependencies with allowed licenses", async () => {
    const deps: Dependency[] = [
      { name: "lodash", version: "^4.17.21" },
      { name: "express", version: "~4.18.2" },
    ];
    const report = await checkLicenses(deps, config, mockLookup);
    expect(report.entries[0].status).toBe("approved");
    expect(report.entries[1].status).toBe("approved");
    expect(report.summary.approved).toBe(2);
    expect(report.summary.denied).toBe(0);
    expect(report.summary.unknown).toBe(0);
  });

  test("denies dependencies with denied licenses", async () => {
    const deps: Dependency[] = [{ name: "gpl-lib", version: "1.0.0" }];
    const report = await checkLicenses(deps, config, mockLookup);
    expect(report.entries[0].status).toBe("denied");
    expect(report.entries[0].license).toBe("GPL-3.0");
    expect(report.summary.denied).toBe(1);
  });

  test("marks dependencies with unknown license lookup as unknown", async () => {
    const deps: Dependency[] = [{ name: "mystery-pkg", version: "0.1.0" }];
    const report = await checkLicenses(deps, config, mockLookup);
    expect(report.entries[0].status).toBe("unknown");
    expect(report.entries[0].license).toBeNull();
    expect(report.summary.unknown).toBe(1);
  });

  test("marks license not in either list as unknown", async () => {
    const lookup = createMockLookup({ "isc-pkg": "ISC" });
    const deps: Dependency[] = [{ name: "isc-pkg", version: "1.0.0" }];
    const report = await checkLicenses(deps, config, lookup);
    expect(report.entries[0].status).toBe("unknown");
    expect(report.entries[0].license).toBe("ISC");
  });

  test("produces correct summary for mixed results", async () => {
    const deps: Dependency[] = [
      { name: "lodash", version: "4.17.21" },
      { name: "gpl-lib", version: "1.0.0" },
      { name: "mystery-pkg", version: "0.1.0" },
    ];
    const report = await checkLicenses(deps, config, mockLookup);
    expect(report.summary.total).toBe(3);
    expect(report.summary.approved).toBe(1);
    expect(report.summary.denied).toBe(1);
    expect(report.summary.unknown).toBe(1);
  });

  test("handles empty dependency list", async () => {
    const report = await checkLicenses([], config, mockLookup);
    expect(report.entries).toEqual([]);
    expect(report.summary.total).toBe(0);
  });
});

// -- Reporter tests --

describe("generateReport", () => {
  test("generates markdown report with all statuses", () => {
    const report = {
      entries: [
        { name: "lodash", version: "4.17.21", license: "MIT", status: "approved" as const },
        { name: "gpl-lib", version: "1.0.0", license: "GPL-3.0", status: "denied" as const },
        { name: "mystery", version: "0.1.0", license: null, status: "unknown" as const },
      ],
      summary: { total: 3, approved: 1, denied: 1, unknown: 1 },
    };
    const output = generateReport(report);
    expect(output).toContain("# Dependency License Compliance Report");
    expect(output).toContain("lodash");
    expect(output).toContain("APPROVED");
    expect(output).toContain("gpl-lib");
    expect(output).toContain("DENIED");
    expect(output).toContain("mystery");
    expect(output).toContain("UNKNOWN");
    expect(output).toContain("Total: 3");
    expect(output).toContain("Approved: 1");
    expect(output).toContain("Denied: 1");
    expect(output).toContain("Unknown: 1");
  });

  test("generates report for empty list", () => {
    const report = {
      entries: [],
      summary: { total: 0, approved: 0, denied: 0, unknown: 0 },
    };
    const output = generateReport(report);
    expect(output).toContain("Total: 0");
  });
});
