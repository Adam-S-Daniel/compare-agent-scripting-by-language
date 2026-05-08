// RED phase tests for the CLI. The CLI is the integration surface used both
// by humans and by the GitHub Actions workflow, so we verify it directly here
// (separate from the act-driven suite which exercises the full pipeline).
import { describe, expect, test } from "bun:test";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const CLI = join(import.meta.dir, "..", "src", "cli.ts");

function setupFixture(files: Record<string, string>): string {
  const dir = mkdtempSync(join(tmpdir(), "license-cli-"));
  for (const [name, content] of Object.entries(files)) {
    writeFileSync(join(dir, name), content);
  }
  return dir;
}

const config = {
  allow: ["MIT", "Apache-2.0"],
  deny: ["GPL-3.0"],
};

const licenses = {
  "left-pad": "MIT",
  "evil-lib": "GPL-3.0",
  "mystery-lib": "WTFPL",
};

describe("cli", () => {
  test("reports compliant manifest with exit 0", () => {
    const dir = setupFixture({
      "package.json": JSON.stringify({ dependencies: { "left-pad": "^1.3.0" } }),
      "config.json": JSON.stringify(config),
      "licenses.json": JSON.stringify(licenses),
    });
    try {
      const r = spawnSync("bun", [
        "run",
        CLI,
        "--manifest", join(dir, "package.json"),
        "--config", join(dir, "config.json"),
        "--licenses", join(dir, "licenses.json"),
      ], { encoding: "utf8" });
      expect(r.status).toBe(0);
      expect(r.stdout).toContain("[APPROVED] left-pad@1.3.0 -> MIT");
      expect(r.stdout).toContain("Totals: 1 deps, 1 approved, 0 denied, 0 unknown");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("exits non-zero when a denied dependency is found", () => {
    const dir = setupFixture({
      "package.json": JSON.stringify({ dependencies: { "evil-lib": "2.0.0" } }),
      "config.json": JSON.stringify(config),
      "licenses.json": JSON.stringify(licenses),
    });
    try {
      const r = spawnSync("bun", [
        "run",
        CLI,
        "--manifest", join(dir, "package.json"),
        "--config", join(dir, "config.json"),
        "--licenses", join(dir, "licenses.json"),
      ], { encoding: "utf8" });
      expect(r.status).toBe(1);
      expect(r.stdout).toContain("[DENIED] evil-lib@2.0.0 -> GPL-3.0");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("--allow-unknown lets unknown licenses pass with exit 0", () => {
    const dir = setupFixture({
      "package.json": JSON.stringify({ dependencies: { "mystery-lib": "0.1.0" } }),
      "config.json": JSON.stringify(config),
      "licenses.json": JSON.stringify(licenses),
    });
    try {
      const strict = spawnSync("bun", [
        "run", CLI,
        "--manifest", join(dir, "package.json"),
        "--config", join(dir, "config.json"),
        "--licenses", join(dir, "licenses.json"),
      ], { encoding: "utf8" });
      expect(strict.status).toBe(2); // unknown by default fails with exit 2

      const lax = spawnSync("bun", [
        "run", CLI,
        "--manifest", join(dir, "package.json"),
        "--config", join(dir, "config.json"),
        "--licenses", join(dir, "licenses.json"),
        "--allow-unknown",
      ], { encoding: "utf8" });
      expect(lax.status).toBe(0);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("emits a meaningful error and exit 3 when manifest is missing", () => {
    const dir = setupFixture({
      "config.json": JSON.stringify(config),
      "licenses.json": JSON.stringify(licenses),
    });
    try {
      const r = spawnSync("bun", [
        "run", CLI,
        "--manifest", join(dir, "does-not-exist.json"),
        "--config", join(dir, "config.json"),
        "--licenses", join(dir, "licenses.json"),
      ], { encoding: "utf8" });
      expect(r.status).toBe(3);
      expect(r.stderr).toMatch(/Could not read manifest/);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
