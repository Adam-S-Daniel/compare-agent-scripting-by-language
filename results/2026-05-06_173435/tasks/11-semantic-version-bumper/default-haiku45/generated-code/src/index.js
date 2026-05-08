const { parseVersion, bumpVersion } = require('./versionBumper');
const { parseGitLog, formatChangelog } = require('./gitLog');
const { updatePackageJsonVersion, updateChangelog } = require('./fileUpdater');

// Main function: Orchestrates version bumping and changelog generation
async function bumpVersionAndGenerateChangelog(projectDir, gitLogOutput) {
  // Parse current version
  const oldVersion = parseVersion(projectDir);

  // Parse commits from git log
  const commits = parseGitLog(gitLogOutput);

  // If no relevant commits, return unchanged
  if (commits.length === 0) {
    return {
      oldVersion,
      newVersion: oldVersion,
      changelog: ''
    };
  }

  // Calculate new version
  const newVersion = bumpVersion(oldVersion, commits);

  // Generate changelog
  const changelog = formatChangelog(newVersion, commits);

  // Update files if version changed
  if (newVersion !== oldVersion) {
    updatePackageJsonVersion(projectDir, newVersion);
    updateChangelog(projectDir, changelog);
  }

  return {
    oldVersion,
    newVersion,
    changelog
  };
}

module.exports = {
  bumpVersionAndGenerateChangelog
};
