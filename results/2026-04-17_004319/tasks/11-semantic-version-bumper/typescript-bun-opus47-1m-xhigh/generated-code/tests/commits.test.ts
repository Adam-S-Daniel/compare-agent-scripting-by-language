// Tests for parsing conventional commits.
//
// The parser supports:
//  - "<type>(scope)?: <subject>"        e.g. "feat(api): add endpoint"
//  - A "!" after type/scope meaning BREAKING CHANGE: "feat!: rewrite"
//  - A commit body containing a "BREAKING CHANGE:" footer
//
// Non-conventional commit lines are flagged with type="other".

import { describe, expect, test } from "bun:test";
import { parseCommit, parseCommitLog } from "../src/commits.ts";

describe("parseCommit (single commit)", () => {
  test("parses feat commit", () => {
    expect(parseCommit("feat: add login")).toEqual({
      type: "feat",
      scope: null,
      breaking: false,
      subject: "add login",
      raw: "feat: add login",
    });
  });

  test("parses fix with scope", () => {
    expect(parseCommit("fix(parser): handle empty input")).toEqual({
      type: "fix",
      scope: "parser",
      breaking: false,
      subject: "handle empty input",
      raw: "fix(parser): handle empty input",
    });
  });

  test("bang marks commit as breaking", () => {
    const c = parseCommit("feat!: drop legacy API");
    expect(c.type).toBe("feat");
    expect(c.breaking).toBe(true);
    expect(c.subject).toBe("drop legacy API");
  });

  test("bang with scope also marks breaking", () => {
    const c = parseCommit("refactor(core)!: rewrite engine");
    expect(c.type).toBe("refactor");
    expect(c.scope).toBe("core");
    expect(c.breaking).toBe(true);
  });

  test("non-conventional line becomes type=other", () => {
    expect(parseCommit("just a random message")).toEqual({
      type: "other",
      scope: null,
      breaking: false,
      subject: "just a random message",
      raw: "just a random message",
    });
  });
});

describe("parseCommitLog (multi-commit buffer with footers)", () => {
  test("splits a git log stream on blank-line separators", () => {
    const log = [
      "feat: add login",
      "",
      "fix: correct typo",
      "",
      "chore: bump deps",
    ].join("\n");
    const commits = parseCommitLog(log);
    expect(commits.map((c) => c.type)).toEqual(["feat", "fix", "chore"]);
  });

  test("detects BREAKING CHANGE footer in body", () => {
    const log = [
      "feat: support plugins",
      "",
      "Plugins can now be registered via config.",
      "",
      "BREAKING CHANGE: the old plugin hook has been removed.",
    ].join("\n");
    const [commit] = parseCommitLog(log);
    expect(commit.type).toBe("feat");
    expect(commit.breaking).toBe(true);
  });

  test("handles empty input", () => {
    expect(parseCommitLog("")).toEqual([]);
    expect(parseCommitLog("\n\n\n")).toEqual([]);
  });

  test("commits separated by a custom delimiter '---' also work", () => {
    const log = ["feat: a", "---", "fix: b", "---", "chore: c"].join("\n");
    const commits = parseCommitLog(log, { delimiter: "---" });
    expect(commits.map((c) => c.type)).toEqual(["feat", "fix", "chore"]);
  });
});
