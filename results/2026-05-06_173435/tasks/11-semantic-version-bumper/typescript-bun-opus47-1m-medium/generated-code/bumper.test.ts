// Red/green TDD tests for the semantic version bumper.
// Each test exercises a small unit of behavior. Library functions are pure
// (no filesystem / git access) — the CLI script wires them together.

import { describe, expect, test, beforeEach, afterEach } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync, readFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  parseVersion,
  formatVersion,
  classifyCommit,
  decideBump,
  bumpVersion,
  parseCommitLog,
  generateChangelogEntry,
  runBump,
  type Commit,
  type BumpType,
} from "./bumper.ts";

describe("parseVersion", () => {
  test("parses a simple semver", () => {
    expect(parseVersion("1.2.3")).toEqual({ major: 1, minor: 2, patch: 3 });
  });
  test("rejects invalid input", () => {
    expect(() => parseVersion("not.a.version")).toThrow();
    expect(() => parseVersion("1.2")).toThrow();
  });
});

describe("formatVersion", () => {
  test("round-trips", () => {
    expect(formatVersion({ major: 0, minor: 5, patch: 11 })).toBe("0.5.11");
  });
});

describe("classifyCommit", () => {
  test("feat -> minor", () => {
    expect(classifyCommit("feat: add login")).toBe("minor");
  });
  test("fix -> patch", () => {
    expect(classifyCommit("fix(parser): handle empty input")).toBe("patch");
  });
  test("BREAKING CHANGE in body -> major", () => {
    expect(classifyCommit("feat: rewrite api\n\nBREAKING CHANGE: drops v1")).toBe("major");
  });
  test("bang in header -> major", () => {
    expect(classifyCommit("feat!: drop node 16")).toBe("major");
  });
  test("chore -> none", () => {
    expect(classifyCommit("chore: update deps")).toBe("none");
  });
  test("docs -> none", () => {
    expect(classifyCommit("docs: tweak README")).toBe("none");
  });
});

describe("decideBump", () => {
  test("picks the highest bump", () => {
    expect(decideBump(["fix: a", "feat: b"])).toBe("minor");
    expect(decideBump(["feat: a", "feat!: b"])).toBe("major");
    expect(decideBump(["chore: a"])).toBe("none");
    expect(decideBump([])).toBe("none");
  });
});

describe("bumpVersion", () => {
  test("major resets minor & patch", () => {
    expect(bumpVersion("1.2.3", "major")).toBe("2.0.0");
  });
  test("minor resets patch", () => {
    expect(bumpVersion("1.2.3", "minor")).toBe("1.3.0");
  });
  test("patch increments patch", () => {
    expect(bumpVersion("1.2.3", "patch")).toBe("1.2.4");
  });
  test("none returns same version", () => {
    expect(bumpVersion("1.2.3", "none")).toBe("1.2.3");
  });
});

describe("parseCommitLog", () => {
  test("parses the simple newline-delimited fixture format", () => {
    const fixture = [
      "abc123|feat: add A",
      "def456|fix: bug",
      "ghi789|chore: tidy",
    ].join("\n");
    const commits = parseCommitLog(fixture);
    expect(commits.length).toBe(3);
    expect(commits[0]).toEqual({ hash: "abc123", message: "feat: add A" });
    expect(commits[2].message).toBe("chore: tidy");
  });
  test("ignores blank lines", () => {
    expect(parseCommitLog("\n\nabc|feat: x\n\n").length).toBe(1);
  });
});

describe("generateChangelogEntry", () => {
  test("groups commits by type", () => {
    const commits: Commit[] = [
      { hash: "a", message: "feat: add login" },
      { hash: "b", message: "fix: oops" },
      { hash: "c", message: "feat!: drop v1" },
      { hash: "d", message: "chore: bump deps" },
    ];
    const entry = generateChangelogEntry("1.0.0", commits, "2026-05-07");
    expect(entry).toContain("## 1.0.0 - 2026-05-07");
    expect(entry).toContain("### Breaking Changes");
    expect(entry).toContain("drop v1");
    expect(entry).toContain("### Features");
    expect(entry).toContain("add login");
    expect(entry).toContain("### Fixes");
    expect(entry).toContain("oops");
    // chore should be in "Other"
    expect(entry).toContain("bump deps");
  });
});

describe("runBump (end-to-end on a tmp dir)", () => {
  let dir: string;
  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), "bumper-"));
  });
  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  test("bumps package.json, writes CHANGELOG, prints new version", () => {
    const pkgPath = join(dir, "package.json");
    writeFileSync(pkgPath, JSON.stringify({ name: "x", version: "1.1.0" }, null, 2));
    const log = "h1|feat: add thing\nh2|fix: small bug";
    const result = runBump({
      versionFilePath: pkgPath,
      commitLog: log,
      changelogPath: join(dir, "CHANGELOG.md"),
      date: "2026-05-07",
    });
    expect(result.previousVersion).toBe("1.1.0");
    expect(result.newVersion).toBe("1.2.0");
    expect(result.bump).toBe("minor");
    const updated = JSON.parse(readFileSync(pkgPath, "utf8"));
    expect(updated.version).toBe("1.2.0");
    expect(existsSync(join(dir, "CHANGELOG.md"))).toBe(true);
    const changelog = readFileSync(join(dir, "CHANGELOG.md"), "utf8");
    expect(changelog).toContain("## 1.2.0 - 2026-05-07");
    expect(changelog).toContain("add thing");
  });

  test("plain-text VERSION file works", () => {
    const vPath = join(dir, "VERSION");
    writeFileSync(vPath, "0.4.2\n");
    const result = runBump({
      versionFilePath: vPath,
      commitLog: "h|feat!: total redesign",
      changelogPath: join(dir, "CHANGELOG.md"),
      date: "2026-05-07",
    });
    expect(result.newVersion).toBe("1.0.0");
    expect(result.bump).toBe("major");
    expect(readFileSync(vPath, "utf8").trim()).toBe("1.0.0");
  });

  test("no-op when no relevant commits", () => {
    const pkgPath = join(dir, "package.json");
    writeFileSync(pkgPath, JSON.stringify({ version: "2.0.0" }));
    const result = runBump({
      versionFilePath: pkgPath,
      commitLog: "h|chore: format\nh2|docs: tweak",
      changelogPath: join(dir, "CHANGELOG.md"),
      date: "2026-05-07",
    });
    expect(result.bump).toBe("none");
    expect(result.newVersion).toBe("2.0.0");
    expect(result.previousVersion).toBe("2.0.0");
  });

  test("missing version file errors clearly", () => {
    expect(() =>
      runBump({
        versionFilePath: join(dir, "missing.json"),
        commitLog: "h|feat: x",
        changelogPath: join(dir, "CHANGELOG.md"),
        date: "2026-05-07",
      }),
    ).toThrow(/version file/i);
  });
});
