// Semantic version parsing, bumping, and formatting.
// A SemVer string has the form MAJOR.MINOR.PATCH (e.g. "1.2.3").

export interface SemVer {
  major: number;
  minor: number;
  patch: number;
}

export type BumpType = "major" | "minor" | "patch";

/** Parse a "MAJOR.MINOR.PATCH" string (with optional leading "v") into a SemVer. */
export function parseVersion(versionStr: string): SemVer {
  const cleaned = versionStr.trim().replace(/^v/, "");
  const match = cleaned.match(/^(\d+)\.(\d+)\.(\d+)$/);
  if (!match) {
    throw new Error(`Invalid semantic version: "${versionStr}"`);
  }
  return {
    major: parseInt(match[1], 10),
    minor: parseInt(match[2], 10),
    patch: parseInt(match[3], 10),
  };
}

/** Produce the next SemVer after applying a bump. */
export function bumpVersion(version: SemVer, bump: BumpType): SemVer {
  switch (bump) {
    case "major":
      return { major: version.major + 1, minor: 0, patch: 0 };
    case "minor":
      return { major: version.major, minor: version.minor + 1, patch: 0 };
    case "patch":
      return { major: version.major, minor: version.minor, patch: version.patch + 1 };
  }
}

/** Format a SemVer back into "MAJOR.MINOR.PATCH". */
export function formatVersion(version: SemVer): string {
  return `${version.major}.${version.minor}.${version.patch}`;
}
