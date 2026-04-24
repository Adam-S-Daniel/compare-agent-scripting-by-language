// TDD tests for semantic version bumper
// Red/green cycle: write failing test -> implement -> pass -> repeat

import { describe, test, expect } from "bun:test";
import {
  parseVersion,
  determineBumpType,
  bumpVersion,
  parseConventionalCommit,
  generateChangelog,
  readVersionFromPackageJson,
} from "./version-bumper";

// --- parseVersion ---
describe("parseVersion", () => {
  test("parses a standard semver string", () => {
    expect(parseVersion("1.2.3")).toEqual({ major: 1, minor: 2, patch: 3 });
  });

  test("parses 0.0.0", () => {
    expect(parseVersion("0.0.0")).toEqual({ major: 0, minor: 0, patch: 0 });
  });

  test("throws on invalid version string", () => {
    expect(() => parseVersion("not-a-version")).toThrow(
      "Invalid semantic version"
    );
  });

  test("throws on missing patch component", () => {
    expect(() => parseVersion("1.2")).toThrow("Invalid semantic version");
  });
});

// --- parseConventionalCommit ---
describe("parseConventionalCommit", () => {
  test("identifies a fix commit", () => {
    const commit = parseConventionalCommit("fix: resolve null pointer in auth");
    expect(commit.type).toBe("fix");
    expect(commit.breaking).toBe(false);
    expect(commit.message).toBe("resolve null pointer in auth");
  });

  test("identifies a feat commit", () => {
    const commit = parseConventionalCommit("feat: add user profile endpoint");
    expect(commit.type).toBe("feat");
    expect(commit.breaking).toBe(false);
  });

  test("identifies a breaking change via BREAKING CHANGE footer", () => {
    const commit = parseConventionalCommit(
      "feat: redesign API\n\nBREAKING CHANGE: endpoints renamed"
    );
    expect(commit.breaking).toBe(true);
  });

  test("identifies a breaking change via ! suffix", () => {
    const commit = parseConventionalCommit("feat!: drop support for v1 API");
    expect(commit.breaking).toBe(true);
    expect(commit.type).toBe("feat");
  });

  test("handles chore and other types", () => {
    const commit = parseConventionalCommit("chore: update dependencies");
    expect(commit.type).toBe("chore");
    expect(commit.breaking).toBe(false);
  });

  test("handles non-conventional commit message", () => {
    const commit = parseConventionalCommit("Update readme");
    expect(commit.type).toBe("unknown");
    expect(commit.breaking).toBe(false);
    expect(commit.message).toBe("Update readme");
  });
});

// --- determineBumpType ---
describe("determineBumpType", () => {
  test("returns patch for fix commits only", () => {
    const commits = [
      { type: "fix", message: "fix bug", breaking: false },
      { type: "chore", message: "cleanup", breaking: false },
    ];
    expect(determineBumpType(commits)).toBe("patch");
  });

  test("returns minor for feat commits", () => {
    const commits = [
      { type: "fix", message: "fix bug", breaking: false },
      { type: "feat", message: "add feature", breaking: false },
    ];
    expect(determineBumpType(commits)).toBe("minor");
  });

  test("returns major for breaking change", () => {
    const commits = [
      { type: "feat", message: "redesign", breaking: true },
      { type: "fix", message: "fix something", breaking: false },
    ];
    expect(determineBumpType(commits)).toBe("major");
  });

  test("returns major even when only one breaking commit", () => {
    const commits = [{ type: "fix", message: "fix", breaking: true }];
    expect(determineBumpType(commits)).toBe("major");
  });

  test("returns none for commits with no version impact", () => {
    const commits = [
      { type: "chore", message: "deps", breaking: false },
      { type: "docs", message: "readme", breaking: false },
    ];
    expect(determineBumpType(commits)).toBe("none");
  });

  test("returns none for empty commit list", () => {
    expect(determineBumpType([])).toBe("none");
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

  test("bumps major version and resets minor and patch", () => {
    expect(bumpVersion("1.2.3", "major")).toBe("2.0.0");
  });

  test("returns same version when bumpType is none", () => {
    expect(bumpVersion("1.2.3", "none")).toBe("1.2.3");
  });

  test("bumps from 0.0.0 patch", () => {
    expect(bumpVersion("0.0.0", "patch")).toBe("0.0.1");
  });
});

// --- generateChangelog ---
describe("generateChangelog", () => {
  test("generates a changelog entry with version and date", () => {
    const commits = [
      { type: "feat", message: "add login page", breaking: false },
      { type: "fix", message: "fix logout bug", breaking: false },
    ];
    const entry = generateChangelog("1.1.0", commits, "2026-04-19");
    expect(entry).toContain("## [1.1.0] - 2026-04-19");
    expect(entry).toContain("add login page");
    expect(entry).toContain("fix logout bug");
  });

  test("groups commits by type (feat under Features, fix under Bug Fixes)", () => {
    const commits = [
      { type: "feat", message: "new feature", breaking: false },
      { type: "fix", message: "fixed something", breaking: false },
    ];
    const entry = generateChangelog("1.0.0", commits, "2026-04-19");
    expect(entry).toContain("### Features");
    expect(entry).toContain("### Bug Fixes");
  });

  test("marks breaking changes in changelog", () => {
    const commits = [{ type: "feat", message: "api redesign", breaking: true }];
    const entry = generateChangelog("2.0.0", commits, "2026-04-19");
    expect(entry).toContain("BREAKING");
  });

  test("handles empty commits gracefully", () => {
    const entry = generateChangelog("1.0.0", [], "2026-04-19");
    expect(entry).toContain("## [1.0.0] - 2026-04-19");
  });
});

// --- readVersionFromPackageJson ---
describe("readVersionFromPackageJson", () => {
  test("reads version field from package.json content", () => {
    const pkgJson = JSON.stringify({ name: "my-app", version: "3.4.5" });
    expect(readVersionFromPackageJson(pkgJson)).toBe("3.4.5");
  });

  test("throws when version field is missing", () => {
    const pkgJson = JSON.stringify({ name: "my-app" });
    expect(() => readVersionFromPackageJson(pkgJson)).toThrow(
      "No version field"
    );
  });

  test("throws on invalid JSON", () => {
    expect(() => readVersionFromPackageJson("not json")).toThrow();
  });
});
