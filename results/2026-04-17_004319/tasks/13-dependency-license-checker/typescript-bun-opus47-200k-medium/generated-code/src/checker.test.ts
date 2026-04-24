// TDD tests for the dependency license checker.
// Red/green cycles: parser -> lookup -> classifier -> report.
import { describe, expect, test } from "bun:test";
import {
  parseManifest,
  classifyLicense,
  generateReport,
  checkDependencies,
  type LicenseConfig,
  type Dependency,
  type ReportEntry,
} from "./checker.ts";

describe("parseManifest", () => {
  test("parses a package.json with dependencies and devDependencies", () => {
    const json = JSON.stringify({
      name: "demo",
      dependencies: { lodash: "^4.17.21", express: "4.18.2" },
      devDependencies: { typescript: "^5.0.0" },
    });
    const deps = parseManifest(json, "package.json");
    expect(deps).toEqual([
      { name: "lodash", version: "^4.17.21" },
      { name: "express", version: "4.18.2" },
      { name: "typescript", version: "^5.0.0" },
    ]);
  });

  test("parses a requirements.txt file", () => {
    const txt = "requests==2.31.0\nflask>=2.0.0\n# comment line\n\nnumpy~=1.24";
    const deps = parseManifest(txt, "requirements.txt");
    expect(deps).toEqual([
      { name: "requests", version: "2.31.0" },
      { name: "flask", version: "2.0.0" },
      { name: "numpy", version: "1.24" },
    ]);
  });

  test("throws on invalid JSON manifest", () => {
    expect(() => parseManifest("not json", "package.json")).toThrow(
      /Failed to parse package.json/,
    );
  });

  test("throws on unknown manifest type", () => {
    expect(() => parseManifest("anything", "Cargo.toml")).toThrow(
      /Unsupported manifest/,
    );
  });
});

describe("classifyLicense", () => {
  const config: LicenseConfig = {
    allow: ["MIT", "Apache-2.0"],
    deny: ["GPL-3.0"],
  };

  test("returns approved when license is on the allow list", () => {
    expect(classifyLicense("MIT", config)).toBe("approved");
  });

  test("returns denied when license is on the deny list", () => {
    expect(classifyLicense("GPL-3.0", config)).toBe("denied");
  });

  test("returns unknown for license not in either list", () => {
    expect(classifyLicense("ISC", config)).toBe("unknown");
  });

  test("returns unknown when license is undefined", () => {
    expect(classifyLicense(undefined, config)).toBe("unknown");
  });

  test("deny list takes precedence over allow list", () => {
    const cfg: LicenseConfig = { allow: ["MIT"], deny: ["MIT"] };
    expect(classifyLicense("MIT", cfg)).toBe("denied");
  });
});

describe("checkDependencies", () => {
  const config: LicenseConfig = {
    allow: ["MIT", "Apache-2.0"],
    deny: ["GPL-3.0"],
  };

  // Mock license lookup for testability (no network).
  const mockLookup = async (dep: Dependency): Promise<string | undefined> => {
    const table: Record<string, string> = {
      lodash: "MIT",
      express: "MIT",
      "bad-lib": "GPL-3.0",
      "fancy-lib": "CC-BY-4.0",
    };
    return table[dep.name];
  };

  test("classifies each dependency using the mock lookup", async () => {
    const deps: Dependency[] = [
      { name: "lodash", version: "4.17.21" },
      { name: "bad-lib", version: "1.0.0" },
      { name: "fancy-lib", version: "2.0.0" },
      { name: "missing-lib", version: "0.1.0" },
    ];
    const entries = await checkDependencies(deps, config, mockLookup);
    expect(entries).toEqual([
      { name: "lodash", version: "4.17.21", license: "MIT", status: "approved" },
      { name: "bad-lib", version: "1.0.0", license: "GPL-3.0", status: "denied" },
      { name: "fancy-lib", version: "2.0.0", license: "CC-BY-4.0", status: "unknown" },
      { name: "missing-lib", version: "0.1.0", license: undefined, status: "unknown" },
    ]);
  });
});

describe("generateReport", () => {
  const entries: ReportEntry[] = [
    { name: "lodash", version: "4.17.21", license: "MIT", status: "approved" },
    { name: "bad-lib", version: "1.0.0", license: "GPL-3.0", status: "denied" },
    { name: "mystery", version: "0.0.1", license: undefined, status: "unknown" },
  ];

  test("produces a human-readable compliance report", () => {
    const report = generateReport(entries);
    expect(report).toContain("Dependency License Compliance Report");
    expect(report).toContain("Total dependencies: 3");
    expect(report).toContain("Approved: 1");
    expect(report).toContain("Denied:   1");
    expect(report).toContain("Unknown:  1");
    expect(report).toContain("lodash@4.17.21");
    expect(report).toContain("MIT");
    expect(report).toContain("APPROVED");
    expect(report).toContain("bad-lib@1.0.0");
    expect(report).toContain("DENIED");
    expect(report).toContain("mystery@0.0.1");
    expect(report).toContain("UNKNOWN");
  });

  test("handles empty dependency list", () => {
    const report = generateReport([]);
    expect(report).toContain("Total dependencies: 0");
  });
});
