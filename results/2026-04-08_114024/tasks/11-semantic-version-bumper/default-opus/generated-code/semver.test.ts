// TDD tests for the semantic version bumper.
// Each section follows red/green/refactor: tests are written first,
// then the implementation is built to satisfy them.

import { describe, test, expect } from "bun:test";
import {
  parseVersion,
  formatVersion,
  parseCommitLog,
  classifyCommits,
  determineBump,
  bumpVersion,
  readVersionFile,
  writeVersionFile,
  generateChangelog,
  type BumpType,
} from "./semver";

// =============================================================================
// 1. Semantic version parsing
// =============================================================================
describe("parseVersion", () => {
  test("parses a simple major.minor.patch string", () => {
    expect(parseVersion("1.2.3")).toEqual({ major: 1, minor: 2, patch: 3 });
  });

  test("parses 0.0.0", () => {
    expect(parseVersion("0.0.0")).toEqual({ major: 0, minor: 0, patch: 0 });
  });

  test("handles a leading 'v' prefix", () => {
    expect(parseVersion("v2.0.1")).toEqual({ major: 2, minor: 0, patch: 1 });
  });

  test("throws on invalid version strings", () => {
    expect(() => parseVersion("not-a-version")).toThrow();
    expect(() => parseVersion("1.2")).toThrow();
    expect(() => parseVersion("")).toThrow();
  });
});

describe("formatVersion", () => {
  test("formats a version object to a string", () => {
    expect(formatVersion({ major: 1, minor: 2, patch: 3 })).toBe("1.2.3");
  });
});

// =============================================================================
// 2. Commit log parsing and classification
// =============================================================================
describe("parseCommitLog", () => {
  test("parses fixture commit lines into structured objects", () => {
    const log = `abc1234 fix: correct off-by-one error in pagination
def5678 feat(ui): new settings panel`;
    const commits = parseCommitLog(log);
    expect(commits).toHaveLength(2);
    expect(commits[0]).toEqual({
      hash: "abc1234",
      message: "fix: correct off-by-one error in pagination",
    });
    expect(commits[1]).toEqual({
      hash: "def5678",
      message: "feat(ui): new settings panel",
    });
  });

  test("skips blank lines", () => {
    const log = `abc1234 fix: something\n\ndef5678 feat: another`;
    expect(parseCommitLog(log)).toHaveLength(2);
  });

  test("returns empty array for empty input", () => {
    expect(parseCommitLog("")).toEqual([]);
    expect(parseCommitLog("  \n  ")).toEqual([]);
  });
});

describe("classifyCommits", () => {
  test("classifies fix commits as patch", () => {
    const result = classifyCommits([
      { hash: "a", message: "fix: something" },
    ]);
    expect(result.patch).toHaveLength(1);
    expect(result.minor).toHaveLength(0);
    expect(result.major).toHaveLength(0);
  });

  test("classifies feat commits as minor", () => {
    const result = classifyCommits([
      { hash: "a", message: "feat: add feature" },
      { hash: "b", message: "feat(scope): scoped feature" },
    ]);
    expect(result.minor).toHaveLength(2);
  });

  test("classifies breaking changes via ! suffix as major", () => {
    const result = classifyCommits([
      { hash: "a", message: "feat!: redesign API" },
      { hash: "b", message: "fix!: breaking fix" },
    ]);
    expect(result.major).toHaveLength(2);
  });

  test("classifies BREAKING CHANGE footer as major", () => {
    const result = classifyCommits([
      { hash: "a", message: "feat: migrate\n\nBREAKING CHANGE: removed v1" },
    ]);
    expect(result.major).toHaveLength(1);
  });

  test("ignores non-conventional commits (docs, chore, etc.)", () => {
    const result = classifyCommits([
      { hash: "a", message: "docs: update readme" },
      { hash: "b", message: "chore: bump deps" },
      { hash: "c", message: "random message" },
    ]);
    expect(result.patch).toHaveLength(0);
    expect(result.minor).toHaveLength(0);
    expect(result.major).toHaveLength(0);
  });
});

// =============================================================================
// 3. Version bumping logic
// =============================================================================
describe("determineBump", () => {
  test("returns 'major' when breaking changes exist", () => {
    expect(
      determineBump({
        major: [{ hash: "a", message: "feat!: break" }],
        minor: [{ hash: "b", message: "feat: add" }],
        patch: [],
      })
    ).toBe("major");
  });

  test("returns 'minor' when features exist but no breaking", () => {
    expect(
      determineBump({
        major: [],
        minor: [{ hash: "a", message: "feat: add" }],
        patch: [{ hash: "b", message: "fix: something" }],
      })
    ).toBe("minor");
  });

  test("returns 'patch' when only fixes exist", () => {
    expect(
      determineBump({
        major: [],
        minor: [],
        patch: [{ hash: "a", message: "fix: bug" }],
      })
    ).toBe("patch");
  });

  test("returns null when no bump-worthy commits exist", () => {
    expect(determineBump({ major: [], minor: [], patch: [] })).toBeNull();
  });
});

describe("bumpVersion", () => {
  test("bumps patch", () => {
    expect(bumpVersion({ major: 1, minor: 2, patch: 3 }, "patch")).toEqual({
      major: 1,
      minor: 2,
      patch: 4,
    });
  });

  test("bumps minor and resets patch", () => {
    expect(bumpVersion({ major: 1, minor: 2, patch: 3 }, "minor")).toEqual({
      major: 1,
      minor: 3,
      patch: 0,
    });
  });

  test("bumps major and resets minor and patch", () => {
    expect(bumpVersion({ major: 1, minor: 2, patch: 3 }, "major")).toEqual({
      major: 2,
      minor: 0,
      patch: 0,
    });
  });
});

// =============================================================================
// 4. Version file reading and writing
// =============================================================================
describe("readVersionFile", () => {
  const fixturesDir = import.meta.dir + "/fixtures";

  test("reads version from a plain text file", async () => {
    const v = await readVersionFile(fixturesDir + "/version.txt");
    expect(v).toEqual({ major: 1, minor: 2, patch: 3 });
  });

  test("reads version from a package.json", async () => {
    const v = await readVersionFile(fixturesDir + "/package.json");
    expect(v).toEqual({ major: 2, minor: 5, patch: 0 });
  });

  test("throws for a nonexistent file", async () => {
    expect(readVersionFile("/tmp/no-such-file-xyz.txt")).rejects.toThrow();
  });
});

describe("writeVersionFile", () => {
  test("writes version to a plain text file", async () => {
    const tmp = "/tmp/semver-test-version.txt";
    await writeVersionFile(tmp, { major: 3, minor: 0, patch: 1 });
    const content = await Bun.file(tmp).text();
    expect(content.trim()).toBe("3.0.1");
  });

  test("writes version to a package.json preserving other fields", async () => {
    const tmp = "/tmp/semver-test-package.json";
    // Seed the file first
    await Bun.write(
      tmp,
      JSON.stringify({ name: "my-pkg", version: "0.0.0", private: true }, null, 2)
    );
    await writeVersionFile(tmp, { major: 1, minor: 0, patch: 0 });
    const parsed = JSON.parse(await Bun.file(tmp).text());
    expect(parsed.version).toBe("1.0.0");
    expect(parsed.name).toBe("my-pkg"); // preserved
    expect(parsed.private).toBe(true); // preserved
  });
});

// =============================================================================
// 5. Changelog generation
// =============================================================================
describe("generateChangelog", () => {
  test("produces a markdown changelog entry", () => {
    const classified = {
      major: [{ hash: "a1", message: "feat!: redesign auth" }],
      minor: [{ hash: "b1", message: "feat: add dark mode" }],
      patch: [{ hash: "c1", message: "fix: memory leak" }],
    };
    const log = generateChangelog("2.0.0", classified);
    // Should contain the version header
    expect(log).toContain("## 2.0.0");
    // Should have sections for each change type
    expect(log).toContain("Breaking Changes");
    expect(log).toContain("Features");
    expect(log).toContain("Bug Fixes");
    // Should list the commit messages
    expect(log).toContain("redesign auth");
    expect(log).toContain("add dark mode");
    expect(log).toContain("memory leak");
  });

  test("omits empty sections", () => {
    const classified = {
      major: [],
      minor: [],
      patch: [{ hash: "c1", message: "fix: typo" }],
    };
    const log = generateChangelog("1.0.1", classified);
    expect(log).not.toContain("Breaking Changes");
    expect(log).not.toContain("Features");
    expect(log).toContain("Bug Fixes");
  });
});

// =============================================================================
// 6. Integration: fixture file end-to-end
// =============================================================================
describe("integration: fixture-based end-to-end", () => {
  const fixturesDir = import.meta.dir + "/fixtures";

  test("patch-only commits bump patch version", async () => {
    const log = await Bun.file(fixturesDir + "/commits-patch.txt").text();
    const commits = parseCommitLog(log);
    const classified = classifyCommits(commits);
    const bump = determineBump(classified);
    expect(bump).toBe("patch");

    const current = await readVersionFile(fixturesDir + "/version.txt");
    const next = bumpVersion(current, bump!);
    expect(formatVersion(next)).toBe("1.2.4");
  });

  test("minor commits bump minor version", async () => {
    const log = await Bun.file(fixturesDir + "/commits-minor.txt").text();
    const commits = parseCommitLog(log);
    const classified = classifyCommits(commits);
    const bump = determineBump(classified);
    expect(bump).toBe("minor");

    const current = await readVersionFile(fixturesDir + "/package.json");
    const next = bumpVersion(current, bump!);
    expect(formatVersion(next)).toBe("2.6.0");
  });

  test("breaking commits bump major version", async () => {
    const log = await Bun.file(fixturesDir + "/commits-major.txt").text();
    const commits = parseCommitLog(log);
    const classified = classifyCommits(commits);
    const bump = determineBump(classified);
    expect(bump).toBe("major");

    const next = bumpVersion({ major: 1, minor: 9, patch: 5 }, bump!);
    expect(formatVersion(next)).toBe("2.0.0");
  });

  test("BREAKING CHANGE footer triggers major bump", async () => {
    const log = await Bun.file(
      fixturesDir + "/commits-breaking-footer.txt"
    ).text();
    const commits = parseCommitLog(log);
    const classified = classifyCommits(commits);
    expect(determineBump(classified)).toBe("major");
  });

  test("empty commit log means no bump needed", async () => {
    const log = await Bun.file(fixturesDir + "/commits-empty.txt").text();
    const commits = parseCommitLog(log);
    const classified = classifyCommits(commits);
    expect(determineBump(classified)).toBeNull();
  });
});
