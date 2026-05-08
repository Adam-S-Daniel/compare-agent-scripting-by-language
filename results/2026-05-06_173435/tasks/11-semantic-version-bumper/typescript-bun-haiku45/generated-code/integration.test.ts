import { describe, it, expect, beforeAll, afterAll } from "bun:test";
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from "fs";
import { join } from "path";
import {
  parseVersion,
  bumpVersion,
  readVersionFile,
  writeVersionFile,
  formatVersion,
} from "./semantic-version";
import { analyzeCommits, parseConventionalCommit } from "./conventional-commits";
import { generateChangelogEntry } from "./changelog";
import { testFixtures, expectedOutputs } from "./test-fixtures";

describe("Integration Tests", () => {
  let tempDir: string;

  beforeAll(() => {
    tempDir = mkdtempSync(join("/tmp", "semver-integration-"));
  });

  afterAll(() => {
    rmSync(tempDir, { recursive: true, force: true });
  });

  it("should handle complete patch bump workflow", () => {
    const pkgPath = join(tempDir, "package-patch.json");
    writeFileSync(pkgPath, JSON.stringify({ version: "1.0.0", name: "test" }));

    // Read current version
    const current = parseVersion(readVersionFile(pkgPath));

    // Analyze commits
    const analysis = analyzeCommits(testFixtures.patchOnly);
    expect(analysis.bumpType).toBe("patch");
    expect(analysis.commits.length).toBe(2);

    // Bump version
    const bumped = bumpVersion(current, analysis.bumpType);
    expect(formatVersion(bumped)).toBe("1.0.1");

    // Write new version
    writeVersionFile(pkgPath, formatVersion(bumped));
    const updated = readVersionFile(pkgPath);
    expect(updated).toBe("1.0.1");

    // Generate changelog
    const changelog = generateChangelogEntry(bumped, analysis.commits);
    expect(changelog).toContain("1.0.1");
    expect(changelog).toContain("Bug Fixes");
    expect(changelog).toContain("resolve null pointer exception");
  });

  it("should handle complete minor bump workflow", () => {
    const pkgPath = join(tempDir, "package-minor.json");
    writeFileSync(pkgPath, JSON.stringify({ version: "1.0.0" }));

    const current = parseVersion(readVersionFile(pkgPath));
    const analysis = analyzeCommits(testFixtures.minorWithFix);

    expect(analysis.bumpType).toBe("minor");
    expect(analysis.commits.length).toBe(3);

    const bumped = bumpVersion(current, analysis.bumpType);
    expect(formatVersion(bumped)).toBe("1.1.0");

    writeVersionFile(pkgPath, formatVersion(bumped));
    const updated = readVersionFile(pkgPath);
    expect(updated).toBe("1.1.0");

    const changelog = generateChangelogEntry(bumped, analysis.commits);
    expect(changelog).toContain("1.1.0");
    expect(changelog).toContain("Features");
    expect(changelog).toContain("add user authentication");
  });

  it("should handle complete major bump workflow with breaking changes", () => {
    const pkgPath = join(tempDir, "package-major.json");
    writeFileSync(pkgPath, JSON.stringify({ version: "1.0.0" }));

    const current = parseVersion(readVersionFile(pkgPath));
    const analysis = analyzeCommits(testFixtures.majorWithBreaking);

    expect(analysis.bumpType).toBe("major");

    const bumped = bumpVersion(current, analysis.bumpType);
    expect(formatVersion(bumped)).toBe("2.0.0");

    writeVersionFile(pkgPath, formatVersion(bumped));

    const changelog = generateChangelogEntry(bumped, analysis.commits);
    expect(changelog).toContain("2.0.0");
    expect(changelog).toContain("Breaking Changes");
    expect(changelog).toContain("redesign API contracts");
  });

  it("should handle mixed scopes correctly", () => {
    const pkgPath = join(tempDir, "package-mixed.json");
    writeFileSync(pkgPath, JSON.stringify({ version: "0.5.0" }));

    const current = parseVersion(readVersionFile(pkgPath));
    const analysis = analyzeCommits(testFixtures.mixedWithScopes);

    // Should be minor due to feat
    expect(analysis.bumpType).toBe("minor");

    const bumped = bumpVersion(current, analysis.bumpType);
    expect(formatVersion(bumped)).toBe("0.6.0");

    const changelog = generateChangelogEntry(bumped, analysis.commits);
    expect(changelog).toContain("frontend:");
    expect(changelog).toContain("backend:");
  });

  it("should handle empty commit log", () => {
    const pkgPath = join(tempDir, "package-empty.json");
    writeFileSync(pkgPath, JSON.stringify({ version: "1.5.0" }));

    const current = parseVersion(readVersionFile(pkgPath));
    const analysis = analyzeCommits(testFixtures.empty);

    // Should default to patch
    expect(analysis.bumpType).toBe("patch");

    const bumped = bumpVersion(current, analysis.bumpType);
    expect(formatVersion(bumped)).toBe("1.5.1");
  });

  it("should prioritize breaking changes over features", () => {
    const pkgPath = join(tempDir, "package-priority.json");
    writeFileSync(pkgPath, JSON.stringify({ version: "1.0.0" }));

    const current = parseVersion(readVersionFile(pkgPath));
    const analysis = analyzeCommits(testFixtures.multipleBreaking);

    expect(analysis.bumpType).toBe("major");
    expect(analysis.commits.some((c) => c.breaking)).toBe(true);

    const bumped = bumpVersion(current, analysis.bumpType);
    expect(formatVersion(bumped)).toBe("2.0.0");
  });

  it("should parse commits with various formats", () => {
    const formats = [
      "feat: simple feature",
      "feat(scope): feature with scope",
      "feat!: breaking change",
      "feat(scope)!: breaking with scope",
      "fix: bug fix",
      "chore: maintenance",
    ];

    for (const format of formats) {
      const commit = parseConventionalCommit(format);
      expect(commit.type).toBeTruthy();
      expect(commit.description).toBeTruthy();
    }
  });
});
