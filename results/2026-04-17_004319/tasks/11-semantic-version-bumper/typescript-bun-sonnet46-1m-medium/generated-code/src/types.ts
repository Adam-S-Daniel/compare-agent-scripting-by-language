// Core types for the semantic version bumper

export interface Commit {
  hash: string;
  message: string;
  type: "feat" | "fix" | "breaking" | "chore" | "docs" | "style" | "refactor" | "test" | "other";
  breaking: boolean;
}

export interface BumpResult {
  previousVersion: string;
  newVersion: string;
  bumpType: "major" | "minor" | "patch" | "none";
  commits: Commit[];
  changelog: string;
}

export interface VersionFile {
  path: string;
  version: string;
  format: "package.json" | "version.txt";
}
