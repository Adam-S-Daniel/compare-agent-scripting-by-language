// Tests for reading and writing a version file — supports two formats:
//   1. package.json  -> read and update the top-level "version" field
//   2. plain VERSION -> whole file contents are the version string

import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdtemp, writeFile, readFile, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { readVersionFile, writeVersionFile } from "../src/versionFile.ts";

let workDir: string;

beforeEach(async () => {
  workDir = await mkdtemp(join(tmpdir(), "svb-"));
});

afterEach(async () => {
  await rm(workDir, { recursive: true, force: true });
});

describe("readVersionFile", () => {
  test("reads a package.json version", async () => {
    const path = join(workDir, "package.json");
    await writeFile(path, JSON.stringify({ name: "x", version: "1.2.3" }, null, 2));
    expect(await readVersionFile(path)).toBe("1.2.3");
  });

  test("reads a plain VERSION file (trimmed)", async () => {
    const path = join(workDir, "VERSION");
    await writeFile(path, "  0.9.1\n");
    expect(await readVersionFile(path)).toBe("0.9.1");
  });

  test("raises a clear error when the package.json has no version", async () => {
    const path = join(workDir, "package.json");
    await writeFile(path, JSON.stringify({ name: "x" }));
    await expect(readVersionFile(path)).rejects.toThrow(/version.*not found|no "version"/i);
  });

  test("raises a clear error when the file does not exist", async () => {
    const path = join(workDir, "missing.json");
    await expect(readVersionFile(path)).rejects.toThrow(/ENOENT|not found/i);
  });
});

describe("writeVersionFile", () => {
  test("preserves package.json formatting/other fields", async () => {
    const path = join(workDir, "package.json");
    const original = JSON.stringify({ name: "x", version: "1.2.3", scripts: { a: "b" } }, null, 2);
    await writeFile(path, original);
    await writeVersionFile(path, "1.3.0");

    const written = JSON.parse(await readFile(path, "utf8"));
    expect(written.version).toBe("1.3.0");
    expect(written.name).toBe("x");
    expect(written.scripts).toEqual({ a: "b" });
  });

  test("writes the plain VERSION file as a single line with trailing newline", async () => {
    const path = join(workDir, "VERSION");
    await writeFile(path, "0.9.1\n");
    await writeVersionFile(path, "0.9.2");
    expect(await readFile(path, "utf8")).toBe("0.9.2\n");
  });
});
