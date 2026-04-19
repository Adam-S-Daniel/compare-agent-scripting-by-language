import { describe, it, expect } from "bun:test";
import { parseCommitMessage, getCommitTypes } from "./src/commits";
import { CommitType } from "./src/bumper";

describe("parseCommitMessage", () => {
  it("should identify feat commits", () => {
    const type = parseCommitMessage("feat: add new feature");
    expect(type).toBe(CommitType.FEAT);
  });

  it("should identify fix commits", () => {
    const type = parseCommitMessage("fix: resolve bug");
    expect(type).toBe(CommitType.FIX);
  });

  it("should identify breaking changes", () => {
    const type = parseCommitMessage("feat!: breaking change");
    expect(type).toBe(CommitType.BREAKING);
  });

  it("should identify BREAKING CHANGE in footer", () => {
    const message = "feat: add feature\n\nBREAKING CHANGE: this breaks API";
    const type = parseCommitMessage(message);
    expect(type).toBe(CommitType.BREAKING);
  });

  it("should identify chore commits", () => {
    const type = parseCommitMessage("chore: update deps");
    expect(type).toBe(CommitType.CHORE);
  });

  it("should return CHORE for unknown types", () => {
    const type = parseCommitMessage("docs: update readme");
    expect(type).toBe(CommitType.CHORE);
  });
});

describe("getCommitTypes", () => {
  it("should extract types from multiple commit messages", () => {
    const messages = [
      "fix: bug fix",
      "feat: new feature",
      "chore: update",
    ];
    const types = getCommitTypes(messages);
    expect(types).toContain(CommitType.FIX);
    expect(types).toContain(CommitType.FEAT);
    expect(types).toContain(CommitType.CHORE);
  });

  it("should handle empty commit list", () => {
    const types = getCommitTypes([]);
    expect(types).toEqual([]);
  });
});
