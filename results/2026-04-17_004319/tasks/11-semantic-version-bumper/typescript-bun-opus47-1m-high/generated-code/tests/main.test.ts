// End-to-end test of the bumper's pure entry point (no process spawning).
// runBump reads a package.json + commit log, writes back, and returns
// the result object the CLI prints.  We test it against a tmp dir.
import { describe, expect, test, beforeEach, afterEach } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync, readFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { runBump } from "../src/main";

let dir = "";
beforeEach(() => {
  dir = mkdtempSync(join(tmpdir(), "svb-"));
});
afterEach(() => {
  rmSync(dir, { recursive: true, force: true });
});

const pkg = (v: string) => JSON.stringify({ name: "x", version: v }, null, 2);

describe("runBump", () => {
  test("feat commit -> minor bump, writes package.json + CHANGELOG.md", () => {
    const pkgPath = join(dir, "package.json");
    const logPath = join(dir, "commits.txt");
    const clPath = join(dir, "CHANGELOG.md");
    writeFileSync(pkgPath, pkg("1.1.0"));
    writeFileSync(logPath, "feat: add dark mode\n---\nchore: tidy\n");

    const result = runBump({
      packageFile: pkgPath,
      commitLog: logPath,
      changelogFile: clPath,
      date: "2026-04-19",
    });

    expect(result.oldVersion).toBe("1.1.0");
    expect(result.newVersion).toBe("1.2.0");
    expect(result.bumpType).toBe("minor");

    const written = JSON.parse(readFileSync(pkgPath, "utf8"));
    expect(written.version).toBe("1.2.0");

    const cl = readFileSync(clPath, "utf8");
    expect(cl).toContain("## 1.2.0 - 2026-04-19");
    expect(cl).toContain("- add dark mode");
  });

  test("fix commit on 1.0.0 -> 1.0.1", () => {
    const pkgPath = join(dir, "package.json");
    const logPath = join(dir, "commits.txt");
    writeFileSync(pkgPath, pkg("1.0.0"));
    writeFileSync(logPath, "fix: null ptr on load");

    const r = runBump({
      packageFile: pkgPath,
      commitLog: logPath,
      changelogFile: join(dir, "CHANGELOG.md"),
      date: "2026-04-19",
    });
    expect(r.newVersion).toBe("1.0.1");
    expect(r.bumpType).toBe("patch");
  });

  test("breaking change on 1.4.7 -> 2.0.0", () => {
    const pkgPath = join(dir, "package.json");
    const logPath = join(dir, "commits.txt");
    writeFileSync(pkgPath, pkg("1.4.7"));
    writeFileSync(
      logPath,
      "feat!: rewrite public api\n\nBREAKING CHANGE: replaces v1 routes"
    );

    const r = runBump({
      packageFile: pkgPath,
      commitLog: logPath,
      changelogFile: join(dir, "CHANGELOG.md"),
      date: "2026-04-19",
    });
    expect(r.newVersion).toBe("2.0.0");
    expect(r.bumpType).toBe("major");
  });

  test("only non-bumping commits -> version unchanged, no changelog written", () => {
    const pkgPath = join(dir, "package.json");
    const logPath = join(dir, "commits.txt");
    const clPath = join(dir, "CHANGELOG.md");
    writeFileSync(pkgPath, pkg("0.3.1"));
    writeFileSync(logPath, "chore: cleanup\n---\ndocs: update readme");

    const r = runBump({
      packageFile: pkgPath,
      commitLog: logPath,
      changelogFile: clPath,
      date: "2026-04-19",
    });
    expect(r.newVersion).toBe("0.3.1");
    expect(r.bumpType).toBe("none");
    expect(existsSync(clPath)).toBe(false);
  });

  test("missing package.json raises a clear error", () => {
    expect(() =>
      runBump({
        packageFile: join(dir, "nope.json"),
        commitLog: join(dir, "log.txt"),
        changelogFile: join(dir, "CHANGELOG.md"),
        date: "2026-04-19",
      })
    ).toThrow(/package.json/i);
  });

  test("prepends new entry to an existing CHANGELOG.md", () => {
    const pkgPath = join(dir, "package.json");
    const logPath = join(dir, "commits.txt");
    const clPath = join(dir, "CHANGELOG.md");
    writeFileSync(pkgPath, pkg("1.0.0"));
    writeFileSync(logPath, "feat: something");
    writeFileSync(clPath, "# Changelog\n\n## 1.0.0 - 2026-01-01\n\nFirst cut.\n");

    runBump({
      packageFile: pkgPath,
      commitLog: logPath,
      changelogFile: clPath,
      date: "2026-04-19",
    });

    const cl = readFileSync(clPath, "utf8");
    // new entry must appear BEFORE the old one.
    const newIdx = cl.indexOf("1.1.0");
    const oldIdx = cl.indexOf("1.0.0 - 2026-01-01");
    expect(newIdx).toBeGreaterThanOrEqual(0);
    expect(oldIdx).toBeGreaterThan(newIdx);
  });
});
