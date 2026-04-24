import { describe, expect, test } from "bun:test";
import { createMockResolver } from "./resolver";

describe("createMockResolver", () => {
  test("returns the licence string from the mock database", async () => {
    const resolve = createMockResolver({
      lodash: "MIT",
      "gpl-pkg": "GPL-3.0",
    });

    expect(await resolve("lodash")).toBe("MIT");
    expect(await resolve("gpl-pkg")).toBe("GPL-3.0");
  });

  test("returns null for packages not present in the mock database", async () => {
    const resolve = createMockResolver({ lodash: "MIT" });
    expect(await resolve("nonexistent-package")).toBeNull();
  });

  test("is async (returns a Promise) so it can be swapped for a real network lookup", () => {
    const resolve = createMockResolver({ lodash: "MIT" });
    const result = resolve("lodash");
    expect(result).toBeInstanceOf(Promise);
  });
});
