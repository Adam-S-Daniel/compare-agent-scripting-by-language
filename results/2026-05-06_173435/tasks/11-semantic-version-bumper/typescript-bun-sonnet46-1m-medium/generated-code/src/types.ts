// Core types for the semantic version bumper

export interface SemanticVersion {
  major: number;
  minor: number;
  patch: number;
}

export interface ConventionalCommit {
  type: string;
  scope?: string;
  description: string;
  isBreaking: boolean;
  raw: string;
}

// How much to bump: major (breaking), minor (feat), patch (fix), none (no releasable change)
export type BumpType = "major" | "minor" | "patch" | "none";

export interface ChangelogEntry {
  version: string;
  date: string;
  breaking: string[];
  features: string[];
  fixes: string[];
  other: string[];
}

// Shape of the fixture file used by the workflow for end-to-end testing
export interface TestFixture {
  currentVersion: string;
  commits: string[];
}
