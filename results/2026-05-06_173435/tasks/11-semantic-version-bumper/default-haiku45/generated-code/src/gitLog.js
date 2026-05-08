// Parses git log output into structured commit objects
function parseGitLog(gitLogOutput) {
  const lines = gitLogOutput.split('\n').filter(line => line.trim());
  const commits = [];

  for (const line of lines) {
    if (line.startsWith('feat') || line.startsWith('fix') || line.startsWith('refactor')) {
      const commit = parseCommitLine(line);
      commits.push(commit);
    }
  }

  return commits;
}

// Parses a single commit line in conventional commit format
function parseCommitLine(line) {
  // Match: type(scope): description or type: description or type!: description
  const match = line.match(/^(feat|fix|refactor)(?:\(([^)]+)\))?(!)?:\s*(.+)$/);

  if (!match) {
    return null;
  }

  const [, type, scope, breaking, description] = match;

  return {
    type,
    scope: scope || null,
    description,
    message: line,
    hasBreaking: breaking === '!' || line.includes('BREAKING CHANGE:')
  };
}

// Generates a changelog entry from commits
function formatChangelog(version, commits) {
  const lines = [`## [${version}]`];
  lines.push('');

  // Group commits by type
  const features = commits.filter(c => c.type === 'feat' && !c.hasBreaking);
  const bugFixes = commits.filter(c => c.type === 'fix');
  const breakingChanges = commits.filter(c => c.hasBreaking);

  // Add breaking changes section first
  if (breakingChanges.length > 0) {
    lines.push('### BREAKING CHANGES');
    breakingChanges.forEach(commit => {
      const scope = commit.scope ? `(${commit.scope})` : '';
      lines.push(`- ${scope} ${commit.description}`);
    });
    lines.push('');
  }

  // Add features section
  if (features.length > 0) {
    lines.push('### Features');
    features.forEach(commit => {
      const scope = commit.scope ? `(${commit.scope})` : '';
      lines.push(`- ${scope} ${commit.description}`);
    });
    lines.push('');
  }

  // Add bug fixes section
  if (bugFixes.length > 0) {
    lines.push('### Bug Fixes');
    bugFixes.forEach(commit => {
      const scope = commit.scope ? `(${commit.scope})` : '';
      lines.push(`- ${scope} ${commit.description}`);
    });
  }

  return lines.join('\n');
}

module.exports = {
  parseGitLog,
  parseCommitLine,
  formatChangelog
};
