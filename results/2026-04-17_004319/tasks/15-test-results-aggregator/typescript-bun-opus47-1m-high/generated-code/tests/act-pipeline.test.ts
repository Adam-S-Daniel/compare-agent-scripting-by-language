// End-to-end pipeline tests: run the GitHub Actions workflow through `act` for
// each fixture case, capturing output to act-result.txt. The test harness
// sets up an isolated git repo per case so each `act push` sees only that
// case's fixtures. All test cases assert on EXACT expected values derived
// from the fixture data.
//
// Why this file exists: the benchmark requires every test case to execute
// through the CI pipeline (act) rather than the script directly.
import { describe, test, expect, beforeAll } from "bun:test";
import { $ } from "bun";
import {
  mkdtempSync,
  cpSync,
  rmSync,
  writeFileSync,
  readFileSync,
  existsSync,
  mkdirSync,
} from "node:fs";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";

// Root of the project (where package.json lives).
const projectRoot = resolve(import.meta.dir, "..");
const actResultPath = join(projectRoot, "act-result.txt");

// Files/dirs to copy from the project into the isolated test repo.
// Skip node_modules (re-install via `bun install`), .git, and act-result.txt itself.
const COPY = [
  "package.json",
  "bun.lock",
  "tsconfig.json",
  ".actrc",
  ".github",
  "src",
  "tests",
];

interface Case {
  name: string;
  fixturesSource: string; // absolute path to the fixture dir we'll rename to `fixtures/`
  // Assertions: substrings that MUST appear in act stdout.
  mustContain: string[];
  // Substrings that must NOT appear.
  mustNotContain?: string[];
}

const CASES: Case[] = [
  {
    name: "default-mixed",
    fixturesSource: join(projectRoot, "fixtures"),
    mustContain: [
      // Exact totals row rendered by renderer.ts for the default fixture set.
      "| 13 | 10 | 2 | 1 |",
      // The flaky test that flips between runs.
      "Calc :: flaky_test",
      // The consistently failing test.
      "Parser :: broken_always",
      // One-line log from cli.ts.
      "total=13 passed=10 failed=2 skipped=1 flaky=1",
    ],
  },
  {
    name: "all-pass",
    fixturesSource: join(projectRoot, "fixtures-allpass"),
    mustContain: [
      "| 3 | 3 | 0 | 0 |",
      "All tests passed.",
      "total=3 passed=3 failed=0 skipped=0 flaky=0",
    ],
    mustNotContain: ["## Failures", "## Flaky Tests"],
  },
  {
    name: "only-failures",
    fixturesSource: join(projectRoot, "fixtures-failures"),
    mustContain: [
      "| 3 | 1 | 2 | 0 |",
      "F :: one",
      "F :: two",
      "boom 1",
      "boom 2",
      "total=3 passed=1 failed=2 skipped=0 flaky=0",
    ],
  },
];

function setUpRepo(repoDir: string, fixturesSource: string): void {
  // Copy project files.
  for (const name of COPY) {
    const from = join(projectRoot, name);
    if (!existsSync(from)) continue;
    cpSync(from, join(repoDir, name), { recursive: true });
  }
  // Replace fixtures/ with the case's fixture set.
  const destFixtures = join(repoDir, "fixtures");
  if (existsSync(destFixtures)) rmSync(destFixtures, { recursive: true, force: true });
  cpSync(fixturesSource, destFixtures, { recursive: true });

  // Minimal .gitignore to keep the repo clean.
  writeFileSync(join(repoDir, ".gitignore"), "node_modules\nout\n", "utf8");
}

async function gitInit(repoDir: string): Promise<void> {
  // Use local git config so we don't depend on the runner's global config.
  await $`git init -q -b main`.cwd(repoDir).quiet();
  await $`git config user.email ci@example.com`.cwd(repoDir).quiet();
  await $`git config user.name CI`.cwd(repoDir).quiet();
  await $`git add -A`.cwd(repoDir).quiet();
  await $`git commit -q -m "test case setup"`.cwd(repoDir).quiet();
}

async function runAct(repoDir: string): Promise<{ exitCode: number; output: string }> {
  // `act push --rm` uses the push event which the workflow is configured for.
  // --rm removes the act containers after the run. We merge stdout+stderr so
  // we capture everything act prints.
  const proc = Bun.spawn(["act", "push", "--rm"], {
    cwd: repoDir,
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  const exitCode = await proc.exited;
  return { exitCode, output: stdout + "\n" + stderr };
}

describe("act pipeline", () => {
  beforeAll(() => {
    // Fresh act-result.txt per run so we don't mix old output with new.
    writeFileSync(actResultPath, "", "utf8");
  });

  for (const c of CASES) {
    test(
      `case: ${c.name}`,
      async () => {
        const repo = mkdtempSync(join(tmpdir(), `act-${c.name}-`));
        try {
          setUpRepo(repo, c.fixturesSource);
          await gitInit(repo);

          const { exitCode, output } = await runAct(repo);

          // Append this case's act output to the required artifact.
          const delimiter = `\n===== case: ${c.name} (exit=${exitCode}) =====\n`;
          const footer = `\n===== end case: ${c.name} =====\n`;
          const fh = Bun.file(actResultPath);
          const existing = (await fh.exists()) ? await fh.text() : "";
          writeFileSync(actResultPath, existing + delimiter + output + footer, "utf8");

          // Must exit zero.
          expect(exitCode).toBe(0);
          // Every job must show success.
          expect(output).toContain("Job succeeded");

          // Exact-value assertions.
          for (const needle of c.mustContain) {
            expect(output).toContain(needle);
          }
          for (const needle of c.mustNotContain ?? []) {
            expect(output).not.toContain(needle);
          }
        } finally {
          // Keep the temp repo around only if something went wrong, to aid debugging.
          // Remove it on success by default.
          try {
            rmSync(repo, { recursive: true, force: true });
          } catch {
            /* best-effort */
          }
        }
      },
      // act can take a while, especially on the first run when it pulls images
      // or installs dependencies inside the container.
      5 * 60 * 1000,
    );
  }
});
