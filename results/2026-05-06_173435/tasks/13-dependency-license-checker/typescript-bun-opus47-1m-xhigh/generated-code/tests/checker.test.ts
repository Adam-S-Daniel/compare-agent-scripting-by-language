// TDD tests for the license checker.
// The checker takes a list of dependencies and a license-lookup function
// (mocked here) and produces compliance results.
import { describe, expect, test } from "bun:test";
import { checkDependencies, type LicenseLookup, type Policy } from "../src/checker.ts";
import type { Dependency } from "../src/parser.ts";

const policy: Policy = {
  allow: ["MIT", "Apache-2.0", "BSD-3-Clause"],
  deny: ["GPL-3.0", "AGPL-3.0"],
};

function mockLookup(table: Record<string, string | null>): LicenseLookup {
  return async (name: string) => {
    if (!(name in table)) return null;
    return table[name] ?? null;
  };
}

const deps: Dependency[] = [
  { name: "lodash", version: "^4.17.21", source: "package.json" },
  { name: "left-pad", version: "1.0.0", source: "package.json" },
  { name: "evil-pkg", version: "1.0.0", source: "package.json" },
  { name: "obscure", version: "0.1.0", source: "package.json" },
];

describe("checkDependencies", () => {
  test("classifies dependencies into approved / denied / unknown by license", async () => {
    const lookup = mockLookup({
      lodash: "MIT",
      "left-pad": "BSD-3-Clause",
      "evil-pkg": "GPL-3.0",
      obscure: null,
    });

    const results = await checkDependencies(deps, policy, lookup);

    expect(results).toEqual([
      {
        name: "evil-pkg",
        version: "1.0.0",
        source: "package.json",
        license: "GPL-3.0",
        status: "denied",
        reason: "license GPL-3.0 is on the deny-list",
      },
      {
        name: "left-pad",
        version: "1.0.0",
        source: "package.json",
        license: "BSD-3-Clause",
        status: "approved",
        reason: "license BSD-3-Clause is on the allow-list",
      },
      {
        name: "lodash",
        version: "^4.17.21",
        source: "package.json",
        license: "MIT",
        status: "approved",
        reason: "license MIT is on the allow-list",
      },
      {
        name: "obscure",
        version: "0.1.0",
        source: "package.json",
        license: null,
        status: "unknown",
        reason: "license could not be determined",
      },
    ]);
  });

  test("treats a license that is on neither list as unknown", async () => {
    const lookup = mockLookup({ "weird-pkg": "WTFPL" });
    const [result] = await checkDependencies(
      [{ name: "weird-pkg", version: "1.0.0", source: "package.json" }],
      policy,
      lookup,
    );
    expect(result?.status).toBe("unknown");
    expect(result?.reason).toBe("license WTFPL is not on the allow-list or deny-list");
  });

  test("deny-list wins over allow-list when both contain the same license", async () => {
    const conflictingPolicy: Policy = {
      allow: ["MIT"],
      deny: ["MIT"],
    };
    const lookup = mockLookup({ "trojan-pkg": "MIT" });
    const [result] = await checkDependencies(
      [{ name: "trojan-pkg", version: "1.0.0", source: "package.json" }],
      conflictingPolicy,
      lookup,
    );
    expect(result?.status).toBe("denied");
  });

  test("propagates lookup errors with context about which dep failed", async () => {
    const flaky: LicenseLookup = async (name) => {
      throw new Error(`registry exploded fetching ${name}`);
    };
    expect(
      checkDependencies([deps[0]!], policy, flaky),
    ).rejects.toThrow(/license lookup failed for lodash: registry exploded/);
  });
});
