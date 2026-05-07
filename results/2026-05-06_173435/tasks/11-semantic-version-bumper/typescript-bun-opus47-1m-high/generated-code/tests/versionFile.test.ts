import { afterEach, describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { readVersionFile, writeVersionFile } from "../src/versionFile.ts";

const tempDirs: string[] = [];

function tmp(): string {
  const dir = mkdtempSync(join(tmpdir(), "semver-bump-"));
  tempDirs.push(dir);
  return dir;
}

afterEach(() => {
  while (tempDirs.length) {
    const d = tempDirs.pop();
    if (d) rmSync(d, { recursive: true, force: true });
  }
});

describe("readVersionFile", () => {
  test("reads version from package.json", () => {
    const dir = tmp();
    const path = join(dir, "package.json");
    writeFileSync(
      path,
      JSON.stringify({ name: "demo", version: "1.4.2" }, null, 2),
    );
    expect(readVersionFile(path)).toBe("1.4.2");
  });

  test("reads version from a plain VERSION file (trims whitespace)", () => {
    const dir = tmp();
    const path = join(dir, "VERSION");
    writeFileSync(path, "  v0.5.0  \n");
    expect(readVersionFile(path)).toBe("v0.5.0");
  });

  test("throws clear error if file does not exist", () => {
    expect(() => readVersionFile("/nope/does-not-exist")).toThrow(
      /version file/i,
    );
  });

  test("throws clear error if package.json has no version", () => {
    const dir = tmp();
    const path = join(dir, "package.json");
    writeFileSync(path, JSON.stringify({ name: "demo" }));
    expect(() => readVersionFile(path)).toThrow(/version/i);
  });
});

describe("writeVersionFile", () => {
  test("updates package.json version while preserving other fields", () => {
    const dir = tmp();
    const path = join(dir, "package.json");
    writeFileSync(
      path,
      JSON.stringify({ name: "demo", version: "1.0.0", scripts: { x: "y" } }, null, 2),
    );
    writeVersionFile(path, "1.1.0");
    const parsed = JSON.parse(readFileSync(path, "utf8"));
    expect(parsed.version).toBe("1.1.0");
    expect(parsed.name).toBe("demo");
    expect(parsed.scripts).toEqual({ x: "y" });
  });

  test("writes plain version files preserving leading 'v' if input has it", () => {
    const dir = tmp();
    const path = join(dir, "VERSION");
    writeFileSync(path, "v0.1.0\n");
    writeVersionFile(path, "0.2.0");
    expect(readFileSync(path, "utf8").trim()).toBe("0.2.0");
  });
});
