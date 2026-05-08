import { describe, it, expect, beforeEach } from "bun:test";
import { parsePackageJson, checkLicenses, parseRequirementsTxt } from "../src/checker";
import { resetMockLicenses, setMockLicense } from "../src/mockLicenses";
import type { Dependency, LicenseConfig, ComplianceReport } from "../src/types";

// Test 1: Parse package.json (RED: this test will fail initially)
describe("parsePackageJson", () => {
  it("should extract dependencies from package.json", () => {
    const packageJson = {
      dependencies: {
        "react": "^18.0.0",
        "lodash": "4.17.21"
      }
    };

    const deps = parsePackageJson(packageJson);
    expect(deps.length).toBe(2);
    expect(deps[0]).toEqual({ name: "react", version: "^18.0.0" });
    expect(deps[1]).toEqual({ name: "lodash", version: "4.17.21" });
  });

  it("should handle empty dependencies", () => {
    const packageJson = { dependencies: {} };
    const deps = parsePackageJson(packageJson);
    expect(deps.length).toBe(0);
  });

  it("should handle missing dependencies field", () => {
    const packageJson = {};
    const deps = parsePackageJson(packageJson);
    expect(deps.length).toBe(0);
  });

  it("should include devDependencies", () => {
    const packageJson = {
      dependencies: {
        "react": "^18.0.0"
      },
      devDependencies: {
        "typescript": "^5.0.0"
      }
    };

    const deps = parsePackageJson(packageJson);
    expect(deps.length).toBe(2);
    expect(deps.map(d => d.name).sort()).toEqual(["react", "typescript"]);
  });
});

// Test 2: Parse requirements.txt
describe("parseRequirementsTxt", () => {
  it("should extract dependencies from requirements.txt format", () => {
    const content = `
requests==2.31.0
numpy>=1.20.0
django~=4.2
    `.trim();

    const deps = parseRequirementsTxt(content);
    expect(deps.length).toBe(3);
    expect(deps[0]).toEqual({ name: "requests", version: "==2.31.0" });
    expect(deps[1]).toEqual({ name: "numpy", version: ">=1.20.0" });
    expect(deps[2]).toEqual({ name: "django", version: "~=4.2" });
  });

  it("should skip empty lines and comments", () => {
    const content = `
# This is a comment
requests==2.31.0

# Another comment
numpy>=1.20.0
    `.trim();

    const deps = parseRequirementsTxt(content);
    expect(deps.length).toBe(2);
  });

  it("should handle edge cases", () => {
    const content = `
requests==2.31.0  # inline comment
numpy>=1.20.0
    `.trim();

    const deps = parseRequirementsTxt(content);
    expect(deps.length).toBe(2);
  });
});

// Test 3: License checking
describe("checkLicenses", () => {
  beforeEach(() => {
    resetMockLicenses();
  });

  it("should mark approved licenses", async () => {
    const config: LicenseConfig = {
      allowList: ["MIT", "Apache-2.0"],
      denyList: ["GPL-2.0", "GPL-3.0"]
    };

    const deps: Dependency[] = [
      { name: "react", version: "18.0.0" },
      { name: "lodash", version: "4.17.21" }
    ];

    const report = await checkLicenses(deps, config);
    expect(report.approved).toBe(2);
    expect(report.denied).toBe(0);
    expect(report.unknown).toBe(0);
    expect(report.licenses[0].status).toBe("approved");
  });

  it("should mark denied licenses", async () => {
    const config: LicenseConfig = {
      allowList: ["MIT"],
      denyList: ["GPL-2.0", "GPL-3.0"]
    };

    const deps: Dependency[] = [
      { name: "some-gpl-package", version: "1.0.0" }
    ];

    const report = await checkLicenses(deps, config);
    expect(report.denied).toBe(1);
    expect(report.licenses[0].status).toBe("denied");
  });

  it("should mark unknown licenses", async () => {
    const config: LicenseConfig = {
      allowList: ["MIT"],
      denyList: ["GPL-2.0"]
    };

    const deps: Dependency[] = [
      { name: "unknown-package", version: "1.0.0" }
    ];

    const report = await checkLicenses(deps, config);
    expect(report.unknown).toBe(1);
    expect(report.licenses[0].status).toBe("unknown");
    expect(report.licenses[0].license).toBeNull();
  });

  it("should generate correct compliance report totals", async () => {
    const config: LicenseConfig = {
      allowList: ["MIT", "Apache-2.0"],
      denyList: ["GPL-2.0", "GPL-3.0"]
    };

    const deps: Dependency[] = [
      { name: "react", version: "18.0.0" },           // MIT
      { name: "some-gpl-package", version: "1.0.0" }, // GPL-2.0 (denied)
      { name: "unknown-package", version: "1.0.0" }   // unknown
    ];

    const report = await checkLicenses(deps, config);
    expect(report.totalDependencies).toBe(3);
    expect(report.approved).toBe(1);
    expect(report.denied).toBe(1);
    expect(report.unknown).toBe(1);
  });

  it("should include package info in report", async () => {
    const config: LicenseConfig = {
      allowList: ["MIT"],
      denyList: []
    };

    const deps: Dependency[] = [
      { name: "react", version: "18.0.0" }
    ];

    const report = await checkLicenses(deps, config);
    const licenseInfo = report.licenses[0];
    expect(licenseInfo.name).toBe("react");
    expect(licenseInfo.version).toBe("18.0.0");
    expect(licenseInfo.license).toBe("MIT");
  });
});

// Test 4: Integration test - full workflow
describe("Integration: Full workflow", () => {
  beforeEach(() => {
    resetMockLicenses();
  });

  it("should process package.json and generate report", async () => {
    const packageJson = {
      dependencies: {
        "react": "^18.0.0",
        "lodash": "4.17.21"
      },
      devDependencies: {
        "typescript": "^5.0.0"
      }
    };

    const config: LicenseConfig = {
      allowList: ["MIT", "Apache-2.0"],
      denyList: ["GPL-2.0"]
    };

    const deps = parsePackageJson(packageJson);
    const report = await checkLicenses(deps, config);

    expect(report.totalDependencies).toBe(3);
    expect(report.approved).toBe(3);
    expect(report.licenses.length).toBe(3);
  });

  it("should generate report with correct timestamp format", async () => {
    const config: LicenseConfig = {
      allowList: ["MIT"],
      denyList: []
    };

    const deps: Dependency[] = [
      { name: "react", version: "18.0.0" }
    ];

    const report = await checkLicenses(deps, config);

    // ISO timestamp format
    expect(report.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/);
  });
});
