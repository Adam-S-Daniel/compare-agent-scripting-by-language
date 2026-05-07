// Integration tests for the CLI entrypoint.
// We invoke the CLI as a subprocess via `bun run` and inspect:
//   - exit code,
//   - the BUMP_TYPE / OLD_VERSION / NEW_VERSION key=value lines on stdout,
//   - the resulting package.json + CHANGELOG.md on disk.
//
// Each test runs in its own tmp dir so they can't interfere.

import { describe, expect, test, beforeEach, afterEach } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync, readFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const CLI = join(import.meta.dir, "..", "src", "cli.ts");

let workdir: string;

beforeEach(() => {
  workdir = mkdtempSync(join(tmpdir(), "svb-"));
});

afterEach(() => {
  rmSync(workdir, { recursive: true, force: true });
});

function pkg(version: string): string {
  return JSON.stringify({ name: "demo", version }, null, 2) + "\n";
}

async function runCli(args: string[]): Promise<{ code: number; stdout: string; stderr: string }> {
  const proc = Bun.spawn(["bun", "run", CLI, ...args], {
    cwd: workdir,
    stdout: "pipe",
    stderr: "pipe",
  });
  const stdout = await new Response(proc.stdout).text();
  const stderr = await new Response(proc.stderr).text();
  const code = await proc.exited;
  return { code, stdout, stderr };
}

describe("CLI", () => {
  test("feat commit minor-bumps package.json and writes changelog", async () => {
    writeFileSync(join(workdir, "package.json"), pkg("1.4.7"));
    writeFileSync(
      join(workdir, "commits.txt"),
      ["feat(api): add list endpoint", "---", "fix: typo in error message"].join("\n"),
    );

    const { code, stdout } = await runCli([
      "--version-file", "package.json",
      "--commits-file", "commits.txt",
      "--changelog", "CHANGELOG.md",
      "--date", "2026-05-07",
    ]);

    expect(code).toBe(0);
    expect(stdout).toContain("OLD_VERSION=1.4.7");
    expect(stdout).toContain("NEW_VERSION=1.5.0");
    expect(stdout).toContain("BUMP_TYPE=minor");

    const written = JSON.parse(readFileSync(join(workdir, "package.json"), "utf8"));
    expect(written.version).toBe("1.5.0");

    const changelog = readFileSync(join(workdir, "CHANGELOG.md"), "utf8");
    expect(changelog).toContain("## [1.5.0] - 2026-05-07");
    expect(changelog).toContain("add list endpoint");
  });

  test("breaking change major-bumps", async () => {
    writeFileSync(join(workdir, "package.json"), pkg("0.9.3"));
    writeFileSync(
      join(workdir, "commits.txt"),
      "feat!: rip out the v0 protocol",
    );
    const { code, stdout } = await runCli([
      "--version-file", "package.json",
      "--commits-file", "commits.txt",
      "--changelog", "CHANGELOG.md",
      "--date", "2026-05-07",
    ]);
    expect(code).toBe(0);
    expect(stdout).toContain("BUMP_TYPE=major");
    expect(stdout).toContain("NEW_VERSION=1.0.0");
  });

  test("chore-only commits leave version unchanged with BUMP_TYPE=none", async () => {
    writeFileSync(join(workdir, "package.json"), pkg("2.0.0"));
    writeFileSync(join(workdir, "commits.txt"), "chore: bump deps");
    const { code, stdout } = await runCli([
      "--version-file", "package.json",
      "--commits-file", "commits.txt",
      "--changelog", "CHANGELOG.md",
      "--date", "2026-05-07",
    ]);
    expect(code).toBe(0);
    expect(stdout).toContain("BUMP_TYPE=none");
    expect(stdout).toContain("NEW_VERSION=2.0.0");
    // Shouldn't have written a changelog entry.
    expect(existsSync(join(workdir, "CHANGELOG.md"))).toBe(false);
  });

  test("missing version file returns nonzero with helpful error", async () => {
    writeFileSync(join(workdir, "commits.txt"), "feat: x");
    const { code, stderr } = await runCli([
      "--version-file", "package.json",
      "--commits-file", "commits.txt",
    ]);
    expect(code).not.toBe(0);
    expect(stderr).toMatch(/version file/i);
  });

  test("--dry-run does not modify files", async () => {
    writeFileSync(join(workdir, "package.json"), pkg("1.0.0"));
    writeFileSync(join(workdir, "commits.txt"), "feat: add thing");
    const { code, stdout } = await runCli([
      "--version-file", "package.json",
      "--commits-file", "commits.txt",
      "--dry-run",
    ]);
    expect(code).toBe(0);
    expect(stdout).toContain("NEW_VERSION=1.1.0");
    const written = JSON.parse(readFileSync(join(workdir, "package.json"), "utf8"));
    expect(written.version).toBe("1.0.0"); // unchanged
  });

  test("supports plain VERSION text file (not just package.json)", async () => {
    writeFileSync(join(workdir, "VERSION"), "3.2.1\n");
    writeFileSync(join(workdir, "commits.txt"), "fix: nudge timeout");
    const { code, stdout } = await runCli([
      "--version-file", "VERSION",
      "--commits-file", "commits.txt",
    ]);
    expect(code).toBe(0);
    expect(stdout).toContain("NEW_VERSION=3.2.2");
    const written = readFileSync(join(workdir, "VERSION"), "utf8").trim();
    expect(written).toBe("3.2.2");
  });
});
