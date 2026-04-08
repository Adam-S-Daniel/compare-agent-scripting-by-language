// Core version parsing, formatting, and bumping logic

import type { SemanticVersion, BumpType } from "./types";

const SEMVER_REGEX = /^v?(\d+)\.(\d+)\.(\d+)$/;

/** Parse a semver string like "1.2.3" or "v1.2.3" into its components */
export function parseVersion(version: string): SemanticVersion {
  const match = version.trim().match(SEMVER_REGEX);
  if (!match) {
    throw new Error(`Invalid semantic version: "${version}"`);
  }
  return {
    major: parseInt(match[1], 10),
    minor: parseInt(match[2], 10),
    patch: parseInt(match[3], 10),
  };
}

/** Format a SemanticVersion object back to a string */
export function formatVersion(v: SemanticVersion): string {
  return `${v.major}.${v.minor}.${v.patch}`;
}

/** Apply a bump type to a version, returning a new version object */
export function bumpVersion(v: SemanticVersion, bump: BumpType): SemanticVersion {
  switch (bump) {
    case "major":
      return { major: v.major + 1, minor: 0, patch: 0 };
    case "minor":
      return { major: v.major, minor: v.minor + 1, patch: 0 };
    case "patch":
      return { major: v.major, minor: v.minor, patch: v.patch + 1 };
  }
}
