// TDD unit tests for dependency license checker.
// Red/green cycle documented inline:
//   RED: write this test → it fails because implementation doesn't exist yet
//   GREEN: implement minimum code in licenseChecker.ts to make it pass
//   REFACTOR: clean up without breaking tests

import { describe, it, expect } from "bun:test";
import {
  parsePackageJson,
  determineLicenseStatus,
  checkDependencies,
  formatReport,
} from "../src/licenseChecker";
import type { LicenseConfig, ComplianceReport } from "../src/types";

// ──────────────────────────────────────────────────
// RED 1: parsePackageJson — extract deps from package.json
// ──────────────────────────────────────────────────
describe("parsePackageJson", () => {
  it("extracts dependency names and stripped versions", () => {
    const deps = parsePackageJson("fixtures/package-all-approved.json");
    expect(deps).toHaveLength(3);
    expect(deps[0].name).toBe("react");
    // Version prefix (^, ~, >=) must be stripped
    expect(deps[0].version).toBe("18.2.0");
    expect(deps[1].name).toBe("lodash");
    expect(deps[1].version).toBe("4.17.21");
    expect(deps[2].name).toBe("axios");
    expect(deps[2].version).toBe("1.4.0");
  });

  it("returns empty array when no dependencies key", () => {
    const deps = parsePackageJson("fixtures/package-no-deps.json");
    expect(deps).toHaveLength(0);
  });

  it("throws a meaningful error for missing file", () => {
    expect(() => parsePackageJson("fixtures/nonexistent.json")).toThrow(
      /nonexistent\.json/
    );
  });
});

// ──────────────────────────────────────────────────
// RED 2: determineLicenseStatus — allow/deny list logic
// ──────────────────────────────────────────────────
describe("determineLicenseStatus", () => {
  const config: LicenseConfig = {
    allowList: ["MIT", "Apache-2.0"],
    denyList: ["GPL-3.0", "GPL-2.0"],
  };

  it("returns 'approved' for a license in the allow list", () => {
    expect(determineLicenseStatus("MIT", config)).toBe("approved");
    expect(determineLicenseStatus("Apache-2.0", config)).toBe("approved");
  });

  it("returns 'denied' for a license in the deny list", () => {
    expect(determineLicenseStatus("GPL-3.0", config)).toBe("denied");
    expect(determineLicenseStatus("GPL-2.0", config)).toBe("denied");
  });

  it("returns 'unknown' for a license in neither list", () => {
    expect(determineLicenseStatus("LGPL-2.1", config)).toBe("unknown");
  });

  it("returns 'unknown' when license is null (lookup failed)", () => {
    expect(determineLicenseStatus(null, config)).toBe("unknown");
  });

  it("deny list takes priority over allow list when license appears in both", () => {
    const conflictConfig: LicenseConfig = {
      allowList: ["MIT", "GPL-3.0"],
      denyList: ["GPL-3.0"],
    };
    expect(determineLicenseStatus("GPL-3.0", conflictConfig)).toBe("denied");
  });
});

// ──────────────────────────────────────────────────
// RED 3: checkDependencies — full pipeline with mock lookup
// ──────────────────────────────────────────────────
describe("checkDependencies", () => {
  const config: LicenseConfig = {
    allowList: ["MIT", "Apache-2.0"],
    denyList: ["GPL-3.0"],
  };

  const mockLookup = (name: string): string | null => {
    const db: Record<string, string> = {
      react: "MIT",
      "gpl-pkg": "GPL-3.0",
      typescript: "Apache-2.0",
    };
    return db[name] ?? null;
  };

  it("returns approved status for MIT packages", () => {
    const deps = [{ name: "react", version: "18.2.0" }];
    const report = checkDependencies(deps, config, mockLookup);
    expect(report.dependencies[0].status).toBe("approved");
    expect(report.dependencies[0].license).toBe("MIT");
  });

  it("returns denied status for GPL packages", () => {
    const deps = [{ name: "gpl-pkg", version: "1.0.0" }];
    const report = checkDependencies(deps, config, mockLookup);
    expect(report.dependencies[0].status).toBe("denied");
    expect(report.dependencies[0].license).toBe("GPL-3.0");
  });

  it("returns unknown status for packages not in mock db", () => {
    const deps = [{ name: "unknown-pkg", version: "2.0.0" }];
    const report = checkDependencies(deps, config, mockLookup);
    expect(report.dependencies[0].status).toBe("unknown");
    expect(report.dependencies[0].license).toBeNull();
  });

  it("computes correct summary counts", () => {
    const deps = [
      { name: "react", version: "18.2.0" },
      { name: "gpl-pkg", version: "1.0.0" },
      { name: "unknown-pkg", version: "2.0.0" },
    ];
    const report = checkDependencies(deps, config, mockLookup);
    expect(report.summary.total).toBe(3);
    expect(report.summary.approved).toBe(1);
    expect(report.summary.denied).toBe(1);
    expect(report.summary.unknown).toBe(1);
  });

  it("handles empty dependency list", () => {
    const report = checkDependencies([], config, mockLookup);
    expect(report.dependencies).toHaveLength(0);
    expect(report.summary.total).toBe(0);
  });
});

// ──────────────────────────────────────────────────
// RED 4: formatReport — text output format
// ──────────────────────────────────────────────────
describe("formatReport", () => {
  const report: ComplianceReport = {
    dependencies: [
      { name: "react", version: "18.2.0", license: "MIT", status: "approved" },
      { name: "gpl-pkg", version: "1.0.0", license: "GPL-3.0", status: "denied" },
      { name: "unknown-pkg", version: "2.0.0", license: null, status: "unknown" },
    ],
    summary: { total: 3, approved: 1, denied: 1, unknown: 1 },
  };

  it("contains a header line", () => {
    const output = formatReport(report);
    expect(output).toContain("DEPENDENCY LICENSE COMPLIANCE REPORT");
  });

  it("formats each dependency on its own line with exact format", () => {
    const output = formatReport(report);
    expect(output).toContain("react@18.2.0: MIT - APPROVED");
    expect(output).toContain("gpl-pkg@1.0.0: GPL-3.0 - DENIED");
    expect(output).toContain("unknown-pkg@2.0.0: UNKNOWN - UNKNOWN");
  });

  it("includes summary with exact counts", () => {
    const output = formatReport(report);
    expect(output).toContain("SUMMARY: 1 approved, 1 denied, 1 unknown");
  });
});
