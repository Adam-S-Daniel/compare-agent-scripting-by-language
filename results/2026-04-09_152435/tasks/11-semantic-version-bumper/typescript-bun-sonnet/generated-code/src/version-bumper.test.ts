/**
 * TDD Tests for Semantic Version Bumper
 *
 * Red/Green approach:
 * 1. Write failing test
 * 2. Write minimum code to pass
 * 3. Refactor
 * 4. Repeat
 *
 * Test coverage:
 * - parseVersion: parse "X.Y.Z" string into SemanticVersion object
 * - formatVersion: convert SemanticVersion back to string
 * - determineBumpType: analyze conventional commits to find bump type
 * - bumpVersion: apply the bump to a version
 * - generateChangelog: produce markdown changelog from commits
 * - Workflow structure: YAML has expected triggers/jobs/steps, paths exist, actionlint passes
 */

import { test, expect, describe } from "bun:test";
import * as fs from "fs";
import * as path from "path";
import {
  parseVersion,
  formatVersion,
  determineBumpType,
  bumpVersion,
  generateChangelog,
} from "./version-bumper";
import type { Commit, SemanticVersion } from "./version-bumper";

// ─── parseVersion ─────────────────────────────────────────────────────────────

describe("parseVersion", () => {
  test("parses standard version string", () => {
    expect(parseVersion("1.2.3")).toEqual({ major: 1, minor: 2, patch: 3 });
  });

  test("parses 0.0.0", () => {
    expect(parseVersion("0.0.0")).toEqual({ major: 0, minor: 0, patch: 0 });
  });

  test("parses large numbers", () => {
    expect(parseVersion("10.20.30")).toEqual({ major: 10, minor: 20, patch: 30 });
  });

  test("throws on invalid version", () => {
    expect(() => parseVersion("not-a-version")).toThrow("Invalid version string");
  });

  test("throws on partial version", () => {
    expect(() => parseVersion("1.2")).toThrow("Invalid version string");
  });
});

// ─── formatVersion ────────────────────────────────────────────────────────────

describe("formatVersion", () => {
  test("formats version to string", () => {
    expect(formatVersion({ major: 1, minor: 2, patch: 3 })).toBe("1.2.3");
  });

  test("formats zero version", () => {
    expect(formatVersion({ major: 0, minor: 0, patch: 0 })).toBe("0.0.0");
  });
});

// ─── determineBumpType ────────────────────────────────────────────────────────

describe("determineBumpType", () => {
  // Fixture: single fix commit → patch
  const fixCommit: Commit = {
    hash: "abc1234",
    message: "fix: correct button color",
    author: "Alice",
    date: "2024-01-01",
  };

  // Fixture: single feat commit → minor
  const featCommit: Commit = {
    hash: "def5678",
    message: "feat: add dark mode",
    author: "Bob",
    date: "2024-01-02",
  };

  // Fixture: breaking change with "!" syntax → major
  const breakingBangCommit: Commit = {
    hash: "ghi9012",
    message: "feat!: redesign public API",
    author: "Carol",
    date: "2024-01-03",
  };

  // Fixture: breaking change with "BREAKING CHANGE:" footer → major
  const breakingFooterCommit: Commit = {
    hash: "jkl3456",
    message: "refactor: rename all endpoints\n\nBREAKING CHANGE: all URLs changed",
    author: "Dave",
    date: "2024-01-04",
  };

  test("fix commits trigger patch bump", () => {
    expect(determineBumpType([fixCommit])).toBe("patch");
  });

  test("feat commits trigger minor bump", () => {
    expect(determineBumpType([featCommit])).toBe("minor");
  });

  test("breaking change (!) triggers major bump", () => {
    expect(determineBumpType([breakingBangCommit])).toBe("major");
  });

  test("BREAKING CHANGE footer triggers major bump", () => {
    expect(determineBumpType([breakingFooterCommit])).toBe("major");
  });

  test("no recognized commits returns none", () => {
    const chore: Commit = { hash: "aaa", message: "chore: update deps", author: "E", date: "2024-01-05" };
    expect(determineBumpType([chore])).toBe("none");
  });

  test("empty commit list returns none", () => {
    expect(determineBumpType([])).toBe("none");
  });

  // Priority: major > minor > patch
  test("feat beats fix in mixed commits", () => {
    expect(determineBumpType([fixCommit, featCommit])).toBe("minor");
  });

  test("breaking beats feat in mixed commits", () => {
    expect(determineBumpType([featCommit, breakingBangCommit])).toBe("major");
  });

  test("breaking beats feat and fix", () => {
    expect(determineBumpType([fixCommit, featCommit, breakingBangCommit])).toBe("major");
  });

  test("feat with scope triggers minor", () => {
    const featScoped: Commit = { hash: "bbb", message: "feat(ui): add tooltip", author: "F", date: "2024-01-06" };
    expect(determineBumpType([featScoped])).toBe("minor");
  });

  test("fix with scope triggers patch", () => {
    const fixScoped: Commit = { hash: "ccc", message: "fix(api): handle null response", author: "G", date: "2024-01-07" };
    expect(determineBumpType([fixScoped])).toBe("patch");
  });
});

// ─── bumpVersion ──────────────────────────────────────────────────────────────

describe("bumpVersion", () => {
  const base: SemanticVersion = { major: 1, minor: 2, patch: 3 };

  test("patch bump increments patch", () => {
    expect(bumpVersion(base, "patch")).toEqual({ major: 1, minor: 2, patch: 4 });
  });

  test("minor bump increments minor and resets patch", () => {
    expect(bumpVersion(base, "minor")).toEqual({ major: 1, minor: 3, patch: 0 });
  });

  test("major bump increments major and resets minor+patch", () => {
    expect(bumpVersion(base, "major")).toEqual({ major: 2, minor: 0, patch: 0 });
  });

  test("none bump leaves version unchanged", () => {
    expect(bumpVersion(base, "none")).toEqual({ major: 1, minor: 2, patch: 3 });
  });
});

// ─── generateChangelog ────────────────────────────────────────────────────────

describe("generateChangelog", () => {
  const commits: Commit[] = [
    { hash: "aaaaaaa1", message: "feat: add dark mode", author: "Alice", date: "2024-01-01" },
    { hash: "bbbbbbb2", message: "fix: correct button color", author: "Bob", date: "2024-01-02" },
    { hash: "ccccccc3", message: "feat!: redesign API", author: "Carol", date: "2024-01-03" },
  ];

  test("changelog contains new version header", () => {
    const cl = generateChangelog(commits, "2.0.0");
    expect(cl).toContain("## [2.0.0]");
  });

  test("changelog has breaking changes section", () => {
    const cl = generateChangelog(commits, "2.0.0");
    expect(cl).toContain("### Breaking Changes");
    expect(cl).toContain("feat!: redesign API");
  });

  test("changelog has features section", () => {
    const cl = generateChangelog(commits, "2.0.0");
    expect(cl).toContain("### Features");
    expect(cl).toContain("feat: add dark mode");
  });

  test("changelog has bug fixes section", () => {
    const cl = generateChangelog(commits, "2.0.0");
    expect(cl).toContain("### Bug Fixes");
    expect(cl).toContain("fix: correct button color");
  });

  test("changelog includes short commit hashes", () => {
    const cl = generateChangelog(commits, "2.0.0");
    expect(cl).toContain("aaaaaaa"); // 7-char hash prefix
  });
});

// ─── Workflow Structure Tests ─────────────────────────────────────────────────

describe("workflow structure", () => {
  // Resolve paths relative to CWD (repo root when running bun test)
  const workflowPath = path.join(process.cwd(), ".github/workflows/semantic-version-bumper.yml");
  const scriptPath = path.join(process.cwd(), "src/version-bumper.ts");
  const fixture1 = path.join(process.cwd(), "fixtures/test-case-1.json");
  const fixture2 = path.join(process.cwd(), "fixtures/test-case-2.json");
  const fixture3 = path.join(process.cwd(), "fixtures/test-case-3.json");
  const fixture4 = path.join(process.cwd(), "fixtures/test-case-4.json");

  test("workflow file exists", () => {
    expect(fs.existsSync(workflowPath)).toBe(true);
  });

  test("script file exists", () => {
    expect(fs.existsSync(scriptPath)).toBe(true);
  });

  test("all fixture files exist", () => {
    expect(fs.existsSync(fixture1)).toBe(true);
    expect(fs.existsSync(fixture2)).toBe(true);
    expect(fs.existsSync(fixture3)).toBe(true);
    expect(fs.existsSync(fixture4)).toBe(true);
  });

  test("workflow has push trigger", () => {
    const content = fs.readFileSync(workflowPath, "utf-8");
    expect(content).toContain("push:");
  });

  test("workflow has pull_request trigger", () => {
    const content = fs.readFileSync(workflowPath, "utf-8");
    expect(content).toContain("pull_request:");
  });

  test("workflow has workflow_dispatch trigger", () => {
    const content = fs.readFileSync(workflowPath, "utf-8");
    expect(content).toContain("workflow_dispatch:");
  });

  test("workflow references the version bumper script", () => {
    const content = fs.readFileSync(workflowPath, "utf-8");
    expect(content).toContain("src/version-bumper.ts");
  });

  test("workflow uses actions/checkout@v4", () => {
    const content = fs.readFileSync(workflowPath, "utf-8");
    expect(content).toContain("actions/checkout@v4");
  });

  test("workflow has jobs section", () => {
    const content = fs.readFileSync(workflowPath, "utf-8");
    expect(content).toContain("jobs:");
  });

  test("actionlint passes on workflow file", () => {
    // Run actionlint as a subprocess and assert exit code 0
    const result = Bun.spawnSync(["actionlint", workflowPath]);
    const stderr = new TextDecoder().decode(result.stderr);
    if (result.exitCode !== 0) {
      console.error("actionlint output:", stderr);
    }
    expect(result.exitCode).toBe(0);
  });
});
