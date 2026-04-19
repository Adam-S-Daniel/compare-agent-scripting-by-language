// Parses a semantic version string (with optional 'v' prefix) into major, minor, patch
function parseVersion(versionStr) {
  const match = versionStr.match(/^v?(\d+)\.(\d+)\.(\d+)$/);
  if (!match) {
    throw new Error(`Invalid version format: ${versionStr}. Expected format: x.y.z or vx.y.z`);
  }
  return {
    major: parseInt(match[1], 10),
    minor: parseInt(match[2], 10),
    patch: parseInt(match[3], 10),
  };
}

// Determines the type of version bump based on conventional commit messages
// Returns 'major' for breaking changes, 'minor' for features, 'patch' for fixes, 'none' for others
function determineVersionBump(commits) {
  let hasBreaking = false;
  let hasFeature = false;
  let hasFix = false;

  for (const commit of commits) {
    const message = commit.message || '';
    // Check for breaking change marker (feat! or fix!)
    if (message.match(/^(feat|fix)!:/)) {
      hasBreaking = true;
    } else if (message.startsWith('feat:')) {
      hasFeature = true;
    } else if (message.startsWith('fix:')) {
      hasFix = true;
    }
  }

  // Priority: breaking > feature > fix > none
  if (hasBreaking) return 'major';
  if (hasFeature) return 'minor';
  if (hasFix) return 'patch';
  return 'none';
}

// Bumps a version string based on the bump type
function bumpVersion(currentVersion, bumpType) {
  const version = parseVersion(currentVersion);

  switch (bumpType) {
    case 'major':
      return `${version.major + 1}.0.0`;
    case 'minor':
      return `${version.major}.${version.minor + 1}.0`;
    case 'patch':
      return `${version.major}.${version.minor}.${version.patch + 1}`;
    case 'none':
      return currentVersion;
    default:
      throw new Error(`Unknown bump type: ${bumpType}`);
  }
}

module.exports = {
  parseVersion,
  determineVersionBump,
  bumpVersion,
};
