// CLI tests: the CLI is the integration surface. We feed it a directory full
// of fixture files and assert on the rendered markdown plus exit status.
import { describe, expect, test } from "bun:test";
import { mkdtempSync, writeFileSync, mkdirSync, readFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { runCli } from "../src/cli.ts";

function makeTempDir(): string {
  return mkdtempSync(join(tmpdir(), "agg-"));
}

describe("runCli", () => {
  test("aggregates a directory of mixed XML and JSON results", () => {
    const dir = makeTempDir();
    writeFileSync(
      join(dir, "run1.xml"),
      `<?xml version="1.0"?>
<testsuite name="S" tests="2" failures="0" time="0.4">
  <testcase name="a" classname="S" time="0.2"/>
  <testcase name="b" classname="S" time="0.2"/>
</testsuite>`,
    );
    writeFileSync(
      join(dir, "run2.json"),
      JSON.stringify({
        suite: "S",
        tests: [
          { name: "a", classname: "S", status: "passed", duration: 0.21 },
          { name: "b", classname: "S", status: "failed", duration: 0.22, message: "boom" },
        ],
      }),
    );
    const summaryPath = join(dir, "summary.md");
    const result = runCli({ inputDir: dir, summaryPath });
    expect(result.exitCode).toBe(1); // a failure occurred → non-zero exit
    expect(result.results.totalTests).toBe(4);
    expect(result.results.passed).toBe(3);
    expect(result.results.failed).toBe(1);
    expect(existsSync(summaryPath)).toBe(true);
    const md = readFileSync(summaryPath, "utf8");
    expect(md).toContain("# Test Results");
    // `b` is flaky (passed in run1, failed in run2).
    expect(md).toContain("## Flaky Tests");
    expect(md).toContain("`S::b`");
  });

  test("exits 0 when every test passes", () => {
    const dir = makeTempDir();
    writeFileSync(
      join(dir, "ok.json"),
      JSON.stringify({
        suite: "S",
        tests: [{ name: "t", status: "passed", duration: 0.1 }],
      }),
    );
    const result = runCli({ inputDir: dir, summaryPath: join(dir, "out.md") });
    expect(result.exitCode).toBe(0);
  });

  test("recurses into subdirectories", () => {
    const dir = makeTempDir();
    mkdirSync(join(dir, "shard-1"));
    mkdirSync(join(dir, "shard-2"));
    writeFileSync(
      join(dir, "shard-1", "results.json"),
      JSON.stringify({ suite: "A", tests: [{ name: "t", status: "passed", duration: 0.1 }] }),
    );
    writeFileSync(
      join(dir, "shard-2", "results.json"),
      JSON.stringify({ suite: "B", tests: [{ name: "t", status: "passed", duration: 0.1 }] }),
    );
    const result = runCli({ inputDir: dir, summaryPath: join(dir, "s.md") });
    expect(result.results.fileCount).toBe(2);
  });

  test("reports a friendly error when input directory is missing", () => {
    expect(() =>
      runCli({ inputDir: "/nonexistent-path-xyz", summaryPath: "/tmp/x.md" }),
    ).toThrow(/nonexistent-path-xyz/);
  });

  test("ignores unrelated files (e.g. .txt)", () => {
    const dir = makeTempDir();
    writeFileSync(join(dir, "readme.txt"), "ignore me");
    writeFileSync(
      join(dir, "ok.json"),
      JSON.stringify({ suite: "S", tests: [{ name: "t", status: "passed", duration: 0.1 }] }),
    );
    const result = runCli({ inputDir: dir, summaryPath: join(dir, "s.md") });
    expect(result.results.fileCount).toBe(1);
  });
});
