// Red-green TDD: end-to-end `runChecker` that stitches together
// parse -> lookup -> policy -> report. This is the function the CLI
// calls. We test it here with pure inputs so the CLI wrapper itself
// stays thin.

import { describe, test, expect } from "bun:test";
import { runChecker } from "../src/runChecker.ts";

describe("runChecker", () => {
  test("builds a complete report for a mixed manifest", () => {
    const manifest = JSON.stringify({
      name: "demo",
      version: "1.0.0",
      dependencies: { "lodash": "^4.17.21", "bad-lib": "1.0.0" },
      devDependencies: { "typescript": "^5.0.0", "mystery": "0.1.0" },
    });
    const policy = { allow: ["MIT", "Apache-2.0"], deny: ["GPL-3.0"] };
    const licenseDb: Record<string, string> = {
      "lodash": "MIT",
      "bad-lib": "GPL-3.0",
      "typescript": "Apache-2.0",
      // mystery is intentionally absent -> unknown
    };

    const report = runChecker({ manifest, policy, licenseDb });

    // Build a name->entry map for order-independent assertions.
    const byName = Object.fromEntries(report.entries.map((e) => [e.name, e]));
    expect(byName["lodash"]!.status).toBe("approved");
    expect(byName["bad-lib"]!.status).toBe("denied");
    expect(byName["typescript"]!.status).toBe("approved");
    expect(byName["mystery"]!.status).toBe("unknown");
    expect(byName["mystery"]!.license).toBeNull();
    expect(report.summary).toEqual({
      approved: 2,
      denied: 1,
      unknown: 1,
      total: 4,
    });
  });

  test("supports name@version keys in the mock license DB", () => {
    const manifest = JSON.stringify({
      dependencies: { "pinned": "1.2.3", "other": "2.0.0" },
    });
    const policy = { allow: ["MIT"], deny: [] };
    const licenseDb: Record<string, string> = {
      "pinned@1.2.3": "MIT", // version-specific key
      "other": "ISC",        // name-only key, not on allow or deny
    };
    const report = runChecker({ manifest, policy, licenseDb });
    const byName = Object.fromEntries(report.entries.map((e) => [e.name, e]));
    expect(byName["pinned"]!.status).toBe("approved");
    expect(byName["other"]!.status).toBe("unknown");
  });
});
