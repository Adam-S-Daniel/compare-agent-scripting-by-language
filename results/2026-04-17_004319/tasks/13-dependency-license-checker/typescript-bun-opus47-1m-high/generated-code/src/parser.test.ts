import { describe, expect, test } from "bun:test";
import { parseManifest } from "./parser";

describe("parseManifest", () => {
  test("extracts dependencies and devDependencies from package.json JSON string", () => {
    const manifest = JSON.stringify({
      name: "app",
      version: "1.0.0",
      dependencies: { lodash: "^4.17.21", express: "4.18.2" },
      devDependencies: { typescript: "5.0.0" },
    });

    const deps = parseManifest(manifest);

    expect(deps).toEqual([
      { name: "lodash", version: "^4.17.21" },
      { name: "express", version: "4.18.2" },
      { name: "typescript", version: "5.0.0" },
    ]);
  });

  test("returns empty array when no dependencies are defined", () => {
    const deps = parseManifest(JSON.stringify({ name: "empty", version: "0.0.1" }));
    expect(deps).toEqual([]);
  });

  test("throws an error with a meaningful message when the manifest is not valid JSON", () => {
    expect(() => parseManifest("{not json")).toThrow(/invalid manifest/i);
  });

  test("throws an error when the manifest is not an object", () => {
    expect(() => parseManifest(JSON.stringify([1, 2, 3]))).toThrow(/manifest must be a JSON object/i);
  });
});
