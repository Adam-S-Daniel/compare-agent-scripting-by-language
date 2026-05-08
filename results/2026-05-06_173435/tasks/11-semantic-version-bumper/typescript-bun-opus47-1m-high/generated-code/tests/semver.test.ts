import { describe, expect, test } from "bun:test";
import { parseVersion, formatVersion, bumpVersion } from "../src/semver.ts";

describe("parseVersion", () => {
  test("parses a basic semver string", () => {
    expect(parseVersion("1.2.3")).toEqual({ major: 1, minor: 2, patch: 3 });
  });

  test("parses with leading 'v'", () => {
    expect(parseVersion("v0.0.1")).toEqual({ major: 0, minor: 0, patch: 1 });
  });

  test("throws on invalid input", () => {
    expect(() => parseVersion("not-a-version")).toThrow(/Invalid semver/);
    expect(() => parseVersion("1.2")).toThrow(/Invalid semver/);
  });
});

describe("formatVersion", () => {
  test("formats a version object back to string", () => {
    expect(formatVersion({ major: 2, minor: 5, patch: 9 })).toBe("2.5.9");
  });
});

describe("bumpVersion", () => {
  test("major bump zeroes minor and patch", () => {
    expect(bumpVersion({ major: 1, minor: 2, patch: 3 }, "major")).toEqual({
      major: 2,
      minor: 0,
      patch: 0,
    });
  });

  test("minor bump zeroes patch only", () => {
    expect(bumpVersion({ major: 1, minor: 2, patch: 3 }, "minor")).toEqual({
      major: 1,
      minor: 3,
      patch: 0,
    });
  });

  test("patch bump increments patch", () => {
    expect(bumpVersion({ major: 1, minor: 2, patch: 3 }, "patch")).toEqual({
      major: 1,
      minor: 2,
      patch: 4,
    });
  });

  test("none bump leaves unchanged", () => {
    expect(bumpVersion({ major: 1, minor: 2, patch: 3 }, "none")).toEqual({
      major: 1,
      minor: 2,
      patch: 3,
    });
  });
});
