// Tests the license-status decision logic against allow/deny config.
// The license lookup is supplied as an injected function (mock-friendly).
import { describe, expect, test } from "bun:test";
import { checkDependencies } from "../src/checker.ts";
import type { LicenseLookup, PolicyConfig } from "../src/checker.ts";

const policy: PolicyConfig = {
  allow: ["MIT", "Apache-2.0", "BSD-3-Clause"],
  deny: ["GPL-3.0", "AGPL-3.0"],
};

describe("checkDependencies", () => {
  test("classifies allowed, denied, and unknown licenses", async () => {
    const lookup: LicenseLookup = async (name) => {
      const map: Record<string, string | null> = {
        left: "MIT",
        evil: "GPL-3.0",
        mystery: null,
        weird: "WTFPL",
      };
      return map[name] ?? null;
    };
    const deps = [
      { name: "left", version: "1.0.0" },
      { name: "evil", version: "2.0.0" },
      { name: "mystery", version: "3.0.0" },
      { name: "weird", version: "4.0.0" },
    ];

    const report = await checkDependencies(deps, policy, lookup);
    expect(report).toEqual([
      { name: "left", version: "1.0.0", license: "MIT", status: "approved" },
      { name: "evil", version: "2.0.0", license: "GPL-3.0", status: "denied" },
      { name: "mystery", version: "3.0.0", license: null, status: "unknown" },
      // Not on allow- or deny-list ⇒ unknown (conservative default).
      { name: "weird", version: "4.0.0", license: "WTFPL", status: "unknown" },
    ]);
  });

  test("lookup errors are surfaced as unknown with a reason", async () => {
    const lookup: LicenseLookup = async () => {
      throw new Error("network down");
    };
    const report = await checkDependencies(
      [{ name: "x", version: "1.0.0" }],
      policy,
      lookup,
    );
    expect(report).toEqual([
      { name: "x", version: "1.0.0", license: null, status: "unknown", error: "network down" },
    ]);
  });

  test("deny-list takes precedence over allow-list", async () => {
    const conflict: PolicyConfig = { allow: ["MIT"], deny: ["MIT"] };
    const lookup: LicenseLookup = async () => "MIT";
    const report = await checkDependencies(
      [{ name: "x", version: "1.0.0" }],
      conflict,
      lookup,
    );
    expect(report[0].status).toBe("denied");
  });
});
