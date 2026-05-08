// TDD test suite for semantic version bumper
// Written BEFORE the implementation (red phase)
import { describe, test, expect } from "bun:test";
import {
  parseVersion,
  parseCommit,
  determineBumpType,
  bumpVersion,
  generateChangelog,
  formatVersion,
  readVersionFromFile,
  writeVersionToFile,
} from "./version-bumper";
import type { SemanticVersion, ConventionalCommit, BumpType } from "./types";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";

// --- parseVersion ---

describe("parseVersion", () => {
  test("parses simple semver string", () => {
    const v = parseVersion("1.0.0");
    expect(v).toEqual({ major: 1, minor: 0, patch: 0 });
  });

  test("parses multi-digit semver", () => {
    const v = parseVersion("2.13.7");
    expect(v).toEqual({ major: 2, minor: 13, patch: 7 });
  });

  test("throws on invalid version string", () => {
    expect(() => parseVersion("not-a-version")).toThrow();
  });

  test("throws on missing patch component", () => {
    expect(() => parseVersion("1.0")).toThrow();
  });

  test("strips leading v prefix", () => {
    const v = parseVersion("v1.2.3");
    expect(v).toEqual({ major: 1, minor: 2, patch: 3 });
  });
});

// --- parseCommit ---

describe("parseCommit", () => {
  test("parses feat commit", () => {
    const c = parseCommit("feat: add login page");
    expect(c.type).toBe("feat");
    expect(c.description).toBe("add login page");
    expect(c.isBreaking).toBe(false);
    expect(c.scope).toBeUndefined();
  });

  test("parses fix commit with scope", () => {
    const c = parseCommit("fix(auth): fix token expiry");
    expect(c.type).toBe("fix");
    expect(c.scope).toBe("auth");
    expect(c.description).toBe("fix token expiry");
    expect(c.isBreaking).toBe(false);
  });

  test("parses breaking change via ! notation", () => {
    const c = parseCommit("feat!: remove deprecated API");
    expect(c.type).toBe("feat");
    expect(c.isBreaking).toBe(true);
  });

  test("parses breaking change with scope and !", () => {
    const c = parseCommit("refactor(api)!: restructure endpoints");
    expect(c.type).toBe("refactor");
    expect(c.scope).toBe("api");
    expect(c.isBreaking).toBe(true);
  });

  test("parses BREAKING CHANGE footer", () => {
    const c = parseCommit("fix: update config\n\nBREAKING CHANGE: config format changed");
    expect(c.isBreaking).toBe(true);
  });

  test("preserves raw commit message", () => {
    const raw = "feat: add feature";
    const c = parseCommit(raw);
    expect(c.raw).toBe(raw);
  });

  test("parses chore commit as non-breaking", () => {
    const c = parseCommit("chore: update deps");
    expect(c.type).toBe("chore");
    expect(c.isBreaking).toBe(false);
  });

  test("handles non-conventional commit gracefully", () => {
    // Non-conventional commits should parse with type 'other'
    const c = parseCommit("update readme and fix stuff");
    expect(c.type).toBe("other");
    expect(c.isBreaking).toBe(false);
  });
});

// --- determineBumpType ---

describe("determineBumpType", () => {
  const makeCommit = (type: string, isBreaking = false): ConventionalCommit => ({
    type,
    description: "test",
    isBreaking,
    raw: `${type}: test`,
  });

  test("fix commits produce patch bump", () => {
    expect(determineBumpType([makeCommit("fix")])).toBe("patch");
  });

  test("feat commits produce minor bump", () => {
    expect(determineBumpType([makeCommit("feat")])).toBe("minor");
  });

  test("breaking commits produce major bump", () => {
    expect(determineBumpType([makeCommit("feat", true)])).toBe("major");
  });

  test("mixed commits take highest bump type", () => {
    expect(determineBumpType([makeCommit("fix"), makeCommit("feat")])).toBe("minor");
  });

  test("breaking overrides everything", () => {
    expect(determineBumpType([makeCommit("fix"), makeCommit("feat", true)])).toBe("major");
  });

  test("empty commits produce no bump", () => {
    expect(determineBumpType([])).toBe("none");
  });

  test("chore/docs commits produce no version bump", () => {
    expect(determineBumpType([makeCommit("chore"), makeCommit("docs")])).toBe("none");
  });
});

// --- bumpVersion ---

describe("bumpVersion", () => {
  const v100: SemanticVersion = { major: 1, minor: 0, patch: 0 };
  const v123: SemanticVersion = { major: 1, minor: 2, patch: 3 };

  test("patch bump increments patch", () => {
    expect(bumpVersion(v100, "patch")).toEqual({ major: 1, minor: 0, patch: 1 });
  });

  test("minor bump increments minor and resets patch", () => {
    expect(bumpVersion(v123, "minor")).toEqual({ major: 1, minor: 3, patch: 0 });
  });

  test("major bump increments major and resets minor and patch", () => {
    expect(bumpVersion(v123, "major")).toEqual({ major: 2, minor: 0, patch: 0 });
  });

  test("none bump returns same version", () => {
    expect(bumpVersion(v123, "none")).toEqual(v123);
  });

  test("does not mutate input", () => {
    const original = { ...v123 };
    bumpVersion(v123, "major");
    expect(v123).toEqual(original);
  });
});

// --- formatVersion ---

describe("formatVersion", () => {
  test("formats version as semver string", () => {
    expect(formatVersion({ major: 1, minor: 2, patch: 3 })).toBe("1.2.3");
  });

  test("formats zero version", () => {
    expect(formatVersion({ major: 0, minor: 0, patch: 0 })).toBe("0.0.0");
  });
});

// --- generateChangelog ---

describe("generateChangelog", () => {
  const commits: ConventionalCommit[] = [
    { type: "feat", description: "add dark mode", isBreaking: false, raw: "feat: add dark mode" },
    { type: "fix", description: "fix login bug", isBreaking: false, raw: "fix: fix login bug", scope: "auth" },
    { type: "feat", description: "remove legacy API", isBreaking: true, raw: "feat!: remove legacy API" },
    { type: "chore", description: "update deps", isBreaking: false, raw: "chore: update deps" },
  ];

  test("includes version in entry", () => {
    const entry = generateChangelog(commits, "2.0.0", "2026-01-01");
    expect(entry.version).toBe("2.0.0");
  });

  test("includes date in entry", () => {
    const entry = generateChangelog(commits, "2.0.0", "2026-01-01");
    expect(entry.date).toBe("2026-01-01");
  });

  test("separates features", () => {
    const entry = generateChangelog(commits, "2.0.0", "2026-01-01");
    expect(entry.features).toContain("add dark mode");
  });

  test("separates fixes", () => {
    const entry = generateChangelog(commits, "2.0.0", "2026-01-01");
    expect(entry.fixes.some(f => f.includes("fix login bug"))).toBe(true);
  });

  test("separates breaking changes", () => {
    const entry = generateChangelog(commits, "2.0.0", "2026-01-01");
    expect(entry.breaking).toContain("remove legacy API");
  });

  test("puts non-feat/fix in other", () => {
    const entry = generateChangelog(commits, "2.0.0", "2026-01-01");
    expect(entry.other.some(o => o.includes("update deps"))).toBe(true);
  });
});

// --- readVersionFromFile / writeVersionToFile ---

describe("readVersionFromFile", () => {
  test("reads version from package.json", () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "ver-test-"));
    const pkgPath = path.join(tmpDir, "package.json");
    fs.writeFileSync(pkgPath, JSON.stringify({ version: "3.4.5" }));
    const v = readVersionFromFile(pkgPath);
    expect(v).toEqual({ major: 3, minor: 4, patch: 5 });
  });

  test("reads version from plain version.json", () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "ver-test-"));
    const vPath = path.join(tmpDir, "version.json");
    fs.writeFileSync(vPath, JSON.stringify({ version: "1.2.3" }));
    const v = readVersionFromFile(vPath);
    expect(v).toEqual({ major: 1, minor: 2, patch: 3 });
  });

  test("throws if file does not exist", () => {
    expect(() => readVersionFromFile("/nonexistent/path/package.json")).toThrow();
  });
});

describe("writeVersionToFile", () => {
  test("updates version in package.json", () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "ver-test-"));
    const pkgPath = path.join(tmpDir, "package.json");
    fs.writeFileSync(pkgPath, JSON.stringify({ name: "my-app", version: "1.0.0" }));
    writeVersionToFile(pkgPath, { major: 2, minor: 0, patch: 0 });
    const updated = JSON.parse(fs.readFileSync(pkgPath, "utf-8"));
    expect(updated.version).toBe("2.0.0");
    // preserves other fields
    expect(updated.name).toBe("my-app");
  });
});
