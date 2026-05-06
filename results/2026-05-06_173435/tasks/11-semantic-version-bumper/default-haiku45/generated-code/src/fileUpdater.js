const fs = require('fs');
const path = require('path');

// Reads package.json from the given directory
function readPackageJson(dirPath) {
  const pkgPath = path.join(dirPath, 'package.json');
  const content = fs.readFileSync(pkgPath, 'utf-8');
  return JSON.parse(content);
}

// Writes updated version to package.json
function writePackageJson(dirPath, newVersion) {
  const pkgPath = path.join(dirPath, 'package.json');
  const pkg = readPackageJson(dirPath);
  pkg.version = newVersion;
  fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n', 'utf-8');
}

// Updates package.json with new version
function updatePackageJsonVersion(dirPath, newVersion) {
  try {
    writePackageJson(dirPath, newVersion);
    return true;
  } catch (error) {
    console.error(`Failed to update package.json: ${error.message}`);
    return false;
  }
}

// Appends changelog entry to CHANGELOG.md
function updateChangelog(dirPath, changelogEntry) {
  const changelogPath = path.join(dirPath, 'CHANGELOG.md');

  let content = '';
  if (fs.existsSync(changelogPath)) {
    content = fs.readFileSync(changelogPath, 'utf-8');
  } else {
    content = '# Changelog\n\n';
  }

  // Insert new entry after the header
  const lines = content.split('\n');
  const headerIndex = lines.findIndex(line => line.startsWith('# Changelog'));

  if (headerIndex !== -1) {
    lines.splice(headerIndex + 1, 0, changelogEntry);
    content = lines.join('\n');
  } else {
    content = changelogEntry + '\n' + content;
  }

  fs.writeFileSync(changelogPath, content, 'utf-8');
}

module.exports = {
  readPackageJson,
  writePackageJson,
  updatePackageJsonVersion,
  updateChangelog
};
