// Tests for the dependency license checker. Each test was written before the
// implementation in red/green/refactor style; they're grouped by the unit
// they cover (parser, classifier, end-to-end report).
import { describe, expect, test } from "bun:test";
import {
  parsePackageJson,
  parseRequirementsTxt,
  parseManifest,
  classify,
  checkLicenses,
  formatReport,
  type LicenseConfig,
  type LicenseLookup,
} from "./checker";

const config: LicenseConfig = {
  allow: ["MIT", "Apache-2.0", "BSD-3-Clause"],
  deny: ["GPL-3.0", "Proprietary"],
};

describe("parsePackageJson", () => {
  test("extracts deps and devDeps with cleaned versions", () => {
    const json = JSON.stringify({
      dependencies: { lodash: "^4.17.21", react: "18.0.0" },
      devDependencies: { typescript: "~5.0.0" },
    });
    expect(parsePackageJson(json)).toEqual([
      { name: "lodash", version: "4.17.21" },
      { name: "react", version: "18.0.0" },
      { name: "typescript", version: "5.0.0" },
    ]);
  });

  test("rejects malformed JSON with a clear error", () => {
    expect(() => parsePackageJson("{not json")).toThrow(/Invalid package\.json/);
  });
});

describe("parseRequirementsTxt", () => {
  test("parses pinned, ranged and bare lines, skips comments", () => {
    const txt = `# top-level\nrequests==2.31.0\npandas>=2.0\nleft-pad\n\n# trailing`;
    expect(parseRequirementsTxt(txt)).toEqual([
      { name: "requests", version: "2.31.0" },
      { name: "pandas", version: "2.0" },
      { name: "left-pad", version: "*" },
    ]);
  });
});

describe("parseManifest dispatch", () => {
  test("routes by filename suffix", () => {
    expect(parseManifest("foo/package.json", '{"dependencies":{"a":"1"}}'))
      .toEqual([{ name: "a", version: "1" }]);
    expect(parseManifest("requirements.txt", "a==1")).toEqual([
      { name: "a", version: "1" },
    ]);
  });
  test("rejects unsupported manifests", () => {
    expect(() => parseManifest("Pipfile", "")).toThrow(/Unsupported/);
  });
});

describe("classify", () => {
  test("null license is unknown", () => {
    expect(classify(null, config)).toBe("unknown");
  });
  test("allow-listed is approved", () => {
    expect(classify("MIT", config)).toBe("approved");
  });
  test("deny-listed is denied even if also allowed", () => {
    expect(classify("GPL-3.0", config)).toBe("denied");
    const both: LicenseConfig = { allow: ["GPL-3.0"], deny: ["GPL-3.0"] };
    expect(classify("GPL-3.0", both)).toBe("denied");
  });
  test("not on either list is unknown", () => {
    expect(classify("WTFPL", config)).toBe("unknown");
  });
  test("matching is case-insensitive", () => {
    expect(classify("mit", config)).toBe("approved");
  });
});

describe("checkLicenses end-to-end", () => {
  const lookup: LicenseLookup = (dep) =>
    ({
      lodash: "MIT",
      "evil-pkg": "GPL-3.0",
      "left-pad": "WTFPL",
    })[dep.name] ?? null;

  test("produces per-dep entries and a tallied summary", () => {
    const deps = [
      { name: "lodash", version: "4" },
      { name: "evil-pkg", version: "1" },
      { name: "left-pad", version: "0" },
      { name: "ghost", version: "0" },
    ];
    const report = checkLicenses(deps, lookup, config);
    expect(report.summary).toEqual({ approved: 1, denied: 1, unknown: 2 });
    expect(report.entries.find((e) => e.name === "lodash")?.status).toBe(
      "approved"
    );
    expect(report.entries.find((e) => e.name === "ghost")?.license).toBeNull();
  });
});

describe("formatReport", () => {
  test("renders a human-readable text report", () => {
    const report = checkLicenses(
      [{ name: "lodash", version: "4.0.0" }],
      () => "MIT",
      config
    );
    const out = formatReport(report);
    expect(out).toContain("lodash@4.0.0");
    expect(out).toContain("[MIT]");
    expect(out).toContain("APPROVED");
    expect(out).toContain("approved=1 denied=0 unknown=0");
  });
});
