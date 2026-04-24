import { describe, expect, test } from "bun:test";
import { checkCompliance, type PolicyConfig } from "./compliance";
import { createMockResolver } from "./resolver";

const policy: PolicyConfig = {
  allow: ["MIT", "Apache-2.0", "BSD-3-Clause"],
  deny: ["GPL-3.0", "AGPL-3.0"],
};

describe("checkCompliance", () => {
  test("marks allow-listed licences as approved", async () => {
    const resolve = createMockResolver({ lodash: "MIT" });
    const result = await checkCompliance(
      [{ name: "lodash", version: "4.17.21" }],
      policy,
      resolve,
    );
    expect(result).toEqual([
      { name: "lodash", version: "4.17.21", license: "MIT", status: "approved" },
    ]);
  });

  test("marks deny-listed licences as denied", async () => {
    const resolve = createMockResolver({ "bad-pkg": "GPL-3.0" });
    const result = await checkCompliance(
      [{ name: "bad-pkg", version: "1.0.0" }],
      policy,
      resolve,
    );
    expect(result[0]?.status).toBe("denied");
    expect(result[0]?.license).toBe("GPL-3.0");
  });

  test("marks licences that match neither list as unknown", async () => {
    const resolve = createMockResolver({ "weird-pkg": "WTFPL" });
    const result = await checkCompliance(
      [{ name: "weird-pkg", version: "1.0.0" }],
      policy,
      resolve,
    );
    expect(result[0]?.status).toBe("unknown");
    expect(result[0]?.license).toBe("WTFPL");
  });

  test("marks dependencies with no resolvable licence as unknown with license=null", async () => {
    const resolve = createMockResolver({});
    const result = await checkCompliance(
      [{ name: "mystery-pkg", version: "1.0.0" }],
      policy,
      resolve,
    );
    expect(result[0]?.status).toBe("unknown");
    expect(result[0]?.license).toBeNull();
  });

  test("classifies a mixed dependency list correctly and preserves order", async () => {
    const resolve = createMockResolver({
      lodash: "MIT",
      "bad-pkg": "AGPL-3.0",
      "weird-pkg": "WTFPL",
    });
    const deps = [
      { name: "lodash", version: "1" },
      { name: "bad-pkg", version: "1" },
      { name: "weird-pkg", version: "1" },
      { name: "mystery-pkg", version: "1" },
    ];
    const result = await checkCompliance(deps, policy, resolve);
    expect(result.map((r) => r.status)).toEqual([
      "approved",
      "denied",
      "unknown",
      "unknown",
    ]);
  });

  test("treats the deny list as authoritative when a licence is on both lists", async () => {
    const ambiguous: PolicyConfig = { allow: ["MIT"], deny: ["MIT"] };
    const resolve = createMockResolver({ lodash: "MIT" });
    const result = await checkCompliance(
      [{ name: "lodash", version: "1" }],
      ambiguous,
      resolve,
    );
    expect(result[0]?.status).toBe("denied");
  });
});
