import { describe, it, expect } from "bun:test";
import { determineNextVersion, CommitType } from "./src/bumper";

describe("determineNextVersion", () => {
  it("should bump patch version for fix commits", () => {
    const next = determineNextVersion("1.0.0", [CommitType.FIX]);
    expect(next).toBe("1.0.1");
  });

  it("should bump minor version for feat commits", () => {
    const next = determineNextVersion("1.0.0", [CommitType.FEAT]);
    expect(next).toBe("1.1.0");
  });

  it("should bump major version for breaking commits", () => {
    const next = determineNextVersion("1.0.0", [CommitType.BREAKING]);
    expect(next).toBe("2.0.0");
  });

  it("should handle multiple commit types, preferring highest impact", () => {
    const commits = [CommitType.FIX, CommitType.FEAT, CommitType.BREAKING];
    const next = determineNextVersion("1.0.0", commits);
    expect(next).toBe("2.0.0");
  });

  it("should handle feat + fix, bumping minor", () => {
    const commits = [CommitType.FIX, CommitType.FEAT];
    const next = determineNextVersion("1.0.0", commits);
    expect(next).toBe("1.1.0");
  });

  it("should handle no commits", () => {
    const next = determineNextVersion("1.0.0", []);
    expect(next).toBe("1.0.0");
  });
});
