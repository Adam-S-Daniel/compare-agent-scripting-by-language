// TDD tests for semantic version bumper - RED phase written before implementation

import { test, expect, describe, beforeEach, afterEach } from "bun:test";
import { parseVersion, bumpVersion, parseCommits, generateChangelog, determineVersionBump } from "./version-bumper";
import {
  patchCommits,
  minorCommits,
  majorCommits,
  breakingFooterCommits,
  noReleaseCommits,
  rawGitLogPatch,
  rawGitLogMinor,
  rawGitLogMajor,
  rawGitLogNone,
} from "./fixtures";
import { join } from "path";
import { mkdirSync, rmSync, writeFileSync, readFileSync } from "fs";
import type { Commit } from "./types";

// --- parseVersion ---

describe("parseVersion", () => {
  test("parses version from package.json content", () => {
    const content = JSON.stringify({ name: "my-app", version: "1.2.3" });
    expect(parseVersion(content, "package.json")).toBe("1.2.3");
  });

  test("parses version from version.txt content", () => {
    expect(parseVersion("2.0.0", "version.txt")).toBe("2.0.0");
  });

  test("parses version.txt with trailing newline", () => {
    expect(parseVersion("1.5.0\n", "version.txt")).toBe("1.5.0");
  });

  test("throws on missing version in package.json", () => {
    expect(() => parseVersion("{}", "package.json")).toThrow();
  });

  test("throws on invalid semver", () => {
    expect(() => parseVersion("not-a-version", "version.txt")).toThrow();
  });
});

// --- parseCommits ---

describe("parseCommits", () => {
  test("parses fix commits as patch type", () => {
    const commits = parseCommits(rawGitLogPatch);
    expect(commits).toHaveLength(2);
    expect(commits[0].type).toBe("fix");
    expect(commits[0].breaking).toBe(false);
  });

  test("parses feat commits as minor type", () => {
    const commits = parseCommits(rawGitLogMinor);
    expect(commits.some((c) => c.type === "feat")).toBe(true);
  });

  test("parses feat! as breaking change", () => {
    const commits = parseCommits(rawGitLogMajor);
    const breakingCommit = commits.find((c) => c.hash === "ghi1234");
    expect(breakingCommit?.breaking).toBe(true);
  });

  test("parses chore/docs commits as non-release types", () => {
    const commits = parseCommits(rawGitLogNone);
    commits.forEach((c) => {
      expect(c.type).not.toBe("feat");
      expect(c.type).not.toBe("fix");
    });
  });

  test("returns empty array for empty log", () => {
    expect(parseCommits("")).toHaveLength(0);
  });

  test("extracts commit hash correctly", () => {
    const commits = parseCommits(rawGitLogPatch);
    expect(commits[0].hash).toBe("abc1234");
  });
});

// --- determineVersionBump ---

describe("determineVersionBump", () => {
  test("returns 'patch' for fix-only commits", () => {
    expect(determineVersionBump(patchCommits)).toBe("patch");
  });

  test("returns 'minor' for feat commits without breaking changes", () => {
    expect(determineVersionBump(minorCommits)).toBe("minor");
  });

  test("returns 'major' for breaking change commits (feat!)", () => {
    expect(determineVersionBump(majorCommits)).toBe("major");
  });

  test("returns 'major' for BREAKING CHANGE footer commits", () => {
    expect(determineVersionBump(breakingFooterCommits)).toBe("major");
  });

  test("returns 'none' for chore/docs-only commits", () => {
    expect(determineVersionBump(noReleaseCommits)).toBe("none");
  });

  test("returns 'none' for empty commit list", () => {
    expect(determineVersionBump([])).toBe("none");
  });
});

// --- bumpVersion ---

describe("bumpVersion", () => {
  test("bumps patch version", () => {
    expect(bumpVersion("1.2.3", "patch")).toBe("1.2.4");
  });

  test("bumps minor version and resets patch", () => {
    expect(bumpVersion("1.2.3", "minor")).toBe("1.3.0");
  });

  test("bumps major version and resets minor+patch", () => {
    expect(bumpVersion("1.2.3", "major")).toBe("2.0.0");
  });

  test("returns same version for 'none'", () => {
    expect(bumpVersion("1.2.3", "none")).toBe("1.2.3");
  });

  test("handles 0.x.y minor bump correctly", () => {
    expect(bumpVersion("0.1.0", "minor")).toBe("0.2.0");
  });

  test("handles 1.0.0 patch bump", () => {
    expect(bumpVersion("1.0.0", "patch")).toBe("1.0.1");
  });
});

// --- generateChangelog ---

describe("generateChangelog", () => {
  test("includes new version header", () => {
    const log = generateChangelog("1.2.3", "1.3.0", minorCommits);
    expect(log).toContain("1.3.0");
  });

  test("lists features section when feat commits present", () => {
    const log = generateChangelog("1.2.3", "1.3.0", minorCommits);
    expect(log).toContain("Features");
  });

  test("lists bug fixes section when fix commits present", () => {
    const log = generateChangelog("1.2.3", "1.2.4", patchCommits);
    expect(log).toContain("Bug Fixes");
  });

  test("lists breaking changes section for breaking commits", () => {
    const log = generateChangelog("1.2.3", "2.0.0", majorCommits);
    expect(log).toContain("Breaking Changes");
  });

  test("includes commit messages in output", () => {
    const log = generateChangelog("1.2.3", "1.2.4", patchCommits);
    expect(log).toContain("resolve null pointer");
  });

  test("includes date in changelog header", () => {
    const log = generateChangelog("1.2.3", "1.3.0", minorCommits);
    // Should contain a date pattern YYYY-MM-DD
    expect(log).toMatch(/\d{4}-\d{2}-\d{2}/);
  });
});

// --- integration: full bump flow with temp files ---

describe("integration: version file update", () => {
  const tmpDir = join(import.meta.dir, "../tmp-test");

  beforeEach(() => {
    mkdirSync(tmpDir, { recursive: true });
  });

  afterEach(() => {
    rmSync(tmpDir, { recursive: true, force: true });
  });

  test("updates package.json version for minor bump", async () => {
    const pkgPath = join(tmpDir, "package.json");
    writeFileSync(pkgPath, JSON.stringify({ name: "test-app", version: "1.2.3" }));

    const { bumpVersionFile } = await import("./version-bumper");
    const result = bumpVersionFile(pkgPath, "package.json", minorCommits);

    expect(result.newVersion).toBe("1.3.0");
    expect(result.previousVersion).toBe("1.2.3");
    expect(result.bumpType).toBe("minor");

    const updated = JSON.parse(readFileSync(pkgPath, "utf8"));
    expect(updated.version).toBe("1.3.0");
  });

  test("updates version.txt for patch bump", async () => {
    const versionPath = join(tmpDir, "version.txt");
    writeFileSync(versionPath, "2.0.0\n");

    const { bumpVersionFile } = await import("./version-bumper");
    const result = bumpVersionFile(versionPath, "version.txt", patchCommits);

    expect(result.newVersion).toBe("2.0.1");
    const updated = readFileSync(versionPath, "utf8").trim();
    expect(updated).toBe("2.0.1");
  });

  test("does not update file when no release commits", async () => {
    const versionPath = join(tmpDir, "version.txt");
    writeFileSync(versionPath, "1.0.0\n");

    const { bumpVersionFile } = await import("./version-bumper");
    const result = bumpVersionFile(versionPath, "version.txt", noReleaseCommits);

    expect(result.bumpType).toBe("none");
    expect(result.newVersion).toBe("1.0.0");
    const unchanged = readFileSync(versionPath, "utf8").trim();
    expect(unchanged).toBe("1.0.0");
  });
});
