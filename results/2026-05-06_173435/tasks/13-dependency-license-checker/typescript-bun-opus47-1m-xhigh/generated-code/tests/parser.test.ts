// Unit tests for the manifest parser.
// We use these for fast TDD iteration; the act-based pipeline harness
// in tests/pipeline.test.ts is what enforces end-to-end behaviour.
import { describe, expect, test } from "bun:test";
import { parseManifest, type Dependency } from "../src/parser.ts";

describe("parseManifest", () => {
  test("parses a package.json with regular and dev dependencies", () => {
    const manifestJson = JSON.stringify({
      name: "demo-app",
      version: "1.0.0",
      dependencies: {
        lodash: "^4.17.21",
        express: "4.18.2",
      },
      devDependencies: {
        typescript: "5.4.0",
      },
    });

    const deps: Dependency[] = parseManifest("package.json", manifestJson);

    expect(deps).toEqual([
      { name: "express", version: "4.18.2", source: "package.json" },
      { name: "lodash", version: "^4.17.21", source: "package.json" },
      { name: "typescript", version: "5.4.0", source: "package.json" },
    ]);
  });

  test("parses a requirements.txt with comments and pinned versions", () => {
    const requirements = [
      "# pinned for reproducibility",
      "requests==2.31.0",
      "flask>=2.2.0",
      "",
      "numpy~=1.26.0  # numerics",
    ].join("\n");

    const deps = parseManifest("requirements.txt", requirements);

    expect(deps).toEqual([
      { name: "flask", version: ">=2.2.0", source: "requirements.txt" },
      { name: "numpy", version: "~=1.26.0", source: "requirements.txt" },
      { name: "requests", version: "==2.31.0", source: "requirements.txt" },
    ]);
  });

  test("throws a meaningful error for an unsupported manifest filename", () => {
    expect(() => parseManifest("Cargo.toml", "[package]\nname = 'x'")).toThrow(
      /Unsupported manifest/,
    );
  });

  test("throws a meaningful error when JSON is malformed", () => {
    expect(() => parseManifest("package.json", "{not valid json")).toThrow(
      /Failed to parse package.json/,
    );
  });

  test("returns an empty list when the manifest has no dependencies", () => {
    const deps = parseManifest("package.json", JSON.stringify({ name: "x" }));
    expect(deps).toEqual([]);
  });
});
