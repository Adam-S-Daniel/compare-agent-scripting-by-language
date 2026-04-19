import { describe, it, expect } from "bun:test";
import {
  parseDependencies,
  checkLicenseCompliance,
  DependencyManifest,
  ComplianceReport,
  parseRequirementsTxt,
  generateComplianceReport,
} from "./license-checker";

describe("License Checker", () => {
  describe("parseDependencies", () => {
    it("should parse package.json and extract dependencies", () => {
      const manifest: DependencyManifest = {
        type: "package.json",
        content: {
          dependencies: {
            express: "^4.18.0",
            "lodash-es": "^4.17.21",
          },
        },
      };

      const deps = parseDependencies(manifest);

      expect(deps).toEqual([
        { name: "express", version: "^4.18.0" },
        { name: "lodash-es", version: "^4.17.21" },
      ]);
    });

    it("should return empty array when no dependencies", () => {
      const manifest: DependencyManifest = {
        type: "package.json",
        content: { dependencies: {} },
      };

      const deps = parseDependencies(manifest);

      expect(deps).toEqual([]);
    });
  });

  describe("checkLicenseCompliance", () => {
    it("should report approved licenses", () => {
      const config = {
        allowlist: ["MIT", "Apache-2.0"],
        denylist: ["GPL-3.0"],
      };

      const licenses = new Map([
        ["express", "MIT"],
        ["lodash-es", "MIT"],
      ]);

      // Mock lookup function
      const mockLookup = (name: string) => licenses.get(name);

      const report = checkLicenseCompliance(
        [
          { name: "express", version: "^4.18.0" },
          { name: "lodash-es", version: "^4.17.21" },
        ],
        config,
        mockLookup
      );

      expect(report.dependencies).toHaveLength(2);
      expect(report.dependencies[0]).toMatchObject({
        name: "express",
        license: "MIT",
        status: "approved",
      });
      expect(report.summary.approved).toBe(2);
      expect(report.summary.denied).toBe(0);
      expect(report.summary.unknown).toBe(0);
    });

    it("should report denied licenses", () => {
      const config = {
        allowlist: ["MIT"],
        denylist: ["GPL-3.0"],
      };

      const licenses = new Map([
        ["bad-lib", "GPL-3.0"],
      ]);

      const mockLookup = (name: string) => licenses.get(name);

      const report = checkLicenseCompliance(
        [{ name: "bad-lib", version: "1.0.0" }],
        config,
        mockLookup
      );

      expect(report.dependencies[0]).toMatchObject({
        name: "bad-lib",
        license: "GPL-3.0",
        status: "denied",
      });
      expect(report.summary.denied).toBe(1);
    });

    it("should report unknown licenses", () => {
      const config = {
        allowlist: ["MIT"],
        denylist: [],
      };

      const mockLookup = (name: string) => undefined;

      const report = checkLicenseCompliance(
        [{ name: "unknown-lib", version: "1.0.0" }],
        config,
        mockLookup
      );

      expect(report.dependencies[0]).toMatchObject({
        name: "unknown-lib",
        license: undefined,
        status: "unknown",
      });
      expect(report.summary.unknown).toBe(1);
    });
  });

  describe("parseRequirementsTxt", () => {
    it("should parse requirements.txt content", () => {
      const content = `requests==2.28.0
numpy>=1.20.0
pandas~=1.3.0`;

      const deps = parseRequirementsTxt(content);

      expect(deps).toHaveLength(3);
      expect(deps[0]).toMatchObject({ name: "requests", version: "2.28.0" });
      expect(deps[1]).toMatchObject({ name: "numpy", version: "1.20.0" });
      expect(deps[2]).toMatchObject({ name: "pandas", version: "1.3.0" });
    });

    it("should ignore comments and empty lines", () => {
      const content = `# This is a comment
requests==2.28.0
# Another comment
numpy>=1.20.0

pandas~=1.3.0`;

      const deps = parseRequirementsTxt(content);

      expect(deps).toHaveLength(3);
    });

    it("should handle lines without version specifiers", () => {
      const content = `requests
numpy>=1.20.0`;

      const deps = parseRequirementsTxt(content);

      expect(deps).toHaveLength(2);
      expect(deps[0]).toMatchObject({ name: "requests", version: "" });
    });
  });

  describe("generateComplianceReport", () => {
    it("should generate a text report with all dependency details", () => {
      const config = {
        allowlist: ["MIT", "Apache-2.0"],
        denylist: ["GPL-3.0"],
      };

      const licenses = new Map([
        ["express", "MIT"],
        ["lodash-es", "Apache-2.0"],
        ["bad-lib", "GPL-3.0"],
      ]);

      const mockLookup = (name: string) => licenses.get(name);

      const report = checkLicenseCompliance(
        [
          { name: "express", version: "4.18.0" },
          { name: "lodash-es", version: "4.17.21" },
          { name: "bad-lib", version: "1.0.0" },
        ],
        config,
        mockLookup
      );

      const text = generateComplianceReport(report);

      expect(text).toContain("express");
      expect(text).toContain("MIT");
      expect(text).toContain("approved");
      expect(text).toContain("bad-lib");
      expect(text).toContain("denied");
      expect(text).toContain("Summary: 2 approved");
    });
  });
});
