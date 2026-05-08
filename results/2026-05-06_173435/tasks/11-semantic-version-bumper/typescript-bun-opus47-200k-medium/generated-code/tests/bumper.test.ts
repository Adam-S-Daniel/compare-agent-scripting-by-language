// TDD tests for the semantic version bumper.
import { describe, test, expect } from "bun:test";
import {
  parseVersion,
  formatVersion,
  parseCommit,
  parseCommits,
  determineBump,
  bumpVersion,
  generateChangelog,
  readVersionFromContent,
  writeVersionToContent,
  bump,
} from "../src/bumper.ts";

describe("parseVersion", () => {
  test("parses a valid semver string", () => {
    expect(parseVersion("1.2.3")).toEqual({ major: 1, minor: 2, patch: 3 });
  });
  test("throws on malformed version", () => {
    expect(() => parseVersion("not-a-version")).toThrow();
    expect(() => parseVersion("1.2")).toThrow();
  });
  test("formatVersion is the inverse", () => {
    expect(formatVersion(parseVersion("4.5.6"))).toBe("4.5.6");
  });
});

describe("parseCommit", () => {
  test("parses simple feat commit", () => {
    const c = parseCommit("feat: add new login flow");
    expect(c?.type).toBe("feat");
    expect(c?.breaking).toBe(false);
    expect(c?.subject).toBe("add new login flow");
  });
  test("parses scoped fix commit", () => {
    const c = parseCommit("fix(auth): handle null token");
    expect(c?.type).toBe("fix");
    expect(c?.scope).toBe("auth");
  });
  test("recognizes breaking via !", () => {
    const c = parseCommit("feat!: drop node 16");
    expect(c?.breaking).toBe(true);
  });
  test("recognizes BREAKING CHANGE in body", () => {
    const c = parseCommit("refactor: migrate api\n\nBREAKING CHANGE: removed v1");
    expect(c?.breaking).toBe(true);
  });
  test("returns null on garbage", () => {
    expect(parseCommit("just some text")).toBeNull();
  });
});

describe("determineBump", () => {
  test("breaking wins over feat and fix", () => {
    const log = "feat: x\nfix: y\nfeat!: breaking";
    expect(determineBump(parseCommits(log))).toBe("major");
  });
  test("feat wins over fix", () => {
    expect(determineBump(parseCommits("fix: y\nfeat: x"))).toBe("minor");
  });
  test("only fixes", () => {
    expect(determineBump(parseCommits("fix: y"))).toBe("patch");
  });
  test("nothing relevant -> none", () => {
    expect(determineBump(parseCommits("docs: update readme"))).toBe("none");
  });
});

describe("bumpVersion", () => {
  test.each([
    ["1.2.3", "major", "2.0.0"],
    ["1.2.3", "minor", "1.3.0"],
    ["1.2.3", "patch", "1.2.4"],
    ["1.2.3", "none", "1.2.3"],
  ] as const)("bumps %s by %s -> %s", (v, b, out) => {
    expect(bumpVersion(v, b)).toBe(out);
  });
});

describe("generateChangelog", () => {
  test("groups commits by type", () => {
    const commits = parseCommits(
      "feat: add a\nfix: fix b\nfeat!: breaking thing\ndocs: tweak",
    );
    const cl = generateChangelog("2.0.0", commits, "2026-05-08");
    expect(cl).toContain("## 2.0.0 - 2026-05-08");
    expect(cl).toContain("### Breaking Changes");
    expect(cl).toContain("breaking thing");
    expect(cl).toContain("### Features");
    expect(cl).toContain("add a");
    expect(cl).toContain("### Bug Fixes");
    expect(cl).toContain("fix b");
  });
});

describe("read/write version files", () => {
  test("reads from package.json", () => {
    expect(
      readVersionFromContent(JSON.stringify({ version: "1.0.0" }), "package.json"),
    ).toBe("1.0.0");
  });
  test("reads from VERSION file", () => {
    expect(readVersionFromContent("1.2.3\n", "VERSION")).toBe("1.2.3");
  });
  test("preserves package.json shape", () => {
    const orig = JSON.stringify({ name: "x", version: "1.0.0" });
    const updated = writeVersionToContent(orig, "package.json", "1.1.0");
    expect(JSON.parse(updated).version).toBe("1.1.0");
    expect(JSON.parse(updated).name).toBe("x");
  });
});

describe("integration: bump()", () => {
  test("end-to-end: feat commit on 1.1.0 -> 1.2.0", () => {
    const result = bump("1.1.0", "feat: new thing\nfix: small fix", "2026-05-08");
    expect(result.newVersion).toBe("1.2.0");
    expect(result.bumpType).toBe("minor");
    expect(result.changelog).toContain("1.2.0");
  });
  test("breaking change gives major bump", () => {
    const result = bump("0.9.4", "feat!: total rewrite", "2026-05-08");
    expect(result.newVersion).toBe("1.0.0");
    expect(result.bumpType).toBe("major");
  });
});
