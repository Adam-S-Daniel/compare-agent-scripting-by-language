/**
 * Semantic version parsing, formatting, and bumping.
 * Handles versions in the format "major.minor.patch" (e.g., "1.2.3").
 */

/** A parsed semantic version with major, minor, and patch components */
export interface SemanticVersion {
  major: number;
  minor: number;
  patch: number;
}

/** The type of version bump to apply */
export type BumpType = "major" | "minor" | "patch" | "none";

/** Parse a version string like "1.2.3" or "v1.2.3" into a SemanticVersion */
export function parseVersion(versionStr: string): SemanticVersion {
  const trimmed = versionStr.trim().replace(/^v/, "");
  const parts = trimmed.split(".");

  if (parts.length !== 3) {
    throw new Error(
      `Invalid version format: "${versionStr}". Expected "major.minor.patch"`,
    );
  }

  const [major, minor, patch] = parts.map(Number);

  if ([major, minor, patch].some(isNaN)) {
    throw new Error(
      `Invalid version format: "${versionStr}". Version parts must be numbers`,
    );
  }

  return { major, minor, patch };
}

/** Format a SemanticVersion back to a string like "1.2.3" */
export function formatVersion(version: SemanticVersion): string {
  return `${version.major}.${version.minor}.${version.patch}`;
}

/** Apply a bump type to a version and return the new version */
export function bumpVersion(
  version: SemanticVersion,
  bump: BumpType,
): SemanticVersion {
  switch (bump) {
    case "major":
      return { major: version.major + 1, minor: 0, patch: 0 };
    case "minor":
      return { major: version.major, minor: version.minor + 1, patch: 0 };
    case "patch":
      return {
        major: version.major,
        minor: version.minor,
        patch: version.patch + 1,
      };
    case "none":
      return { ...version };
  }
}
