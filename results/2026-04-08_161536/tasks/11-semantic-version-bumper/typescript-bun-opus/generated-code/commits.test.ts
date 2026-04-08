// TDD tests for conventional commit parsing and bump determination

import { describe, test, expect } from "bun:test";
import type { ConventionalCommit, BumpType } from "./types";
import { parseCommitLog, determineBumpType } from "./commits";
import {
  FIXTURE_PATCH_ONLY,
  FIXTURE_MINOR_WITH_FIXES,
  FIXTURE_MAJOR_BREAKING,
  FIXTURE_BREAKING_IN_BODY,
  FIXTURE_MIXED_WITH_CHORES,
  FIXTURE_NO_CONVENTIONAL,
  FIXTURE_EMPTY,
} from "./fixtures";

describe("parseCommitLog", () => {
  test("parses fix commits", () => {
    const commits = parseCommitLog(FIXTURE_PATCH_ONLY);
    expect(commits).toHaveLength(2);
    expect(commits[0].type).toBe("fix");
    expect(commits[0].hash).toBe("abc1234");
    expect(commits[0].description).toBe("resolve null pointer in user lookup");
    expect(commits[0].breaking).toBe(false);
  });

  test("parses feat commits with scope", () => {
    const commits = parseCommitLog(FIXTURE_MINOR_WITH_FIXES);
    expect(commits).toHaveLength(3);
    expect(commits[0].type).toBe("feat");
    expect(commits[0].scope).toBeUndefined();
    expect(commits[2].type).toBe("fix");
    expect(commits[2].scope).toBe("ui");
  });

  test("detects breaking change via ! suffix", () => {
    const commits = parseCommitLog(FIXTURE_MAJOR_BREAKING);
    expect(commits[0].breaking).toBe(true);
    expect(commits[0].type).toBe("feat");
  });

  test("detects BREAKING CHANGE in body", () => {
    const commits = parseCommitLog(FIXTURE_BREAKING_IN_BODY);
    expect(commits).toHaveLength(1);
    expect(commits[0].breaking).toBe(true);
  });

  test("parses chore and docs commits", () => {
    const commits = parseCommitLog(FIXTURE_MIXED_WITH_CHORES);
    expect(commits).toHaveLength(4);
    expect(commits[0].type).toBe("chore");
    expect(commits[2].type).toBe("docs");
  });

  test("skips non-conventional commits", () => {
    const commits = parseCommitLog(FIXTURE_NO_CONVENTIONAL);
    expect(commits).toHaveLength(0);
  });

  test("returns empty array for empty input", () => {
    const commits = parseCommitLog(FIXTURE_EMPTY);
    expect(commits).toHaveLength(0);
  });
});

describe("determineBumpType", () => {
  test("returns patch for fix-only commits", () => {
    const commits = parseCommitLog(FIXTURE_PATCH_ONLY);
    expect(determineBumpType(commits)).toBe("patch");
  });

  test("returns minor when feat is present", () => {
    const commits = parseCommitLog(FIXTURE_MINOR_WITH_FIXES);
    expect(determineBumpType(commits)).toBe("minor");
  });

  test("returns major when breaking change is present", () => {
    const commits = parseCommitLog(FIXTURE_MAJOR_BREAKING);
    expect(determineBumpType(commits)).toBe("major");
  });

  test("returns major for BREAKING CHANGE in body", () => {
    const commits = parseCommitLog(FIXTURE_BREAKING_IN_BODY);
    expect(determineBumpType(commits)).toBe("major");
  });

  test("returns null when no bumpable commits exist", () => {
    const commits = parseCommitLog(FIXTURE_NO_CONVENTIONAL);
    expect(determineBumpType(commits)).toBeNull();
  });

  test("returns minor for mixed feat/chore commits", () => {
    const commits = parseCommitLog(FIXTURE_MIXED_WITH_CHORES);
    expect(determineBumpType(commits)).toBe("minor");
  });
});
