import { BumpType } from "./semantic-version";

export interface ConventionalCommit {
  type: string | null;
  scope: string | null;
  description: string;
  breaking: boolean;
}

export interface CommitAnalysis {
  commits: ConventionalCommit[];
  bumpType: BumpType;
}

// Parse a commit message following conventional commits format
// Format: type(scope)!: description
export function parseConventionalCommit(message: string): ConventionalCommit {
  const trimmed = message.trim();

  // Match: type(scope)!: description or type(scope): description or type!: description
  const match = trimmed.match(
    /^([a-z]+)(?:\(([^)]+)\))?(!)?:\s*(.+)$/
  );

  if (!match) {
    return {
      type: null,
      scope: null,
      description: trimmed,
      breaking: false,
    };
  }

  const [, type, scope, breakingIndicator, description] = match;

  return {
    type,
    scope: scope || null,
    description: description.trim(),
    breaking: breakingIndicator === "!",
  };
}

// Determine the bump type based on parsed commits
// Priority: breaking > feat > fix > default (patch)
export function determineBumpType(commits: ConventionalCommit[]): BumpType {
  // Check for breaking changes first
  if (commits.some((c) => c.breaking)) {
    return "major";
  }

  // Check for features
  if (commits.some((c) => c.type === "feat")) {
    return "minor";
  }

  // Check for fixes
  if (commits.some((c) => c.type === "fix")) {
    return "patch";
  }

  // Default to patch
  return "patch";
}

// Analyze a commit log string and determine bump type
export function analyzeCommits(logString: string): CommitAnalysis {
  if (!logString.trim()) {
    return {
      commits: [],
      bumpType: "patch",
    };
  }

  const lines = logString
    .split("\n")
    .filter((line) => line.trim().length > 0);

  const commits = lines.map((line) => parseConventionalCommit(line));
  const bumpType = determineBumpType(commits);

  return {
    commits,
    bumpType,
  };
}
