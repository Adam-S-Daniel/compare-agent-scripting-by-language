// Unit tests for the semantic version bumper library.
// Built incrementally with red/green TDD: each describe block was added with a
// failing assertion first, then implemented in src/lib.ts until it passed.

import { describe, expect, test } from "bun:test";
import {
  parseCommit,
  parseCommitLog,
  determineBump,
  bumpVersion,
  generateChangelogEntry,
  type Commit,
} from "../src/lib";

describe("parseCommit", () => {
  test("parses a feat commit with subject", () => {
    const c = parseCommit("feat: add user signup flow");
    expect(c).toEqual({
      type: "feat",
      scope: undefined,
      subject: "add user signup flow",
      breaking: false,
    });
  });

  test("parses a fix commit with scope", () => {
    const c = parseCommit("fix(auth): correct token expiry math");
    expect(c).toEqual({
      type: "fix",
      scope: "auth",
      subject: "correct token expiry math",
      breaking: false,
    });
  });

  test("flags ! suffix as breaking", () => {
    const c = parseCommit("feat!: drop legacy v1 endpoints");
    expect(c.breaking).toBe(true);
    expect(c.type).toBe("feat");
  });

  test("flags scoped ! suffix as breaking", () => {
    const c = parseCommit("refactor(api)!: rename payload field");
    expect(c.breaking).toBe(true);
    expect(c.scope).toBe("api");
  });

  test("returns chore type for non-conventional message", () => {
    const c = parseCommit("just a random commit message");
    // Falls through to "chore" so it doesn't trigger any bump.
    expect(c.type).toBe("chore");
    expect(c.breaking).toBe(false);
  });

  test("throws on empty commit message", () => {
    expect(() => parseCommit("")).toThrow(/empty/i);
  });
});

describe("parseCommitLog", () => {
  test("splits multi-commit log delimited by `---`", () => {
    const log = [
      "feat: add login",
      "---",
      "fix: typo in readme",
      "---",
      "chore: bump deps",
    ].join("\n");
    const commits = parseCommitLog(log);
    expect(commits).toHaveLength(3);
    expect(commits[0]!.type).toBe("feat");
    expect(commits[1]!.type).toBe("fix");
    expect(commits[2]!.type).toBe("chore");
  });

  test("detects BREAKING CHANGE footer in commit body", () => {
    const log = [
      "refactor: reorganize storage layer",
      "",
      "BREAKING CHANGE: removed the old KV API.",
    ].join("\n");
    const commits = parseCommitLog(log);
    expect(commits).toHaveLength(1);
    expect(commits[0]!.breaking).toBe(true);
  });

  test("ignores empty entries between separators", () => {
    const log = "feat: x\n---\n\n---\nfix: y";
    const commits = parseCommitLog(log);
    expect(commits.map((c) => c.type)).toEqual(["feat", "fix"]);
  });
});

describe("determineBump", () => {
  test("breaking beats feat beats fix", () => {
    const commits: Commit[] = [
      { type: "fix", subject: "a", breaking: false },
      { type: "feat", subject: "b", breaking: false },
      { type: "feat", subject: "c", breaking: true },
    ];
    expect(determineBump(commits)).toBe("major");
  });

  test("feat returns minor", () => {
    const commits: Commit[] = [
      { type: "fix", subject: "a", breaking: false },
      { type: "feat", subject: "b", breaking: false },
    ];
    expect(determineBump(commits)).toBe("minor");
  });

  test("fix only returns patch", () => {
    const commits: Commit[] = [
      { type: "fix", subject: "a", breaking: false },
      { type: "chore", subject: "b", breaking: false },
    ];
    expect(determineBump(commits)).toBe("patch");
  });

  test("chore/docs only returns null (no bump)", () => {
    const commits: Commit[] = [
      { type: "chore", subject: "a", breaking: false },
      { type: "docs", subject: "b", breaking: false },
    ];
    expect(determineBump(commits)).toBeNull();
  });

  test("empty list returns null", () => {
    expect(determineBump([])).toBeNull();
  });
});

describe("bumpVersion", () => {
  test("major resets minor and patch", () => {
    expect(bumpVersion("1.4.7", "major")).toBe("2.0.0");
  });

  test("minor resets patch", () => {
    expect(bumpVersion("1.4.7", "minor")).toBe("1.5.0");
  });

  test("patch increments only patch", () => {
    expect(bumpVersion("1.4.7", "patch")).toBe("1.4.8");
  });

  test("rejects non-semver input", () => {
    expect(() => bumpVersion("not-a-version", "patch")).toThrow(/semver/i);
    expect(() => bumpVersion("1.2", "patch")).toThrow(/semver/i);
  });
});

describe("generateChangelogEntry", () => {
  test("groups commits by type with version + date heading", () => {
    const commits: Commit[] = [
      { type: "feat", scope: "auth", subject: "add SSO", breaking: false },
      { type: "fix", subject: "off-by-one in pager", breaking: false },
      { type: "chore", subject: "deps bump", breaking: false },
    ];
    const entry = generateChangelogEntry("1.5.0", commits, "2026-05-07");
    expect(entry).toContain("## [1.5.0] - 2026-05-07");
    expect(entry).toContain("### Features");
    expect(entry).toMatch(/-\s+\*\*auth\*\*:\s+add SSO/);
    expect(entry).toContain("### Bug Fixes");
    expect(entry).toContain("- off-by-one in pager");
    // Chore should NOT appear in changelog by default.
    expect(entry).not.toContain("deps bump");
  });

  test("breaking changes get their own section", () => {
    const commits: Commit[] = [
      { type: "feat", subject: "rip out old api", breaking: true },
    ];
    const entry = generateChangelogEntry("2.0.0", commits, "2026-05-07");
    expect(entry).toContain("### BREAKING CHANGES");
    expect(entry).toContain("rip out old api");
  });
});
