import { describe, expect, test } from "bun:test";
import { generateChangelogEntry } from "../src/changelog.ts";
import type { ParsedCommit } from "../src/commits.ts";

const c = (
  type: string,
  description: string,
  opts: { scope?: string | null; breaking?: boolean } = {},
): ParsedCommit => ({
  type,
  scope: opts.scope ?? null,
  breaking: opts.breaking ?? false,
  description,
  raw: `${type}: ${description}`,
});

describe("generateChangelogEntry", () => {
  test("groups commits by type with a header containing version + date", () => {
    const entry = generateChangelogEntry({
      version: "1.3.0",
      date: "2026-05-07",
      commits: [
        c("feat", "add login flow"),
        c("feat", "add 2fa", { scope: "auth" }),
        c("fix", "null pointer"),
        c("chore", "bump deps"),
      ],
    });
    expect(entry).toContain("## 1.3.0 (2026-05-07)");
    expect(entry).toContain("### Features");
    expect(entry).toContain("- add login flow");
    expect(entry).toContain("- **auth**: add 2fa");
    expect(entry).toContain("### Bug Fixes");
    expect(entry).toContain("- null pointer");
    // chore by itself doesn't get its own section
    expect(entry).not.toContain("### Chore");
  });

  test("breaking changes are highlighted in their own section", () => {
    const entry = generateChangelogEntry({
      version: "2.0.0",
      date: "2026-05-07",
      commits: [
        c("feat", "drop legacy api", { breaking: true }),
        c("fix", "trivial typo"),
      ],
    });
    expect(entry).toContain("## 2.0.0 (2026-05-07)");
    expect(entry).toContain("### BREAKING CHANGES");
    expect(entry).toContain("- drop legacy api");
  });

  test("no commits -> placeholder body", () => {
    const entry = generateChangelogEntry({
      version: "1.0.1",
      date: "2026-05-07",
      commits: [],
    });
    expect(entry).toContain("## 1.0.1 (2026-05-07)");
    expect(entry.toLowerCase()).toContain("no notable changes");
  });
});
