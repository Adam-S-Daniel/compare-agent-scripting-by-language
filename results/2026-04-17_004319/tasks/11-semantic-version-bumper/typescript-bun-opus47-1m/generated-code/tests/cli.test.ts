// Integration tests for the CLI (src/cli.ts).
// Spawn `bun run src/cli.ts ...` and assert on the stdout version string and
// the side effects on the version file + changelog.

import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdtemp, readFile, rm, writeFile, copyFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";

const ROOT = resolve(import.meta.dir, "..");
const CLI = join(ROOT, "src", "cli.ts");

let workDir: string;
beforeEach(async () => {
  workDir = await mkdtemp(join(tmpdir(), "svb-cli-"));
});
afterEach(async () => {
  await rm(workDir, { recursive: true, force: true });
});

async function runCli(args: string[]): Promise<{ code: number; stdout: string; stderr: string }> {
  const proc = Bun.spawn(["bun", "run", CLI, ...args], {
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  const code = await proc.exited;
  return { code, stdout, stderr };
}

describe("cli", () => {
  test("feat commit bumps minor and prints new version", async () => {
    const pkg = join(workDir, "package.json");
    const log = join(workDir, "commits.log");
    const cl = join(workDir, "CHANGELOG.md");
    await writeFile(pkg, JSON.stringify({ name: "t", version: "1.1.0" }, null, 2));
    await copyFile(join(ROOT, "fixtures", "feat-minor.log"), log);

    const r = await runCli([
      "--version-file", pkg,
      "--changelog", cl,
      "--commits", log,
      "--date", "2026-04-17",
    ]);
    expect(r.code).toBe(0);
    expect(r.stdout.trim()).toBe("1.2.0");
    const pkgJson = JSON.parse(await readFile(pkg, "utf8"));
    expect(pkgJson.version).toBe("1.2.0");
    const changelog = await readFile(cl, "utf8");
    expect(changelog).toContain("## [1.2.0] - 2026-04-17");
    expect(changelog).toContain("- **api:** add login endpoint");
  });

  test("fix commit bumps patch", async () => {
    const pkg = join(workDir, "package.json");
    const log = join(workDir, "commits.log");
    const cl = join(workDir, "CHANGELOG.md");
    await writeFile(pkg, JSON.stringify({ name: "t", version: "0.9.3" }, null, 2));
    await copyFile(join(ROOT, "fixtures", "fix-patch.log"), log);

    const r = await runCli([
      "--version-file", pkg,
      "--changelog", cl,
      "--commits", log,
      "--date", "2026-04-17",
    ]);
    expect(r.code).toBe(0);
    expect(r.stdout.trim()).toBe("0.9.4");
  });

  test("breaking-change footer bumps major", async () => {
    const pkg = join(workDir, "package.json");
    const log = join(workDir, "commits.log");
    const cl = join(workDir, "CHANGELOG.md");
    await writeFile(pkg, JSON.stringify({ name: "t", version: "2.3.4" }, null, 2));
    await copyFile(join(ROOT, "fixtures", "breaking-major.log"), log);

    const r = await runCli([
      "--version-file", pkg,
      "--changelog", cl,
      "--commits", log,
      "--date", "2026-04-17",
    ]);
    expect(r.code).toBe(0);
    expect(r.stdout.trim()).toBe("3.0.0");
  });

  test("no meaningful commits leaves version unchanged", async () => {
    const pkg = join(workDir, "package.json");
    const log = join(workDir, "commits.log");
    const cl = join(workDir, "CHANGELOG.md");
    await writeFile(pkg, JSON.stringify({ name: "t", version: "0.5.0" }, null, 2));
    await copyFile(join(ROOT, "fixtures", "noop-none.log"), log);

    const r = await runCli([
      "--version-file", pkg,
      "--changelog", cl,
      "--commits", log,
      "--date", "2026-04-17",
    ]);
    expect(r.code).toBe(0);
    expect(r.stdout.trim()).toBe("0.5.0");
    expect(r.stderr).toContain("bump=none");
  });

  test("errors on missing required flag", async () => {
    const r = await runCli([]);
    expect(r.code).not.toBe(0);
    expect(r.stderr.toLowerCase()).toContain("version-file");
  });
});
