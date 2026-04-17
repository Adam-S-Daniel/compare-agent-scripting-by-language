// Integration tests for the CLI — exercise the bump pipeline against fixture
// commit logs. Each test runs in an isolated tmp dir.
import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdtemp, rm, writeFile, readFile, copyFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { main } from "./cli.ts";

let tmp: string;
beforeEach(async () => {
  tmp = await mkdtemp(join(tmpdir(), "bumper-"));
});
afterEach(async () => {
  await rm(tmp, { recursive: true, force: true });
});

async function setupPkg(version: string): Promise<string> {
  const pkg = join(tmp, "package.json");
  await writeFile(pkg, JSON.stringify({ name: "x", version }, null, 2));
  return pkg;
}

describe("CLI integration", () => {
  test("feat commit bumps minor: 1.1.0 -> 1.2.0", async () => {
    const pkg = await setupPkg("1.1.0");
    const commits = join(tmp, "commits.txt");
    await copyFile("fixtures/feat-commits.txt", commits);
    const changelog = join(tmp, "CHANGELOG.md");
    const out = await main(["--version-file", pkg, "--commits-file", commits, "--changelog-file", changelog, "--date", "2026-04-17"]);
    expect(out).toBe("1.2.0");
    const pkgAfter = JSON.parse(await readFile(pkg, "utf8"));
    expect(pkgAfter.version).toBe("1.2.0");
    const cl = await readFile(changelog, "utf8");
    expect(cl).toContain("## 1.2.0 - 2026-04-17");
    expect(cl).toContain("### Features");
  });

  test("only fix commits bumps patch: 2.0.5 -> 2.0.6", async () => {
    const pkg = await setupPkg("2.0.5");
    const commits = join(tmp, "commits.txt");
    await copyFile("fixtures/fix-commits.txt", commits);
    const out = await main(["--version-file", pkg, "--commits-file", commits, "--changelog-file", join(tmp, "CHANGELOG.md"), "--date", "2026-04-17"]);
    expect(out).toBe("2.0.6");
  });

  test("breaking commit bumps major: 1.4.2 -> 2.0.0", async () => {
    const pkg = await setupPkg("1.4.2");
    const commits = join(tmp, "commits.txt");
    await copyFile("fixtures/breaking-commits.txt", commits);
    const out = await main(["--version-file", pkg, "--commits-file", commits, "--changelog-file", join(tmp, "CHANGELOG.md"), "--date", "2026-04-17"]);
    expect(out).toBe("2.0.0");
  });

  test("missing version file gives a helpful error", async () => {
    await expect(
      main(["--version-file", join(tmp, "nope.json"), "--commits-file", "fixtures/feat-commits.txt"])
    ).rejects.toThrow(/Version file not found/);
  });
});
