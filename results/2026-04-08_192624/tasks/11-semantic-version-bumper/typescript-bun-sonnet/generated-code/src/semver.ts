/**
 * Semantic Version Bumper - Core Version Logic
 *
 * Handles parsing, bumping, and version string formatting.
 * Follows SemVer 2.0.0 specification.
 */

import type { Commit } from "./changelog";

// ============================================================
// Types & Interfaces
// ============================================================

export interface SemanticVersion {
  major: number;
  minor: number;
  patch: number;
}

export enum BumpType {
  PATCH = "patch",
  MINOR = "minor",
  MAJOR = "major",
}

// ============================================================
// parseVersion: Parse a semver string into a structured object
// ============================================================

export function parseVersion(versionStr: string): SemanticVersion {
  // Strip leading 'v' prefix if present (e.g., "v1.2.3" -> "1.2.3")
  const cleaned = versionStr.startsWith("v") ? versionStr.slice(1) : versionStr;

  const parts = cleaned.split(".");
  if (parts.length !== 3) {
    throw new Error(`Invalid semantic version: ${versionStr}`);
  }

  const [majorStr, minorStr, patchStr] = parts;
  const major = parseInt(majorStr, 10);
  const minor = parseInt(minorStr, 10);
  const patch = parseInt(patchStr, 10);

  if (isNaN(major) || isNaN(minor) || isNaN(patch)) {
    throw new Error(`Invalid semantic version: ${versionStr}`);
  }

  return { major, minor, patch };
}

// ============================================================
// bumpVersion: Apply a bump type and return the new version string
// ============================================================

export function bumpVersion(current: SemanticVersion, bump: BumpType): string {
  switch (bump) {
    case BumpType.MAJOR:
      // Major bump: reset minor and patch to 0
      return `${current.major + 1}.0.0`;
    case BumpType.MINOR:
      // Minor bump: reset patch to 0, keep major
      return `${current.major}.${current.minor + 1}.0`;
    case BumpType.PATCH:
      // Patch bump: only increment patch
      return `${current.major}.${current.minor}.${current.patch + 1}`;
  }
}

// ============================================================
// determineVersionBump: Analyze commits to pick bump type
//
// Rules (highest precedence wins):
//   breaking change (! or BREAKING CHANGE) -> MAJOR
//   feat -> MINOR
//   fix, chore, docs, style, test, refactor -> PATCH
// ============================================================

export function determineVersionBump(commits: Commit[]): BumpType {
  let bump = BumpType.PATCH; // default

  for (const commit of commits) {
    if (commit.breaking) {
      // Breaking change always wins - short-circuit
      return BumpType.MAJOR;
    }
    if (commit.type === "feat") {
      // Feat promotes to at least minor
      bump = BumpType.MINOR;
    }
    // fix and others keep current bump level
  }

  return bump;
}
