import { describe, it, expect } from "bun:test";
import { generateChangelogEntry } from "./src/changelog";

describe("generateChangelogEntry", () => {
  it("should generate changelog for feat commits", () => {
    const commits = ["feat: add user authentication"];
    const entry = generateChangelogEntry("1.1.0", commits);
    expect(entry).toContain("1.1.0");
    expect(entry).toContain("Features");
    expect(entry).toContain("user authentication");
  });

  it("should generate changelog for fix commits", () => {
    const commits = ["fix: resolve memory leak"];
    const entry = generateChangelogEntry("1.0.1", commits);
    expect(entry).toContain("1.0.1");
    expect(entry).toContain("Bug Fixes");
    expect(entry).toContain("memory leak");
  });

  it("should generate changelog for multiple commits", () => {
    const commits = [
      "feat: add new endpoint",
      "fix: resolve timeout issue",
      "chore: update dependencies",
    ];
    const entry = generateChangelogEntry("1.1.0", commits);
    expect(entry).toContain("1.1.0");
    expect(entry).toContain("new endpoint");
    expect(entry).toContain("timeout issue");
  });

  it("should format commit messages properly", () => {
    const commits = ["feat(auth): add oauth support"];
    const entry = generateChangelogEntry("1.1.0", commits);
    expect(entry).toContain("oauth support");
  });
});
