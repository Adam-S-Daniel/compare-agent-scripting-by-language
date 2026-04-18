// Tests for the changelog entry generator.
//
// Output format (Keep-a-Changelog inspired):
//
//   ## [1.2.0] - 2026-04-17
//
//   ### Breaking changes
//   - drop legacy API
//
//   ### Features
//   - add login
//   - **api:** new endpoint
//
//   ### Bug fixes
//   - handle empty input
//
// Empty sections are omitted. "other" commits are not shown.

import { describe, expect, test } from "bun:test";
import type { Commit } from "../src/commits.ts";
import { renderChangelogEntry } from "../src/changelog.ts";

const mkCommit = (raw: string, breaking = false): Commit => {
  // Use the real parser so our tests also exercise it lightly; keep the import
  // minimal by constructing directly.
  const match = /^([a-zA-Z]+)(?:\(([^)]+)\))?(!)?:\s*(.+)$/.exec(raw);
  if (!match) throw new Error(`bad test input: ${raw}`);
  return {
    type: match[1].toLowerCase(),
    scope: match[2] ?? null,
    breaking: breaking || Boolean(match[3]),
    subject: match[4],
    raw,
  };
};

describe("renderChangelogEntry", () => {
  test("emits heading with version and date, plus three grouped sections", () => {
    const commits: Commit[] = [
      mkCommit("feat: add login"),
      mkCommit("feat(api): new endpoint"),
      mkCommit("fix: handle empty input"),
      mkCommit("feat!: drop legacy API"),
      mkCommit("chore: bump deps"),
    ];
    const entry = renderChangelogEntry({
      version: "1.2.0",
      date: "2026-04-17",
      commits,
    });
    const expected = [
      "## [1.2.0] - 2026-04-17",
      "",
      "### Breaking changes",
      "- drop legacy API",
      "",
      "### Features",
      "- add login",
      "- **api:** new endpoint",
      "",
      "### Bug fixes",
      "- handle empty input",
      "",
    ].join("\n");
    expect(entry).toBe(expected);
  });

  test("omits empty sections", () => {
    const commits: Commit[] = [mkCommit("fix: one thing")];
    const entry = renderChangelogEntry({
      version: "0.1.1",
      date: "2026-04-17",
      commits,
    });
    expect(entry).toContain("## [0.1.1] - 2026-04-17");
    expect(entry).toContain("### Bug fixes");
    expect(entry).toContain("- one thing");
    expect(entry).not.toContain("### Features");
    expect(entry).not.toContain("### Breaking changes");
  });

  test("no-op bump still produces an entry but notes no changes", () => {
    const entry = renderChangelogEntry({
      version: "0.1.0",
      date: "2026-04-17",
      commits: [mkCommit("chore: bump deps")],
    });
    expect(entry).toContain("## [0.1.0] - 2026-04-17");
    expect(entry).toContain("_No user-facing changes._");
  });
});
