import { describe, expect, test } from "bun:test";
import {
  parseCommit,
  parseCommitLog,
  determineBump,
  type ParsedCommit,
} from "../src/commits.ts";

describe("parseCommit", () => {
  test("parses a feat commit", () => {
    const c = parseCommit("feat: add login flow");
    expect(c).toEqual({
      type: "feat",
      scope: null,
      breaking: false,
      description: "add login flow",
      raw: "feat: add login flow",
    });
  });

  test("parses a fix commit with scope", () => {
    const c = parseCommit("fix(api): handle null user");
    expect(c).toEqual({
      type: "fix",
      scope: "api",
      breaking: false,
      description: "handle null user",
      raw: "fix(api): handle null user",
    });
  });

  test("detects breaking change via '!'", () => {
    const c = parseCommit("feat(core)!: drop legacy endpoints");
    expect(c?.breaking).toBe(true);
    expect(c?.type).toBe("feat");
    expect(c?.scope).toBe("core");
  });

  test("detects breaking change via 'BREAKING CHANGE:' footer", () => {
    const c = parseCommit(
      "refactor: rename helpers\n\nBREAKING CHANGE: removed foo() helper",
    );
    expect(c?.breaking).toBe(true);
    expect(c?.type).toBe("refactor");
  });

  test("returns null for non-conventional commits", () => {
    expect(parseCommit("oops random message")).toBeNull();
    expect(parseCommit("")).toBeNull();
  });
});

describe("parseCommitLog", () => {
  test("splits on blank-line delimiters and ignores empties", () => {
    const log = [
      "feat: a",
      "",
      "fix: b",
      "",
      "chore: c",
      "",
      "not-a-commit-message",
    ].join("\n");
    const commits = parseCommitLog(log);
    expect(commits.map((c) => c.type)).toEqual(["feat", "fix", "chore"]);
  });

  test("uses --- delimiter when present (multi-line bodies)", () => {
    const log = [
      "feat: a",
      "",
      "more body",
      "---",
      "fix: b",
      "---",
      "refactor: c",
      "",
      "BREAKING CHANGE: x",
    ].join("\n");
    const commits = parseCommitLog(log);
    expect(commits.length).toBe(3);
    expect(commits[2]?.breaking).toBe(true);
  });
});

describe("determineBump", () => {
  test("returns 'none' for empty list", () => {
    expect(determineBump([])).toBe("none");
  });

  test("'patch' when only fixes", () => {
    const commits: ParsedCommit[] = [
      { type: "fix", scope: null, breaking: false, description: "a", raw: "fix: a" },
      { type: "chore", scope: null, breaking: false, description: "b", raw: "chore: b" },
    ];
    expect(determineBump(commits)).toBe("patch");
  });

  test("'minor' when any feat present", () => {
    const commits: ParsedCommit[] = [
      { type: "fix", scope: null, breaking: false, description: "a", raw: "fix: a" },
      { type: "feat", scope: null, breaking: false, description: "b", raw: "feat: b" },
    ];
    expect(determineBump(commits)).toBe("minor");
  });

  test("'major' when any breaking present", () => {
    const commits: ParsedCommit[] = [
      { type: "feat", scope: null, breaking: false, description: "a", raw: "feat: a" },
      { type: "fix", scope: null, breaking: true, description: "b", raw: "fix!: b" },
    ];
    expect(determineBump(commits)).toBe("major");
  });

  test("'none' when only chore/docs/style", () => {
    const commits: ParsedCommit[] = [
      { type: "chore", scope: null, breaking: false, description: "a", raw: "chore: a" },
      { type: "docs", scope: null, breaking: false, description: "b", raw: "docs: b" },
    ];
    expect(determineBump(commits)).toBe("none");
  });
});
