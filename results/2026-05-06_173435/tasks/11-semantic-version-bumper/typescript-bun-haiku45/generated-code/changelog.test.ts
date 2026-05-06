import { describe, it, expect } from "bun:test";
import { generateChangelogEntry, generateFullChangelog } from "./changelog";
import { SemVersion } from "./semantic-version";

describe("Changelog Generation", () => {
  describe("generateChangelogEntry", () => {
    it("should generate entry for version", () => {
      const version: SemVersion = { major: 1, minor: 1, patch: 0 };
      const commits = [
        { type: "feat", scope: null, description: "add feature", breaking: false },
        { type: "fix", scope: "api", description: "fix endpoint", breaking: false },
      ];
      const entry = generateChangelogEntry(version, commits);

      expect(entry).toContain("## [1.1.0]");
      expect(entry).toContain("add feature");
      expect(entry).toContain("fix endpoint");
      expect(entry).toContain("Features");
      expect(entry).toContain("Bug Fixes");
    });

    it("should group commits by type", () => {
      const version: SemVersion = { major: 2, minor: 0, patch: 0 };
      const commits = [
        { type: "feat", scope: "core", description: "refactored system", breaking: true },
        { type: "feat", scope: null, description: "add feature 1", breaking: false },
        { type: "feat", scope: null, description: "add feature 2", breaking: false },
        { type: "fix", scope: "db", description: "fix query", breaking: false },
      ];
      const entry = generateChangelogEntry(version, commits);

      expect(entry).toContain("## [2.0.0]");
      expect(entry).toContain("Breaking Changes");
      expect(entry).toContain("refactored system");
      // Features section should appear once
      const featuresCount = (entry.match(/### Features/g) || []).length;
      expect(featuresCount).toBe(1);
    });

    it("should handle commits with scopes", () => {
      const version: SemVersion = { major: 1, minor: 2, patch: 3 };
      const commits = [
        { type: "feat", scope: "auth", description: "add oauth", breaking: false },
        { type: "fix", scope: "ui", description: "fix button color", breaking: false },
      ];
      const entry = generateChangelogEntry(version, commits);

      expect(entry).toContain("auth:");
      expect(entry).toContain("ui:");
    });

    it("should handle empty commit list", () => {
      const version: SemVersion = { major: 1, minor: 0, patch: 0 };
      const entry = generateChangelogEntry(version, []);

      expect(entry).toContain("## [1.0.0]");
    });
  });

  describe("generateFullChangelog", () => {
    it("should combine multiple entries", () => {
      const entries = [
        "## [1.1.0]\n### Features\n- add feature",
        "## [1.0.0]\n### Bug Fixes\n- fix bug",
      ];
      const changelog = generateFullChangelog(entries);

      expect(changelog).toContain("## [1.1.0]");
      expect(changelog).toContain("## [1.0.0]");
    });

    it("should add header to changelog", () => {
      const entries = ["## [1.0.0]\n### Features\n- add feature"];
      const changelog = generateFullChangelog(entries);

      expect(changelog).toContain("# Changelog");
    });
  });
});
