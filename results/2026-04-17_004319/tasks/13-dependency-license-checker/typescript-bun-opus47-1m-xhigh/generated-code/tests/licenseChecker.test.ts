// Red-green TDD: license checker.
// The checker takes a list of dependencies, a policy (allow/deny),
// and a lookup function. It returns one ComplianceEntry per dep.
//
// - license on allow-list  -> "approved"
// - license on deny-list   -> "denied"
// - license null / neither -> "unknown"
// - deny takes precedence over allow if somehow both match,
//   because a deny is a hard compliance failure.

import { describe, test, expect } from "bun:test";
import { checkLicenses } from "../src/licenseChecker.ts";
import type { LicenseLookup, LicensePolicy, Dependency } from "../src/types.ts";

// Small in-memory lookup builder — the "mock license lookup" the task requires.
function mockLookup(table: Record<string, string | null>): LicenseLookup {
  return (dep: Dependency) => {
    const key = `${dep.name}@${dep.version}`;
    if (key in table) return table[key] ?? null;
    if (dep.name in table) return table[dep.name] ?? null;
    return null;
  };
}

const policy: LicensePolicy = {
  allow: ["MIT", "Apache-2.0", "BSD-3-Clause"],
  deny: ["GPL-3.0", "AGPL-3.0"],
};

describe("checkLicenses", () => {
  test("marks allow-listed license as approved", () => {
    const deps: Dependency[] = [{ name: "lodash", version: "4.17.21" }];
    const lookup = mockLookup({ lodash: "MIT" });
    const entries = checkLicenses(deps, policy, lookup);
    expect(entries).toEqual([
      { name: "lodash", version: "4.17.21", license: "MIT", status: "approved" },
    ]);
  });

  test("marks deny-listed license as denied", () => {
    const deps: Dependency[] = [{ name: "some-gpl-pkg", version: "1.0.0" }];
    const lookup = mockLookup({ "some-gpl-pkg": "GPL-3.0" });
    const entries = checkLicenses(deps, policy, lookup);
    expect(entries[0]!.status).toBe("denied");
    expect(entries[0]!.license).toBe("GPL-3.0");
  });

  test("marks missing license as unknown", () => {
    const deps: Dependency[] = [{ name: "mystery", version: "0.1.0" }];
    const lookup = mockLookup({});
    const entries = checkLicenses(deps, policy, lookup);
    expect(entries[0]!.status).toBe("unknown");
    expect(entries[0]!.license).toBeNull();
  });

  test("marks license not on either list as unknown", () => {
    const deps: Dependency[] = [{ name: "weird", version: "1.0.0" }];
    const lookup = mockLookup({ weird: "WTFPL" });
    const entries = checkLicenses(deps, policy, lookup);
    expect(entries[0]!.status).toBe("unknown");
    expect(entries[0]!.license).toBe("WTFPL");
  });

  test("comparison is case-insensitive", () => {
    const deps: Dependency[] = [{ name: "x", version: "1.0.0" }];
    const lookup = mockLookup({ x: "mit" }); // lower-case input
    const entries = checkLicenses(deps, policy, lookup);
    expect(entries[0]!.status).toBe("approved");
  });

  test("deny takes precedence over allow", () => {
    const overlap: LicensePolicy = {
      allow: ["MIT", "GPL-3.0"],
      deny: ["GPL-3.0"],
    };
    const deps: Dependency[] = [{ name: "x", version: "1.0.0" }];
    const lookup = mockLookup({ x: "GPL-3.0" });
    const entries = checkLicenses(deps, overlap, lookup);
    expect(entries[0]!.status).toBe("denied");
  });

  test("processes each dependency independently", () => {
    const deps: Dependency[] = [
      { name: "a", version: "1.0.0" },
      { name: "b", version: "2.0.0" },
      { name: "c", version: "3.0.0" },
    ];
    const lookup = mockLookup({ a: "MIT", b: "GPL-3.0" /* c: unknown */ });
    const entries = checkLicenses(deps, policy, lookup);
    expect(entries.map((e) => e.status)).toEqual([
      "approved",
      "denied",
      "unknown",
    ]);
  });
});
