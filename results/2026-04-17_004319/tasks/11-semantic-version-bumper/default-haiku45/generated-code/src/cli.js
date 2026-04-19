#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { parseVersion, determineVersionBump, bumpVersion } = require('./semantic-version-bumper');
const {
  readVersionFromPackageJson,
  writeVersionToPackageJson,
  generateChangelogEntry,
  getCommitsSinceTag,
} = require('./file-handler');

function main() {
  try {
    // Parse command-line arguments
    const args = process.argv.slice(2);
    const packageJsonPath = args[0] || path.join(process.cwd(), 'package.json');
    const commitsFixturePath = args[1];

    if (!fs.existsSync(packageJsonPath)) {
      console.error(`ERROR: package.json not found at ${packageJsonPath}`);
      process.exit(1);
    }

    if (!commitsFixturePath || !fs.existsSync(commitsFixturePath)) {
      console.error(`ERROR: commits fixture file not found at ${commitsFixturePath}`);
      process.exit(1);
    }

    // Read current version
    const currentVersion = readVersionFromPackageJson(packageJsonPath);
    console.log(`Current version: ${currentVersion}`);

    // Get commits from fixture
    const commits = getCommitsSinceTag(commitsFixturePath);
    console.log(`Found ${commits.length} commits`);

    // Determine version bump
    const bumpType = determineVersionBump(commits);
    console.log(`Determined bump type: ${bumpType}`);

    if (bumpType === 'none') {
      console.log('No version bump needed');
      return;
    }

    // Bump the version
    const newVersion = bumpVersion(currentVersion, bumpType);
    console.log(`New version: ${newVersion}`);

    // Update package.json
    writeVersionToPackageJson(packageJsonPath, newVersion);
    console.log(`Updated ${packageJsonPath}`);

    // Generate changelog
    const changelogEntry = generateChangelogEntry(newVersion, commits);
    console.log('\n--- Changelog Entry ---');
    console.log(changelogEntry);
  } catch (err) {
    console.error(`ERROR: ${err.message}`);
    process.exit(1);
  }
}

main();
