// TDD: Failing tests first, then implementation
import { describe, it, expect } from "bun:test";
import { generateDockerTags, sanitizeTag } from "./docker-tags";
import type { GitContext } from "./docker-tags";

describe("sanitizeTag", () => {
  it("lowercases the tag", () => {
    expect(sanitizeTag("MyBranch")).toBe("mybranch");
  });

  it("replaces slashes with dashes", () => {
    expect(sanitizeTag("feature/my-thing")).toBe("feature-my-thing");
  });

  it("replaces consecutive special chars with single dash", () => {
    expect(sanitizeTag("feat--cool__thing")).toBe("feat-cool-thing");
  });

  it("removes leading and trailing dashes", () => {
    expect(sanitizeTag("-bad-tag-")).toBe("bad-tag");
  });
});

describe("generateDockerTags", () => {
  it("returns 'latest' for main branch with no tag", () => {
    const ctx: GitContext = { branch: "main", sha: "abc1234", tags: [], prNumber: null };
    expect(generateDockerTags(ctx)).toEqual(["latest", "main-abc1234"]);
  });

  it("returns 'latest' for master branch with no tag", () => {
    const ctx: GitContext = { branch: "master", sha: "def5678", tags: [], prNumber: null };
    expect(generateDockerTags(ctx)).toEqual(["latest", "master-def5678"]);
  });

  it("returns pr-{number} tag for PRs", () => {
    const ctx: GitContext = { branch: "feature/login", sha: "aaa1111", tags: [], prNumber: 42 };
    expect(generateDockerTags(ctx)).toEqual(["pr-42", "feature-login-aaa1111"]);
  });

  it("returns semver tag for version tags", () => {
    const ctx: GitContext = { branch: "main", sha: "bbb2222", tags: ["v1.2.3"], prNumber: null };
    expect(generateDockerTags(ctx)).toEqual(["v1.2.3", "1.2.3", "latest", "main-bbb2222"]);
  });

  it("sanitizes branch names in tags", () => {
    const ctx: GitContext = { branch: "Feature/My-Cool_Branch", sha: "ccc3333", tags: [], prNumber: null };
    const tags = generateDockerTags(ctx);
    expect(tags).toContain("feature-my-cool-branch-ccc3333");
  });

  it("handles multiple semver tags", () => {
    const ctx: GitContext = { branch: "main", sha: "ddd4444", tags: ["v2.0.0", "v2.0"], prNumber: null };
    const tags = generateDockerTags(ctx);
    expect(tags).toContain("v2.0.0");
    expect(tags).toContain("v2.0");
  });

  it("uses only first 7 chars of sha", () => {
    const ctx: GitContext = { branch: "develop", sha: "abcdef1234567", tags: [], prNumber: null };
    const tags = generateDockerTags(ctx);
    expect(tags).toContain("develop-abcdef1");
  });

  it("throws on empty branch", () => {
    const ctx: GitContext = { branch: "", sha: "abc1234", tags: [], prNumber: null };
    expect(() => generateDockerTags(ctx)).toThrow("branch name is required");
  });

  it("throws on empty sha", () => {
    const ctx: GitContext = { branch: "main", sha: "", tags: [], prNumber: null };
    expect(() => generateDockerTags(ctx)).toThrow("commit SHA is required");
  });
});
