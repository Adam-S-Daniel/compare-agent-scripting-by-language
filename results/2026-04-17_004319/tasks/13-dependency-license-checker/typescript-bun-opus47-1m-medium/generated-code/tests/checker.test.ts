// Unit tests for the license checker. Exercises parsing, lookup via a
// mocked resolver, allow/deny list matching, and report generation.
import { describe, test, expect } from "bun:test";
import {
  parseManifest,
  checkDependencies,
  formatReport,
  type LicenseLookup,
  type PolicyConfig,
} from "../src/checker.ts";

const policy: PolicyConfig = {
  allow: ["MIT", "Apache-2.0", "BSD-3-Clause"],
  deny: ["GPL-3.0", "AGPL-3.0"],
};

describe("parseManifest", () => {
  test("parses dependencies and devDependencies from package.json", () => {
    const json = JSON.stringify({
      name: "x",
      version: "1.0.0",
      dependencies: { lodash: "^4.17.0", express: "4.18.0" },
      devDependencies: { typescript: "5.0.0" },
    });
    const deps = parseManifest(json);
    expect(deps).toEqual([
      { name: "lodash", version: "^4.17.0" },
      { name: "express", version: "4.18.0" },
      { name: "typescript", version: "5.0.0" },
    ]);
  });

  test("handles missing dep sections", () => {
    expect(parseManifest(JSON.stringify({ name: "x" }))).toEqual([]);
  });

  test("throws on invalid JSON", () => {
    expect(() => parseManifest("not-json")).toThrow(/Failed to parse manifest/);
  });
});

describe("checkDependencies", () => {
  const lookup: LicenseLookup = async (name) => {
    const table: Record<string, string> = {
      lodash: "MIT",
      express: "MIT",
      "bad-pkg": "GPL-3.0",
      mystery: "WTFPL",
    };
    return table[name] ?? null;
  };

  test("marks allow-listed deps as approved", async () => {
    const results = await checkDependencies(
      [{ name: "lodash", version: "^4" }],
      policy,
      lookup,
    );
    expect(results[0]).toMatchObject({
      name: "lodash",
      license: "MIT",
      status: "approved",
    });
  });

  test("marks deny-listed deps as denied", async () => {
    const results = await checkDependencies(
      [{ name: "bad-pkg", version: "1.0.0" }],
      policy,
      lookup,
    );
    expect(results[0].status).toBe("denied");
  });

  test("marks unrecognized license as unknown", async () => {
    const results = await checkDependencies(
      [{ name: "mystery", version: "1.0.0" }],
      policy,
      lookup,
    );
    expect(results[0].status).toBe("unknown");
  });

  test("marks missing license as unknown with null license", async () => {
    const results = await checkDependencies(
      [{ name: "ghost", version: "1.0.0" }],
      policy,
      lookup,
    );
    expect(results[0]).toMatchObject({
      name: "ghost",
      license: null,
      status: "unknown",
    });
  });

  test("surfaces lookup errors as unknown with reason", async () => {
    const brokenLookup: LicenseLookup = async () => {
      throw new Error("network down");
    };
    const results = await checkDependencies(
      [{ name: "lodash", version: "^4" }],
      policy,
      brokenLookup,
    );
    expect(results[0].status).toBe("unknown");
    expect(results[0].reason).toMatch(/network down/);
  });
});

describe("formatReport", () => {
  test("produces JSON with summary counts", () => {
    const report = formatReport([
      { name: "a", version: "1", license: "MIT", status: "approved" },
      { name: "b", version: "1", license: "GPL-3.0", status: "denied" },
      { name: "c", version: "1", license: null, status: "unknown" },
    ]);
    const parsed = JSON.parse(report);
    expect(parsed.summary).toEqual({
      total: 3,
      approved: 1,
      denied: 1,
      unknown: 1,
    });
    expect(parsed.dependencies).toHaveLength(3);
  });
});
