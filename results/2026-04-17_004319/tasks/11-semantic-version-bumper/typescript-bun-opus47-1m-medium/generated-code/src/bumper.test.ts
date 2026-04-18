import { describe, expect, test } from "bun:test";
import {
  parseVersion,
  formatVersion,
  classifyCommit,
  determineBump,
  bumpVersion,
  generateChangelog,
  type Commit,
} from "./bumper.ts";

describe("parseVersion", () => {
  test("parses a valid semver string", () => {
    expect(parseVersion("1.2.3")).toEqual({ major: 1, minor: 2, patch: 3 });
  });

  test("throws on invalid semver", () => {
    expect(() => parseVersion("abc")).toThrow(/invalid semantic version/i);
  });
});

describe("formatVersion", () => {
  test("formats a version back to string", () => {
    expect(formatVersion({ major: 2, minor: 0, patch: 5 })).toBe("2.0.5");
  });
});

describe("classifyCommit", () => {
  test("classifies feat as minor", () => {
    expect(classifyCommit("feat: add login")).toBe("minor");
  });
  test("classifies fix as patch", () => {
    expect(classifyCommit("fix: bug")).toBe("patch");
  });
  test("classifies scoped feat", () => {
    expect(classifyCommit("feat(api): new endpoint")).toBe("minor");
  });
  test("classifies breaking change with !", () => {
    expect(classifyCommit("feat!: remove v1 api")).toBe("major");
  });
  test("classifies BREAKING CHANGE in body", () => {
    expect(classifyCommit("refactor: x\n\nBREAKING CHANGE: drops support")).toBe("major");
  });
  test("unknown type returns none", () => {
    expect(classifyCommit("chore: deps")).toBe("none");
  });
});

describe("determineBump", () => {
  test("picks the highest bump level", () => {
    expect(determineBump(["fix: a", "feat: b"])).toBe("minor");
    expect(determineBump(["feat: a", "feat!: b"])).toBe("major");
    expect(determineBump(["chore: a", "fix: b"])).toBe("patch");
    expect(determineBump(["chore: a"])).toBe("none");
  });
});

describe("bumpVersion", () => {
  test("bumps major resetting minor/patch", () => {
    expect(bumpVersion("1.2.3", "major")).toBe("2.0.0");
  });
  test("bumps minor resetting patch", () => {
    expect(bumpVersion("1.2.3", "minor")).toBe("1.3.0");
  });
  test("bumps patch", () => {
    expect(bumpVersion("1.2.3", "patch")).toBe("1.2.4");
  });
  test("none returns input unchanged", () => {
    expect(bumpVersion("1.2.3", "none")).toBe("1.2.3");
  });
});

describe("generateChangelog", () => {
  test("groups commits by type with heading", () => {
    const commits: Commit[] = [
      { subject: "feat: add login", body: "" },
      { subject: "fix: handle null", body: "" },
      { subject: "feat!: remove legacy", body: "" },
      { subject: "chore: deps", body: "" },
    ];
    const entry = generateChangelog("1.3.0", commits, "2026-04-17");
    expect(entry).toContain("## 1.3.0 - 2026-04-17");
    expect(entry).toContain("### Breaking Changes");
    expect(entry).toContain("remove legacy");
    expect(entry).toContain("### Features");
    expect(entry).toContain("add login");
    expect(entry).toContain("### Fixes");
    expect(entry).toContain("handle null");
    // chore / unknown should not appear
    expect(entry).not.toContain("deps");
  });
});
