// TDD tests for the semantic version bumper
// Red/Green methodology: each test written before the implementation

import { describe, test, expect } from "bun:test";
import type { SemanticVersion, BumpType } from "./types";

// These imports will fail initially (RED phase)
import { parseVersion, formatVersion, bumpVersion } from "./version";

describe("parseVersion", () => {
  test("parses a valid semver string", () => {
    const result: SemanticVersion = parseVersion("1.2.3");
    expect(result).toEqual({ major: 1, minor: 2, patch: 3 });
  });

  test("parses version 0.0.0", () => {
    expect(parseVersion("0.0.0")).toEqual({ major: 0, minor: 0, patch: 0 });
  });

  test("parses version with leading v", () => {
    expect(parseVersion("v2.0.1")).toEqual({ major: 2, minor: 0, patch: 1 });
  });

  test("throws on invalid version string", () => {
    expect(() => parseVersion("not-a-version")).toThrow("Invalid semantic version");
  });

  test("throws on incomplete version", () => {
    expect(() => parseVersion("1.2")).toThrow("Invalid semantic version");
  });
});

describe("formatVersion", () => {
  test("formats a version object to string", () => {
    expect(formatVersion({ major: 1, minor: 2, patch: 3 })).toBe("1.2.3");
  });

  test("formats version 0.0.0", () => {
    expect(formatVersion({ major: 0, minor: 0, patch: 0 })).toBe("0.0.0");
  });
});

describe("bumpVersion", () => {
  test("bumps patch version", () => {
    const v: SemanticVersion = { major: 1, minor: 2, patch: 3 };
    expect(bumpVersion(v, "patch")).toEqual({ major: 1, minor: 2, patch: 4 });
  });

  test("bumps minor version and resets patch", () => {
    const v: SemanticVersion = { major: 1, minor: 2, patch: 3 };
    expect(bumpVersion(v, "minor")).toEqual({ major: 1, minor: 3, patch: 0 });
  });

  test("bumps major version and resets minor and patch", () => {
    const v: SemanticVersion = { major: 1, minor: 2, patch: 3 };
    expect(bumpVersion(v, "major")).toEqual({ major: 2, minor: 0, patch: 0 });
  });
});
