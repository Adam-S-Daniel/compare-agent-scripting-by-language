import { parseVersion } from "./version";

// Represents types of commits based on conventional commits
export enum CommitType {
  FIX = "fix",
  FEAT = "feat",
  BREAKING = "breaking",
  CHORE = "chore",
}

// Determines the next semantic version based on commit types
// Priority: BREAKING > FEAT > FIX > CHORE
export function determineNextVersion(
  currentVersion: string,
  commits: CommitType[]
): string {
  const version = parseVersion(currentVersion);

  // Determine the highest priority change
  let isMajor = false;
  let isMinor = false;
  let isPatch = false;

  for (const commit of commits) {
    if (commit === CommitType.BREAKING) {
      isMajor = true;
    } else if (commit === CommitType.FEAT && !isMajor) {
      isMinor = true;
    } else if (commit === CommitType.FIX && !isMajor && !isMinor) {
      isPatch = true;
    }
  }

  // Calculate next version
  if (isMajor) {
    return `${version.major + 1}.0.0`;
  } else if (isMinor) {
    return `${version.major}.${version.minor + 1}.0`;
  } else if (isPatch) {
    return `${version.major}.${version.minor}.${version.patch + 1}`;
  }

  // No changes
  return currentVersion;
}
