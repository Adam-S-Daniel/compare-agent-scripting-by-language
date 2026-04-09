// Mock commit log fixtures for testing

/** Simulates git log output with conventional commit messages */
export const FIXTURE_PATCH_ONLY = [
  "abc1234 fix: resolve null pointer in user lookup",
  "def5678 fix(auth): handle expired token gracefully",
].join("\n");

export const FIXTURE_MINOR_WITH_FIXES = [
  "aaa1111 feat: add dark mode toggle",
  "bbb2222 fix: correct CSS alignment on mobile",
  "ccc3333 fix(ui): button hover state missing",
].join("\n");

export const FIXTURE_MAJOR_BREAKING = [
  "ddd4444 feat!: redesign authentication API",
  "eee5555 feat: add OAuth2 support",
  "fff6666 fix: patch login redirect",
].join("\n");

export const FIXTURE_BREAKING_IN_BODY = [
  "ggg7777 feat: new config format\nBREAKING CHANGE: config v1 no longer supported",
].join("\n");

export const FIXTURE_MIXED_WITH_CHORES = [
  "hhh8888 chore: update dependencies",
  "iii9999 feat(api): add rate limiting endpoint",
  "jjj0000 docs: update README",
  "kkk1111 fix: memory leak in connection pool",
].join("\n");

export const FIXTURE_NO_CONVENTIONAL = [
  "lll2222 updated some stuff",
  "mmm3333 WIP",
].join("\n");

export const FIXTURE_EMPTY = "";

/** Sample package.json content for testing */
export const SAMPLE_PACKAGE_JSON = JSON.stringify(
  {
    name: "test-project",
    version: "1.2.3",
    description: "A test project",
  },
  null,
  2
);

/** Sample VERSION file content */
export const SAMPLE_VERSION_FILE = "1.2.3\n";
