import { describe, it, expect } from "bun:test";
import { parseVersion } from "./src/version";

describe("parseVersion", () => {
  it("should parse a semantic version string", () => {
    const version = parseVersion("1.2.3");
    expect(version.major).toBe(1);
    expect(version.minor).toBe(2);
    expect(version.patch).toBe(3);
  });

  it("should parse version from package.json", () => {
    const pkgJson = { version: "2.0.0" };
    const version = parseVersion(pkgJson.version);
    expect(version.major).toBe(2);
    expect(version.minor).toBe(0);
    expect(version.patch).toBe(0);
  });

  it("should throw on invalid version format", () => {
    expect(() => parseVersion("not-a-version")).toThrow();
  });
});
