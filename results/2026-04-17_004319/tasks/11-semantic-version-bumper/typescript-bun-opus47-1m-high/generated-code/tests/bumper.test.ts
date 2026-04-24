// TDD for the semver bumping logic.
import { describe, expect, test } from "bun:test";
import {
  determineBumpType,
  bumpVersion,
  parseSemver,
  type BumpType,
} from "../src/bumper";
import type { Commit } from "../src/parser";

const mkCommit = (
  type: string,
  breaking = false,
  description = "x"
): Commit => ({ type, scope: undefined, breaking, description });

describe("parseSemver", () => {
  test("splits a simple semver", () => {
    expect(parseSemver("1.2.3")).toEqual({ major: 1, minor: 2, patch: 3 });
  });
  test("accepts a leading v", () => {
    expect(parseSemver("v0.1.0")).toEqual({ major: 0, minor: 1, patch: 0 });
  });
  test("throws on garbage", () => {
    expect(() => parseSemver("not-a-version")).toThrow();
  });
});

describe("determineBumpType", () => {
  test("empty or non-bumping commits yield 'none'", () => {
    expect(determineBumpType([])).toBe<BumpType>("none");
    expect(determineBumpType([mkCommit("chore"), mkCommit("docs")])).toBe<BumpType>(
      "none"
    );
  });

  test("any fix means at least patch", () => {
    expect(determineBumpType([mkCommit("fix")])).toBe<BumpType>("patch");
  });

  test("any feat upgrades to minor", () => {
    expect(
      determineBumpType([mkCommit("fix"), mkCommit("feat")])
    ).toBe<BumpType>("minor");
  });

  test("any breaking upgrades to major (even if type is fix)", () => {
    expect(
      determineBumpType([mkCommit("feat"), mkCommit("fix", true)])
    ).toBe<BumpType>("major");
  });
});

describe("bumpVersion", () => {
  test("patch bump", () => {
    expect(bumpVersion("1.2.3", "patch")).toBe("1.2.4");
  });
  test("minor bump resets patch", () => {
    expect(bumpVersion("1.2.3", "minor")).toBe("1.3.0");
  });
  test("major bump resets minor and patch", () => {
    expect(bumpVersion("1.2.3", "major")).toBe("2.0.0");
  });
  test("'none' keeps the version", () => {
    expect(bumpVersion("1.2.3", "none")).toBe("1.2.3");
  });
});
