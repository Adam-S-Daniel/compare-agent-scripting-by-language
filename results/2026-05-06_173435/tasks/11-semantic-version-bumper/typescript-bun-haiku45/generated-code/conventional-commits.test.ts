import { describe, it, expect } from "bun:test";
import {
  parseConventionalCommit,
  determineBumpType,
  analyzeCommits,
} from "./conventional-commits";

describe("Conventional Commits", () => {
  describe("parseConventionalCommit", () => {
    it("should parse feat commit", () => {
      const commit = parseConventionalCommit("feat: add new feature");
      expect(commit).toEqual({
        type: "feat",
        scope: null,
        description: "add new feature",
        breaking: false,
      });
    });

    it("should parse fix commit", () => {
      const commit = parseConventionalCommit("fix: resolve bug");
      expect(commit).toEqual({
        type: "fix",
        scope: null,
        description: "resolve bug",
        breaking: false,
      });
    });

    it("should parse commit with scope", () => {
      const commit = parseConventionalCommit("feat(api): add endpoint");
      expect(commit).toEqual({
        type: "feat",
        scope: "api",
        description: "add endpoint",
        breaking: false,
      });
    });

    it("should detect breaking change with !", () => {
      const commit = parseConventionalCommit("feat!: major refactor");
      expect(commit).toEqual({
        type: "feat",
        scope: null,
        description: "major refactor",
        breaking: true,
      });
    });

    it("should detect breaking change with scope and !", () => {
      const commit = parseConventionalCommit("feat(core)!: breaking change");
      expect(commit).toEqual({
        type: "feat",
        scope: "core",
        description: "breaking change",
        breaking: true,
      });
    });

    it("should handle non-conventional commits", () => {
      const commit = parseConventionalCommit("some random commit message");
      expect(commit).toEqual({
        type: null,
        scope: null,
        description: "some random commit message",
        breaking: false,
      });
    });
  });

  describe("determineBumpType", () => {
    it("should return major for breaking changes", () => {
      const bump = determineBumpType([
        {
          type: "feat",
          scope: null,
          description: "feature",
          breaking: true,
        },
      ]);
      expect(bump).toBe("major");
    });

    it("should return minor for feat commits", () => {
      const bump = determineBumpType([
        {
          type: "feat",
          scope: null,
          description: "feature",
          breaking: false,
        },
      ]);
      expect(bump).toBe("minor");
    });

    it("should return patch for fix commits", () => {
      const bump = determineBumpType([
        {
          type: "fix",
          scope: null,
          description: "fix",
          breaking: false,
        },
      ]);
      expect(bump).toBe("patch");
    });

    it("should prioritize breaking changes", () => {
      const bump = determineBumpType([
        {
          type: "fix",
          scope: null,
          description: "fix",
          breaking: false,
        },
        {
          type: "feat",
          scope: null,
          description: "feature",
          breaking: true,
        },
      ]);
      expect(bump).toBe("major");
    });

    it("should prioritize feat over fix", () => {
      const bump = determineBumpType([
        {
          type: "fix",
          scope: null,
          description: "fix",
          breaking: false,
        },
        {
          type: "feat",
          scope: null,
          description: "feature",
          breaking: false,
        },
      ]);
      expect(bump).toBe("minor");
    });

    it("should return patch as default", () => {
      const bump = determineBumpType([
        {
          type: "chore",
          scope: null,
          description: "chore",
          breaking: false,
        },
      ]);
      expect(bump).toBe("patch");
    });
  });

  describe("analyzeCommits", () => {
    it("should analyze commit log string", () => {
      const log = "feat: add feature\nfix: fix bug\nchore: update deps";
      const result = analyzeCommits(log);
      expect(result.bumpType).toBe("minor");
      expect(result.commits.length).toBe(3);
      expect(result.commits[0].type).toBe("feat");
      expect(result.commits[1].type).toBe("fix");
      expect(result.commits[2].type).toBe("chore");
    });

    it("should handle empty commit log", () => {
      const result = analyzeCommits("");
      expect(result.bumpType).toBe("patch");
      expect(result.commits.length).toBe(0);
    });
  });
});
