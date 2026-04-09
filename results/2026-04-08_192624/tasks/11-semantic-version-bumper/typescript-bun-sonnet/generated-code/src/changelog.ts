/**
 * Semantic Version Bumper - Changelog Generation
 *
 * Parses conventional commit messages and generates CHANGELOG.md entries.
 * Follows the Conventional Commits 1.0.0 specification.
 *
 * Commit format: <type>[optional scope][optional !]: <description>
 *   feat(api): add endpoint  -> minor bump
 *   fix: correct bug         -> patch bump
 *   feat!: breaking change   -> major bump
 *   feat: change\n\nBREAKING CHANGE: ... -> major bump
 */

// ============================================================
// Types & Interfaces
// ============================================================

export interface Commit {
  type: string;
  scope: string | null;
  description: string;
  breaking: boolean;
  raw: string;
}

// ============================================================
// parseCommits: Parse an array of raw commit message strings
// ============================================================

// Regex for conventional commit format:
//   <type>[(<scope>)][!]: <description>
const COMMIT_REGEX = /^(\w+)(?:\(([^)]+)\))?(!)?:\s+(.+)/;

export function parseCommits(rawMessages: string[]): Commit[] {
  return rawMessages.map((raw) => {
    // Split off body/footer from subject line
    const [subject, ...bodyLines] = raw.split("\n");
    const body = bodyLines.join("\n");

    const match = subject.match(COMMIT_REGEX);

    if (!match) {
      // Non-conventional commit: treat as unknown type, non-breaking
      return {
        type: "unknown",
        scope: null,
        description: subject.trim(),
        breaking: false,
        raw,
      };
    }

    const [, type, scope, bangBreaking, description] = match;

    // Breaking if ! syntax OR BREAKING CHANGE in body/footer
    const breaking =
      bangBreaking === "!" ||
      body.includes("BREAKING CHANGE:");

    return {
      type: type.toLowerCase(),
      scope: scope ?? null,
      description: description.trim(),
      breaking,
      raw,
    };
  });
}

// ============================================================
// generateChangelog: Build a CHANGELOG.md entry for a release
// ============================================================

export function generateChangelog(
  version: string,
  commits: Commit[],
  date: string
): string {
  const lines: string[] = [];

  // Version header
  lines.push(`## [${version}] - ${date}`);
  lines.push("");

  // Collect breaking changes
  const breakingCommits = commits.filter((c) => c.breaking);
  if (breakingCommits.length > 0) {
    lines.push("### ⚠ BREAKING CHANGE");
    lines.push("");
    for (const c of breakingCommits) {
      lines.push(`- ${formatCommitLine(c)}`);
    }
    lines.push("");
  }

  // Collect features
  const featCommits = commits.filter((c) => c.type === "feat");
  if (featCommits.length > 0) {
    lines.push("### Features");
    lines.push("");
    for (const c of featCommits) {
      lines.push(`- ${formatCommitLine(c)}`);
    }
    lines.push("");
  }

  // Collect bug fixes
  const fixCommits = commits.filter((c) => c.type === "fix");
  if (fixCommits.length > 0) {
    lines.push("### Bug Fixes");
    lines.push("");
    for (const c of fixCommits) {
      lines.push(`- ${formatCommitLine(c)}`);
    }
    lines.push("");
  }

  return lines.join("\n");
}

// ============================================================
// formatCommitLine: Format a single commit as a changelog line
// ============================================================

function formatCommitLine(commit: Commit): string {
  if (commit.scope) {
    return `**(${commit.scope})** ${commit.description}`;
  }
  return commit.description;
}
