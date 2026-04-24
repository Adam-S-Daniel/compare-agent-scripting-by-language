// Act harness: runs the full GitHub Actions workflow through `act push --rm`
// inside a throwaway git repo built from the project sources, then asserts on
// exact values in the captured output.
//
// The workflow contains four test cases (basic, with-exclude, with-include,
// too-big) as distinct steps — we run act once and parse markers from the
// combined log, so the whole test matrix costs exactly one act invocation.
//
// The full log is persisted to act-result.txt in the project root so the
// benchmark runner can attach it as an artifact.
//
// Gated on RUN_ACT_HARNESS=1 so plain `bun test` (including the `bun test`
// step that runs inside act itself) does not recursively invoke act.
import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import { spawnSync } from "node:child_process";
import { mkdtempSync, cpSync, writeFileSync, rmSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const ROOT = join(import.meta.dir, "..");
const ACT_RESULT = join(ROOT, "act-result.txt");
const TIMEOUT_MS = 10 * 60 * 1000;
const RUN = process.env.RUN_ACT_HARNESS === "1";
const maybe = RUN ? describe : describe.skip;

maybe("act harness", () => {
  let actLog = "";
  let actExit = -1;
  let actWorkdir = "";

  beforeAll(() => {
    actWorkdir = mkdtempSync(join(tmpdir(), "env-matrix-act-"));

    // Copy project sources. Skip node_modules and .git — act gets a fresh repo.
    for (const entry of [
      "src",
      "tests",
      "fixtures",
      ".github",
      "package.json",
      "tsconfig.json",
      ".actrc",
    ]) {
      const src = join(ROOT, entry);
      if (existsSync(src)) {
        cpSync(src, join(actWorkdir, entry), { recursive: true });
      }
    }

    const git = (args: string[]) =>
      spawnSync("git", args, { cwd: actWorkdir, encoding: "utf8" });
    git(["init", "-q", "-b", "main"]);
    git(["config", "user.email", "harness@test.local"]);
    git(["config", "user.name", "Harness"]);
    git(["config", "commit.gpgsign", "false"]);
    git(["add", "-A"]);
    const commit = git(["commit", "-q", "-m", "harness fixture"]);
    if (commit.status !== 0) {
      throw new Error(`git commit failed: ${commit.stderr}`);
    }

    // --pull=false reuses the local act-ubuntu-pwsh:latest image the benchmark
    // rig provides via .actrc; act will still fall back to pulling if absent.
    const act = spawnSync(
      "act",
      ["push", "--rm", "--pull=false", "--container-architecture", "linux/amd64"],
      {
        cwd: actWorkdir,
        encoding: "utf8",
        maxBuffer: 64 * 1024 * 1024,
        timeout: TIMEOUT_MS,
      },
    );
    actLog = (act.stdout ?? "") + "\n" + (act.stderr ?? "");
    actExit = act.status ?? -1;

    writeFileSync(
      ACT_RESULT,
      [
        `=== act push --rm (combined stdout+stderr) ===`,
        `exit code: ${actExit}`,
        `scratch repo: ${actWorkdir}`,
        ``,
        actLog,
      ].join("\n"),
    );
  }, TIMEOUT_MS);

  afterAll(() => {
    if (actWorkdir && existsSync(actWorkdir)) {
      rmSync(actWorkdir, { recursive: true, force: true });
    }
  });

  test("act exits 0", () => {
    if (actExit !== 0) console.error(actLog.slice(-4000));
    expect(actExit).toBe(0);
  });

  test("both jobs report success", () => {
    const matches = [...actLog.matchAll(/Job succeeded/g)];
    expect(matches.length).toBeGreaterThanOrEqual(2);
  });

  test("basic case: total=4", () => {
    expect(actLog).toContain("=== CASE basic ===");
    expect(actLog).toContain("BASIC_TOTAL=4");
  });

  test("with-exclude case: total=7 (3x3 minus two excluded pairs)", () => {
    expect(actLog).toContain("=== CASE with-exclude ===");
    expect(actLog).toContain("EXCLUDE_TOTAL=7");
  });

  test("with-include case: total=2 and macos entry appears", () => {
    expect(actLog).toContain("=== CASE with-include ===");
    expect(actLog).toContain("INCLUDE_TOTAL=2");
    expect(actLog).toContain("macos-latest");
  });

  test("too-big case: CLI exits 2 on maxSize violation", () => {
    expect(actLog).toContain("=== CASE too-big ===");
    expect(actLog).toContain("TOO_BIG_EXIT=2");
  });
});
