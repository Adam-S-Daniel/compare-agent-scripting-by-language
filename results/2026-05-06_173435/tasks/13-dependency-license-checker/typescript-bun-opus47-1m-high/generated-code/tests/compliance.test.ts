// RED phase tests for the compliance engine.
// The engine takes parsed dependencies, calls a (mocked) license lookup for
// each one, and classifies the result against an allow/deny config.
import { describe, expect, test } from "bun:test";
import { checkCompliance, type LicenseLookup, type LicenseConfig } from "../src/compliance.ts";

const config: LicenseConfig = {
  allow: ["MIT", "Apache-2.0", "BSD-3-Clause"],
  deny: ["GPL-3.0", "AGPL-3.0"],
};

// A synchronous mock lookup keeps tests deterministic — no network, no fs.
const mockLookup = (table: Record<string, string | null>): LicenseLookup => {
  return async ({ name }) => {
    if (!(name in table)) return null;
    return table[name] ?? null;
  };
};

describe("checkCompliance", () => {
  test("classifies each dependency as approved, denied, or unknown", async () => {
    const lookup = mockLookup({
      "left-pad": "MIT",
      "evil-lib": "GPL-3.0",
      "mystery-lib": null,
    });
    const deps = [
      { name: "left-pad", version: "1.3.0" },
      { name: "evil-lib", version: "2.0.0" },
      { name: "mystery-lib", version: "0.1.0" },
      { name: "ghost-lib", version: "9.9.9" }, // not in lookup at all
    ];
    const report = await checkCompliance(deps, lookup, config);
    expect(report).toEqual([
      { name: "left-pad", version: "1.3.0", license: "MIT", status: "approved" },
      { name: "evil-lib", version: "2.0.0", license: "GPL-3.0", status: "denied" },
      { name: "mystery-lib", version: "0.1.0", license: null, status: "unknown" },
      { name: "ghost-lib", version: "9.9.9", license: null, status: "unknown" },
    ]);
  });

  test("treats licenses outside both lists as unknown", async () => {
    const lookup = mockLookup({ "weirdlib": "WTFPL" });
    const report = await checkCompliance(
      [{ name: "weirdlib", version: "1.0.0" }],
      lookup,
      config,
    );
    expect(report[0]!.status).toBe("unknown");
    expect(report[0]!.license).toBe("WTFPL");
  });

  test("license matching is case-insensitive", async () => {
    const lookup = mockLookup({ a: "mit", b: "gpl-3.0" });
    const report = await checkCompliance(
      [
        { name: "a", version: "1" },
        { name: "b", version: "1" },
      ],
      lookup,
      config,
    );
    expect(report[0]!.status).toBe("approved");
    expect(report[1]!.status).toBe("denied");
  });

  test("propagates lookup errors with dependency context", async () => {
    const failing: LicenseLookup = async () => {
      throw new Error("network down");
    };
    await expect(
      checkCompliance([{ name: "boom", version: "1" }], failing, config),
    ).rejects.toThrow(/license lookup failed for boom: network down/);
  });
});
