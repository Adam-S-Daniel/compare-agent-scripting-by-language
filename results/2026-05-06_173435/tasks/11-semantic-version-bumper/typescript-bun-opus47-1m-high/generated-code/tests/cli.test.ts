import { afterEach, describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync, readFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { runBump } from "../src/cli.ts";

const tempDirs: string[] = [];

function tmp(): string {
  const dir = mkdtempSync(join(tmpdir(), "semver-bump-cli-"));
  tempDirs.push(dir);
  return dir;
}

afterEach(() => {
  while (tempDirs.length) {
    const d = tempDirs.pop();
    if (d) rmSync(d, { recursive: true, force: true });
  }
});

describe("runBump (orchestrator)", () => {
  test("feat commit bumps minor (1.1.0 -> 1.2.0) and writes changelog", () => {
    const dir = tmp();
    const pkg = join(dir, "package.json");
    const log = join(dir, "commits.txt");
    const cl = join(dir, "CHANGELOG.md");
    writeFileSync(pkg, JSON.stringify({ name: "demo", version: "1.1.0" }, null, 2));
    writeFileSync(log, "feat: shiny new endpoint\n\nfix: edge case\n");

    const result = runBump({
      versionFile: pkg,
      commitLog: log,
      changelogFile: cl,
      date: "2026-05-07",
    });

    expect(result.previousVersion).toBe("1.1.0");
    expect(result.newVersion).toBe("1.2.0");
    expect(result.bump).toBe("minor");

    const parsed = JSON.parse(readFileSync(pkg, "utf8"));
    expect(parsed.version).toBe("1.2.0");

    const changelog = readFileSync(cl, "utf8");
    expect(changelog).toContain("## 1.2.0 (2026-05-07)");
    expect(changelog).toContain("- shiny new endpoint");
    expect(changelog).toContain("- edge case");
  });

  test("breaking commit bumps major (1.4.2 -> 2.0.0)", () => {
    const dir = tmp();
    const pkg = join(dir, "package.json");
    const log = join(dir, "commits.txt");
    writeFileSync(pkg, JSON.stringify({ name: "demo", version: "1.4.2" }, null, 2));
    writeFileSync(log, "feat!: drop legacy v1 api\n\nfix: random\n");

    const result = runBump({
      versionFile: pkg,
      commitLog: log,
      changelogFile: join(dir, "CHANGELOG.md"),
      date: "2026-05-07",
    });

    expect(result.newVersion).toBe("2.0.0");
    expect(result.bump).toBe("major");
  });

  test("only fix commits bump patch (0.1.0 -> 0.1.1)", () => {
    const dir = tmp();
    const pkg = join(dir, "package.json");
    const log = join(dir, "commits.txt");
    writeFileSync(pkg, JSON.stringify({ name: "demo", version: "0.1.0" }, null, 2));
    writeFileSync(log, "fix: typo\n\nchore: bump deps\n");

    const result = runBump({
      versionFile: pkg,
      commitLog: log,
      changelogFile: join(dir, "CHANGELOG.md"),
      date: "2026-05-07",
    });

    expect(result.newVersion).toBe("0.1.1");
    expect(result.bump).toBe("patch");
  });

  test("no relevant commits keeps version (no rewrite, no changelog)", () => {
    const dir = tmp();
    const pkg = join(dir, "package.json");
    const log = join(dir, "commits.txt");
    const cl = join(dir, "CHANGELOG.md");
    writeFileSync(pkg, JSON.stringify({ name: "demo", version: "1.0.0" }, null, 2));
    writeFileSync(log, "chore: housekeeping\n\ndocs: tweak readme\n");

    const result = runBump({
      versionFile: pkg,
      commitLog: log,
      changelogFile: cl,
      date: "2026-05-07",
    });

    expect(result.bump).toBe("none");
    expect(result.newVersion).toBe("1.0.0");
    expect(result.previousVersion).toBe("1.0.0");
    expect(existsSync(cl)).toBe(false);
  });

  test("prepends new entry above existing changelog content", () => {
    const dir = tmp();
    const pkg = join(dir, "package.json");
    const log = join(dir, "commits.txt");
    const cl = join(dir, "CHANGELOG.md");
    writeFileSync(pkg, JSON.stringify({ name: "demo", version: "1.0.0" }, null, 2));
    writeFileSync(log, "feat: new thing\n");
    writeFileSync(cl, "# Changelog\n\n## 1.0.0 (2026-04-01)\n\nold body\n");

    runBump({
      versionFile: pkg,
      commitLog: log,
      changelogFile: cl,
      date: "2026-05-07",
    });

    const text = readFileSync(cl, "utf8");
    // Header is preserved, new entry sits between header and old entry.
    expect(text.indexOf("## 1.1.0")).toBeLessThan(text.indexOf("## 1.0.0"));
    expect(text).toContain("# Changelog");
    expect(text).toContain("- new thing");
    expect(text).toContain("old body");
  });
});
