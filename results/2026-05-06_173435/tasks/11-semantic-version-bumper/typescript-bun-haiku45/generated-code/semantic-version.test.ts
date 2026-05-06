import { describe, it, expect, beforeAll, afterAll } from "bun:test";
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from "fs";
import { join } from "path";
import { parseVersion, bumpVersion, readVersionFile, writeVersionFile } from "./semantic-version";

describe("Semantic Version Bumper", () => {
  let tempDir: string;

  beforeAll(() => {
    tempDir = mkdtempSync(join("/tmp", "semver-test-"));
  });

  afterAll(() => {
    rmSync(tempDir, { recursive: true, force: true });
  });

  describe("parseVersion", () => {
    it("should parse a valid semver string", () => {
      const version = parseVersion("1.2.3");
      expect(version).toEqual({ major: 1, minor: 2, patch: 3 });
    });

    it("should parse version with leading v", () => {
      const version = parseVersion("v2.0.0");
      expect(version).toEqual({ major: 2, minor: 0, patch: 0 });
    });

    it("should throw on invalid semver", () => {
      expect(() => parseVersion("not-a-version")).toThrow();
    });
  });

  describe("bumpVersion", () => {
    it("should bump major version on breaking change", () => {
      const version = parseVersion("1.2.3");
      const bumped = bumpVersion(version, "major");
      expect(bumped).toEqual({ major: 2, minor: 0, patch: 0 });
    });

    it("should bump minor version on feat", () => {
      const version = parseVersion("1.2.3");
      const bumped = bumpVersion(version, "minor");
      expect(bumped).toEqual({ major: 1, minor: 3, patch: 0 });
    });

    it("should bump patch version on fix", () => {
      const version = parseVersion("1.2.3");
      const bumped = bumpVersion(version, "patch");
      expect(bumped).toEqual({ major: 1, minor: 2, patch: 4 });
    });
  });

  describe("readVersionFile", () => {
    it("should read version from package.json", () => {
      const pkgPath = join(tempDir, "package.json");
      writeFileSync(pkgPath, JSON.stringify({ version: "1.0.0" }));
      const version = readVersionFile(pkgPath);
      expect(version).toBe("1.0.0");
    });

    it("should read version from VERSION file", () => {
      const versionPath = join(tempDir, "VERSION");
      writeFileSync(versionPath, "2.5.1\n");
      const version = readVersionFile(versionPath);
      expect(version).toBe("2.5.1");
    });

    it("should throw if file not found", () => {
      expect(() => readVersionFile(join(tempDir, "nonexistent.json"))).toThrow();
    });
  });

  describe("writeVersionFile", () => {
    it("should write version to package.json", () => {
      const pkgPath = join(tempDir, "package-write.json");
      writeFileSync(pkgPath, JSON.stringify({ version: "1.0.0", name: "test" }));
      writeVersionFile(pkgPath, "2.0.0");
      const content = JSON.parse(readFileSync(pkgPath, "utf-8"));
      expect(content.version).toBe("2.0.0");
      expect(content.name).toBe("test");
    });

    it("should write version to VERSION file", () => {
      const versionPath = join(tempDir, "VERSION-write");
      writeFileSync(versionPath, "1.0.0");
      writeVersionFile(versionPath, "1.5.0");
      const content = readFileSync(versionPath, "utf-8").trim();
      expect(content).toBe("1.5.0");
    });
  });
});
