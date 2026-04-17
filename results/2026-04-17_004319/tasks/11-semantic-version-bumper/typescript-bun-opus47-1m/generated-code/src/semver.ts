// Semantic version parsing and bumping.
//
// A Version is represented as a struct of three unsigned integers. Only the
// major/minor/patch triplet is supported here — pre-release and build metadata
// are intentionally out of scope for this bumper.

export interface Version {
  major: number;
  minor: number;
  patch: number;
}

export type BumpType = "major" | "minor" | "patch" | "none";

const SEMVER_RE = /^v?(\d+)\.(\d+)\.(\d+)$/;

export function parseVersion(raw: string): Version {
  const match = SEMVER_RE.exec(raw.trim());
  if (!match) {
    throw new Error(`Invalid semver string: "${raw}"`);
  }
  // Capture groups are guaranteed by the regex above; Number is safe here.
  return {
    major: Number(match[1]),
    minor: Number(match[2]),
    patch: Number(match[3]),
  };
}

export function formatVersion(v: Version): string {
  return `${v.major}.${v.minor}.${v.patch}`;
}

export function bumpVersion(v: Version, bump: BumpType): Version {
  switch (bump) {
    case "major":
      return { major: v.major + 1, minor: 0, patch: 0 };
    case "minor":
      return { major: v.major, minor: v.minor + 1, patch: 0 };
    case "patch":
      return { major: v.major, minor: v.minor, patch: v.patch + 1 };
    case "none":
      return { ...v };
  }
}
