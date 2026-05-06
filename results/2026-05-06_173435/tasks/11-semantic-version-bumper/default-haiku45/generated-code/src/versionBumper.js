const fs = require('fs');
const path = require('path');

// Parses version from package.json in the given directory
function parseVersion(dirPath) {
  const packageJsonPath = path.join(dirPath, 'package.json');
  const content = fs.readFileSync(packageJsonPath, 'utf-8');
  const pkg = JSON.parse(content);
  return pkg.version;
}

// Determines if a message is a conventional commit (feat/fix)
function isConventionalCommit(message) {
  return /^(feat|fix|refactor)(?:\(.*\))?!?:/.test(message);
}

// Extracts the type of commit (feat, fix, or null)
function parseCommitType(message) {
  const match = message.match(/^(feat|fix)(?:\(.*\))?!?:/);
  return match ? match[1] : null;
}

// Checks if a commit has breaking change marker
function hasBreakingChange(commit) {
  return commit.message.includes('BREAKING CHANGE:') || /^(feat|fix)!:/.test(commit.message);
}

// Bumps version based on conventional commits
// Returns new semantic version string
function bumpVersion(currentVersion, commits) {
  const parts = currentVersion.split('.');
  let major = parseInt(parts[0], 10);
  let minor = parseInt(parts[1], 10);
  let patch = parseInt(parts[2], 10);

  // Determine highest priority bump needed
  let needsMajor = false;
  let needsMinor = false;
  let needsPatch = false;

  for (const commit of commits) {
    if (hasBreakingChange(commit)) {
      needsMajor = true;
    } else if (parseCommitType(commit.message) === 'feat') {
      needsMinor = true;
    } else if (parseCommitType(commit.message) === 'fix') {
      needsPatch = true;
    }
  }

  // Apply bumps in priority order (major > minor > patch)
  if (needsMajor) {
    major += 1;
    minor = 0;
    patch = 0;
  } else if (needsMinor) {
    minor += 1;
    patch = 0;
  } else if (needsPatch) {
    patch += 1;
  }

  return `${major}.${minor}.${patch}`;
}

module.exports = {
  parseVersion,
  bumpVersion,
  isConventionalCommit,
  parseCommitType,
  hasBreakingChange
};
