// TDD tests for file operations (reading/writing version files)

import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { mkdtemp, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import {
  readVersionFromPackageJson,
  writeVersionToPackageJson,
  readVersionFile,
  writeVersionFile,
} from "./file-ops";

let tempDir: string;

beforeEach(async () => {
  tempDir = await mkdtemp(join(tmpdir(), "semver-test-"));
});

afterEach(async () => {
  await rm(tempDir, { recursive: true, force: true });
});

describe("readVersionFromPackageJson", () => {
  test("reads version from package.json", async () => {
    const pkg = { name: "test", version: "1.2.3" };
    await Bun.write(join(tempDir, "package.json"), JSON.stringify(pkg, null, 2));
    const version = await readVersionFromPackageJson(tempDir);
    expect(version).toBe("1.2.3");
  });

  test("throws if package.json has no version field", async () => {
    const pkg = { name: "test" };
    await Bun.write(join(tempDir, "package.json"), JSON.stringify(pkg));
    await expect(readVersionFromPackageJson(tempDir)).rejects.toThrow(
      "No version field"
    );
  });

  test("throws if package.json does not exist", async () => {
    await expect(readVersionFromPackageJson(tempDir)).rejects.toThrow();
  });
});

describe("writeVersionToPackageJson", () => {
  test("updates version in package.json preserving other fields", async () => {
    const pkg = { name: "test", version: "1.2.3", description: "hello" };
    const filePath = join(tempDir, "package.json");
    await Bun.write(filePath, JSON.stringify(pkg, null, 2));
    await writeVersionToPackageJson(tempDir, "1.3.0");
    const updated = JSON.parse(await Bun.file(filePath).text());
    expect(updated.version).toBe("1.3.0");
    expect(updated.name).toBe("test");
    expect(updated.description).toBe("hello");
  });
});

describe("readVersionFile", () => {
  test("reads version from a plain VERSION file", async () => {
    await Bun.write(join(tempDir, "VERSION"), "2.0.1\n");
    const version = await readVersionFile(join(tempDir, "VERSION"));
    expect(version).toBe("2.0.1");
  });

  test("trims whitespace from VERSION file", async () => {
    await Bun.write(join(tempDir, "VERSION"), "  3.1.0  \n");
    const version = await readVersionFile(join(tempDir, "VERSION"));
    expect(version).toBe("3.1.0");
  });
});

describe("writeVersionFile", () => {
  test("writes version to a plain VERSION file", async () => {
    const filePath = join(tempDir, "VERSION");
    await writeVersionFile(filePath, "4.0.0");
    const content = await Bun.file(filePath).text();
    expect(content.trim()).toBe("4.0.0");
  });
});
