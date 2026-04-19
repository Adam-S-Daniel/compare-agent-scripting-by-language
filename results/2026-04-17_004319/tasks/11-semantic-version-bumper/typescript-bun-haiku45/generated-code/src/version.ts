// Represents a parsed semantic version
interface SemanticVersion {
  major: number;
  minor: number;
  patch: number;
}

// Parses a semantic version string (major.minor.patch)
// Throws if the format is invalid
export function parseVersion(versionString: string): SemanticVersion {
  const match = versionString.match(/^(\d+)\.(\d+)\.(\d+)$/);
  if (!match) {
    throw new Error(`Invalid semantic version format: "${versionString}"`);
  }
  return {
    major: parseInt(match[1], 10),
    minor: parseInt(match[2], 10),
    patch: parseInt(match[3], 10),
  };
}
