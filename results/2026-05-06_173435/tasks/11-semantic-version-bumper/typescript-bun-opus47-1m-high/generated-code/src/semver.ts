// Minimal semver utilities. Only major.minor.patch — no pre-release/build metadata,
// since this script is scoped to package versioning driven by conventional commits.

export interface Version {
  major: number;
  minor: number;
  patch: number;
}

export type BumpKind = "major" | "minor" | "patch" | "none";

const SEMVER_RE = /^v?(\d+)\.(\d+)\.(\d+)$/;

export function parseVersion(input: string): Version {
  const match = SEMVER_RE.exec(input.trim());
  if (!match) {
    throw new Error(`Invalid semver string: ${JSON.stringify(input)}`);
  }
  return {
    major: Number(match[1]),
    minor: Number(match[2]),
    patch: Number(match[3]),
  };
}

export function formatVersion(v: Version): string {
  return `${v.major}.${v.minor}.${v.patch}`;
}

export function bumpVersion(v: Version, kind: BumpKind): Version {
  switch (kind) {
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
