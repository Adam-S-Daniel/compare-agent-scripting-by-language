// Integration test: run the CLI as a subprocess against fixture files
// so we exercise argv parsing, file I/O, and exit codes end-to-end.

import { describe, test, expect, beforeAll } from "bun:test";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

let fixtureDir = "";

const manifest = {
  name: "demo",
  version: "1.0.0",
  dependencies: { "lodash": "^4.17.21", "bad-lib": "1.0.0" },
  devDependencies: { "mystery": "0.1.0" },
};
const policy = { allow: ["MIT"], deny: ["GPL-3.0"] };
const licenses = { "lodash": "MIT", "bad-lib": "GPL-3.0" };

beforeAll(() => {
  fixtureDir = mkdtempSync(join(tmpdir(), "licchk-"));
  writeFileSync(join(fixtureDir, "package.json"), JSON.stringify(manifest));
  writeFileSync(join(fixtureDir, "policy.json"), JSON.stringify(policy));
  writeFileSync(join(fixtureDir, "licenses.json"), JSON.stringify(licenses));
});

async function runCli(extra: string[] = []): Promise<{ code: number; stdout: string; stderr: string }> {
  const proc = Bun.spawn({
    cmd: [
      "bun",
      "run",
      new URL("../src/cli.ts", import.meta.url).pathname,
      "--manifest", join(fixtureDir, "package.json"),
      "--policy",   join(fixtureDir, "policy.json"),
      "--licenses", join(fixtureDir, "licenses.json"),
      ...extra,
    ],
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  const code = await proc.exited;
  return { code, stdout, stderr };
}

describe("CLI", () => {
  test("exits with code 2 when a denied license is present", async () => {
    const { code, stdout } = await runCli();
    expect(code).toBe(2);
    const report = JSON.parse(stdout);
    expect(report.summary).toEqual({
      approved: 1,
      denied: 1,
      unknown: 1,
      total: 3,
    });
  });

  test("text format is human-readable", async () => {
    const { stdout } = await runCli(["--format", "text"]);
    expect(stdout).toContain("lodash@4.17.21 MIT approved");
    expect(stdout).toContain("bad-lib@1.0.0 GPL-3.0 denied");
    expect(stdout).toContain("Total: 3");
  });

  test("reports a helpful error on missing manifest", async () => {
    const proc = Bun.spawn({
      cmd: [
        "bun", "run",
        new URL("../src/cli.ts", import.meta.url).pathname,
        "--manifest", "/nonexistent/file.json",
        "--policy", join(fixtureDir, "policy.json"),
        "--licenses", join(fixtureDir, "licenses.json"),
      ],
      stdout: "pipe",
      stderr: "pipe",
    });
    const stderr = await new Response(proc.stderr).text();
    const code = await proc.exited;
    expect(code).toBe(1);
    expect(stderr).toContain("error:");
  });
});
