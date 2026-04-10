// TDD: Tests for manifest parsing
// Red phase: write failing tests first, then implement

import { describe, test, expect } from "bun:test";
import { parsePackageJson, parseRequirementsTxt, parseManifest } from "../src/parser";
import type { Dependency } from "../src/types";

describe("parsePackageJson", () => {
  test("extracts dependencies and devDependencies from package.json", () => {
    const content = JSON.stringify({
      name: "test-project",
      dependencies: {
        express: "^4.18.0",
        lodash: "~4.17.21",
      },
      devDependencies: {
        typescript: "^5.0.0",
      },
    });

    const deps: Dependency[] = parsePackageJson(content);
    expect(deps).toEqual([
      { name: "express", version: "^4.18.0" },
      { name: "lodash", version: "~4.17.21" },
      { name: "typescript", version: "^5.0.0" },
    ]);
  });

  test("handles package.json with no dependencies", () => {
    const content = JSON.stringify({ name: "empty-project" });
    const deps = parsePackageJson(content);
    expect(deps).toEqual([]);
  });

  test("handles only dependencies (no devDependencies)", () => {
    const content = JSON.stringify({
      dependencies: { react: "^18.0.0" },
    });
    const deps = parsePackageJson(content);
    expect(deps).toEqual([{ name: "react", version: "^18.0.0" }]);
  });

  test("throws on invalid JSON", () => {
    expect(() => parsePackageJson("not valid json")).toThrow();
  });
});

describe("parseRequirementsTxt", () => {
  test("parses pinned versions", () => {
    const content = "requests==2.28.0\nflask==2.3.1\n";
    const deps = parseRequirementsTxt(content);
    expect(deps).toEqual([
      { name: "requests", version: "2.28.0" },
      { name: "flask", version: "2.3.1" },
    ]);
  });

  test("parses version ranges", () => {
    const content = "django>=4.0,<5.0\nnumpy>=1.24\n";
    const deps = parseRequirementsTxt(content);
    expect(deps).toEqual([
      { name: "django", version: ">=4.0,<5.0" },
      { name: "numpy", version: ">=1.24" },
    ]);
  });

  test("skips comments and blank lines", () => {
    const content = "# This is a comment\nrequests==2.28.0\n\n# Another comment\nflask==2.3.1\n";
    const deps = parseRequirementsTxt(content);
    expect(deps).toEqual([
      { name: "requests", version: "2.28.0" },
      { name: "flask", version: "2.3.1" },
    ]);
  });

  test("handles packages with no version", () => {
    const content = "requests\nflask==2.3.1\n";
    const deps = parseRequirementsTxt(content);
    expect(deps).toEqual([
      { name: "requests", version: "*" },
      { name: "flask", version: "2.3.1" },
    ]);
  });
});

describe("parseManifest", () => {
  test("auto-detects package.json by filename", () => {
    const content = JSON.stringify({ dependencies: { lodash: "^4.17.21" } });
    const deps = parseManifest("package.json", content);
    expect(deps).toEqual([{ name: "lodash", version: "^4.17.21" }]);
  });

  test("auto-detects requirements.txt by filename", () => {
    const content = "requests==2.28.0\n";
    const deps = parseManifest("requirements.txt", content);
    expect(deps).toEqual([{ name: "requests", version: "2.28.0" }]);
  });

  test("throws for unsupported manifest type", () => {
    expect(() => parseManifest("Gemfile", "source ...")).toThrow(
      "Unsupported manifest file: Gemfile"
    );
  });
});
