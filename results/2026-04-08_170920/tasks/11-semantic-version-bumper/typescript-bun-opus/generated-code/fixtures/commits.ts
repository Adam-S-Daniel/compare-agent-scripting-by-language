// Mock commit log fixtures for testing conventional commit parsing.
// Each fixture represents a set of git log lines in "one-line" format.

export interface MockCommitLog {
  name: string;
  commits: string[];
  expectedBumpType: "major" | "minor" | "patch" | "none";
}

export const PATCH_ONLY_COMMITS: MockCommitLog = {
  name: "patch-only",
  commits: [
    "abc1234 fix: resolve null pointer in user lookup",
    "def5678 fix(auth): handle expired tokens gracefully",
    "ghi9012 fix: correct off-by-one in pagination",
  ],
  expectedBumpType: "patch",
};

export const MINOR_COMMITS: MockCommitLog = {
  name: "minor-with-fixes",
  commits: [
    "aaa1111 feat: add user search endpoint",
    "bbb2222 fix: handle empty query strings",
    "ccc3333 feat(api): support pagination in list responses",
  ],
  expectedBumpType: "minor",
};

export const MAJOR_COMMITS_FOOTER: MockCommitLog = {
  name: "major-breaking-footer",
  commits: [
    "ddd4444 feat: redesign authentication flow\n\nBREAKING CHANGE: token format changed from JWT to opaque",
    "eee5555 fix: update error codes",
  ],
  expectedBumpType: "major",
};

export const MAJOR_COMMITS_BANG: MockCommitLog = {
  name: "major-breaking-bang",
  commits: [
    "fff6666 feat!: remove deprecated v1 endpoints",
    "ggg7777 fix: update migration script",
  ],
  expectedBumpType: "major",
};

export const NO_CONVENTIONAL_COMMITS: MockCommitLog = {
  name: "no-conventional",
  commits: [
    "hhh8888 update readme",
    "iii9999 misc cleanup",
  ],
  expectedBumpType: "none",
};

export const MIXED_COMMITS: MockCommitLog = {
  name: "mixed-conventional-and-non",
  commits: [
    "jjj0000 feat: add dark mode support",
    "kkk1111 updated docs",
    "lll2222 fix(ui): correct button alignment",
  ],
  expectedBumpType: "minor",
};

export const ALL_FIXTURES: MockCommitLog[] = [
  PATCH_ONLY_COMMITS,
  MINOR_COMMITS,
  MAJOR_COMMITS_FOOTER,
  MAJOR_COMMITS_BANG,
  NO_CONVENTIONAL_COMMITS,
  MIXED_COMMITS,
];
