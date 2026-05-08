// Tests for manifest parsing. Supports package.json (npm) and requirements.txt (pip).
import { describe, expect, test } from "bun:test";
import { parseManifest } from "../src/parser.ts";

describe("parseManifest", () => {
  test("parses package.json dependencies and devDependencies", () => {
    const json = JSON.stringify({
      name: "demo",
      dependencies: { left: "^1.0.0", right: "2.3.4" },
      devDependencies: { jest: "29.0.0" },
    });
    const deps = parseManifest("package.json", json);
    expect(deps).toEqual([
      { name: "left", version: "^1.0.0" },
      { name: "right", version: "2.3.4" },
      { name: "jest", version: "29.0.0" },
    ]);
  });

  test("parses requirements.txt entries, skipping comments and blanks", () => {
    const txt = [
      "# a comment",
      "requests==2.31.0",
      "",
      "flask>=2.0",
      "  numpy ~= 1.26  ",
      "no-version",
    ].join("\n");
    const deps = parseManifest("requirements.txt", txt);
    expect(deps).toEqual([
      { name: "requests", version: "==2.31.0" },
      { name: "flask", version: ">=2.0" },
      { name: "numpy", version: "~=1.26" },
      { name: "no-version", version: "*" },
    ]);
  });

  test("throws on unsupported manifest", () => {
    expect(() => parseManifest("Cargo.toml", "")).toThrow(/Unsupported/);
  });

  test("throws on malformed package.json", () => {
    expect(() => parseManifest("package.json", "{bad")).toThrow(/Invalid package.json/);
  });
});
