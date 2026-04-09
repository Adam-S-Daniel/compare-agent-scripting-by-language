#!/usr/bin/env bun

/**
 * Test harness that runs all matrix generator tests through GitHub Actions
 * via `act`. Each test sets up a temp git repo, runs act, captures output,
 * and asserts on exact expected values.
 *
 * Output is appended to act-result.txt in the working directory.
 */

import { describe, test, expect, beforeAll, afterAll, setDefaultTimeout } from "bun:test";

// Act may take a long time to pull images and run
setDefaultTimeout(600_000);
import { mkdtemp, rm, cp, mkdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { existsSync, readFileSync, writeFileSync, appendFileSync } from "node:fs";

// The project directory where our source lives
const PROJECT_DIR = resolve(import.meta.dir);
const ACT_RESULT_FILE = join(PROJECT_DIR, "act-result.txt");

// Files needed in each temp repo
const PROJECT_FILES = [
  "matrix-generator.ts",
  ".github/workflows/environment-matrix-generator.yml",
];

const FIXTURE_FILES = [
  "fixtures/basic.json",
  "fixtures/with-exclude.json",
  "fixtures/with-include.json",
  "fixtures/full-config.json",
  "fixtures/exceeds-max-size.json",
  "fixtures/single-dimension.json",
];

/**
 * Set up a temporary git repo with all project files for act to use.
 */
async function setupTempRepo(): Promise<string> {
  const tempDir = await mkdtemp(join(tmpdir(), "matrix-gen-test-"));

  // Create directory structure
  await mkdir(join(tempDir, ".github", "workflows"), { recursive: true });
  await mkdir(join(tempDir, "fixtures"), { recursive: true });

  // Copy project files
  for (const file of [...PROJECT_FILES, ...FIXTURE_FILES]) {
    const src = join(PROJECT_DIR, file);
    const dest = join(tempDir, file);
    await cp(src, dest);
  }

  // Initialize git repo (act requires a git repo)
  const gitInit = Bun.spawnSync(["git", "init"], { cwd: tempDir });
  Bun.spawnSync(["git", "config", "user.email", "test@test.com"], { cwd: tempDir });
  Bun.spawnSync(["git", "config", "user.name", "Test"], { cwd: tempDir });
  Bun.spawnSync(["git", "add", "."], { cwd: tempDir });
  Bun.spawnSync(["git", "commit", "-m", "init"], { cwd: tempDir });

  return tempDir;
}

/**
 * Run act in the given directory and return stdout + exit code.
 */
function runAct(cwd: string): { stdout: string; stderr: string; exitCode: number } {
  const result = Bun.spawnSync(
    ["act", "push", "--rm", "-P", "ubuntu-latest=catthehacker/ubuntu:act-latest"],
    {
      cwd,
      env: { ...process.env, DOCKER_HOST: process.env.DOCKER_HOST || "" },
      timeout: 300_000, // 5 minute timeout
    }
  );

  const stdout = result.stdout?.toString() ?? "";
  const stderr = result.stderr?.toString() ?? "";
  return { stdout, stderr, exitCode: result.exitCode };
}

// --- Workflow structure tests ---

describe("Workflow structure validation", () => {
  test("workflow YAML has correct structure", () => {
    const yamlPath = join(PROJECT_DIR, ".github/workflows/environment-matrix-generator.yml");
    const content = readFileSync(yamlPath, "utf-8");

    // Check triggers
    expect(content).toContain("push:");
    expect(content).toContain("pull_request:");
    expect(content).toContain("workflow_dispatch:");

    // Check jobs
    expect(content).toContain("jobs:");
    expect(content).toContain("generate-matrix:");

    // Check steps
    expect(content).toContain("actions/checkout@v4");
    expect(content).toContain("oven-sh/setup-bun@v2");

    // Check permissions
    expect(content).toContain("permissions:");
    expect(content).toContain("contents: read");
  });

  test("workflow references existing script files", () => {
    // Verify the matrix-generator.ts file exists
    expect(existsSync(join(PROJECT_DIR, "matrix-generator.ts"))).toBe(true);

    // Verify all fixture files exist
    for (const fixture of FIXTURE_FILES) {
      expect(existsSync(join(PROJECT_DIR, fixture))).toBe(true);
    }

    // Verify workflow file exists
    expect(
      existsSync(join(PROJECT_DIR, ".github/workflows/environment-matrix-generator.yml"))
    ).toBe(true);
  });

  test("actionlint passes with exit code 0", () => {
    const result = Bun.spawnSync(
      ["actionlint", join(PROJECT_DIR, ".github/workflows/environment-matrix-generator.yml")],
      { cwd: PROJECT_DIR }
    );
    const stderr = result.stderr?.toString() ?? "";
    expect(result.exitCode).toBe(0);
  });
});

// --- Integration tests via act ---

describe("Integration tests via act", () => {
  let tempDir: string;
  let actOutput: string;
  let actExitCode: number;

  beforeAll(async () => {
    // Clear the act-result.txt file
    writeFileSync(ACT_RESULT_FILE, "");

    // Set up temp repo and run act once (the workflow tests all fixtures)
    tempDir = await setupTempRepo();

    appendFileSync(ACT_RESULT_FILE, "=== ACT RUN START ===\n");
    appendFileSync(ACT_RESULT_FILE, `Temp directory: ${tempDir}\n`);
    appendFileSync(ACT_RESULT_FILE, `Timestamp: ${new Date().toISOString()}\n\n`);

    const result = runAct(tempDir);
    actOutput = result.stdout + "\n" + result.stderr;
    actExitCode = result.exitCode;

    appendFileSync(ACT_RESULT_FILE, actOutput);
    appendFileSync(ACT_RESULT_FILE, `\nExit code: ${actExitCode}\n`);
    appendFileSync(ACT_RESULT_FILE, "=== ACT RUN END ===\n\n");
  });

  afterAll(async () => {
    // Clean up temp directory
    if (tempDir) {
      await rm(tempDir, { recursive: true, force: true });
    }
  });

  test("act exits with code 0", () => {
    expect(actExitCode).toBe(0);
  });

  test("generate-matrix job succeeded", () => {
    // act reports job success
    expect(actOutput).toContain("Job succeeded");
  });

  // --- Basic fixture: 2 OS x 2 node versions = 4 combinations ---
  test("basic fixture produces exactly 4 combinations", () => {
    // The basic fixture has os=[ubuntu-latest, macos-latest] x node-version=[18, 20]
    // That's 2x2 = 4 combinations
    expect(actOutput).toContain('"ubuntu-latest"');
    expect(actOutput).toContain('"macos-latest"');
    expect(actOutput).toContain('"18"');
    expect(actOutput).toContain('"20"');

    // Extract the basic matrix output and count combinations
    const basicSection = extractSection(actOutput, "Basic matrix:");
    expect(basicSection).toBeTruthy();
    const parsed = parseJsonFromSection(basicSection!);
    expect(parsed).not.toBeNull();
    expect(parsed!.matrix.include).toHaveLength(4);
  });

  // --- Single dimension: 3 OS values = 3 combinations with fail-fast ---
  test("single-dimension fixture produces 3 combinations with fail-fast true", () => {
    const section = extractSection(actOutput, "Single-dimension matrix:");
    expect(section).toBeTruthy();
    const parsed = parseJsonFromSection(section!);
    expect(parsed).not.toBeNull();
    expect(parsed!.matrix.include).toHaveLength(3);
    expect(parsed!["fail-fast"]).toBe(true);

    // Verify exact OS values
    const osValues = parsed!.matrix.include.map((e: any) => e.os).sort();
    expect(osValues).toEqual(["macos-latest", "ubuntu-latest", "windows-latest"]);
  });

  // --- Exclude fixture: 3x3=9 minus 1 excluded = 8 ---
  test("exclude fixture produces 8 combinations (9 - 1 excluded)", () => {
    const section = extractSection(actOutput, "Matrix with exclude:");
    expect(section).toBeTruthy();
    const parsed = parseJsonFromSection(section!);
    expect(parsed).not.toBeNull();
    expect(parsed!.matrix.include).toHaveLength(8);

    // Verify windows+18 is NOT in the results
    const hasExcluded = parsed!.matrix.include.some(
      (e: any) => e.os === "windows-latest" && e["node-version"] === "18"
    );
    expect(hasExcluded).toBe(false);

    // But windows+20 and windows+22 should be there
    const hasWin20 = parsed!.matrix.include.some(
      (e: any) => e.os === "windows-latest" && e["node-version"] === "20"
    );
    expect(hasWin20).toBe(true);
  });

  // --- Include fixture: 1x1=1 plus 1 included = 2 ---
  test("include fixture produces 2 combinations (1 base + 1 included)", () => {
    const section = extractSection(actOutput, "Matrix with include:");
    expect(section).toBeTruthy();
    const parsed = parseJsonFromSection(section!);
    expect(parsed).not.toBeNull();
    expect(parsed!.matrix.include).toHaveLength(2);

    // Check the included entry has the extra field
    const experimental = parsed!.matrix.include.find(
      (e: any) => e.os === "macos-latest"
    );
    expect(experimental).toBeTruthy();
    expect(experimental!.experimental).toBe("true");
    expect(experimental!["node-version"]).toBe("22");
  });

  // --- Full config: 2x2x2=8, minus 2 excluded (macos+disabled combos), plus 1 included = 7 ---
  test("full config produces correct matrix with max-parallel and fail-fast", () => {
    const section = extractSection(actOutput, "Full config matrix:");
    expect(section).toBeTruthy();
    const parsed = parseJsonFromSection(section!);
    expect(parsed).not.toBeNull();

    // 2 OS x 2 python x 2 flags = 8
    // exclude macos-latest + disabled removes 2 (macos+3.10+disabled, macos+3.11+disabled)
    // = 6 remaining
    // include adds ubuntu+3.12+enabled (new) = 7 total
    expect(parsed!.matrix.include).toHaveLength(7);
    expect(parsed!["max-parallel"]).toBe(4);
    expect(parsed!["fail-fast"]).toBe(false);

    // Verify no macos+disabled combinations
    const macosDisabled = parsed!.matrix.include.filter(
      (e: any) => e.os === "macos-latest" && e["feature-flag"] === "disabled"
    );
    expect(macosDisabled).toHaveLength(0);

    // Verify the included 3.12 entry exists
    const py312 = parsed!.matrix.include.find(
      (e: any) => e["python-version"] === "3.12"
    );
    expect(py312).toBeTruthy();
    expect(py312!.os).toBe("ubuntu-latest");
  });

  // --- Max-size enforcement ---
  test("max-size enforcement correctly rejects oversized matrix", () => {
    expect(actOutput).toContain("PASS: Correctly rejected oversized matrix");
  });

  // --- Error handling ---
  test("error handling for invalid inputs", () => {
    expect(actOutput).toContain("PASS: Correctly rejected empty input");
    expect(actOutput).toContain("PASS: Correctly rejected invalid JSON");
    expect(actOutput).toContain("PASS: Correctly rejected missing dimensions");
  });
});

// --- Helper functions ---

/**
 * Extract a section of act output starting from a marker.
 * Strips act's line prefix (e.g., "[Job/step]   | ") and collects
 * the JSON block that follows.
 */
function extractSection(output: string, marker: string): string | null {
  const idx = output.indexOf(marker);
  if (idx === -1) return null;

  const afterMarker = output.substring(idx + marker.length);
  const lines = afterMarker.split("\n");
  const jsonLines: string[] = [];
  let braceDepth = 0;
  let started = false;

  for (const line of lines) {
    // Strip act's "[...] | " prefix, handling various formats
    const stripped = line.replace(/^\[.*?\]\s*\|\s?/, "").trim();

    // Stop if we hit a non-output line (success marker, next step, etc.)
    if (started && (line.includes("✅") || line.includes("⭐") || line.includes("❌"))) {
      break;
    }

    if (!started && stripped.startsWith("{")) {
      started = true;
    }
    if (started) {
      jsonLines.push(stripped);
      braceDepth += (stripped.match(/{/g) || []).length;
      braceDepth -= (stripped.match(/}/g) || []).length;
      if (braceDepth <= 0) break;
    }
  }

  return jsonLines.join("\n") || null;
}

/**
 * Parse a JSON object from a section of text.
 */
function parseJsonFromSection(section: string): any | null {
  try {
    // Try to find JSON within the section
    const jsonMatch = section.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return null;
    return JSON.parse(jsonMatch[0]);
  } catch {
    return null;
  }
}
