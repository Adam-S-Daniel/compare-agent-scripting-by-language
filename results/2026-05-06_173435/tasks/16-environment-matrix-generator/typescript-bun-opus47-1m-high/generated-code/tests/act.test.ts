// End-to-end test harness driven through `act`.
//
// For each test case:
//   1. Stage the project files into a temp dir + that case's fixture.
//   2. Initialise a fresh git repo + single commit (act needs `push` context).
//   3. Run `act push --rm` and capture stdout/stderr.
//   4. Append the captured output to act-result.txt with clear delimiters.
//   5. Assert exit code 0, "Job succeeded" appears for every job, and the
//      parsed MATRIX_JSON_LINE matches EXACT expected values for that case.
//
// The harness intentionally limits itself to 3 act invocations -
// each act push run is expensive (30-90s) and the task budget caps it at 3.

import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import {
  appendFileSync,
  cpSync,
  existsSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const PROJECT_ROOT = join(import.meta.dir, "..");
const ACT_RESULT_FILE = join(PROJECT_ROOT, "act-result.txt");

interface TestCase {
  name: string;
  config: unknown;
  expect: {
    failFast: boolean;
    maxParallel: number | "unset";
    combinations: number;
    contains: Record<string, unknown>[];
  };
}

// Three cases, each producing a known-good matrix. Numbers and contents are
// asserted EXACTLY, not just structurally.
const CASES: TestCase[] = [
  {
    name: "simple-cartesian",
    // 2 OS x 2 node = 4 combinations, no include/exclude, defaults.
    config: {
      axes: {
        os: ["ubuntu-latest", "macos-latest"],
        node: ["18", "20"],
      },
    },
    expect: {
      failFast: true,
      maxParallel: "unset",
      combinations: 4,
      contains: [
        { os: "ubuntu-latest", node: "18" },
        { os: "ubuntu-latest", node: "20" },
        { os: "macos-latest", node: "18" },
        { os: "macos-latest", node: "20" },
      ],
    },
  },
  {
    name: "include-exclude-options",
    // 2 OS x 2 node - 1 exclude + 1 include = 4 combinations,
    // failFast=false, maxParallel=3.
    config: {
      axes: {
        os: ["ubuntu-latest", "macos-latest"],
        node: ["18", "20"],
      },
      exclude: [{ os: "macos-latest", node: "18" }],
      include: [{ os: "windows-latest", node: "20", experimental: true }],
      failFast: false,
      maxParallel: 3,
      maxSize: 10,
    },
    expect: {
      failFast: false,
      maxParallel: 3,
      combinations: 4,
      contains: [
        { os: "ubuntu-latest", node: "18" },
        { os: "ubuntu-latest", node: "20" },
        { os: "macos-latest", node: "20" },
        { os: "windows-latest", node: "20", experimental: true },
      ],
    },
  },
  {
    name: "three-axes-feature-flags",
    // 1 OS x 2 versions x 3 features = 6 combinations.
    config: {
      axes: {
        os: ["ubuntu-latest"],
        python: ["3.11", "3.12"],
        feature: ["a", "b", "c"],
      },
      maxParallel: 2,
    },
    expect: {
      failFast: true,
      maxParallel: 2,
      combinations: 6,
      contains: [
        { os: "ubuntu-latest", python: "3.11", feature: "a" },
        { os: "ubuntu-latest", python: "3.11", feature: "b" },
        { os: "ubuntu-latest", python: "3.11", feature: "c" },
        { os: "ubuntu-latest", python: "3.12", feature: "a" },
        { os: "ubuntu-latest", python: "3.12", feature: "b" },
        { os: "ubuntu-latest", python: "3.12", feature: "c" },
      ],
    },
  },
];

beforeAll(() => {
  // Reset the act-result.txt artifact at the start of the harness run.
  if (existsSync(ACT_RESULT_FILE)) rmSync(ACT_RESULT_FILE);
  writeFileSync(
    ACT_RESULT_FILE,
    `# act-result.txt - aggregated output of ${CASES.length} act runs\n` +
      `# generated ${new Date().toISOString()}\n\n`,
  );
});

interface ActResult {
  exitCode: number;
  stdout: string;
  stderr: string;
}

function runAct(cwd: string): ActResult {
  // Use the project's .actrc which selects act-ubuntu-pwsh:latest.
  // --pull=false: the custom image is provisioned locally; don't try to pull
  // it from a registry (the local tag isn't published anywhere).
  const proc = Bun.spawnSync({
    cmd: ["act", "push", "--rm", "--pull=false"],
    cwd,
    stdout: "pipe",
    stderr: "pipe",
  });
  return {
    exitCode: proc.exitCode ?? -1,
    stdout: new TextDecoder().decode(proc.stdout),
    stderr: new TextDecoder().decode(proc.stderr),
  };
}

function setupTempRepo(caseConfig: unknown): string {
  const dir = mkdtempSync(join(tmpdir(), "matrix-act-"));
  // Copy project files (excluding .git, node_modules, the result artifact).
  cpSync(PROJECT_ROOT, dir, {
    recursive: true,
    filter: (src: string): boolean => {
      const tail = src.slice(PROJECT_ROOT.length);
      // Exclude the literal .git directory (NOT .github) and node_modules.
      if (tail === "/.git" || tail.startsWith("/.git/")) return false;
      if (tail.includes("/node_modules")) return false;
      if (tail === "/act-result.txt") return false;
      return true;
    },
  });
  // Overwrite the fixture with this case's config.
  writeFileSync(
    join(dir, "fixtures", "config.json"),
    JSON.stringify(caseConfig, null, 2),
  );
  // Carry the .actrc so the project's container preference applies.
  if (existsSync(join(PROJECT_ROOT, ".actrc"))) {
    cpSync(join(PROJECT_ROOT, ".actrc"), join(dir, ".actrc"));
  }
  // Init a fresh git repo so `act push` has a real commit to operate on.
  const git = (args: string[]) =>
    Bun.spawnSync({ cmd: ["git", ...args], cwd: dir, stdout: "ignore", stderr: "ignore" });
  git(["init", "-q", "-b", "main"]);
  git(["config", "user.email", "test@example.com"]);
  git(["config", "user.name", "Test"]);
  git(["add", "-A"]);
  git(["commit", "-q", "-m", "init"]);
  return dir;
}

/**
 * Pull a single line out of act output that starts with the given prefix.
 * act prefixes every step line with `[<workflow>/<step>] | `, so we strip
 * leading non-prefix gunk and look for the marker anywhere on the line.
 */
function extractMarkerLine(stdout: string, marker: string): string | undefined {
  for (const line of stdout.split("\n")) {
    const idx = line.indexOf(marker);
    if (idx !== -1) {
      return line.slice(idx + marker.length).trim();
    }
  }
  return undefined;
}

describe("act end-to-end (workflow drives the script)", () => {
  for (const c of CASES) {
    test(
      `case '${c.name}': runs through act and matches exact expected output`,
      async () => {
        const dir = setupTempRepo(c.config);
        const result = runAct(dir);

        // Append output to the global artifact.
        const banner = `===== CASE: ${c.name} =====\n`;
        const tail = "\n===== END CASE =====\n\n";
        const stderrSection = result.stderr.length
          ? `\n--- act stderr ---\n${result.stderr}`
          : "";
        const block =
          banner +
          `exit_code=${result.exitCode}\n` +
          `--- act stdout ---\n${result.stdout}` +
          stderrSection +
          tail;
        appendFileSync(ACT_RESULT_FILE, block);

        // Hard requirements.
        expect(result.exitCode).toBe(0);

        // Both jobs must have succeeded - act prints "Job succeeded" per job.
        const successCount = (result.stdout.match(/Job succeeded/g) ?? []).length;
        expect(successCount).toBeGreaterThanOrEqual(2);

        // Extract the structured matrix JSON marker line.
        const jsonLine = extractMarkerLine(result.stdout, "MATRIX_JSON_LINE:");
        expect(jsonLine).toBeDefined();
        const parsed = JSON.parse(jsonLine!);

        // EXACT value assertions (not just shape).
        expect(parsed.strategy["fail-fast"]).toBe(c.expect.failFast);
        if (c.expect.maxParallel === "unset") {
          expect(parsed.strategy["max-parallel"]).toBeUndefined();
        } else {
          expect(parsed.strategy["max-parallel"]).toBe(c.expect.maxParallel);
        }
        expect(parsed.strategy.matrix.include).toHaveLength(
          c.expect.combinations,
        );
        for (const combo of c.expect.contains) {
          expect(parsed.strategy.matrix.include).toContainEqual(combo);
        }

        // Summary line cross-check (independent of the JSON marker).
        const summary = extractMarkerLine(result.stdout, "MATRIX_SUMMARY ");
        expect(summary).toBeDefined();
        expect(summary).toContain(`combinations=${c.expect.combinations}`);
        expect(summary).toContain(`fail-fast=${c.expect.failFast}`);
        const mpExpected =
          c.expect.maxParallel === "unset" ? "unset" : String(c.expect.maxParallel);
        expect(summary).toContain(`max-parallel=${mpExpected}`);

        rmSync(dir, { recursive: true, force: true });
      },
      300_000, // 5-minute timeout per act run
    );
  }
});

afterAll(() => {
  // Sanity: act-result.txt must exist as a required artifact.
  if (!existsSync(ACT_RESULT_FILE)) {
    throw new Error("act-result.txt was not produced");
  }
});
