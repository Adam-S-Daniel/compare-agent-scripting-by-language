/**
 * Semantic Version Bumper - Test Suite (TDD: Red Phase First)
 *
 * Tests follow TDD methodology:
 * 1. Write failing test (RED)
 * 2. Implement minimum code to pass (GREEN)
 * 3. Refactor
 *
 * Test fixtures use mock commit logs for deterministic testing.
 */

import { describe, it, expect } from "bun:test";
import {
  parseVersion,
  bumpVersion,
  determineVersionBump,
  BumpType,
  type SemanticVersion,
} from "./semver";
import { parseCommits, generateChangelog, type Commit } from "./changelog";

// ============================================================
// SECTION 1: Version Parsing
// ============================================================

describe("parseVersion", () => {
  it("parses a standard semver string", () => {
    const result = parseVersion("1.2.3");
    expect(result).toEqual({ major: 1, minor: 2, patch: 3 });
  });

  it("parses version with v prefix", () => {
    const result = parseVersion("v2.0.0");
    expect(result).toEqual({ major: 2, minor: 0, patch: 0 });
  });

  it("parses version 0.0.1", () => {
    const result = parseVersion("0.0.1");
    expect(result).toEqual({ major: 0, minor: 0, patch: 1 });
  });

  it("throws on invalid version string", () => {
    expect(() => parseVersion("not-a-version")).toThrow(
      "Invalid semantic version: not-a-version"
    );
  });

  it("throws on empty string", () => {
    expect(() => parseVersion("")).toThrow("Invalid semantic version: ");
  });
});

// ============================================================
// SECTION 2: Version Bumping
// ============================================================

describe("bumpVersion", () => {
  it("bumps patch version", () => {
    const v: SemanticVersion = { major: 1, minor: 2, patch: 3 };
    expect(bumpVersion(v, BumpType.PATCH)).toBe("1.2.4");
  });

  it("bumps minor version and resets patch", () => {
    const v: SemanticVersion = { major: 1, minor: 2, patch: 3 };
    expect(bumpVersion(v, BumpType.MINOR)).toBe("1.3.0");
  });

  it("bumps major version and resets minor and patch", () => {
    const v: SemanticVersion = { major: 1, minor: 2, patch: 3 };
    expect(bumpVersion(v, BumpType.MAJOR)).toBe("2.0.0");
  });

  it("bumps from 0.0.1 to 0.0.2 (patch)", () => {
    const v: SemanticVersion = { major: 0, minor: 0, patch: 1 };
    expect(bumpVersion(v, BumpType.PATCH)).toBe("0.0.2");
  });

  it("bumps from 1.9.9 to 2.0.0 (major)", () => {
    const v: SemanticVersion = { major: 1, minor: 9, patch: 9 };
    expect(bumpVersion(v, BumpType.MAJOR)).toBe("2.0.0");
  });
});

// ============================================================
// SECTION 3: Commit Analysis - Bump Type Determination
// ============================================================

describe("determineVersionBump", () => {
  // FIXTURE: Mock commit logs for patch bump
  const patchCommits: Commit[] = [
    { type: "fix", scope: null, description: "fix login redirect bug", breaking: false, raw: "fix: fix login redirect bug" },
    { type: "fix", scope: "auth", description: "resolve token expiry issue", breaking: false, raw: "fix(auth): resolve token expiry issue" },
  ];

  // FIXTURE: Mock commit logs for minor bump
  const minorCommits: Commit[] = [
    { type: "feat", scope: null, description: "add dark mode support", breaking: false, raw: "feat: add dark mode support" },
    { type: "fix", scope: null, description: "fix typo in readme", breaking: false, raw: "fix: fix typo in readme" },
  ];

  // FIXTURE: Mock commit logs for major bump (breaking via ! syntax)
  const majorCommitsExclamation: Commit[] = [
    { type: "feat", scope: null, description: "redesign API endpoints", breaking: true, raw: "feat!: redesign API endpoints" },
    { type: "fix", scope: null, description: "fix old bug", breaking: false, raw: "fix: fix old bug" },
  ];

  // FIXTURE: Mock commit logs for major bump (breaking via BREAKING CHANGE footer)
  const majorCommitsFooter: Commit[] = [
    { type: "feat", scope: null, description: "change auth flow", breaking: true, raw: "feat: change auth flow\n\nBREAKING CHANGE: old tokens no longer valid" },
  ];

  // FIXTURE: Non-bumping commits (chore, docs, style, etc.)
  const nonBumpingCommits: Commit[] = [
    { type: "chore", scope: null, description: "update dependencies", breaking: false, raw: "chore: update dependencies" },
    { type: "docs", scope: null, description: "update README", breaking: false, raw: "docs: update README" },
    { type: "style", scope: null, description: "fix formatting", breaking: false, raw: "style: fix formatting" },
  ];

  it("returns PATCH for fix commits", () => {
    expect(determineVersionBump(patchCommits)).toBe(BumpType.PATCH);
  });

  it("returns MINOR for feat commits (even with fixes)", () => {
    expect(determineVersionBump(minorCommits)).toBe(BumpType.MINOR);
  });

  it("returns MAJOR for breaking change (! syntax)", () => {
    expect(determineVersionBump(majorCommitsExclamation)).toBe(BumpType.MAJOR);
  });

  it("returns MAJOR for breaking change (BREAKING CHANGE footer)", () => {
    expect(determineVersionBump(majorCommitsFooter)).toBe(BumpType.MAJOR);
  });

  it("returns PATCH for non-bumping commits (defaults to patch)", () => {
    expect(determineVersionBump(nonBumpingCommits)).toBe(BumpType.PATCH);
  });

  it("returns PATCH for empty commit list", () => {
    expect(determineVersionBump([])).toBe(BumpType.PATCH);
  });
});

// ============================================================
// SECTION 4: Commit Parsing
// ============================================================

describe("parseCommits", () => {
  it("parses a simple fix commit", () => {
    const commits = parseCommits(["fix: correct off-by-one error"]);
    expect(commits).toHaveLength(1);
    expect(commits[0]).toMatchObject({
      type: "fix",
      scope: null,
      description: "correct off-by-one error",
      breaking: false,
    });
  });

  it("parses a feat commit with scope", () => {
    const commits = parseCommits(["feat(api): add user endpoint"]);
    expect(commits).toHaveLength(1);
    expect(commits[0]).toMatchObject({
      type: "feat",
      scope: "api",
      description: "add user endpoint",
      breaking: false,
    });
  });

  it("parses a breaking change commit with ! syntax", () => {
    const commits = parseCommits(["feat!: remove deprecated API"]);
    expect(commits[0]).toMatchObject({
      type: "feat",
      breaking: true,
    });
  });

  it("parses a breaking change with BREAKING CHANGE footer", () => {
    const commits = parseCommits([
      "feat: new auth\n\nBREAKING CHANGE: old tokens invalid",
    ]);
    expect(commits[0]).toMatchObject({
      type: "feat",
      breaking: true,
    });
  });

  it("parses multiple commits", () => {
    const raw = [
      "fix: bug fix one",
      "feat: add feature",
      "chore: update deps",
    ];
    const commits = parseCommits(raw);
    expect(commits).toHaveLength(3);
    expect(commits[0].type).toBe("fix");
    expect(commits[1].type).toBe("feat");
    expect(commits[2].type).toBe("chore");
  });

  it("skips malformed commits", () => {
    const commits = parseCommits(["this is not a conventional commit", "fix: valid one"]);
    // malformed commits get type 'unknown'
    expect(commits.find(c => c.type === "fix")).toBeTruthy();
  });
});

// ============================================================
// SECTION 5: Changelog Generation
// ============================================================

describe("generateChangelog", () => {
  const commits: Commit[] = [
    { type: "feat", scope: "ui", description: "add dark mode", breaking: false, raw: "feat(ui): add dark mode" },
    { type: "fix", scope: null, description: "fix memory leak", breaking: false, raw: "fix: fix memory leak" },
    { type: "fix", scope: "api", description: "handle null response", breaking: false, raw: "fix(api): handle null response" },
    { type: "chore", scope: null, description: "update deps", breaking: false, raw: "chore: update deps" },
    { type: "feat", scope: null, description: "redesign auth", breaking: true, raw: "feat!: redesign auth" },
  ];

  it("generates changelog with version header", () => {
    const changelog = generateChangelog("2.0.0", commits, "2026-04-08");
    expect(changelog).toContain("## [2.0.0]");
    expect(changelog).toContain("2026-04-08");
  });

  it("groups features under ### Features", () => {
    const changelog = generateChangelog("2.0.0", commits, "2026-04-08");
    expect(changelog).toContain("### Features");
    expect(changelog).toContain("add dark mode");
    expect(changelog).toContain("redesign auth");
  });

  it("groups fixes under ### Bug Fixes", () => {
    const changelog = generateChangelog("2.0.0", commits, "2026-04-08");
    expect(changelog).toContain("### Bug Fixes");
    expect(changelog).toContain("fix memory leak");
    expect(changelog).toContain("handle null response");
  });

  it("includes BREAKING CHANGE section for breaking commits", () => {
    const changelog = generateChangelog("2.0.0", commits, "2026-04-08");
    expect(changelog).toContain("BREAKING CHANGE");
    expect(changelog).toContain("redesign auth");
  });

  it("includes scope in parentheses when present", () => {
    const changelog = generateChangelog("2.0.0", commits, "2026-04-08");
    expect(changelog).toContain("**(ui)**");
    expect(changelog).toContain("**(api)**");
  });
});
