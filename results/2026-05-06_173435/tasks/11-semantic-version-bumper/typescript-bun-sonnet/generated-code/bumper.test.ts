// bumper.test.ts
// TDD: Tests written FIRST. Each test was written before the corresponding implementation.
// Red -> Green -> Refactor cycle per feature.

import { test, expect, describe, beforeEach, afterEach } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync, mkdirSync, readFileSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";

import {
  parseCommit,
  determineBumpType,
  bumpVersion,
  generateChangelog,
  parseCommitsFile,
  bump,
} from "./bumper";
import type { Commit, BumpType } from "./bumper";

// --- parseCommit ---
describe("parseCommit", () => {
  test("parses a fix commit", () => {
    const commit = parseCommit("abc1234 fix(auth): resolve login redirect issue");
    expect(commit.type).toBe("fix");
    expect(commit.scope).toBe("auth");
    expect(commit.message).toBe("resolve login redirect issue");
    expect(commit.breaking).toBe(false);
    expect(commit.hash).toBe("abc1234");
  });

  test("parses a feat commit without scope", () => {
    const commit = parseCommit("def5678 feat: add user profile endpoint");
    expect(commit.type).toBe("feat");
    expect(commit.scope).toBeUndefined();
    expect(commit.message).toBe("add user profile endpoint");
    expect(commit.breaking).toBe(false);
  });

  test("parses a breaking change with ! marker", () => {
    const commit = parseCommit("ghi9012 feat!: redesign authentication flow");
    expect(commit.type).toBe("feat");
    expect(commit.breaking).toBe(true);
  });

  test("parses a breaking change with BREAKING CHANGE in message", () => {
    const commit = parseCommit("abc0001 fix: BREAKING CHANGE update config format");
    expect(commit.breaking).toBe(true);
  });

  test("parses a chore commit", () => {
    const commit = parseCommit("abc0002 chore: update dependencies");
    expect(commit.type).toBe("chore");
    expect(commit.breaking).toBe(false);
  });

  test("parses a scoped breaking feat", () => {
    const commit = parseCommit("abc0003 feat(api)!: remove deprecated endpoint");
    expect(commit.type).toBe("feat");
    expect(commit.scope).toBe("api");
    expect(commit.breaking).toBe(true);
  });
});

// --- determineBumpType ---
describe("determineBumpType", () => {
  test("returns patch for fix commits only", () => {
    const commits: Commit[] = [
      { hash: "a", type: "fix", message: "fix bug", breaking: false },
      { hash: "b", type: "chore", message: "update deps", breaking: false },
    ];
    expect(determineBumpType(commits)).toBe("patch");
  });

  test("returns minor for feat commits", () => {
    const commits: Commit[] = [
      { hash: "a", type: "feat", message: "new feature", breaking: false },
      { hash: "b", type: "fix", message: "fix bug", breaking: false },
    ];
    expect(determineBumpType(commits)).toBe("minor");
  });

  test("returns major for breaking commits", () => {
    const commits: Commit[] = [
      { hash: "a", type: "feat", message: "breaking", breaking: true },
      { hash: "b", type: "feat", message: "new feature", breaking: false },
    ];
    expect(determineBumpType(commits)).toBe("major");
  });

  test("returns none for chore-only commits", () => {
    const commits: Commit[] = [
      { hash: "a", type: "chore", message: "update deps", breaking: false },
    ];
    expect(determineBumpType(commits)).toBe("none");
  });

  test("returns none for empty commit list", () => {
    expect(determineBumpType([])).toBe("none");
  });

  test("major beats minor beats patch (precedence)", () => {
    const commits: Commit[] = [
      { hash: "a", type: "fix", message: "patch fix", breaking: false },
      { hash: "b", type: "feat", message: "new feature", breaking: false },
      { hash: "c", type: "fix", message: "breaking fix", breaking: true },
    ];
    expect(determineBumpType(commits)).toBe("major");
  });
});

// --- bumpVersion ---
describe("bumpVersion", () => {
  test("bumps patch version", () => {
    expect(bumpVersion("1.0.0", "patch")).toBe("1.0.1");
  });

  test("bumps minor version and resets patch", () => {
    expect(bumpVersion("1.2.3", "minor")).toBe("1.3.0");
  });

  test("bumps major version and resets minor/patch", () => {
    expect(bumpVersion("1.2.3", "major")).toBe("2.0.0");
  });

  test("returns same version for none", () => {
    expect(bumpVersion("1.0.0", "none")).toBe("1.0.0");
  });

  test("handles versions with leading zeros correctly", () => {
    expect(bumpVersion("0.0.1", "patch")).toBe("0.0.2");
    expect(bumpVersion("0.1.0", "minor")).toBe("0.2.0");
    expect(bumpVersion("0.0.0", "major")).toBe("1.0.0");
  });
});

// --- generateChangelog ---
describe("generateChangelog", () => {
  const date = new Date().toISOString().split("T")[0];

  test("includes version header with today's date", () => {
    const commits: Commit[] = [];
    const changelog = generateChangelog("1.1.0", commits);
    expect(changelog).toContain(`## [1.1.0] - ${date}`);
  });

  test("groups feat commits under Features", () => {
    const commits: Commit[] = [
      { hash: "abc1234", type: "feat", message: "add profile page", breaking: false },
    ];
    const changelog = generateChangelog("1.1.0", commits);
    expect(changelog).toContain("### Features");
    expect(changelog).toContain("add profile page");
    expect(changelog).toContain("abc1234");
  });

  test("groups fix commits under Bug Fixes", () => {
    const commits: Commit[] = [
      { hash: "def5678", type: "fix", message: "fix null pointer", breaking: false },
    ];
    const changelog = generateChangelog("1.0.1", commits);
    expect(changelog).toContain("### Bug Fixes");
    expect(changelog).toContain("fix null pointer");
  });

  test("groups breaking commits under Breaking Changes", () => {
    const commits: Commit[] = [
      { hash: "ghi9012", type: "feat", message: "redesign api", breaking: true },
    ];
    const changelog = generateChangelog("2.0.0", commits);
    expect(changelog).toContain("### Breaking Changes");
    expect(changelog).toContain("redesign api");
  });

  test("includes scope in feat entry when present", () => {
    const commits: Commit[] = [
      { hash: "abc0001", type: "feat", scope: "api", message: "add endpoint", breaking: false },
    ];
    const changelog = generateChangelog("1.1.0", commits);
    expect(changelog).toContain("**api**");
  });
});

// --- parseCommitsFile ---
describe("parseCommitsFile", () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = mkdtempSync(join(tmpdir(), "bumper-test-"));
  });

  afterEach(() => {
    rmSync(tmpDir, { recursive: true, force: true });
  });

  test("parses a multi-line commits file", () => {
    const content = [
      "abc1234 fix(auth): resolve login issue",
      "def5678 feat: add profile page",
      "ghi9012 chore: update deps",
    ].join("\n");
    const filePath = join(tmpDir, "commits.txt");
    writeFileSync(filePath, content);

    const commits = parseCommitsFile(filePath);
    expect(commits).toHaveLength(3);
    expect(commits[0].type).toBe("fix");
    expect(commits[1].type).toBe("feat");
    expect(commits[2].type).toBe("chore");
  });

  test("returns empty array for missing file", () => {
    const commits = parseCommitsFile(join(tmpDir, "nonexistent.txt"));
    expect(commits).toEqual([]);
  });

  test("returns empty array for empty file", () => {
    const filePath = join(tmpDir, "commits.txt");
    writeFileSync(filePath, "");
    expect(parseCommitsFile(filePath)).toEqual([]);
  });
});

// --- bump integration tests ---
describe("bump (integration)", () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = mkdtempSync(join(tmpdir(), "bumper-int-"));
  });

  afterEach(() => {
    rmSync(tmpDir, { recursive: true, force: true });
  });

  test("patch bump via version.txt with fix commits", () => {
    writeFileSync(join(tmpDir, "version.txt"), "1.0.0\n");
    writeFileSync(join(tmpDir, "commits.txt"), "abc1234 fix: correct typo\ndef5678 fix(ui): fix button color\n");

    const result = bump(tmpDir, join(tmpDir, "commits.txt"));

    expect(result.oldVersion).toBe("1.0.0");
    expect(result.newVersion).toBe("1.0.1");
    expect(result.bumpType).toBe("patch");
    expect(readFileSync(join(tmpDir, "version.txt"), "utf-8").trim()).toBe("1.0.1");
  });

  test("minor bump via package.json with feat commit", () => {
    writeFileSync(join(tmpDir, "package.json"), JSON.stringify({ name: "my-pkg", version: "1.1.0" }, null, 2));
    writeFileSync(join(tmpDir, "commits.txt"), "abc1234 feat(api): add user endpoint\n");

    const result = bump(tmpDir, join(tmpDir, "commits.txt"));

    expect(result.newVersion).toBe("1.2.0");
    expect(result.bumpType).toBe("minor");
    const pkg = JSON.parse(readFileSync(join(tmpDir, "package.json"), "utf-8"));
    expect(pkg.version).toBe("1.2.0");
  });

  test("major bump with breaking change", () => {
    writeFileSync(join(tmpDir, "version.txt"), "2.0.0\n");
    writeFileSync(join(tmpDir, "commits.txt"), "abc1234 feat!: redesign auth flow\n");

    const result = bump(tmpDir, join(tmpDir, "commits.txt"));

    expect(result.newVersion).toBe("3.0.0");
    expect(result.bumpType).toBe("major");
  });

  test("no bump for chore-only commits", () => {
    writeFileSync(join(tmpDir, "version.txt"), "1.2.3\n");
    writeFileSync(join(tmpDir, "commits.txt"), "abc1234 chore: update deps\n");

    const result = bump(tmpDir, join(tmpDir, "commits.txt"));

    expect(result.newVersion).toBe("1.2.3");
    expect(result.bumpType).toBe("none");
    // version.txt should remain unchanged
    expect(readFileSync(join(tmpDir, "version.txt"), "utf-8").trim()).toBe("1.2.3");
  });

  test("mixed commits: feat + fix = minor bump", () => {
    writeFileSync(join(tmpDir, "version.txt"), "1.1.0\n");
    writeFileSync(
      join(tmpDir, "commits.txt"),
      "abc1234 feat(dashboard): add analytics widget\ndef5678 fix(api): handle null response\nghi9012 chore: update deps\n"
    );

    const result = bump(tmpDir, join(tmpDir, "commits.txt"));

    expect(result.newVersion).toBe("1.2.0");
    expect(result.bumpType).toBe("minor");
  });

  test("writes CHANGELOG.md entry on bump", () => {
    writeFileSync(join(tmpDir, "version.txt"), "1.0.0\n");
    writeFileSync(join(tmpDir, "commits.txt"), "abc1234 feat: new feature\n");

    bump(tmpDir, join(tmpDir, "commits.txt"));

    const changelog = readFileSync(join(tmpDir, "CHANGELOG.md"), "utf-8");
    expect(changelog).toContain("## [1.1.0]");
    expect(changelog).toContain("new feature");
  });

  test("throws meaningful error when no version file found", () => {
    writeFileSync(join(tmpDir, "commits.txt"), "abc1234 fix: a fix\n");
    expect(() => bump(tmpDir, join(tmpDir, "commits.txt"))).toThrow("No version file found");
  });
});
