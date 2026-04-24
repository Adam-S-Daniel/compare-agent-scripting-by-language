// Red/green TDD tests for the conventional-commit parser.
// We test one small behavior at a time before implementing it.
import { describe, expect, test } from "bun:test";
import { parseCommit, parseCommitLog } from "../src/parser";

describe("parseCommit", () => {
  test("parses a plain feat commit", () => {
    const c = parseCommit("feat: add login page");
    expect(c).toEqual({
      type: "feat",
      scope: undefined,
      breaking: false,
      description: "add login page",
    });
  });

  test("parses a scoped fix commit", () => {
    const c = parseCommit("fix(auth): handle expired token");
    expect(c.type).toBe("fix");
    expect(c.scope).toBe("auth");
    expect(c.breaking).toBe(false);
    expect(c.description).toBe("handle expired token");
  });

  test("marks bang-suffixed commits as breaking", () => {
    const c = parseCommit("feat!: drop legacy API");
    expect(c.type).toBe("feat");
    expect(c.breaking).toBe(true);
  });

  test("marks commits with BREAKING CHANGE footer as breaking", () => {
    const msg = "feat: new auth flow\n\nBREAKING CHANGE: sessions now require MFA";
    const c = parseCommit(msg);
    expect(c.breaking).toBe(true);
  });

  test("returns null for non-conventional messages", () => {
    expect(parseCommit("wip random stuff")).toBeNull();
  });
});

describe("parseCommitLog", () => {
  test("splits a multi-commit log by a known delimiter", () => {
    // Fixture format: commits separated by a null-byte-like delimiter "---".
    const log = [
      "feat: a",
      "---",
      "fix: b",
      "---",
      "chore: c",
    ].join("\n");
    const parsed = parseCommitLog(log);
    expect(parsed.length).toBe(3);
    expect(parsed[0]?.type).toBe("feat");
    expect(parsed[1]?.type).toBe("fix");
    expect(parsed[2]?.type).toBe("chore");
  });

  test("skips unparseable entries", () => {
    const log = "feat: a\n---\nnot a commit\n---\nfix: c";
    const parsed = parseCommitLog(log);
    expect(parsed.length).toBe(2);
  });
});
