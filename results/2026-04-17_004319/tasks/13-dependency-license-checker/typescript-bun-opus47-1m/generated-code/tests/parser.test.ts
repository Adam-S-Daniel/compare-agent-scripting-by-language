// Red-green TDD: parser for package.json manifest.
// The parser extracts a flat list of { name, version } entries
// from both `dependencies` and `devDependencies`, normalizing
// common version prefixes (^, ~, >=, etc.) to bare semver.

import { describe, test, expect } from "bun:test";
import { parsePackageJson } from "../src/parser.ts";

describe("parsePackageJson", () => {
  test("returns an empty list when no deps present", () => {
    const deps = parsePackageJson(JSON.stringify({ name: "x", version: "1.0.0" }));
    expect(deps).toEqual([]);
  });

  test("extracts dependencies and devDependencies", () => {
    const manifest = JSON.stringify({
      name: "demo",
      version: "1.0.0",
      dependencies: { "lodash": "^4.17.21", "chalk": "~5.3.0" },
      devDependencies: { "typescript": ">=5.0.0" },
    });
    const deps = parsePackageJson(manifest);
    // Names are unique, order-independent — sort for stable comparison.
    const sorted = [...deps].sort((a, b) => a.name.localeCompare(b.name));
    expect(sorted).toEqual([
      { name: "chalk", version: "5.3.0" },
      { name: "lodash", version: "4.17.21" },
      { name: "typescript", version: "5.0.0" },
    ]);
  });

  test("throws a helpful error on invalid JSON", () => {
    expect(() => parsePackageJson("{ not json")).toThrow(
      /Failed to parse manifest/,
    );
  });

  test("throws when the manifest is not an object", () => {
    expect(() => parsePackageJson("42")).toThrow(/must be a JSON object/);
  });
});
