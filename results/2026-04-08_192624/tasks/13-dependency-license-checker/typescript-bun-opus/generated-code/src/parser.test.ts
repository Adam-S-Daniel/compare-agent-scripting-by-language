// TDD Step 1: Write failing tests for manifest parsing
import { describe, expect, test } from "bun:test";
import { parsePackageJson, parseRequirementsTxt, parseManifest } from "./parser";
import type { Dependency } from "./types";

describe("parsePackageJson", () => {
  test("extracts dependencies from a valid package.json", () => {
    const content = JSON.stringify({
      name: "my-app",
      dependencies: {
        express: "^4.18.0",
        lodash: "~4.17.21",
      },
      devDependencies: {
        jest: "^29.0.0",
      },
    });

    const deps: Dependency[] = parsePackageJson(content);
    expect(deps).toEqual([
      { name: "express", version: "^4.18.0" },
      { name: "lodash", version: "~4.17.21" },
      { name: "jest", version: "^29.0.0" },
    ]);
  });

  test("handles package.json with no dependencies", () => {
    const content = JSON.stringify({ name: "empty-app" });
    const deps = parsePackageJson(content);
    expect(deps).toEqual([]);
  });

  test("handles only devDependencies", () => {
    const content = JSON.stringify({
      devDependencies: { typescript: "^5.0.0" },
    });
    const deps = parsePackageJson(content);
    expect(deps).toEqual([{ name: "typescript", version: "^5.0.0" }]);
  });

  test("throws on invalid JSON", () => {
    expect(() => parsePackageJson("not json")).toThrow("Invalid package.json");
  });
});

describe("parseRequirementsTxt", () => {
  test("extracts dependencies from requirements.txt", () => {
    const content = "flask==2.3.0\nrequests>=2.28.0\nnumpy==1.24.0\n";
    const deps = parseRequirementsTxt(content);
    expect(deps).toEqual([
      { name: "flask", version: "2.3.0" },
      { name: "requests", version: "2.28.0" },
      { name: "numpy", version: "1.24.0" },
    ]);
  });

  test("ignores comments and blank lines", () => {
    const content = "# This is a comment\nflask==2.3.0\n\n# Another comment\n";
    const deps = parseRequirementsTxt(content);
    expect(deps).toEqual([{ name: "flask", version: "2.3.0" }]);
  });

  test("handles packages without version specifiers", () => {
    const content = "flask\nrequests\n";
    const deps = parseRequirementsTxt(content);
    expect(deps).toEqual([
      { name: "flask", version: "*" },
      { name: "requests", version: "*" },
    ]);
  });

  test("returns empty array for empty content", () => {
    const deps = parseRequirementsTxt("");
    expect(deps).toEqual([]);
  });
});

describe("parseManifest", () => {
  test("auto-detects package.json format", () => {
    const content = JSON.stringify({
      dependencies: { express: "^4.18.0" },
    });
    const deps = parseManifest("package.json", content);
    expect(deps).toEqual([{ name: "express", version: "^4.18.0" }]);
  });

  test("auto-detects requirements.txt format", () => {
    const content = "flask==2.3.0\n";
    const deps = parseManifest("requirements.txt", content);
    expect(deps).toEqual([{ name: "flask", version: "2.3.0" }]);
  });

  test("throws for unsupported manifest type", () => {
    expect(() => parseManifest("Gemfile", "")).toThrow("Unsupported manifest");
  });
});
