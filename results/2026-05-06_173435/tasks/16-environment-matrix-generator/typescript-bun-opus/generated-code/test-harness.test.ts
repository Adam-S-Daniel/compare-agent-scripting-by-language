import { describe, test, expect, beforeAll } from "bun:test";
import { execSync, spawnSync } from "child_process";
import { readFileSync, writeFileSync, mkdtempSync, cpSync, existsSync, appendFileSync } from "fs";
import { tmpdir } from "os";
import { join, resolve } from "path";

const PROJECT_DIR = resolve(import.meta.dir);
const RESULT_FILE = join(PROJECT_DIR, "act-result.txt");

function extractFixtureOutput(actOutput: string, fixtureName: string): string {
  const startMarker = `===FIXTURE:${fixtureName}===`;
  const endMarker = `===END:${fixtureName}===`;
  const lines = actOutput.split("\n");
  let capturing = false;
  const captured: string[] = [];
  for (const line of lines) {
    const cleaned = stripActPrefix(line);
    if (cleaned.includes(startMarker)) {
      capturing = true;
      continue;
    }
    if (cleaned.includes(endMarker)) {
      capturing = false;
      continue;
    }
    if (capturing) captured.push(line);
  }
  return captured.join("\n");
}

function stripActPrefix(line: string): string {
  const pipeIdx = line.indexOf("| ");
  if (pipeIdx !== -1) return line.substring(pipeIdx + 2);
  return line.trim();
}

function extractJson(text: string): Record<string, unknown> | null {
  const lines = text.split("\n");
  let jsonStr = "";
  let braceDepth = 0;
  let inJson = false;
  for (const line of lines) {
    const cleaned = stripActPrefix(line);
    if (!inJson && cleaned.startsWith("{")) {
      inJson = true;
      jsonStr = "";
    }
    if (inJson) {
      jsonStr += cleaned + "\n";
      for (const ch of cleaned) {
        if (ch === "{") braceDepth++;
        if (ch === "}") braceDepth--;
      }
      if (braceDepth === 0) {
        try {
          return JSON.parse(jsonStr);
        } catch {
          inJson = false;
          jsonStr = "";
        }
      }
    }
  }
  return null;
}

describe("Workflow structure tests", () => {
  test("workflow YAML file exists", () => {
    const path = join(PROJECT_DIR, ".github/workflows/environment-matrix-generator.yml");
    expect(existsSync(path)).toBe(true);
  });

  test("workflow has correct triggers", () => {
    const content = readFileSync(
      join(PROJECT_DIR, ".github/workflows/environment-matrix-generator.yml"),
      "utf-8"
    );
    expect(content).toContain("push:");
    expect(content).toContain("pull_request:");
    expect(content).toContain("workflow_dispatch:");
  });

  test("workflow references existing script files", () => {
    const content = readFileSync(
      join(PROJECT_DIR, ".github/workflows/environment-matrix-generator.yml"),
      "utf-8"
    );
    expect(content).toContain("matrix-generator.ts");
    expect(existsSync(join(PROJECT_DIR, "matrix-generator.ts"))).toBe(true);

    const fixtures = ["basic.json", "include-exclude.json", "options.json", "too-large.json", "complex.json"];
    for (const f of fixtures) {
      expect(content).toContain(`fixtures/${f}`);
      expect(existsSync(join(PROJECT_DIR, "fixtures", f))).toBe(true);
    }
  });

  test("workflow has checkout step", () => {
    const content = readFileSync(
      join(PROJECT_DIR, ".github/workflows/environment-matrix-generator.yml"),
      "utf-8"
    );
    expect(content).toContain("actions/checkout@v4");
  });

  test("workflow has permissions set", () => {
    const content = readFileSync(
      join(PROJECT_DIR, ".github/workflows/environment-matrix-generator.yml"),
      "utf-8"
    );
    expect(content).toContain("permissions:");
    expect(content).toContain("contents: read");
  });

  test("actionlint passes with exit code 0", () => {
    const result = spawnSync("actionlint", [
      join(PROJECT_DIR, ".github/workflows/environment-matrix-generator.yml"),
    ]);
    expect(result.status).toBe(0);
  });
});

describe("Matrix generator via act", () => {
  let actOutput: string = "";
  let actExitCode: number | null = null;

  beforeAll(() => {
    writeFileSync(RESULT_FILE, "");

    const tmpDir = mkdtempSync(join(tmpdir(), "matrix-test-"));
    cpSync(PROJECT_DIR, tmpDir, {
      recursive: true,
      filter: (src: string) => !src.includes("node_modules") && !src.endsWith("/.git") && !src.includes("/.git/"),
    });

    execSync("git init && git add -A && git commit -m 'test'", {
      cwd: tmpDir,
      stdio: "pipe",
      env: {
        ...process.env,
        GIT_AUTHOR_NAME: "test",
        GIT_AUTHOR_EMAIL: "test@test.com",
        GIT_COMMITTER_NAME: "test",
        GIT_COMMITTER_EMAIL: "test@test.com",
      },
    });

    cpSync(join(PROJECT_DIR, ".actrc"), join(tmpDir, ".actrc"));

    const actResult = spawnSync("act", ["push", "--rm", "--pull=false"], {
      cwd: tmpDir,
      timeout: 300_000,
      env: { ...process.env },
      maxBuffer: 10 * 1024 * 1024,
    });

    actOutput = actResult.stdout?.toString() ?? "";
    actOutput += actResult.stderr?.toString() ?? "";
    actExitCode = actResult.status;

    appendFileSync(RESULT_FILE, `=== ACT RUN: all fixtures ===\n`);
    appendFileSync(RESULT_FILE, `Exit code: ${actExitCode}\n`);
    appendFileSync(RESULT_FILE, actOutput);
    appendFileSync(RESULT_FILE, `\n=== END ACT RUN ===\n`);
  }, 300_000);

  test("act exits with code 0", () => {
    expect(actExitCode).toBe(0);
  });

  test("act output contains Job succeeded", () => {
    expect(actOutput).toContain("succeeded");
  });

  test("basic matrix produces exactly 4 combinations", () => {
    const section = extractFixtureOutput(actOutput, "basic");
    const json = extractJson(section);
    expect(json).not.toBeNull();
    expect((json as Record<string, unknown>).total_combinations).toBe(4);

    const strategy = (json as Record<string, unknown>).strategy as Record<string, unknown>;
    const matrix = strategy.matrix as Record<string, unknown>;
    const include = matrix.include as Record<string, unknown>[];
    expect(include.length).toBe(4);
    expect(strategy["fail-fast"]).toBe(true);

    const combos = include.map((e) => `${e.os}|${e["node-version"]}`).sort();
    expect(combos).toEqual([
      "ubuntu-latest|18",
      "ubuntu-latest|20",
      "windows-latest|18",
      "windows-latest|20",
    ]);
  });

  test("include-exclude produces exactly 4 combinations (4 base - 1 excluded + 1 included)", () => {
    const section = extractFixtureOutput(actOutput, "include-exclude");
    const json = extractJson(section);
    expect(json).not.toBeNull();
    expect((json as Record<string, unknown>).total_combinations).toBe(4);

    const strategy = (json as Record<string, unknown>).strategy as Record<string, unknown>;
    const matrix = strategy.matrix as Record<string, unknown>;
    const include = matrix.include as Record<string, unknown>[];
    expect(include.length).toBe(4);

    const hasExcluded = include.some(
      (e) => e.os === "windows-latest" && e["node-version"] === "18"
    );
    expect(hasExcluded).toBe(false);

    const hasIncluded = include.some(
      (e) => e.os === "macos-latest" && e["node-version"] === "22"
    );
    expect(hasIncluded).toBe(true);
  });

  test("options fixture sets fail-fast=false and max-parallel=2", () => {
    const section = extractFixtureOutput(actOutput, "options");
    const json = extractJson(section);
    expect(json).not.toBeNull();

    const strategy = (json as Record<string, unknown>).strategy as Record<string, unknown>;
    expect(strategy["fail-fast"]).toBe(false);
    expect(strategy["max-parallel"]).toBe(2);
    expect((json as Record<string, unknown>).total_combinations).toBe(3);
  });

  test("too-large fixture produces validation error", () => {
    const section = extractFixtureOutput(actOutput, "too-large");
    expect(section).toContain("EXPECTED_ERROR");
    expect(section).toContain("125");
    expect(section).toContain("10");
  });

  test("complex matrix produces 10 combinations (12 base - 2 excluded, + coverage merge)", () => {
    const section = extractFixtureOutput(actOutput, "complex");
    const json = extractJson(section);
    expect(json).not.toBeNull();
    expect((json as Record<string, unknown>).total_combinations).toBe(10);

    const strategy = (json as Record<string, unknown>).strategy as Record<string, unknown>;
    expect(strategy["fail-fast"]).toBe(false);
    expect(strategy["max-parallel"]).toBe(4);

    const matrix = strategy.matrix as Record<string, unknown>;
    const include = matrix.include as Record<string, unknown>[];

    const noneWithMacGcc = include.every(
      (e) => !(e.os === "macos-latest" && e.compiler === "gcc")
    );
    expect(noneWithMacGcc).toBe(true);

    const coverageEntry = include.find(
      (e) => e.os === "ubuntu-latest" && e.compiler === "gcc" && e["build-type"] === "release"
    );
    expect(coverageEntry).toBeDefined();
    expect(coverageEntry!.coverage).toBe(true);
  });

  test("act-result.txt exists and has content", () => {
    expect(existsSync(RESULT_FILE)).toBe(true);
    const content = readFileSync(RESULT_FILE, "utf-8");
    expect(content.length).toBeGreaterThan(0);
  });
});
