import { describe, test, expect, beforeAll } from "bun:test";
import { mkdtempSync, cpSync, writeFileSync, appendFileSync, readFileSync, existsSync } from "fs";
import { tmpdir } from "os";
import { join } from "path";
import { execSync, spawnSync } from "child_process";
import * as YAML from "yaml";

const PROJECT = process.cwd();
const ACT_RESULT = join(PROJECT, "act-result.txt");
const WORKFLOW = join(PROJECT, ".github/workflows/environment-matrix-generator.yml");

interface Case {
  name: string;
  fixture: string;
  expected: (out: string) => void;
}

function extractBlock(out: string): string {
  // Act prefixes every line with "[workflow/job]   | ". Strip it first.
  const cleaned = out
    .split("\n")
    .map((l) => l.replace(/^\[[^\]]+\]\s*\|\s?/, ""))
    .join("\n");
  const b = cleaned.indexOf("----- MATRIX_OUTPUT_BEGIN -----");
  const e = cleaned.indexOf("----- MATRIX_OUTPUT_END -----");
  if (b < 0 || e < 0) return "";
  return cleaned.slice(b + "----- MATRIX_OUTPUT_BEGIN -----".length, e).trim();
}

function setupRepo(fixturePath: string): string {
  const dir = mkdtempSync(join(tmpdir(), "matrix-act-"));
  // Copy project files needed for workflow to run.
  for (const name of ["src", "tests", "fixtures", ".github", "package.json", "tsconfig.json", ".actrc"]) {
    const src = join(PROJECT, name);
    if (existsSync(src)) cpSync(src, join(dir, name), { recursive: true });
  }
  // Overwrite fixtures/input.json with the case's fixture.
  cpSync(fixturePath, join(dir, "fixtures/input.json"));
  execSync("git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -q -m init", {
    cwd: dir,
    stdio: "ignore",
  });
  return dir;
}

function runAct(dir: string): { code: number; output: string } {
  const res = spawnSync("act", ["push", "--rm", "--pull=false"], {
    cwd: dir,
    encoding: "utf8",
    maxBuffer: 50 * 1024 * 1024,
  });
  const output = (res.stdout ?? "") + (res.stderr ?? "");
  return { code: res.status ?? 1, output };
}

const cases: Case[] = [
  {
    name: "basic",
    fixture: join(PROJECT, "fixtures/basic.json"),
    expected: (out) => {
      const block = extractBlock(out);
      const parsed = JSON.parse(block);
      expect(parsed.matrix.include).toHaveLength(4);
      expect(parsed.matrix["max-parallel"]).toBe(4);
      expect(parsed.matrix["fail-fast"]).toBe(true);
      expect(parsed.matrix.include).toContainEqual({ os: "ubuntu-latest", node: "18" });
      expect(parsed.matrix.include).toContainEqual({ os: "macos-latest", node: "20" });
    },
  },
  {
    name: "with-rules",
    fixture: join(PROJECT, "fixtures/with-rules.json"),
    expected: (out) => {
      const block = extractBlock(out);
      const parsed = JSON.parse(block);
      // 3 os * 2 node = 6, minus 1 excluded, plus 1 include = 6
      expect(parsed.matrix.include).toHaveLength(6);
      expect(parsed.matrix["max-parallel"]).toBe(3);
      expect(parsed.matrix["fail-fast"]).toBe(false);
      // No windows/18
      for (const e of parsed.matrix.include) {
        expect(!(e.os === "windows-latest" && e.node === "18")).toBe(true);
      }
      // coverage merged
      const nonInclude = parsed.matrix.include.filter(
        (e: any) => !(e.node === "22" && e.experimental === true),
      );
      for (const e of nonInclude) expect(e.coverage).toBe(true);
    },
  },
  {
    name: "too-big",
    fixture: join(PROJECT, "fixtures/too-big.json"),
    expected: (out) => {
      expect(out).toContain("exceeds maximum size 5");
      expect(out).toContain("MATRIX_ERROR");
    },
  },
];

describe("workflow structure", () => {
  test("actionlint passes", () => {
    const res = spawnSync("actionlint", [WORKFLOW], { encoding: "utf8" });
    expect(res.status).toBe(0);
  });

  test("workflow YAML has expected shape", () => {
    const doc = YAML.parse(readFileSync(WORKFLOW, "utf8"));
    expect(doc.on).toHaveProperty("push");
    expect(doc.on).toHaveProperty("pull_request");
    expect(doc.on).toHaveProperty("workflow_dispatch");
    expect(doc.jobs).toHaveProperty("generate");
    const steps = doc.jobs.generate.steps;
    const runs = steps.map((s: any) => s.run ?? "").join("\n");
    expect(runs).toContain("bun test tests/matrix.test.ts");
    expect(runs).toContain("src/cli.ts");
  });

  test("referenced script files exist", () => {
    expect(existsSync(join(PROJECT, "src/cli.ts"))).toBe(true);
    expect(existsSync(join(PROJECT, "src/matrix.ts"))).toBe(true);
  });
});

describe("act end-to-end", () => {
  beforeAll(() => {
    writeFileSync(ACT_RESULT, "");
  });

  for (const c of cases) {
    test(
      `act case: ${c.name}`,
      () => {
        const dir = setupRepo(c.fixture);
        const { code, output } = runAct(dir);
        appendFileSync(
          ACT_RESULT,
          `\n===== CASE: ${c.name} =====\nExit: ${code}\n${output}\n===== END ${c.name} =====\n`,
        );
        expect(code).toBe(0);
        expect(output).toContain("Job succeeded");
        c.expected(output);
      },
      300_000,
    );
  }
});
