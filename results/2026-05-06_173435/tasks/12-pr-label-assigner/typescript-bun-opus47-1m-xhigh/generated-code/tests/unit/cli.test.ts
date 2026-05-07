import { describe, expect, test, beforeAll, afterAll } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

// CLI tests: drive the actual `bun run pr-label-assigner.ts` binary
// against temp config + files fixtures. These exercise the complete I/O
// path (stdin/stdout, JSON parsing, error reporting, exit codes).

const CLI = join(import.meta.dir, "..", "..", "pr-label-assigner.ts");

let dir: string;

beforeAll(() => {
  dir = mkdtempSync(join(tmpdir(), "pr-label-cli-"));
});

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

async function runCli(args: string[]): Promise<{
  exitCode: number;
  stdout: string;
  stderr: string;
}> {
  const proc = Bun.spawn(["bun", "run", CLI, ...args], {
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  await proc.exited;
  return { exitCode: proc.exitCode ?? -1, stdout, stderr };
}

describe("CLI", () => {
  test("prints JSON labels to stdout for matching files", async () => {
    const cfg = join(dir, "cfg.json");
    const files = join(dir, "files.txt");
    writeFileSync(
      cfg,
      JSON.stringify({
        rules: [
          { label: "documentation", patterns: ["docs/**", "*.md"] },
          { label: "api", patterns: ["src/api/**"] },
          { label: "tests", patterns: ["**/*.test.*"] },
        ],
      }),
    );
    writeFileSync(files, ["docs/intro.md", "src/api/users.ts"].join("\n"));

    const { exitCode, stdout, stderr } = await runCli([
      "--config",
      cfg,
      "--files",
      files,
    ]);

    expect(stderr).toBe("");
    expect(exitCode).toBe(0);
    const out = JSON.parse(stdout);
    expect(out.labels.sort()).toEqual(["api", "documentation"]);
  });

  test("exits non-zero with helpful error if config is missing", async () => {
    const { exitCode, stderr } = await runCli([
      "--config",
      join(dir, "nope.json"),
      "--files",
      join(dir, "x.txt"),
    ]);
    expect(exitCode).not.toBe(0);
    expect(stderr).toContain("config");
  });

  test("exits non-zero with helpful error if config JSON is invalid", async () => {
    const cfg = join(dir, "bad.json");
    const files = join(dir, "files2.txt");
    writeFileSync(cfg, "{not json");
    writeFileSync(files, "");
    const { exitCode, stderr } = await runCli([
      "--config",
      cfg,
      "--files",
      files,
    ]);
    expect(exitCode).not.toBe(0);
    expect(stderr).toMatch(/config|JSON/i);
  });

  test("ignores blank lines and trims whitespace in the files list", async () => {
    const cfg = join(dir, "cfg2.json");
    const files = join(dir, "files3.txt");
    writeFileSync(
      cfg,
      JSON.stringify({
        rules: [{ label: "documentation", patterns: ["docs/**"] }],
      }),
    );
    writeFileSync(files, "\n  docs/a.md  \n\n\n");
    const { exitCode, stdout } = await runCli([
      "--config",
      cfg,
      "--files",
      files,
    ]);
    expect(exitCode).toBe(0);
    expect(JSON.parse(stdout).labels).toEqual(["documentation"]);
  });
});
