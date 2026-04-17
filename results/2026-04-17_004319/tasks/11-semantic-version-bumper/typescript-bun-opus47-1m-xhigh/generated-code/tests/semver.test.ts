// Tests for semver parsing and bumping.
// TDD: start with parsing a version string, then bumping it by each component.

import { describe, expect, test } from "bun:test";
import { parseVersion, bumpVersion, type BumpType } from "../src/semver.ts";

describe("parseVersion", () => {
  test("parses a plain semver string into its three numeric components", () => {
    expect(parseVersion("1.2.3")).toEqual({ major: 1, minor: 2, patch: 3 });
  });

  test("parses a version with a leading 'v'", () => {
    expect(parseVersion("v0.9.1")).toEqual({ major: 0, minor: 9, patch: 1 });
  });

  test("throws on a malformed version string", () => {
    expect(() => parseVersion("not-a-version")).toThrow(/invalid semver/i);
  });

  test("throws on missing components", () => {
    expect(() => parseVersion("1.2")).toThrow(/invalid semver/i);
  });
});

describe("bumpVersion", () => {
  test("patch bump increments only the patch segment", () => {
    expect(bumpVersion({ major: 1, minor: 2, patch: 3 }, "patch")).toEqual({
      major: 1,
      minor: 2,
      patch: 4,
    });
  });

  test("minor bump increments minor and resets patch", () => {
    expect(bumpVersion({ major: 1, minor: 2, patch: 3 }, "minor")).toEqual({
      major: 1,
      minor: 3,
      patch: 0,
    });
  });

  test("major bump increments major and resets minor+patch", () => {
    expect(bumpVersion({ major: 1, minor: 2, patch: 3 }, "major")).toEqual({
      major: 2,
      minor: 0,
      patch: 0,
    });
  });

  test("'none' returns an equal version (no bump)", () => {
    const same = bumpVersion({ major: 1, minor: 2, patch: 3 }, "none" as BumpType);
    expect(same).toEqual({ major: 1, minor: 2, patch: 3 });
  });
});
