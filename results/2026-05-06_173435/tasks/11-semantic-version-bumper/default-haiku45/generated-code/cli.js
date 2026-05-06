#!/usr/bin/env node

const { bumpVersionAndGenerateChangelog } = require('./src/index');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

async function main() {
  try {
    // Get project directory from argument or use current directory
    const projectDir = process.argv[2] || process.cwd();

    // Validate package.json exists
    if (!fs.existsSync(path.join(projectDir, 'package.json'))) {
      console.error('Error: package.json not found in', projectDir);
      process.exit(1);
    }

    // Get git log from recent commits
    // If not in a git repo, use provided commits or fall back to empty
    let gitLog = '';
    try {
      gitLog = execSync('git log --format=%s --grep="^(feat|fix|refactor)" -E', {
        cwd: projectDir,
        encoding: 'utf-8'
      }).trim();
    } catch (e) {
      // Not in a git repo or no matching commits
      gitLog = '';
    }

    // Allow override via environment variable (useful for testing)
    if (process.env.COMMITS) {
      gitLog = process.env.COMMITS;
    }

    const result = await bumpVersionAndGenerateChangelog(projectDir, gitLog);

    // Output results
    console.log(JSON.stringify({
      success: true,
      oldVersion: result.oldVersion,
      newVersion: result.newVersion,
      changelog: result.changelog,
      versionChanged: result.oldVersion !== result.newVersion
    }, null, 2));

    process.exit(0);
  } catch (error) {
    console.error(JSON.stringify({
      success: false,
      error: error.message
    }, null, 2));
    process.exit(1);
  }
}

main();
