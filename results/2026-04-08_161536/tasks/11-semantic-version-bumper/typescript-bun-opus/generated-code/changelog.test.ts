// TDD tests for changelog generation

import { describe, test, expect } from "bun:test";
import { generateChangelog, formatChangelog } from "./changelog";
import { parseCommitLog } from "./commits";
import {
  FIXTURE_MINOR_WITH_FIXES,
  FIXTURE_MAJOR_BREAKING,
  FIXTURE_MIXED_WITH_CHORES,
} from "./fixtures";
import type { ChangelogEntry } from "./types";

describe("generateChangelog", () => {
  test("generates entry with features and fixes", () => {
    const commits = parseCommitLog(FIXTURE_MINOR_WITH_FIXES);
    const entry = generateChangelog(commits, "1.3.0", "2026-04-08");
    expect(entry.version).toBe("1.3.0");
    expect(entry.date).toBe("2026-04-08");
    expect(entry.features).toHaveLength(1);
    expect(entry.features[0]).toContain("dark mode toggle");
    expect(entry.fixes).toHaveLength(2);
  });

  test("generates entry with breaking changes", () => {
    const commits = parseCommitLog(FIXTURE_MAJOR_BREAKING);
    const entry = generateChangelog(commits, "2.0.0", "2026-04-08");
    expect(entry.breaking).toHaveLength(1);
    expect(entry.breaking[0]).toContain("redesign authentication API");
    expect(entry.features).toHaveLength(1); // OAuth2 support (non-breaking feat)
  });

  test("categorizes chore and docs as other", () => {
    const commits = parseCommitLog(FIXTURE_MIXED_WITH_CHORES);
    const entry = generateChangelog(commits, "1.1.0", "2026-04-08");
    expect(entry.other).toHaveLength(2); // chore + docs
    expect(entry.features).toHaveLength(1);
    expect(entry.fixes).toHaveLength(1);
  });
});

describe("formatChangelog", () => {
  test("formats a changelog entry as markdown", () => {
    const entry: ChangelogEntry = {
      version: "2.0.0",
      date: "2026-04-08",
      features: ["add OAuth2 support"],
      fixes: ["patch login redirect"],
      breaking: ["redesign authentication API"],
      other: [],
    };
    const md = formatChangelog(entry);
    expect(md).toContain("## 2.0.0 (2026-04-08)");
    expect(md).toContain("### Breaking Changes");
    expect(md).toContain("- redesign authentication API");
    expect(md).toContain("### Features");
    expect(md).toContain("### Bug Fixes");
  });

  test("omits empty sections", () => {
    const entry: ChangelogEntry = {
      version: "1.0.1",
      date: "2026-04-08",
      features: [],
      fixes: ["fix a bug"],
      breaking: [],
      other: [],
    };
    const md = formatChangelog(entry);
    expect(md).not.toContain("### Features");
    expect(md).not.toContain("### Breaking Changes");
    expect(md).toContain("### Bug Fixes");
  });
});
