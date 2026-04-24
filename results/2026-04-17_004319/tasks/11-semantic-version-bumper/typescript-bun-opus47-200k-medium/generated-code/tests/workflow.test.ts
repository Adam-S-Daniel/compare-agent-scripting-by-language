import { describe, test, expect, beforeAll } from "bun:test";
import { readFileSync, writeFileSync, existsSync, statSync } from "node:fs";
import { spawnSync } from "node:child_process";
import * as path from "node:path";
import yaml from "js-yaml";

// These tests cover workflow structure + execution. The fixture-driven act
// runs produce `act-result.txt` in the project root, which is the required
// artifact.

const ROOT = path.resolve(import.meta.dir, "..");
const WORKFLOW = path.join(ROOT, ".github/workflows/semantic-version-bumper.yml");
const ACT_RESULT = path.join(ROOT, "act-result.txt");

interface FixtureCase {
  name: string;      // fixture directory under fixtures/
  current: string;   // starting version
  bump: string;      // expected bump type
  next: string;      // expected resulting version
}

// Known-good fixture outputs. The harness asserts on these exact strings.
const CASES: FixtureCase[] = [
  { name: "case-feat", current: "1.1.0", bump: "minor", next: "1.2.0" },
  { name: "case-fix", current: "0.4.2", bump: "patch", next: "0.4.3" },
  { name: "case-breaking", current: "2.3.4", bump: "major", next: "3.0.0" },
];

describe("workflow structure", () => {
  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW)).toBe(true);
  });

  test("actionlint passes with exit code 0", () => {
    const result = spawnSync("actionlint", [WORKFLOW], { encoding: "utf8" });
    if (result.status !== 0) {
      console.error("actionlint stdout:", result.stdout);
      console.error("actionlint stderr:", result.stderr);
    }
    expect(result.status).toBe(0);
  });

  test("YAML parses and has expected shape", () => {
    // Cast to `any` — YAML parse returns unknown; we poke into known keys below.
    const doc = yaml.load(readFileSync(WORKFLOW, "utf8")) as any;
    expect(doc.name).toBe("semantic-version-bumper");
    // `on` in YAML parses as boolean true unless quoted, so check both forms.
    const triggers = doc.on ?? doc[true];
    expect(triggers).toBeDefined();
    expect(triggers.push !== undefined).toBe(true);
    expect(triggers.pull_request !== undefined).toBe(true);
    expect(triggers.workflow_dispatch !== undefined).toBe(true);
    expect(doc.jobs.bump).toBeDefined();
    expect(doc.jobs.bump["runs-on"]).toBe("ubuntu-latest");
    const steps = doc.jobs.bump.steps as any[];
    // checkout + install bun + install deps + tests + bump
    expect(steps.length).toBeGreaterThanOrEqual(4);
    const checkout = steps.find((s) => (s.uses ?? "").startsWith("actions/checkout"));
    expect(checkout).toBeDefined();
    expect(checkout.uses).toBe("actions/checkout@v4");
  });

  test("referenced script paths exist", () => {
    expect(existsSync(path.join(ROOT, "src/cli.ts"))).toBe(true);
    expect(existsSync(path.join(ROOT, "src/bumper.ts"))).toBe(true);
    for (const c of CASES) {
      expect(statSync(path.join(ROOT, "fixtures", c.name, "VERSION")).isFile()).toBe(true);
      expect(statSync(path.join(ROOT, "fixtures", c.name, "commits.log")).isFile()).toBe(true);
    }
  });
});

// Act-driven integration tests. Each case runs the workflow once via `act push`
// with FIXTURE set to the fixture directory name. We append each run's output
// to act-result.txt so reviewers have one canonical log file.
describe("workflow via act", () => {
  beforeAll(() => {
    // Truncate the result log at the start of the suite.
    writeFileSync(ACT_RESULT, "");
  });

  for (const c of CASES) {
    test(
      `act push with fixture ${c.name} produces ${c.next}`,
      () => {
        const result = spawnSync(
          "act",
          ["push", "--rm", "--env", `FIXTURE=${c.name}`],
          { cwd: ROOT, encoding: "utf8", timeout: 10 * 60 * 1000 },
        );
        const combined =
          `\n===== fixture: ${c.name} =====\n` +
          `exit=${result.status}\n` +
          `--- stdout ---\n${result.stdout ?? ""}\n` +
          `--- stderr ---\n${result.stderr ?? ""}\n` +
          `===== end: ${c.name} =====\n`;
        // Append — `beforeAll` already truncated once.
        const prior = readFileSync(ACT_RESULT, "utf8");
        writeFileSync(ACT_RESULT, prior + combined);

        const output = (result.stdout ?? "") + "\n" + (result.stderr ?? "");
        if (result.status !== 0) {
          console.error(output.slice(-2000));
        }
        expect(result.status).toBe(0);
        // Assert exact bumper output lines appear in the act log.
        expect(output).toContain(`current=${c.current}`);
        expect(output).toContain(`bump=${c.bump}`);
        expect(output).toContain(`next=${c.next}`);
        // Every job must report success.
        expect(output).toContain("Job succeeded");
      },
      15 * 60 * 1000,
    );
  }
});
