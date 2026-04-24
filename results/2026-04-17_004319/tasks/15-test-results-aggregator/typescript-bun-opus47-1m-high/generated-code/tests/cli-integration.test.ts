// Integration test: run the CLI against on-disk fixtures and assert the
// generated markdown summary matches expectations.
import { describe, test, expect, beforeAll } from "bun:test";
import { $ } from "bun";
import { mkdtempSync, writeFileSync, rmSync, readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

const cliPath = join(import.meta.dir, "..", "src", "cli.ts");
const fixturesDir = join(import.meta.dir, "..", "fixtures");

describe("cli integration", () => {
  let tmp: string;

  beforeAll(() => {
    tmp = mkdtempSync(join(tmpdir(), "tra-"));
  });

  test("aggregates mixed xml + json fixtures and writes summary", async () => {
    const outPath = join(tmp, "summary.md");
    const result =
      await $`bun run ${cliPath} --input ${fixturesDir} --output ${outPath}`.quiet();
    expect(result.exitCode).toBe(0);
    expect(existsSync(outPath)).toBe(true);
    const md = readFileSync(outPath, "utf8");

    // Fixtures: 3 files (run1.xml, run2.xml, run3.json). We assert exact totals.
    // run1.xml: 3 passed, 1 failed, 1 skipped (5 total)
    // run2.xml: 4 passed, 0 failed, 0 skipped (4 total) — flips "flaky_test" to pass
    // run3.json: 3 passed, 1 failed, 0 skipped (4 total)
    // grand total = 13, passed = 10, failed = 2, skipped = 1
    expect(md).toContain("| 13 | 10 | 2 | 1 |");
    // One test flipped: Calc :: flaky_test → flaky
    expect(md).toContain("## Flaky Tests");
    expect(md).toContain("Calc :: flaky_test");
    // One consistently failing test: Parser :: broken_always
    expect(md).toContain("Parser :: broken_always");
  });

  test("exits non-zero on missing input directory", async () => {
    const result =
      await $`bun run ${cliPath} --input ${join(tmp, "nope")} --output ${join(tmp, "x.md")}`
        .nothrow()
        .quiet();
    expect(result.exitCode).not.toBe(0);
    expect(result.stderr.toString()).toMatch(/not found|does not exist|ENOENT/i);
  });
});
