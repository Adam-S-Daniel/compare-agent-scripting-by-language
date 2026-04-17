// Tests for decideBump: given a list of commits, choose the appropriate bump.
//
// Precedence (highest first):
//   - any breaking commit            -> "major"
//   - otherwise any feat             -> "minor"
//   - otherwise any fix              -> "patch"
//   - otherwise                      -> "none"

import { describe, expect, test } from "bun:test";
import type { Commit } from "../src/commits.ts";
import { decideBump } from "../src/decide.ts";

const c = (type: string, opts: Partial<Commit> = {}): Commit => ({
  type,
  scope: null,
  breaking: false,
  subject: `${type}: example`,
  raw: `${type}: example`,
  ...opts,
});

describe("decideBump", () => {
  test("empty list -> none", () => {
    expect(decideBump([])).toBe("none");
  });

  test("only chores -> none", () => {
    expect(decideBump([c("chore"), c("docs"), c("style")])).toBe("none");
  });

  test("a fix bumps patch", () => {
    expect(decideBump([c("chore"), c("fix")])).toBe("patch");
  });

  test("a feat bumps minor (overrides fix)", () => {
    expect(decideBump([c("fix"), c("feat")])).toBe("minor");
  });

  test("any breaking change bumps major", () => {
    expect(decideBump([c("fix"), c("feat"), c("chore", { breaking: true })])).toBe(
      "major"
    );
  });

  test("breaking feat alone bumps major", () => {
    expect(decideBump([c("feat", { breaking: true })])).toBe("major");
  });
});
