// End-to-end test: invoke the CLI as a subprocess against fixture files
// and assert on its stdout + exit code.
import { describe, expect, test, beforeAll } from "bun:test";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

let workdir: string;
const cli = new URL("../src/cli.ts", import.meta.url).pathname;

beforeAll(() => {
  workdir = mkdtempSync(join(tmpdir(), "lic-cli-"));
  writeFileSync(
    join(workdir, "package.json"),
    JSON.stringify({
      name: "demo",
      dependencies: { left: "1.0.0", evil: "2.0.0", mystery: "3.0.0" },
    }),
  );
  writeFileSync(
    join(workdir, "policy.json"),
    JSON.stringify({ allow: ["MIT"], deny: ["GPL-3.0"] }),
  );
  writeFileSync(
    join(workdir, "licenses.json"),
    JSON.stringify({ left: "MIT", evil: "GPL-3.0" }),
  );
});

async function runCli(args: string[]): Promise<{ stdout: string; stderr: string; code: number }> {
  const proc = Bun.spawn(["bun", "run", cli, ...args], { stdout: "pipe", stderr: "pipe" });
  const stdout = await new Response(proc.stdout).text();
  const stderr = await new Response(proc.stderr).text();
  const code = await proc.exited;
  return { stdout, stderr, code };
}

describe("cli", () => {
  test("exits 1 when a dependency is denied, prints full report", async () => {
    const { stdout, code } = await runCli([
      "--manifest", join(workdir, "package.json"),
      "--policy", join(workdir, "policy.json"),
      "--mock-licenses", join(workdir, "licenses.json"),
    ]);
    expect(stdout).toContain("APPROVED left@1.0.0");
    expect(stdout).toContain("DENIED   evil@2.0.0");
    expect(stdout).toContain("UNKNOWN  mystery@3.0.0");
    expect(stdout).toContain("approved=1 denied=1 unknown=1");
    expect(code).toBe(1);
  });

  test("exits 0 when all deps are approved", async () => {
    const okDir = mkdtempSync(join(tmpdir(), "lic-cli-ok-"));
    const onlyAllowed = join(okDir, "package.json");
    writeFileSync(
      onlyAllowed,
      JSON.stringify({ name: "x", dependencies: { left: "1.0.0" } }),
    );
    const { stdout, code } = await runCli([
      "--manifest", onlyAllowed,
      "--policy", join(workdir, "policy.json"),
      "--mock-licenses", join(workdir, "licenses.json"),
    ]);
    expect(stdout).toContain("APPROVED left@1.0.0");
    expect(code).toBe(0);
  });

  test("missing --manifest produces a helpful error and non-zero exit", async () => {
    const { stderr, code } = await runCli([]);
    expect(stderr).toMatch(/--manifest/);
    expect(code).not.toBe(0);
  });
});
