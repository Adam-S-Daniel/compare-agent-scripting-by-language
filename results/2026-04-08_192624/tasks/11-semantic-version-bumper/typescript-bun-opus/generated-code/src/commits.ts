/**
 * Conventional commit message parsing and bump type determination.
 * Supports the Conventional Commits specification:
 *   type(scope)!: description
 *   - feat -> minor bump
 *   - fix -> patch bump
 *   - ! or BREAKING CHANGE -> major bump
 */

import type { BumpType } from "./version";

/** A parsed conventional commit message */
export interface ConventionalCommit {
  type: string;
  scope?: string;
  breaking: boolean;
  description: string;
  raw: string;
}

/**
 * Parse a single commit message line into a ConventionalCommit.
 * Returns null if the message doesn't follow conventional commit format.
 */
export function parseCommit(message: string): ConventionalCommit | null {
  const trimmed = message.trim();
  if (!trimmed) return null;

  // Match: type(scope)!: description  OR  type!: description  OR  type: description
  const match = trimmed.match(/^(\w+)(?:\(([^)]*)\))?(!)?\s*:\s*(.+)$/);
  if (!match) return null;

  const [, type, scope, bang, description] = match;
  const breaking = bang === "!" || /BREAKING[ -]CHANGE/i.test(trimmed);

  return {
    type,
    scope: scope || undefined,
    breaking,
    description: description.trim(),
    raw: trimmed,
  };
}

/** Parse multiple commit messages (one per line) into ConventionalCommits */
export function parseCommits(commitLog: string): ConventionalCommit[] {
  return commitLog
    .split("\n")
    .map((line) => parseCommit(line))
    .filter((c): c is ConventionalCommit => c !== null);
}

/**
 * Determine the highest-priority bump type from a list of commits.
 * Priority: major > minor > patch > none
 */
export function determineBumpType(commits: ConventionalCommit[]): BumpType {
  let bump: BumpType = "none";

  for (const commit of commits) {
    if (commit.breaking) return "major"; // Short-circuit: major is the highest
    if (commit.type === "feat" && bump !== "major") bump = "minor";
    if (commit.type === "fix" && bump === "none") bump = "patch";
  }

  return bump;
}
