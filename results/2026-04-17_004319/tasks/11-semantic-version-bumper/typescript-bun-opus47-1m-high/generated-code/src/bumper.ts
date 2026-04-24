// Semver bumping logic driven by a list of parsed conventional commits.
// The precedence is major > minor > patch > none.
import type { Commit } from "./parser";

export type BumpType = "major" | "minor" | "patch" | "none";

export interface Semver {
  major: number;
  minor: number;
  patch: number;
}

const SEMVER_RE = /^v?(\d+)\.(\d+)\.(\d+)$/;

export function parseSemver(version: string): Semver {
  const m = SEMVER_RE.exec(version.trim());
  if (!m) {
    throw new Error(`Invalid semver: '${version}'`);
  }
  return {
    major: Number.parseInt(m[1]!, 10),
    minor: Number.parseInt(m[2]!, 10),
    patch: Number.parseInt(m[3]!, 10),
  };
}

// Walk all commits and pick the highest-priority bump.
// A single breaking change is enough to force major.
export function determineBumpType(commits: readonly Commit[]): BumpType {
  let result: BumpType = "none";
  for (const c of commits) {
    if (c.breaking) return "major";
    if (c.type === "feat" && result !== "major") {
      result = "minor";
    } else if (c.type === "fix" && result === "none") {
      result = "patch";
    }
  }
  return result;
}

export function bumpVersion(version: string, type: BumpType): string {
  const { major, minor, patch } = parseSemver(version);
  switch (type) {
    case "major":
      return `${major + 1}.0.0`;
    case "minor":
      return `${major}.${minor + 1}.0`;
    case "patch":
      return `${major}.${minor}.${patch + 1}`;
    case "none":
      return `${major}.${minor}.${patch}`;
  }
}
