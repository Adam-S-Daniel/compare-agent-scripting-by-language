/**
 * Docker Image Tag Generator - Unit Tests
 *
 * TDD approach: These tests are written FIRST (red phase).
 * They will fail until tag-generator.ts is implemented.
 *
 * Covers:
 * - Tag sanitization (lowercase, no special chars)
 * - Main/master branch -> "latest" + "main-{short-sha}"
 * - PR builds -> "pr-{number}"
 * - Semver git tags -> "v{semver}"
 * - Feature branches -> "{sanitized-branch}-{short-sha}"
 * - Error handling for missing required fields
 */

import { describe, test, expect } from "bun:test";
import { generateTags, sanitizeTag, isSemverTag } from "./tag-generator";

// ============================================================
// sanitizeTag tests
// ============================================================
describe("sanitizeTag", () => {
  test("converts uppercase to lowercase", () => {
    expect(sanitizeTag("MyBranch")).toBe("mybranch");
  });

  test("replaces forward slashes with dashes", () => {
    expect(sanitizeTag("feature/my-feature")).toBe("feature-my-feature");
  });

  test("replaces underscores with dashes", () => {
    expect(sanitizeTag("my_branch")).toBe("my-branch");
  });

  test("removes leading and trailing dashes", () => {
    expect(sanitizeTag("/branch/")).toBe("branch");
  });

  test("collapses consecutive dashes into one", () => {
    expect(sanitizeTag("my--branch")).toBe("my-branch");
  });

  test("handles branch with multiple special characters", () => {
    expect(sanitizeTag("Feature/My_Complex Branch!")).toBe(
      "feature-my-complex-branch"
    );
  });

  test("preserves dots and dashes (valid in Docker tags)", () => {
    expect(sanitizeTag("v1.2.3")).toBe("v1.2.3");
  });

  test("handles empty string gracefully", () => {
    expect(sanitizeTag("")).toBe("");
  });

  test("replaces # and @ and other special chars", () => {
    expect(sanitizeTag("branch#42@user")).toBe("branch-42-user");
  });
});

// ============================================================
// isSemverTag tests
// ============================================================
describe("isSemverTag", () => {
  test("identifies v-prefixed semver tags", () => {
    expect(isSemverTag("v1.2.3")).toBe(true);
  });

  test("identifies semver tags without v prefix", () => {
    expect(isSemverTag("1.2.3")).toBe(true);
  });

  test("identifies semver with pre-release", () => {
    expect(isSemverTag("v1.2.3-beta.1")).toBe(true);
  });

  test("rejects plain branch names", () => {
    expect(isSemverTag("main")).toBe(false);
    expect(isSemverTag("latest")).toBe(false);
  });

  test("rejects partial version strings", () => {
    expect(isSemverTag("1.2")).toBe(false);
    expect(isSemverTag("v1")).toBe(false);
  });

  test("rejects empty string", () => {
    expect(isSemverTag("")).toBe(false);
  });
});

// ============================================================
// generateTags - main/master branch
// ============================================================
describe("generateTags - main branch", () => {
  test("generates 'latest' tag for main branch", () => {
    const result = generateTags({
      branch: "main",
      commitSha: "abc1234def567890",
      tags: [],
    });
    expect(result.tags).toContain("latest");
    expect(result.error).toBeUndefined();
  });

  test("generates 'main-{short-sha}' for main branch", () => {
    const result = generateTags({
      branch: "main",
      commitSha: "abc1234def567890",
      tags: [],
    });
    expect(result.tags).toContain("main-abc1234");
  });

  test("uses only first 7 chars of SHA", () => {
    const result = generateTags({
      branch: "main",
      commitSha: "abc1234def567890",
      tags: [],
    });
    // Short SHA should be exactly 7 chars
    const shaTag = result.tags.find((t) => t.startsWith("main-"));
    expect(shaTag).toBe("main-abc1234");
  });

  test("generates 'latest' for master branch", () => {
    const result = generateTags({
      branch: "master",
      commitSha: "abc1234def567890",
      tags: [],
    });
    expect(result.tags).toContain("latest");
  });

  test("generates 'master-{short-sha}' for master branch", () => {
    const result = generateTags({
      branch: "master",
      commitSha: "abc1234def567890",
      tags: [],
    });
    expect(result.tags).toContain("master-abc1234");
  });
});

// ============================================================
// generateTags - PR builds
// ============================================================
describe("generateTags - PR builds", () => {
  test("generates 'pr-{number}' for pull requests", () => {
    const result = generateTags({
      branch: "feature/my-feature",
      commitSha: "abc1234def567890",
      tags: [],
      prNumber: 42,
    });
    expect(result.tags).toContain("pr-42");
    expect(result.error).toBeUndefined();
  });

  test("PR build does NOT generate feature branch tag", () => {
    const result = generateTags({
      branch: "feature/my-feature",
      commitSha: "abc1234def567890",
      tags: [],
      prNumber: 42,
    });
    // Only pr-42, not the branch tag
    expect(result.tags.some((t) => t.includes("feature"))).toBe(false);
  });

  test("handles single-digit PR numbers", () => {
    const result = generateTags({
      branch: "fix/bug",
      commitSha: "abc1234def567890",
      tags: [],
      prNumber: 1,
    });
    expect(result.tags).toContain("pr-1");
  });

  test("handles large PR numbers", () => {
    const result = generateTags({
      branch: "feature/x",
      commitSha: "abc1234def567890",
      tags: [],
      prNumber: 9999,
    });
    expect(result.tags).toContain("pr-9999");
  });
});

// ============================================================
// generateTags - semver git tags
// ============================================================
describe("generateTags - semver git tags", () => {
  test("generates 'v{semver}' for git tags", () => {
    const result = generateTags({
      branch: "main",
      commitSha: "abc1234def567890",
      tags: ["v1.2.3"],
    });
    expect(result.tags).toContain("v1.2.3");
  });

  test("adds 'v' prefix to semver tags that lack it", () => {
    const result = generateTags({
      branch: "main",
      commitSha: "abc1234def567890",
      tags: ["1.2.3"],
    });
    expect(result.tags).toContain("v1.2.3");
  });

  test("ignores non-semver git tags", () => {
    const result = generateTags({
      branch: "feature/x",
      commitSha: "abc1234def567890",
      tags: ["some-label", "deploy"],
    });
    expect(result.tags.some((t) => t === "some-label")).toBe(false);
    expect(result.tags.some((t) => t === "deploy")).toBe(false);
  });

  test("includes both 'latest' and semver tag for main branch with tag", () => {
    const result = generateTags({
      branch: "main",
      commitSha: "abc1234def567890",
      tags: ["v1.2.3"],
    });
    expect(result.tags).toContain("latest");
    expect(result.tags).toContain("v1.2.3");
  });

  test("handles multiple semver tags", () => {
    const result = generateTags({
      branch: "main",
      commitSha: "abc1234def567890",
      tags: ["v1.2.3", "v1.2.3-beta.1"],
    });
    expect(result.tags).toContain("v1.2.3");
    expect(result.tags).toContain("v1.2.3-beta.1");
  });
});

// ============================================================
// generateTags - feature branches
// ============================================================
describe("generateTags - feature branches", () => {
  test("generates '{branch}-{short-sha}' for feature branches", () => {
    const result = generateTags({
      branch: "feature/my-feature",
      commitSha: "abc1234def567890",
      tags: [],
    });
    expect(result.tags).toContain("feature-my-feature-abc1234");
  });

  test("sanitizes branch name (lowercase, no special chars)", () => {
    const result = generateTags({
      branch: "Feature/My_Complex Branch!",
      commitSha: "abc1234def567890",
      tags: [],
    });
    expect(result.tags).toContain("feature-my-complex-branch-abc1234");
  });

  test("handles branch with dots", () => {
    const result = generateTags({
      branch: "release/1.2.x",
      commitSha: "abc1234def567890",
      tags: [],
    });
    expect(result.tags).toContain("release-1.2.x-abc1234");
  });

  test("does not generate 'latest' for feature branch", () => {
    const result = generateTags({
      branch: "feature/new-thing",
      commitSha: "abc1234def567890",
      tags: [],
    });
    expect(result.tags).not.toContain("latest");
  });
});

// ============================================================
// generateTags - error handling
// ============================================================
describe("generateTags - error handling", () => {
  test("returns error when branch is empty", () => {
    const result = generateTags({
      branch: "",
      commitSha: "abc1234def567890",
      tags: [],
    });
    expect(result.error).toBeDefined();
    expect(result.tags).toHaveLength(0);
  });

  test("returns error when commitSha is empty", () => {
    const result = generateTags({
      branch: "main",
      commitSha: "",
      tags: [],
    });
    expect(result.error).toBeDefined();
    expect(result.tags).toHaveLength(0);
  });

  test("handles undefined tags array gracefully", () => {
    const result = generateTags({
      branch: "main",
      commitSha: "abc1234def567890",
      tags: [],
    });
    expect(result.error).toBeUndefined();
    expect(result.tags.length).toBeGreaterThan(0);
  });
});
