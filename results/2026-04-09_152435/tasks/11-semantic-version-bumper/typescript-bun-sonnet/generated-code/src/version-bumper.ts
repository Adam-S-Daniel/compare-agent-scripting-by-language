/**
 * Semantic Version Bumper
 *
 * Implements conventional-commits-based semantic versioning:
 * - "fix:" prefix  → patch bump (1.0.0 → 1.0.1)
 * - "feat:" prefix → minor bump (1.0.0 → 1.1.0)
 * - "type!:" or "BREAKING CHANGE:" → major bump (1.0.0 → 2.0.0)
 *
 * Usage (CLI):
 *   bun run src/version-bumper.ts fixtures/test-case-1.json
 *
 * The test-case JSON format:
 * {
 *   "currentVersion": "1.0.0",
 *   "commits": [ { "hash": "abc1234", "message": "fix: ...", "author": "...", "date": "..." } ]
 * }
 */

// ─── Types ────────────────────────────────────────────────────────────────────

export interface SemanticVersion {
  major: number;
  minor: number;
  patch: number;
}

export interface Commit {
  hash: string;
  message: string;
  author: string;
  date: string;
}

export interface TestCase {
  currentVersion: string;
  commits: Commit[];
  expectedNewVersion?: string; // Optional: for assertion in CI
}

export type BumpType = "major" | "minor" | "patch" | "none";

// ─── parseVersion ─────────────────────────────────────────────────────────────

/**
 * Parse a "X.Y.Z" semver string into a SemanticVersion object.
 * Throws a clear error for malformed strings.
 */
export function parseVersion(versionString: string): SemanticVersion {
  const match = versionString.match(/^(\d+)\.(\d+)\.(\d+)$/);
  if (!match) {
    throw new Error(`Invalid version string: "${versionString}" (expected X.Y.Z format)`);
  }
  return {
    major: parseInt(match[1], 10),
    minor: parseInt(match[2], 10),
    patch: parseInt(match[3], 10),
  };
}

// ─── formatVersion ────────────────────────────────────────────────────────────

/**
 * Format a SemanticVersion object into "X.Y.Z" string.
 */
export function formatVersion(version: SemanticVersion): string {
  return `${version.major}.${version.minor}.${version.patch}`;
}

// ─── determineBumpType ────────────────────────────────────────────────────────

/**
 * Analyze an array of conventional commits to determine the highest bump type.
 *
 * Conventional commit rules:
 * - "fix:"   or "fix(scope):"   → patch
 * - "feat:"  or "feat(scope):"  → minor
 * - "type!:" or body contains "BREAKING CHANGE:" → major (immediate return)
 *
 * Priority: major > minor > patch > none
 */
export function determineBumpType(commits: Commit[]): BumpType {
  let bumpType: BumpType = "none";

  for (const commit of commits) {
    const msg = commit.message;

    // Breaking change: type followed by "!" OR "BREAKING CHANGE:" in body
    // Check this first since it short-circuits (major always wins)
    if (/^[a-z]+(\([^)]+\))?!:/.test(msg) || msg.includes("BREAKING CHANGE:")) {
      return "major";
    }

    // feat (with or without scope) → minor
    if (/^feat(\([^)]+\))?:/.test(msg)) {
      bumpType = "minor";
      continue;
    }

    // fix (with or without scope) → patch (only if we haven't found minor yet)
    if (/^fix(\([^)]+\))?:/.test(msg) && bumpType === "none") {
      bumpType = "patch";
    }
  }

  return bumpType;
}

// ─── bumpVersion ──────────────────────────────────────────────────────────────

/**
 * Apply a bump type to a version, following semver rules:
 * - major: increment major, reset minor+patch to 0
 * - minor: increment minor, reset patch to 0
 * - patch: increment patch
 * - none: return version unchanged
 */
export function bumpVersion(version: SemanticVersion, bumpType: BumpType): SemanticVersion {
  switch (bumpType) {
    case "major":
      return { major: version.major + 1, minor: 0, patch: 0 };
    case "minor":
      return { major: version.major, minor: version.minor + 1, patch: 0 };
    case "patch":
      return { major: version.major, minor: version.minor, patch: version.patch + 1 };
    case "none":
      return { ...version };
  }
}

// ─── generateChangelog ────────────────────────────────────────────────────────

/**
 * Generate a markdown changelog entry from commits for the given new version.
 * Groups commits into: Breaking Changes, Features, Bug Fixes, Other.
 */
export function generateChangelog(commits: Commit[], newVersion: string): string {
  const date = new Date().toISOString().split("T")[0];
  const lines: string[] = [`## [${newVersion}] - ${date}`, ""];

  const breaking: string[] = [];
  const features: string[] = [];
  const fixes: string[] = [];
  const other: string[] = [];

  for (const commit of commits) {
    const msg = commit.message;
    // Use first 7 chars of hash for brevity (like git log --abbrev)
    const shortHash = commit.hash.slice(0, 7);
    const entry = `- ${msg.split("\n")[0]} (${shortHash})`;

    if (/^[a-z]+(\([^)]+\))?!:/.test(msg) || msg.includes("BREAKING CHANGE:")) {
      breaking.push(entry);
    } else if (/^feat(\([^)]+\))?:/.test(msg)) {
      features.push(entry);
    } else if (/^fix(\([^)]+\))?:/.test(msg)) {
      fixes.push(entry);
    } else {
      other.push(entry);
    }
  }

  if (breaking.length > 0) {
    lines.push("### Breaking Changes");
    lines.push(...breaking);
    lines.push("");
  }
  if (features.length > 0) {
    lines.push("### Features");
    lines.push(...features);
    lines.push("");
  }
  if (fixes.length > 0) {
    lines.push("### Bug Fixes");
    lines.push(...fixes);
    lines.push("");
  }
  if (other.length > 0) {
    lines.push("### Other");
    lines.push(...other);
    lines.push("");
  }

  return lines.join("\n");
}

// ─── CLI Entry Point ──────────────────────────────────────────────────────────

/**
 * When run directly with `bun run src/version-bumper.ts <test-case-file>`:
 * - Reads the test case JSON file
 * - Determines the new version from commits
 * - Prints: NEW_VERSION: X.Y.Z
 * - Prints the changelog entry
 * - Exits with non-zero if expected version doesn't match
 */
if (import.meta.main) {
  const testCaseFile = Bun.argv[2];

  if (!testCaseFile) {
    console.error("Usage: bun run src/version-bumper.ts <test-case-file.json>");
    console.error("  The JSON file must have: { currentVersion, commits, expectedNewVersion? }");
    process.exit(1);
  }

  const file = Bun.file(testCaseFile);
  const exists = await file.exists();
  if (!exists) {
    console.error(`Error: File not found: ${testCaseFile}`);
    process.exit(1);
  }

  const testCase: TestCase = await file.json();

  // Validate input
  if (!testCase.currentVersion) {
    console.error("Error: testCase.currentVersion is required");
    process.exit(1);
  }
  if (!Array.isArray(testCase.commits)) {
    console.error("Error: testCase.commits must be an array");
    process.exit(1);
  }

  const version = parseVersion(testCase.currentVersion);
  const bumpType = determineBumpType(testCase.commits);
  const newVersion = bumpVersion(version, bumpType);
  const newVersionStr = formatVersion(newVersion);
  const changelog = generateChangelog(testCase.commits, newVersionStr);

  // Structured output that the workflow can grep for
  console.log(`NEW_VERSION: ${newVersionStr}`);
  console.log(`BUMP_TYPE: ${bumpType}`);
  console.log("");
  console.log("CHANGELOG:");
  console.log(changelog);

  // Optional: assert expected version matches if provided in fixture
  if (testCase.expectedNewVersion !== undefined) {
    if (newVersionStr !== testCase.expectedNewVersion) {
      console.error(
        `ERROR: Version mismatch! Expected ${testCase.expectedNewVersion}, got ${newVersionStr}`
      );
      process.exit(1);
    }
    console.log(`ASSERTION PASSED: ${testCase.expectedNewVersion}`);
  }
}
