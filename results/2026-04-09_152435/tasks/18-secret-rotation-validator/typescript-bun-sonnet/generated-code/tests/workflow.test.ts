/**
 * Workflow structure tests and act integration test.
 *
 * Three categories:
 * 1. Workflow structure tests - parse YAML, check expected structure
 * 2. Path existence tests - verify script files referenced in workflow exist
 * 3. Act integration test - run the actual workflow in Docker via `act push --rm`
 *    (skipped when running inside GitHub Actions to prevent infinite recursion)
 */
import { describe, test, expect } from "bun:test";
import { execSync } from "child_process";
import {
  readFileSync,
  existsSync,
  mkdtempSync,
  writeFileSync,
  cpSync,
  appendFileSync,
} from "fs";
import { tmpdir } from "os";
import { join, resolve } from "path";

const WORKFLOW_FILE = ".github/workflows/secret-rotation-validator.yml";
// Directory containing THIS test file (tests/); project root is one level up
const PROJECT_DIR = resolve(import.meta.dir, "..");

// ─── 1. Workflow Structure Tests ──────────────────────────────────────────────

describe("Workflow structure", () => {
  test("workflow file exists at expected path", () => {
    expect(existsSync(WORKFLOW_FILE)).toBe(true);
  });

  test("workflow has push trigger", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("push:");
  });

  test("workflow has schedule trigger", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("schedule:");
  });

  test("workflow has workflow_dispatch trigger", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("workflow_dispatch:");
  });

  test("workflow has validate-secrets job", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("validate-secrets");
  });

  test("workflow uses actions/checkout@v4", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("actions/checkout@v4");
  });

  test("workflow references app.ts", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("app.ts");
  });

  test("workflow references test fixture", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("test-secrets.json");
  });

  test("workflow uses fixed date for deterministic output", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    expect(content).toContain("2026-04-10");
  });

  test("workflow validates exact expected values", () => {
    const content = readFileSync(WORKFLOW_FILE, "utf-8");
    // The workflow should assert on specific secret names and urgency values
    expect(content).toContain("PROD_DB_PASSWORD");
    expect(content).toContain("expired");
    expect(content).toContain("API_KEY");
    expect(content).toContain("warning");
    expect(content).toContain("JWT_SECRET");
  });
});

// ─── 2. Path Existence Tests ──────────────────────────────────────────────────

describe("Referenced files exist", () => {
  test("app.ts exists", () => {
    expect(existsSync(join(PROJECT_DIR, "app.ts"))).toBe(true);
  });

  test("fixtures/test-secrets.json exists", () => {
    expect(existsSync(join(PROJECT_DIR, "fixtures/test-secrets.json"))).toBe(true);
  });

  test("fixtures/secrets.json exists", () => {
    expect(existsSync(join(PROJECT_DIR, "fixtures/secrets.json"))).toBe(true);
  });

  test("src/validator.ts exists", () => {
    expect(existsSync(join(PROJECT_DIR, "src/validator.ts"))).toBe(true);
  });

  test("src/formatter.ts exists", () => {
    expect(existsSync(join(PROJECT_DIR, "src/formatter.ts"))).toBe(true);
  });

  test("src/types.ts exists", () => {
    expect(existsSync(join(PROJECT_DIR, "src/types.ts"))).toBe(true);
  });
});

// ─── 3. Actionlint Validation ─────────────────────────────────────────────────

describe("actionlint validation", () => {
  test("workflow passes actionlint with exit code 0", () => {
    let exitCode = 0;
    let output = "";
    try {
      output = execSync(`actionlint ${WORKFLOW_FILE}`, {
        encoding: "utf-8",
        stdio: ["pipe", "pipe", "pipe"],
      });
    } catch (err: unknown) {
      if (err && typeof err === "object" && "status" in err) {
        exitCode = (err as { status: number }).status ?? 1;
        output =
          ("stdout" in err ? String((err as { stdout: unknown }).stdout) : "") +
          ("stderr" in err ? String((err as { stderr: unknown }).stderr) : "");
      } else {
        exitCode = 1;
      }
    }
    if (exitCode !== 0) {
      console.error("actionlint output:", output);
    }
    expect(exitCode).toBe(0);
  });
});

// ─── 4. Act Integration Test ──────────────────────────────────────────────────
// Runs the full workflow in Docker via `act push --rm`.
// Skipped when running inside GitHub Actions to prevent infinite recursion.

const isInCI = !!process.env.GITHUB_ACTIONS;
const ACT_RESULT_FILE = join(PROJECT_DIR, "act-result.txt");

describe("Act integration", () => {
  test(
    "act push succeeds and produces exact expected output",
    () => {
      if (isInCI) {
        console.log("Skipping act integration test - already running inside CI");
        // Write a placeholder so act-result.txt always exists
        appendFileSync(
          ACT_RESULT_FILE,
          "\n=== Skipped: running inside CI ===\n"
        );
        return;
      }

      // Set up a fresh temp git repo with all project files
      const tmpDir = mkdtempSync(join(tmpdir(), "secret-rotation-"));
      console.log(`Act temp dir: ${tmpDir}`);

      // Copy all necessary project files
      const itemsToCopy = [
        "src",
        "tests",
        "fixtures",
        "app.ts",
        "tsconfig.json",
        ".github",
        ".actrc",
      ];

      for (const item of itemsToCopy) {
        const src = join(PROJECT_DIR, item);
        const dst = join(tmpDir, item);
        if (existsSync(src)) {
          cpSync(src, dst, { recursive: true });
        }
      }

      // Initialize git repo in temp dir (act requires a git repo)
      execSync(
        [
          "git init",
          'git config user.email "test@benchmark.local"',
          'git config user.name "Benchmark Test"',
          "git add -A",
          'git commit -m "test: secret rotation validator"',
        ].join(" && "),
        { cwd: tmpDir, stdio: "pipe" }
      );

      // Run act and capture all output (stdout + stderr merged)
      let output = "";
      let exitCode = 0;

      try {
        output = execSync("act push --rm 2>&1", {
          cwd: tmpDir,
          timeout: 180000, // 3 minutes max
          encoding: "utf-8",
        });
      } catch (err: unknown) {
        if (err && typeof err === "object") {
          exitCode = ("status" in err ? Number((err as { status: unknown }).status) : 0) ?? 1;
          output =
            ("stdout" in err ? String((err as { stdout: unknown }).stdout) : "") ||
            ("stderr" in err ? String((err as { stderr: unknown }).stderr) : "");
        }
        if (!output) output = String(err);
      }

      // Append full output to act-result.txt with clear delimiters
      const delimiter = "=".repeat(70);
      const entry = [
        "",
        delimiter,
        "TEST CASE: Secret Rotation Validator (act push)",
        `DATE: ${new Date().toISOString()}`,
        `EXIT CODE: ${exitCode}`,
        delimiter,
        output,
        delimiter,
        "",
      ].join("\n");

      appendFileSync(ACT_RESULT_FILE, entry);
      console.log(`Output saved to act-result.txt (exit code: ${exitCode})`);

      // ── Assertions on exact expected values ──────────────────────────────

      // Exit code must be 0
      expect(exitCode).toBe(0);

      // Every job must show success
      expect(output).toContain("Job succeeded");

      // Exact values from fixture data + --today 2026-04-10
      // PROD_DB_PASSWORD: expires 2026-01-31, daysUntilExpiry=-69, urgency=expired
      expect(output).toContain('"name": "PROD_DB_PASSWORD"');
      expect(output).toContain('"expiryDate": "2026-01-31"');
      expect(output).toContain('"daysUntilExpiry": -69');
      expect(output).toContain('"urgency": "expired"');

      // API_KEY: expires 2026-04-11, daysUntilExpiry=1, urgency=warning
      expect(output).toContain('"name": "API_KEY"');
      expect(output).toContain('"expiryDate": "2026-04-11"');
      expect(output).toContain('"daysUntilExpiry": 1');
      expect(output).toContain('"urgency": "warning"');

      // JWT_SECRET: expires 2026-07-04, daysUntilExpiry=85, urgency=ok
      expect(output).toContain('"name": "JWT_SECRET"');
      expect(output).toContain('"expiryDate": "2026-07-04"');
      expect(output).toContain('"daysUntilExpiry": 85');
      expect(output).toContain('"urgency": "ok"');

      // Summary counts
      expect(output).toContain('"expired": 1');
      expect(output).toContain('"warning": 1');
      expect(output).toContain('"ok": 1');

      // Validation step must confirm all checks passed
      expect(output).toContain("All structural validations passed!");
    },
    { timeout: 200000 } // 200 seconds for Docker container startup + workflow
  );
});
