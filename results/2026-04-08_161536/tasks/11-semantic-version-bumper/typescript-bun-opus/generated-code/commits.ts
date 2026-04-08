// Parsing conventional commits and determining bump type

import type { ConventionalCommit, BumpType } from "./types";

// Matches: hash type(scope)!: description
// Groups: hash, type, scope (optional), ! (optional), description
// Hash allows any alphanumeric chars (test fixtures use non-hex letters)
// Hash is 7-40 lowercase alphanumeric chars (git short/full hash)
const COMMIT_REGEX = /^([a-z0-9]{7,40})\s+(\w+)(?:\(([^)]+)\))?(!)?\s*:\s*(.+)/;

/** Parse a multi-line git log into conventional commit objects.
 *  Non-conventional commits are silently skipped. */
export function parseCommitLog(log: string): ConventionalCommit[] {
  if (!log.trim()) return [];

  const commits: ConventionalCommit[] = [];
  const lines = log.split("\n");

  // Walk lines: each line matching COMMIT_REGEX starts a new entry.
  // Subsequent non-matching lines are body text for the current entry.
  let currentMatch: RegExpMatchArray | null = null;
  let bodyLines: string[] = [];

  function flush(): void {
    if (!currentMatch) return;
    const [, hash, type, scope, bang, description] = currentMatch;
    const body = bodyLines.join("\n");
    const breaking = bang === "!" || body.includes("BREAKING CHANGE");
    commits.push({
      hash,
      type,
      scope: scope || undefined,
      description: description.trim(),
      breaking,
    });
    currentMatch = null;
    bodyLines = [];
  }

  for (const line of lines) {
    const match = line.match(COMMIT_REGEX);
    if (match) {
      flush(); // Save previous commit if any
      currentMatch = match;
    } else if (currentMatch) {
      bodyLines.push(line);
    }
  }
  flush(); // Don't forget the last commit

  return commits;
}

/** Determine the highest-priority bump type from a list of commits.
 *  Priority: major > minor > patch. Returns null if no bump needed. */
export function determineBumpType(commits: ConventionalCommit[]): BumpType | null {
  let bump: BumpType | null = null;

  for (const commit of commits) {
    if (commit.breaking) return "major"; // Short-circuit: can't go higher
    if (commit.type === "feat") bump = "minor";
    if (commit.type === "fix" && bump === null) bump = "patch";
  }

  return bump;
}
