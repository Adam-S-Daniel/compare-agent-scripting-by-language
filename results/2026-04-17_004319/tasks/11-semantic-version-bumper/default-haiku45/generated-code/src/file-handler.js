const fs = require('fs');
const path = require('path');

// Reads the current version from package.json
function readVersionFromPackageJson(packageJsonPath) {
  try {
    const content = fs.readFileSync(packageJsonPath, 'utf8');
    const pkg = JSON.parse(content);
    if (!pkg.version) {
      throw new Error('No version field found in package.json');
    }
    return pkg.version;
  } catch (err) {
    if (err.code === 'ENOENT') {
      throw new Error(`package.json not found at ${packageJsonPath}`);
    }
    throw err;
  }
}

// Updates the version in package.json
function writeVersionToPackageJson(packageJsonPath, newVersion) {
  const content = fs.readFileSync(packageJsonPath, 'utf8');
  const pkg = JSON.parse(content);
  pkg.version = newVersion;
  fs.writeFileSync(packageJsonPath, JSON.stringify(pkg, null, 2) + '\n');
}

// Generates a changelog entry from a list of commits
function generateChangelogEntry(version, commits, date = new Date()) {
  const dateStr = date.toISOString().split('T')[0];
  let entry = `## [${version}] - ${dateStr}\n\n`;

  // Group commits by type
  const features = commits.filter(c => c.message.startsWith('feat:'));
  const fixes = commits.filter(c => c.message.startsWith('fix:'));
  const breaking = commits.filter(c => c.message.match(/^(feat|fix)!:/));

  if (breaking.length > 0) {
    entry += '### Breaking Changes\n\n';
    breaking.forEach(c => {
      const msg = c.message.replace(/^(feat|fix)!:\s*/, '').split('\n')[0];
      entry += `- ${msg} ([${c.hash.substring(0, 7)}])\n`;
    });
    entry += '\n';
  }

  if (features.length > 0) {
    entry += '### Features\n\n';
    features.forEach(c => {
      const msg = c.message.replace(/^feat:\s*/, '').split('\n')[0];
      entry += `- ${msg} ([${c.hash.substring(0, 7)}])\n`;
    });
    entry += '\n';
  }

  if (fixes.length > 0) {
    entry += '### Bug Fixes\n\n';
    fixes.forEach(c => {
      const msg = c.message.replace(/^fix:\s*/, '').split('\n')[0];
      entry += `- ${msg} ([${c.hash.substring(0, 7)}])\n`;
    });
    entry += '\n';
  }

  return entry;
}

// Parses commits from a fixture file (format: "hash message")
function getCommitsSinceTag(fixturePath) {
  if (!fs.existsSync(fixturePath)) {
    throw new Error(`Fixture file not found: ${fixturePath}`);
  }

  const content = fs.readFileSync(fixturePath, 'utf8');
  const lines = content.trim().split('\n').filter(line => line.trim());

  return lines.map(line => {
    const [hash, ...rest] = line.split(' ');
    const message = rest.join(' ');
    return { hash, message };
  });
}

module.exports = {
  readVersionFromPackageJson,
  writeVersionToPackageJson,
  generateChangelogEntry,
  getCommitsSinceTag,
};
