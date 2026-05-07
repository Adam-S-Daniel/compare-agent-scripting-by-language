// TDD tests for the semantic version bumper.
// Each test was written FIRST (red), then the implementation to pass (green).

import { describe, test, expect } from "bun:test";
import {
  parseVersion,
  formatVersion,
  parseCommit,
  parseCommitLog,
  determineBumpType,
  bumpVersion,
  generateChangelog,
  readVersionFromPackageJson,
  updatePackageJsonVersion,
} from "./version-bumper";
import type { SemanticVersion, CommitInfo } from "./version-bumper";

describe("parseVersion", () => {
  test("parses a valid semver string", () => {
    const result = parseVersion("1.2.3");
    expect(result).toEqual({ major: 1, minor: 2, patch: 3 });
  });

  test("parses version with v prefix", () => {
    const result = parseVersion("v2.0.1");
    expect(result).toEqual({ major: 2, minor: 0, patch: 1 });
  });

  test("handles whitespace", () => {
    const result = parseVersion("  3.4.5  ");
    expect(result).toEqual({ major: 3, minor: 4, patch: 5 });
  });

  test("throws on invalid version", () => {
    expect(() => parseVersion("not.a.version")).toThrow("Invalid semantic version");
  });

  test("throws on partial version", () => {
    expect(() => parseVersion("1.2")).toThrow("Invalid semantic version");
  });
});

describe("formatVersion", () => {
  test("formats version object to string", () => {
    expect(formatVersion({ major: 1, minor: 2, patch: 3 })).toBe("1.2.3");
  });

  test("formats zeroed version", () => {
    expect(formatVersion({ major: 0, minor: 0, patch: 0 })).toBe("0.0.0");
  });
});

describe("parseCommit", () => {
  test("parses feat commit", () => {
    const result = parseCommit("feat: add login page");
    expect(result.type).toBe("feat");
    expect(result.message).toBe("add login page");
    expect(result.breaking).toBe(false);
  });

  test("parses fix commit", () => {
    const result = parseCommit("fix: resolve null pointer");
    expect(result.type).toBe("fix");
    expect(result.message).toBe("resolve null pointer");
    expect(result.breaking).toBe(false);
  });

  test("parses breaking commit with bang", () => {
    const result = parseCommit("feat!: redesign API");
    expect(result.type).toBe("feat");
    expect(result.breaking).toBe(true);
  });

  test("parses scoped commit", () => {
    const result = parseCommit("fix(auth): handle expired tokens");
    expect(result.type).toBe("fix");
    expect(result.message).toBe("handle expired tokens");
  });

  test("parses BREAKING CHANGE line", () => {
    const result = parseCommit("BREAKING CHANGE: remove v1 API");
    expect(result.breaking).toBe(true);
  });

  test("handles empty line", () => {
    const result = parseCommit("");
    expect(result.type).toBe("other");
    expect(result.breaking).toBe(false);
  });

  test("handles non-conventional commit", () => {
    const result = parseCommit("random commit message");
    expect(result.type).toBe("other");
  });
});

describe("determineBumpType", () => {
  test("returns major for breaking changes", () => {
    const commits: CommitInfo[] = [
      { type: "feat", message: "new feature", breaking: true },
      { type: "fix", message: "a fix", breaking: false },
    ];
    expect(determineBumpType(commits)).toBe("major");
  });

  test("returns minor for feat commits", () => {
    const commits: CommitInfo[] = [
      { type: "feat", message: "new feature", breaking: false },
      { type: "fix", message: "a fix", breaking: false },
    ];
    expect(determineBumpType(commits)).toBe("minor");
  });

  test("returns patch for fix-only commits", () => {
    const commits: CommitInfo[] = [
      { type: "fix", message: "a fix", breaking: false },
      { type: "chore", message: "cleanup", breaking: false },
    ];
    expect(determineBumpType(commits)).toBe("patch");
  });

  test("returns none when no relevant commits", () => {
    const commits: CommitInfo[] = [
      { type: "docs", message: "update readme", breaking: false },
      { type: "chore", message: "cleanup", breaking: false },
    ];
    expect(determineBumpType(commits)).toBe("none");
  });
});

describe("bumpVersion", () => {
  const base: SemanticVersion = { major: 1, minor: 2, patch: 3 };

  test("major bump resets minor and patch", () => {
    expect(bumpVersion(base, "major")).toEqual({ major: 2, minor: 0, patch: 0 });
  });

  test("minor bump resets patch", () => {
    expect(bumpVersion(base, "minor")).toEqual({ major: 1, minor: 3, patch: 0 });
  });

  test("patch bump increments patch", () => {
    expect(bumpVersion(base, "patch")).toEqual({ major: 1, minor: 2, patch: 4 });
  });

  test("none returns same version", () => {
    expect(bumpVersion(base, "none")).toEqual({ major: 1, minor: 2, patch: 3 });
  });
});

describe("generateChangelog", () => {
  test("generates changelog with features section", () => {
    const version: SemanticVersion = { major: 1, minor: 3, patch: 0 };
    const commits: CommitInfo[] = [
      { type: "feat", message: "add search", breaking: false },
    ];
    const result = generateChangelog(version, commits, "2026-01-15");
    expect(result).toContain("## [1.3.0] - 2026-01-15");
    expect(result).toContain("### Features");
    expect(result).toContain("- add search");
  });

  test("groups commits by type", () => {
    const version: SemanticVersion = { major: 2, minor: 0, patch: 0 };
    const commits: CommitInfo[] = [
      { type: "feat", message: "new API", breaking: true },
      { type: "fix", message: "fix bug", breaking: false },
    ];
    const result = generateChangelog(version, commits, "2026-01-15");
    expect(result).toContain("### Breaking Changes");
    expect(result).toContain("### Bug Fixes");
  });
});

describe("parseCommitLog", () => {
  test("parses multi-line commit log", () => {
    const log = "feat: add feature\nfix: fix bug\n";
    const commits = parseCommitLog(log);
    expect(commits).toHaveLength(2);
    expect(commits[0].type).toBe("feat");
    expect(commits[1].type).toBe("fix");
  });

  test("skips empty lines", () => {
    const log = "feat: add feature\n\nfix: fix bug\n\n";
    const commits = parseCommitLog(log);
    expect(commits).toHaveLength(2);
  });
});

describe("readVersionFromPackageJson", () => {
  test("reads version from package.json content", () => {
    const content = JSON.stringify({ name: "test", version: "2.1.0" });
    expect(readVersionFromPackageJson(content)).toBe("2.1.0");
  });

  test("throws when version is missing", () => {
    const content = JSON.stringify({ name: "test" });
    expect(() => readVersionFromPackageJson(content)).toThrow("No version field");
  });
});

describe("updatePackageJsonVersion", () => {
  test("updates version in package.json content", () => {
    const content = JSON.stringify({ name: "test", version: "1.0.0" }, null, 2);
    const result = updatePackageJsonVersion(content, "1.1.0");
    const parsed = JSON.parse(result);
    expect(parsed.version).toBe("1.1.0");
    expect(parsed.name).toBe("test");
  });
});
