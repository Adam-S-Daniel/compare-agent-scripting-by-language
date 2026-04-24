import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

// End-to-end tests: spawn `bun run src/cli.ts` as a real subprocess
// (no shell), read stdout/stderr and exit code. We use real temp files
// instead of mocks here because the CLI's whole job is reading files.

let workdir: string;
const cliPath = join(import.meta.dir, "cli.ts");

beforeEach(() => {
  workdir = mkdtempSync(join(tmpdir(), "license-checker-test-"));
});

afterEach(() => {
  rmSync(workdir, { recursive: true, force: true });
});

async function runCli(args: string[]): Promise<{
  stdout: string;
  stderr: string;
  exitCode: number;
}> {
  const proc = Bun.spawn(["bun", "run", cliPath, ...args], {
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  const exitCode = await proc.exited;
  return { stdout, stderr, exitCode };
}

describe("cli", () => {
  test("prints a compliance report for a manifest + config", async () => {
    const manifestPath = join(workdir, "package.json");
    const configPath = join(workdir, "license-policy.json");
    writeFileSync(
      manifestPath,
      JSON.stringify({
        name: "demo",
        version: "1.0.0",
        dependencies: { lodash: "^4.17.21", "bad-pkg": "1.0.0" },
        devDependencies: { "mystery-pkg": "1.0.0" },
      }),
    );
    writeFileSync(
      configPath,
      JSON.stringify({
        allow: ["MIT"],
        deny: ["GPL-3.0"],
        licenses: { lodash: "MIT", "bad-pkg": "GPL-3.0" },
      }),
    );

    const { stdout, exitCode } = await runCli([
      "--manifest",
      manifestPath,
      "--config",
      configPath,
    ]);

    expect(exitCode).toBe(0);
    expect(stdout).toContain("# Dependency License Compliance Report");
    expect(stdout).toContain("Total dependencies: 3");
    expect(stdout).toContain("Approved: 1");
    expect(stdout).toContain("Denied: 1");
    expect(stdout).toContain("Unknown: 1");
    expect(stdout).toContain("| lodash | ^4.17.21 | MIT | approved |");
    expect(stdout).toContain("| bad-pkg | 1.0.0 | GPL-3.0 | denied |");
    expect(stdout).toContain("| mystery-pkg | 1.0.0 | UNKNOWN | unknown |");
  });

  test("exits with a non-zero code when the manifest file does not exist", async () => {
    const configPath = join(workdir, "license-policy.json");
    writeFileSync(configPath, JSON.stringify({ allow: [], deny: [], licenses: {} }));
    const { stderr, exitCode } = await runCli([
      "--manifest",
      join(workdir, "missing.json"),
      "--config",
      configPath,
    ]);
    expect(exitCode).not.toBe(0);
    expect(stderr.toLowerCase()).toMatch(/manifest/);
  });

  test("exits with code 1 when --fail-on-violation is set and a denied dep is present", async () => {
    const manifestPath = join(workdir, "package.json");
    const configPath = join(workdir, "license-policy.json");
    writeFileSync(
      manifestPath,
      JSON.stringify({ name: "demo", dependencies: { "bad-pkg": "1.0.0" } }),
    );
    writeFileSync(
      configPath,
      JSON.stringify({
        allow: ["MIT"],
        deny: ["GPL-3.0"],
        licenses: { "bad-pkg": "GPL-3.0" },
      }),
    );
    const { exitCode } = await runCli([
      "--manifest",
      manifestPath,
      "--config",
      configPath,
      "--fail-on-violation",
    ]);
    expect(exitCode).toBe(1);
  });

  test("exits 0 with --fail-on-violation when all deps are approved", async () => {
    const manifestPath = join(workdir, "package.json");
    const configPath = join(workdir, "license-policy.json");
    writeFileSync(
      manifestPath,
      JSON.stringify({ name: "demo", dependencies: { lodash: "4.17.21" } }),
    );
    writeFileSync(
      configPath,
      JSON.stringify({
        allow: ["MIT"],
        deny: ["GPL-3.0"],
        licenses: { lodash: "MIT" },
      }),
    );
    const { exitCode } = await runCli([
      "--manifest",
      manifestPath,
      "--config",
      configPath,
      "--fail-on-violation",
    ]);
    expect(exitCode).toBe(0);
  });

  test("prints usage and exits non-zero when required args are missing", async () => {
    const { stderr, exitCode } = await runCli([]);
    expect(exitCode).not.toBe(0);
    expect(stderr.toLowerCase()).toMatch(/usage|required/);
  });
});
