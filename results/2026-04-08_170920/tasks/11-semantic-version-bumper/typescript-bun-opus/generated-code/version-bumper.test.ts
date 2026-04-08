// TDD tests for semantic version bumper.
// Each section starts as a failing test, then code is written to make it pass.

import { describe, test, expect } from "bun:test";
import {
  parseCommit,
  determineBumpType,
  bumpVersion,
  parseVersion,
  generateChangelog,
  readVersionFromPackageJson,
  writeVersionToPackageJson,
} from "./version-bumper";
import {
  PATCH_ONLY_COMMITS,
  MINOR_COMMITS,
  MAJOR_COMMITS_FOOTER,
  MAJOR_COMMITS_BANG,
  NO_CONVENTIONAL_COMMITS,
  MIXED_COMMITS,
  ALL_FIXTURES,
} from "./fixtures/commits";
import { mkdtemp, rm, writeFile, readFile } from "fs/promises";
import { tmpdir } from "os";
import { join } from "path";

// ─── 1. Commit parsing ───────────────────────────────────────────────

describe("parseCommit", () => {
  test("parses a fix commit", () => {
    const result = parseCommit("abc1234 fix: resolve null pointer in user lookup");
    expect(result).toEqual({
      hash: "abc1234",
      type: "fix",
      scope: undefined,
      breaking: false,
      description: "resolve null pointer in user lookup",
    });
  });

  test("parses a feat commit with scope", () => {
    const result = parseCommit("ccc3333 feat(api): support pagination in list responses");
    expect(result).toEqual({
      hash: "ccc3333",
      type: "feat",
      scope: "api",
      breaking: false,
      description: "support pagination in list responses",
    });
  });

  test("parses a breaking change with bang", () => {
    const result = parseCommit("fff6666 feat!: remove deprecated v1 endpoints");
    expect(result).toEqual({
      hash: "fff6666",
      type: "feat",
      scope: undefined,
      breaking: true,
      description: "remove deprecated v1 endpoints",
    });
  });

  test("parses a breaking change in footer", () => {
    const result = parseCommit(
      "ddd4444 feat: redesign authentication flow\n\nBREAKING CHANGE: token format changed from JWT to opaque"
    );
    expect(result).toEqual({
      hash: "ddd4444",
      type: "feat",
      scope: undefined,
      breaking: true,
      description: "redesign authentication flow",
    });
  });

  test("returns null for non-conventional commits", () => {
    const result = parseCommit("hhh8888 update readme");
    expect(result).toBeNull();
  });
});

// ─── 2. Version parsing ──────────────────────────────────────────────

describe("parseVersion", () => {
  test("parses a standard semver string", () => {
    expect(parseVersion("1.2.3")).toEqual({ major: 1, minor: 2, patch: 3 });
  });

  test("parses version with v prefix", () => {
    expect(parseVersion("v2.0.1")).toEqual({ major: 2, minor: 0, patch: 1 });
  });

  test("throws on invalid version string", () => {
    expect(() => parseVersion("not-a-version")).toThrow();
  });
});

// ─── 3. Bump type determination ──────────────────────────────────────

describe("determineBumpType", () => {
  test("returns patch for fix-only commits", () => {
    expect(determineBumpType(PATCH_ONLY_COMMITS.commits)).toBe("patch");
  });

  test("returns minor when feat commits present", () => {
    expect(determineBumpType(MINOR_COMMITS.commits)).toBe("minor");
  });

  test("returns major for BREAKING CHANGE footer", () => {
    expect(determineBumpType(MAJOR_COMMITS_FOOTER.commits)).toBe("major");
  });

  test("returns major for bang notation", () => {
    expect(determineBumpType(MAJOR_COMMITS_BANG.commits)).toBe("major");
  });

  test("returns none for non-conventional commits", () => {
    expect(determineBumpType(NO_CONVENTIONAL_COMMITS.commits)).toBe("none");
  });

  test("returns minor for mixed commits with feat", () => {
    expect(determineBumpType(MIXED_COMMITS.commits)).toBe("minor");
  });

  // Validate all fixtures match their expected bump type
  for (const fixture of ALL_FIXTURES) {
    test(`fixture "${fixture.name}" matches expected bump type: ${fixture.expectedBumpType}`, () => {
      expect(determineBumpType(fixture.commits)).toBe(fixture.expectedBumpType);
    });
  }
});

// ─── 4. Version bumping ─────────────────────────────────────────────

describe("bumpVersion", () => {
  test("bumps patch version", () => {
    expect(bumpVersion("1.2.3", "patch")).toBe("1.2.4");
  });

  test("bumps minor version and resets patch", () => {
    expect(bumpVersion("1.2.3", "minor")).toBe("1.3.0");
  });

  test("bumps major version and resets minor and patch", () => {
    expect(bumpVersion("1.2.3", "major")).toBe("2.0.0");
  });

  test("returns same version for none", () => {
    expect(bumpVersion("1.2.3", "none")).toBe("1.2.3");
  });

  test("handles v prefix", () => {
    expect(bumpVersion("v1.0.0", "minor")).toBe("1.1.0");
  });
});

// ─── 5. Changelog generation ────────────────────────────────────────

describe("generateChangelog", () => {
  test("generates changelog from commits", () => {
    const changelog = generateChangelog("1.3.0", MINOR_COMMITS.commits);
    expect(changelog).toContain("## 1.3.0");
    expect(changelog).toContain("### Features");
    expect(changelog).toContain("add user search endpoint");
    expect(changelog).toContain("### Bug Fixes");
    expect(changelog).toContain("handle empty query strings");
  });

  test("includes scope in parentheses", () => {
    const changelog = generateChangelog("1.3.0", MINOR_COMMITS.commits);
    expect(changelog).toContain("**api:**");
  });

  test("marks breaking changes", () => {
    const changelog = generateChangelog("2.0.0", MAJOR_COMMITS_BANG.commits);
    expect(changelog).toContain("BREAKING");
  });
});

// ─── 6. Package.json read/write ──────────────────────────────────────

describe("package.json integration", () => {
  let tempDir: string;

  test("reads version from package.json", async () => {
    tempDir = await mkdtemp(join(tmpdir(), "bumper-test-"));
    const pkgPath = join(tempDir, "package.json");
    await writeFile(pkgPath, JSON.stringify({ name: "test", version: "1.2.3" }));
    const version = await readVersionFromPackageJson(pkgPath);
    expect(version).toBe("1.2.3");
    await rm(tempDir, { recursive: true });
  });

  test("writes version to package.json", async () => {
    tempDir = await mkdtemp(join(tmpdir(), "bumper-test-"));
    const pkgPath = join(tempDir, "package.json");
    await writeFile(
      pkgPath,
      JSON.stringify({ name: "test", version: "1.2.3" }, null, 2)
    );
    await writeVersionToPackageJson(pkgPath, "1.3.0");
    const raw = await readFile(pkgPath, "utf-8");
    const pkg = JSON.parse(raw);
    expect(pkg.version).toBe("1.3.0");
    await rm(tempDir, { recursive: true });
  });

  test("throws on missing package.json", async () => {
    await expect(readVersionFromPackageJson("/nonexistent/package.json")).rejects.toThrow();
  });

  test("throws on package.json without version", async () => {
    tempDir = await mkdtemp(join(tmpdir(), "bumper-test-"));
    const pkgPath = join(tempDir, "package.json");
    await writeFile(pkgPath, JSON.stringify({ name: "test" }));
    await expect(readVersionFromPackageJson(pkgPath)).rejects.toThrow("no version field");
    await rm(tempDir, { recursive: true });
  });
});
