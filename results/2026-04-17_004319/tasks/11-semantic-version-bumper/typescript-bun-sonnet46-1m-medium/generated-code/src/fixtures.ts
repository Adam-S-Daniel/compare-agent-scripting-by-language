// Mock commit log fixtures for testing

import type { Commit } from "./types";

export const patchCommits: Commit[] = [
  { hash: "abc1234", message: "fix: resolve null pointer in parser", type: "fix", breaking: false },
  { hash: "abc1235", message: "fix: handle empty string input", type: "fix", breaking: false },
];

export const minorCommits: Commit[] = [
  { hash: "def1234", message: "feat: add support for pre-release versions", type: "feat", breaking: false },
  { hash: "def1235", message: "fix: correct semver comparison", type: "fix", breaking: false },
];

export const majorCommits: Commit[] = [
  { hash: "ghi1234", message: "feat!: redesign API surface\n\nBREAKING CHANGE: old API removed", type: "feat", breaking: true },
  { hash: "ghi1235", message: "feat: add new flags", type: "feat", breaking: false },
];

export const breakingFooterCommits: Commit[] = [
  {
    hash: "jkl1234",
    message: "feat: new auth flow\n\nBREAKING CHANGE: requires new env variable",
    type: "feat",
    breaking: true,
  },
];

export const noReleaseCommits: Commit[] = [
  { hash: "mno1234", message: "chore: update dependencies", type: "chore", breaking: false },
  { hash: "mno1235", message: "docs: fix typo in README", type: "docs", breaking: false },
];

// Raw git log lines as they'd come from `git log --oneline`
export const rawGitLogPatch = [
  "abc1234 fix: resolve null pointer in parser",
  "abc1235 fix: handle empty string input",
].join("\n");

export const rawGitLogMinor = [
  "def1234 feat: add support for pre-release versions",
  "def1235 fix: correct semver comparison",
].join("\n");

export const rawGitLogMajor = [
  "ghi1234 feat!: redesign API surface",
  "ghi1235 feat: add new flags",
].join("\n");

export const rawGitLogNone = [
  "mno1234 chore: update dependencies",
  "mno1235 docs: fix typo in README",
].join("\n");
