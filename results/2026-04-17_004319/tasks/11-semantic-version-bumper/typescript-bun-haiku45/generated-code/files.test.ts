import { describe, it, expect, beforeEach, afterEach } from "bun:test";
import {
  readVersionFromPackageJson,
  updateVersionInPackageJson,
} from "./src/files";
import { mkdir, rm } from "fs/promises";
import { join } from "path";

const testDir = "/tmp/version-bumper-test";

describe("readVersionFromPackageJson", () => {
  beforeEach(async () => {
    await mkdir(testDir, { recursive: true });
  });

  afterEach(async () => {
    await rm(testDir, { recursive: true, force: true });
  });

  it("should read version from package.json", async () => {
    const pkgPath = join(testDir, "package.json");
    await Bun.write(pkgPath, JSON.stringify({ version: "1.2.3" }));
    const version = await readVersionFromPackageJson(pkgPath);
    expect(version).toBe("1.2.3");
  });

  it("should throw when package.json not found", async () => {
    const pkgPath = join(testDir, "nonexistent.json");
    try {
      await readVersionFromPackageJson(pkgPath);
      expect(true).toBe(false); // Should not reach here
    } catch (e) {
      expect(e instanceof Error).toBe(true);
    }
  });
});

describe("updateVersionInPackageJson", () => {
  beforeEach(async () => {
    await mkdir(testDir, { recursive: true });
  });

  afterEach(async () => {
    await rm(testDir, { recursive: true, force: true });
  });

  it("should update version in package.json", async () => {
    const pkgPath = join(testDir, "package.json");
    const original = { version: "1.0.0", name: "test-pkg" };
    await Bun.write(pkgPath, JSON.stringify(original, null, 2));

    await updateVersionInPackageJson(pkgPath, "1.1.0");

    const content = await Bun.file(pkgPath).text();
    const updated = JSON.parse(content);
    expect(updated.version).toBe("1.1.0");
    expect(updated.name).toBe("test-pkg");
  });

  it("should preserve formatting when updating", async () => {
    const pkgPath = join(testDir, "package.json");
    const original = { version: "1.0.0", name: "test" };
    await Bun.write(pkgPath, JSON.stringify(original, null, 2));

    await updateVersionInPackageJson(pkgPath, "2.0.0");

    const content = await Bun.file(pkgPath).text();
    expect(content).toContain('"version": "2.0.0"');
  });
});
