// TDD for changelog generation.
import { describe, expect, test } from "bun:test";
import { generateChangelogEntry } from "../src/changelog";
import type { Commit } from "../src/parser";

const mk = (
  type: string,
  description: string,
  breaking = false,
  scope?: string
): Commit => ({ type, scope, breaking, description });

describe("generateChangelogEntry", () => {
  test("header includes new version and date", () => {
    const out = generateChangelogEntry("1.2.0", [mk("feat", "a")], "2026-04-19");
    expect(out.split("\n")[0]).toBe("## 1.2.0 - 2026-04-19");
  });

  test("groups commits by section and ignores chore/docs", () => {
    const commits: Commit[] = [
      mk("feat", "shiny new flag"),
      mk("fix", "crash on start", false, "boot"),
      mk("chore", "bump deps"),
      mk("feat", "break old api", true),
    ];
    const out = generateChangelogEntry("2.0.0", commits, "2026-04-19");

    expect(out).toContain("### Breaking Changes");
    expect(out).toContain("- break old api");
    expect(out).toContain("### Features");
    expect(out).toContain("- shiny new flag");
    expect(out).toContain("### Fixes");
    expect(out).toContain("- **boot**: crash on start");
    // chores must not leak in.
    expect(out).not.toContain("bump deps");
  });

  test("no commits yields a 'no changes' note", () => {
    const out = generateChangelogEntry("1.0.0", [], "2026-04-19");
    expect(out).toContain("No user-facing changes.");
  });
});
