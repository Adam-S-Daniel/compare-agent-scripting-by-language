// Types for the semantic version bumper

/** Represents a parsed semantic version */
export interface SemanticVersion {
  major: number;
  minor: number;
  patch: number;
}

/** The type of version bump to apply */
export type BumpType = "major" | "minor" | "patch";

/** A parsed conventional commit */
export interface ConventionalCommit {
  hash: string;
  type: string; // feat, fix, chore, etc.
  scope?: string;
  description: string;
  breaking: boolean;
}

/** A changelog entry for a version bump */
export interface ChangelogEntry {
  version: string;
  date: string;
  features: string[];
  fixes: string[];
  breaking: string[];
  other: string[];
}
