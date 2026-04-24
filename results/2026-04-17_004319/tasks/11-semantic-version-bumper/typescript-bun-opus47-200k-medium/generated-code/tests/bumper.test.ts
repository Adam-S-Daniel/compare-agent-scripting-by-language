import { describe, test, expect } from "bun:test";
import {
  parseVersion,
  parseCommits,
  determineBump,
  bumpVersion,
  generateChangelog,
  type Commit,
  type BumpType,
} from "../src/bumper.ts";

// Unit tests follow red-green-refactor TDD. Each `describe` block was written
// as a failing test first, then the minimum code added to pass.

describe("parseVersion", () => {
  test("parses plain version string", () => {
    expect(parseVersion("1.2.3")).toEqual({ major: 1, minor: 2, patch: 3 });
  });
  test("parses version with trailing newline", () => {
    expect(parseVersion("0.0.1\n")).toEqual({ major: 0, minor: 0, patch: 1 });
  });
  test("parses version from package.json content", () => {
    const pkg = JSON.stringify({ name: "x", version: "2.5.7" });
    expect(parseVersion(pkg)).toEqual({ major: 2, minor: 5, patch: 7 });
  });
  test("throws on invalid version", () => {
    expect(() => parseVersion("not-a-version")).toThrow(/invalid version/i);
  });
});

describe("parseCommits", () => {
  test("parses conventional commit lines", () => {
    const log = [
      "feat: add login",
      "fix: broken button",
      "chore: update deps",
    ].join("\n");
    const commits = parseCommits(log);
    expect(commits).toHaveLength(3);
    expect(commits[0]).toEqual({ type: "feat", breaking: false, subject: "add login" });
    expect(commits[1]).toEqual({ type: "fix", breaking: false, subject: "broken button" });
    expect(commits[2]).toEqual({ type: "chore", breaking: false, subject: "update deps" });
  });
  test("flags ! as breaking", () => {
    const commits = parseCommits("feat!: drop node 14");
    expect(commits[0]!.breaking).toBe(true);
  });
  test("flags BREAKING CHANGE footer as breaking", () => {
    const commits = parseCommits("feat: x\n\nBREAKING CHANGE: yes");
    expect(commits[0]!.breaking).toBe(true);
  });
  test("handles scope in type", () => {
    const commits = parseCommits("feat(api): add v2");
    expect(commits[0]!.type).toBe("feat");
    expect(commits[0]!.subject).toBe("add v2");
  });
  test("ignores non-conventional lines", () => {
    const commits = parseCommits("Merge pull request #12\nfeat: good one");
    expect(commits).toHaveLength(1);
    expect(commits[0]!.subject).toBe("good one");
  });
});

describe("determineBump", () => {
  const mk = (type: string, breaking = false): Commit => ({ type, breaking, subject: "x" });
  test("breaking -> major", () => {
    expect(determineBump([mk("feat", true), mk("fix")])).toBe<BumpType>("major");
  });
  test("feat -> minor", () => {
    expect(determineBump([mk("feat"), mk("fix")])).toBe<BumpType>("minor");
  });
  test("fix -> patch", () => {
    expect(determineBump([mk("fix"), mk("chore")])).toBe<BumpType>("patch");
  });
  test("none -> none", () => {
    expect(determineBump([mk("chore")])).toBe<BumpType>("none");
  });
});

describe("bumpVersion", () => {
  test("major resets minor/patch", () => {
    expect(bumpVersion({ major: 1, minor: 2, patch: 3 }, "major")).toBe("2.0.0");
  });
  test("minor resets patch", () => {
    expect(bumpVersion({ major: 1, minor: 2, patch: 3 }, "minor")).toBe("1.3.0");
  });
  test("patch increments patch", () => {
    expect(bumpVersion({ major: 1, minor: 2, patch: 3 }, "patch")).toBe("1.2.4");
  });
  test("none leaves as-is", () => {
    expect(bumpVersion({ major: 1, minor: 2, patch: 3 }, "none")).toBe("1.2.3");
  });
});

describe("generateChangelog", () => {
  test("groups commits under version header", () => {
    const commits: Commit[] = [
      { type: "feat", breaking: false, subject: "add a" },
      { type: "fix", breaking: false, subject: "repair b" },
      { type: "feat", breaking: true, subject: "drop c" },
    ];
    const out = generateChangelog("1.2.0", commits);
    expect(out).toContain("## 1.2.0");
    expect(out).toContain("### Features");
    expect(out).toContain("- add a");
    expect(out).toContain("### Bug Fixes");
    expect(out).toContain("- repair b");
    expect(out).toContain("### BREAKING CHANGES");
    expect(out).toContain("- drop c");
  });
});
