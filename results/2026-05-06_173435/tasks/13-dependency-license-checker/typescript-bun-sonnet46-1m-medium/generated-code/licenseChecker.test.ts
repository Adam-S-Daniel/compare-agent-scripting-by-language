// TDD test suite for Dependency License Checker
// Written BEFORE the implementation (red/green TDD)
// Tests are ordered: each group was written failing, then code was added to pass it.

import { test, expect, describe, beforeAll, afterAll } from "bun:test";
import { existsSync, appendFileSync, mkdirSync, copyFileSync, writeFileSync, rmSync, readFileSync } from "fs";
import { spawnSync } from "child_process";
import { mkdtempSync } from "fs";
import { tmpdir } from "os";
import { join } from "path";

// --- Step 1 (first failing test): parseDependencies ---
describe("parseDependencies", () => {
  test("parses production dependencies from package.json", async () => {
    const { parseDependencies } = await import("./licenseChecker");
    const deps = parseDependencies("fixtures/package.json");
    expect(deps.length).toBe(5);
    expect(deps[0].name).toBe("express");
    expect(deps[0].version).toBe("^4.18.2");
  });

  test("returns Dependency objects with name and version", async () => {
    const { parseDependencies } = await import("./licenseChecker");
    const deps = parseDependencies("fixtures/package.json");
    for (const dep of deps) {
      expect(typeof dep.name).toBe("string");
      expect(typeof dep.version).toBe("string");
    }
  });

  test("throws meaningful error for missing file", async () => {
    const { parseDependencies } = await import("./licenseChecker");
    expect(() => parseDependencies("nonexistent.json")).toThrow();
  });

  test("throws meaningful error for invalid JSON", async () => {
    const { parseDependencies } = await import("./licenseChecker");
    writeFileSync("/tmp/bad.json", "not json");
    expect(() => parseDependencies("/tmp/bad.json")).toThrow();
  });
});

// --- Step 2 (failing test): lookupLicense ---
describe("lookupLicense", () => {
  test("returns license string for known package", async () => {
    const { lookupLicense } = await import("./licenseChecker");
    const mockData = { express: "MIT", lodash: "MIT" };
    expect(lookupLicense("express", mockData)).toBe("MIT");
  });

  test("returns null for unknown package", async () => {
    const { lookupLicense } = await import("./licenseChecker");
    const mockData = { express: "MIT" };
    expect(lookupLicense("unknown-lib", mockData)).toBeNull();
  });

  test("returns null when package explicitly has null license", async () => {
    const { lookupLicense } = await import("./licenseChecker");
    const mockData: Record<string, string | null> = { "mystery-lib": null };
    expect(lookupLicense("mystery-lib", mockData)).toBeNull();
  });
});

// --- Step 3 (failing test): checkLicenseStatus ---
describe("checkLicenseStatus", () => {
  const config = {
    allowed: ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC"],
    denied: ["GPL-2.0", "GPL-3.0", "AGPL-3.0"],
  };

  test("returns approved for allowed license", async () => {
    const { checkLicenseStatus } = await import("./licenseChecker");
    expect(checkLicenseStatus("MIT", config)).toBe("approved");
    expect(checkLicenseStatus("Apache-2.0", config)).toBe("approved");
  });

  test("returns denied for denied license", async () => {
    const { checkLicenseStatus } = await import("./licenseChecker");
    expect(checkLicenseStatus("GPL-3.0", config)).toBe("denied");
    expect(checkLicenseStatus("AGPL-3.0", config)).toBe("denied");
  });

  test("returns unknown for license not in either list", async () => {
    const { checkLicenseStatus } = await import("./licenseChecker");
    expect(checkLicenseStatus("Unlicense", config)).toBe("unknown");
  });

  test("returns unknown for null license", async () => {
    const { checkLicenseStatus } = await import("./licenseChecker");
    expect(checkLicenseStatus(null, config)).toBe("unknown");
  });
});

// --- Step 4 (failing test): checkLicenses ---
describe("checkLicenses", () => {
  const config = {
    allowed: ["MIT"],
    denied: ["GPL-3.0"],
  };
  const mockData: Record<string, string | null> = {
    express: "MIT",
    "gpl-violator": "GPL-3.0",
    "mystery-lib": null,
  };

  test("returns LicenseStatus array for all deps", async () => {
    const { checkLicenses } = await import("./licenseChecker");
    const deps = [
      { name: "express", version: "^4.18.2" },
      { name: "gpl-violator", version: "^1.0.0" },
      { name: "mystery-lib", version: "^2.0.0" },
    ];
    const statuses = checkLicenses(deps, config, mockData);
    expect(statuses.length).toBe(3);
    expect(statuses[0]).toMatchObject({ dependency: "express", status: "approved", license: "MIT" });
    expect(statuses[1]).toMatchObject({ dependency: "gpl-violator", status: "denied", license: "GPL-3.0" });
    expect(statuses[2]).toMatchObject({ dependency: "mystery-lib", status: "unknown", license: null });
  });
});

// --- Step 5 (failing test): generateReport ---
describe("generateReport", () => {
  test("produces ComplianceReport with correct summary counts", async () => {
    const { generateReport } = await import("./licenseChecker");
    const statuses = [
      { dependency: "a", version: "1.0.0", license: "MIT", status: "approved" as const },
      { dependency: "b", version: "1.0.0", license: "GPL-3.0", status: "denied" as const },
      { dependency: "c", version: "1.0.0", license: null, status: "unknown" as const },
    ];
    const report = generateReport(statuses);
    expect(report.summary.total).toBe(3);
    expect(report.summary.approved).toBe(1);
    expect(report.summary.denied).toBe(1);
    expect(report.summary.unknown).toBe(1);
    expect(report.results).toHaveLength(3);
  });
});

// --- Step 6 (failing test): formatReport ---
describe("formatReport", () => {
  test("includes each dependency with license and status", async () => {
    const { generateReport, formatReport } = await import("./licenseChecker");
    const statuses = [
      { dependency: "express", version: "^4.18.2", license: "MIT", status: "approved" as const },
      { dependency: "gpl-violator", version: "^1.0.0", license: "GPL-3.0", status: "denied" as const },
      { dependency: "mystery-lib", version: "^2.0.0", license: null, status: "unknown" as const },
    ];
    const report = generateReport(statuses);
    const output = formatReport(report);
    expect(output).toContain("express@^4.18.2: MIT -> APPROVED");
    expect(output).toContain("gpl-violator@^1.0.0: GPL-3.0 -> DENIED");
    expect(output).toContain("mystery-lib@^2.0.0: unknown -> UNKNOWN");
    expect(output).toContain("Total: 3");
    expect(output).toContain("Approved: 1");
    expect(output).toContain("Denied: 1");
    expect(output).toContain("Unknown: 1");
  });
});

// --- Step 7: Workflow structure tests ---
describe("Workflow structure", () => {
  const workflowPath = ".github/workflows/dependency-license-checker.yml";

  test("workflow file exists", () => {
    expect(existsSync(workflowPath)).toBe(true);
  });

  test("workflow references licenseChecker.ts", () => {
    const content = readFileSync(workflowPath, "utf8");
    expect(content).toContain("licenseChecker.ts");
  });

  test("workflow uses actions/checkout@v4", () => {
    const content = readFileSync(workflowPath, "utf8");
    expect(content).toContain("actions/checkout@v4");
  });

  test("workflow has push trigger", () => {
    const content = readFileSync(workflowPath, "utf8");
    expect(content).toContain("push:");
  });

  test("workflow has pull_request trigger", () => {
    const content = readFileSync(workflowPath, "utf8");
    expect(content).toContain("pull_request:");
  });

  test("workflow has jobs section", () => {
    const content = readFileSync(workflowPath, "utf8");
    expect(content).toContain("jobs:");
  });

  test("fixture files referenced by workflow exist", () => {
    expect(existsSync("fixtures/package.json")).toBe(true);
    expect(existsSync("fixtures/license-config.json")).toBe(true);
    expect(existsSync("fixtures/mock-licenses.json")).toBe(true);
    expect(existsSync("licenseChecker.ts")).toBe(true);
  });

  test("actionlint passes with exit code 0", () => {
    const result = spawnSync("actionlint", [workflowPath], { encoding: "utf8" });
    if (result.status !== 0) {
      console.error("actionlint output:", result.stdout, result.stderr);
    }
    expect(result.status).toBe(0);
  });
});

// --- Step 8: Act integration test ---
// Sets up a temp git repo, runs act push, asserts on exact output values.
describe("Act integration", () => {
  let tmpDir: string;
  const actResultPath = join(process.cwd(), "act-result.txt");

  beforeAll(() => {
    // Create temp directory for the git repo
    tmpDir = mkdtempSync(join(tmpdir(), "license-checker-act-"));
  });

  afterAll(() => {
    // Clean up temp directory
    try {
      rmSync(tmpDir, { recursive: true, force: true });
    } catch {
      // ignore cleanup errors
    }
  });

  test("workflow runs successfully and produces correct compliance report", () => {
    // Copy all required files into the temp repo
    mkdirSync(join(tmpDir, "fixtures"), { recursive: true });
    mkdirSync(join(tmpDir, ".github", "workflows"), { recursive: true });

    const filesToCopy: string[] = [
      "licenseChecker.ts",
      "fixtures/package.json",
      "fixtures/license-config.json",
      "fixtures/mock-licenses.json",
      ".github/workflows/dependency-license-checker.yml",
      ".actrc",
    ];
    for (const f of filesToCopy) {
      copyFileSync(join(process.cwd(), f), join(tmpDir, f));
    }

    // Initialize git repo (required for act push)
    for (const [cmd, args] of [
      ["git", ["init"]],
      ["git", ["config", "user.email", "test@test.com"]],
      ["git", ["config", "user.name", "Test"]],
      ["git", ["add", "-A"]],
      ["git", ["commit", "-m", "test: initial"]],
    ] as [string, string[]][]) {
      const r = spawnSync(cmd, args, { cwd: tmpDir, encoding: "utf8" });
      if (r.status !== 0) {
        throw new Error(`${cmd} ${args.join(" ")} failed: ${r.stderr}`);
      }
    }

    // Run act push and capture full output; --pull=false avoids force-pulling local images
    const actResult = spawnSync("act", ["push", "--rm", "--pull=false"], {
      cwd: tmpDir,
      timeout: 150_000,
      encoding: "utf8",
    });

    const output = (actResult.stdout ?? "") + (actResult.stderr ?? "");

    // Append to act-result.txt (required artifact)
    appendFileSync(
      actResultPath,
      `\n=== Test Case: basic fixture (act integration) ===\n${output}\n`
    );

    // Assert job succeeded
    expect(actResult.status).toBe(0);
    expect(output).toContain("Job succeeded");

    // Assert exact compliance report values
    expect(output).toContain("express@^4.18.2: MIT -> APPROVED");
    expect(output).toContain("lodash@^4.17.21: MIT -> APPROVED");
    expect(output).toContain("react@^18.2.0: MIT -> APPROVED");
    expect(output).toContain("gpl-violator@^1.0.0: GPL-3.0 -> DENIED");
    expect(output).toContain("mystery-lib@^2.0.0: unknown -> UNKNOWN");

    // Assert summary counts
    expect(output).toContain("Total: 5");
    expect(output).toContain("Approved: 3");
    expect(output).toContain("Denied: 1");
    expect(output).toContain("Unknown: 1");
  }, 180_000);
});
