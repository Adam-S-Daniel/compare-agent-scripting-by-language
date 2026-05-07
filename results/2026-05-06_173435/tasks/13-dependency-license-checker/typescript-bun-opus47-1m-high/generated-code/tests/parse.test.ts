// RED phase tests for manifest parsing.
// We support package.json (npm) and requirements.txt (pip) flavors.
import { describe, expect, test } from "bun:test";
import { parseManifest, parsePackageJson, parseRequirementsTxt } from "../src/parse.ts";

describe("parsePackageJson", () => {
  test("extracts dependencies and devDependencies with cleaned version ranges", () => {
    const content = JSON.stringify({
      name: "demo",
      dependencies: {
        "left-pad": "^1.3.0",
        "lodash": "~4.17.21",
      },
      devDependencies: {
        "typescript": ">=5.0.0",
      },
    });
    const deps = parsePackageJson(content);
    expect(deps).toEqual([
      { name: "left-pad", version: "1.3.0" },
      { name: "lodash", version: "4.17.21" },
      { name: "typescript", version: "5.0.0" },
    ]);
  });

  test("returns empty list when no dependency keys present", () => {
    expect(parsePackageJson(JSON.stringify({ name: "empty" }))).toEqual([]);
  });

  test("throws a meaningful error for malformed JSON", () => {
    expect(() => parsePackageJson("{not json")).toThrow(/Failed to parse package\.json/);
  });
});

describe("parseRequirementsTxt", () => {
  test("extracts name==version entries and skips comments and blanks", () => {
    const content = [
      "# top-level deps",
      "requests==2.31.0",
      "",
      "flask>=3.0.0  # web framework",
      "numpy",
    ].join("\n");
    const deps = parseRequirementsTxt(content);
    expect(deps).toEqual([
      { name: "requests", version: "2.31.0" },
      { name: "flask", version: "3.0.0" },
      { name: "numpy", version: "unknown" },
    ]);
  });
});

describe("parseManifest auto-detect", () => {
  test("dispatches by filename", () => {
    const pkg = parseManifest("package.json", JSON.stringify({ dependencies: { foo: "1.0.0" } }));
    expect(pkg).toEqual([{ name: "foo", version: "1.0.0" }]);

    const req = parseManifest("requirements.txt", "foo==1.0.0");
    expect(req).toEqual([{ name: "foo", version: "1.0.0" }]);
  });

  test("throws on unknown manifest type", () => {
    expect(() => parseManifest("Cargo.toml", "")).toThrow(/Unsupported manifest/);
  });
});
