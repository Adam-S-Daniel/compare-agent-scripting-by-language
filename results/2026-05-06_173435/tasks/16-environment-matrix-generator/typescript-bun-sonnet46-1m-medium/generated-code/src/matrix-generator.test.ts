// TDD test suite for the Environment Matrix Generator.
// Tests are written first (red), then implementation makes them pass (green).

import { describe, test, expect } from "bun:test";
import { generateMatrix, type MatrixConfig } from "./matrix-generator";

describe("generateMatrix - core functionality", () => {
  test("generates basic matrix from two dimensions", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest"],
        "node-version": ["18", "20"],
      },
    };
    const result = generateMatrix(config);
    expect(result.matrix.os).toEqual(["ubuntu-latest", "windows-latest"]);
    expect(result.matrix["node-version"]).toEqual(["18", "20"]);
    expect(result.totalCombinations).toBe(4);
    expect(result.effectiveCombinations).toBe(4);
  });

  test("generates matrix with single dimension", () => {
    const config: MatrixConfig = {
      dimensions: { os: ["ubuntu-latest"] },
    };
    const result = generateMatrix(config);
    expect(result.totalCombinations).toBe(1);
    expect(result.effectiveCombinations).toBe(1);
  });

  test("generates matrix with three dimensions", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest"],
        "node-version": ["18", "20"],
        cache: ["true", "false"],
      },
    };
    const result = generateMatrix(config);
    expect(result.totalCombinations).toBe(8);
    expect(result.effectiveCombinations).toBe(8);
  });

  test("handles empty dimensions", () => {
    const config: MatrixConfig = { dimensions: {} };
    const result = generateMatrix(config);
    expect(result.totalCombinations).toBe(0);
    expect(result.effectiveCombinations).toBe(0);
  });
});

describe("generateMatrix - exclude rules", () => {
  test("applies exclude rule removing one combination", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest"],
        "node-version": ["18", "20"],
      },
      exclude: [{ os: "windows-latest", "node-version": "18" }],
    };
    const result = generateMatrix(config);
    // 4 total - 1 excluded = 3 effective
    expect(result.totalCombinations).toBe(4);
    expect(result.effectiveCombinations).toBe(3);
    expect(result.matrix.exclude).toEqual([
      { os: "windows-latest", "node-version": "18" },
    ]);
  });

  test("applies multiple exclude rules", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest"],
        "node-version": ["18", "20"],
      },
      exclude: [
        { os: "windows-latest", "node-version": "18" },
        { os: "windows-latest", "node-version": "20" },
      ],
    };
    const result = generateMatrix(config);
    // 4 total - 2 excluded = 2 effective
    expect(result.effectiveCombinations).toBe(2);
  });
});

describe("generateMatrix - include rules", () => {
  test("include that adds new combination increases effective count", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest"],
        "node-version": ["18"],
      },
      include: [{ os: "ubuntu-latest", "node-version": "20", experimental: "true" }],
    };
    const result = generateMatrix(config);
    // 1 base + 1 new include (node-version:20 not in dimensions) = 2 effective
    expect(result.totalCombinations).toBe(1);
    expect(result.effectiveCombinations).toBe(2);
    expect(result.matrix.include).toEqual([
      { os: "ubuntu-latest", "node-version": "20", experimental: "true" },
    ]);
  });

  test("include that matches existing combination does not increase effective count", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest"],
        "node-version": ["18", "20"],
      },
      // This include matches {os: ubuntu-latest, node-version: 20} which already exists
      include: [{ os: "ubuntu-latest", "node-version": "20", extra: "data" }],
    };
    const result = generateMatrix(config);
    // 2 base, include augments existing - no new combo
    expect(result.totalCombinations).toBe(2);
    expect(result.effectiveCombinations).toBe(2);
  });

  test("include with new os adds new combination", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest"],
        "node-version": ["18", "20"],
      },
      include: [{ os: "macos-latest", "node-version": "20" }],
    };
    const result = generateMatrix(config);
    // 4 base + 1 new include (macos-latest not in os dimension) = 5 effective
    expect(result.effectiveCombinations).toBe(5);
  });

  test("computes effective combinations with both include and exclude", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest"],
        "node-version": ["18", "20"],
      },
      exclude: [{ os: "windows-latest", "node-version": "18" }],
      include: [{ os: "macos-latest", "node-version": "20" }],
    };
    const result = generateMatrix(config);
    // 4 - 1 (exclude) + 1 (new include) = 4 effective
    expect(result.effectiveCombinations).toBe(4);
  });
});

describe("generateMatrix - max-parallel and fail-fast", () => {
  test("sets max-parallel in output", () => {
    const config: MatrixConfig = {
      dimensions: { os: ["ubuntu-latest"] },
      maxParallel: 4,
    };
    const result = generateMatrix(config);
    expect(result["max-parallel"]).toBe(4);
  });

  test("sets fail-fast to false in output", () => {
    const config: MatrixConfig = {
      dimensions: { os: ["ubuntu-latest"] },
      failFast: false,
    };
    const result = generateMatrix(config);
    expect(result["fail-fast"]).toBe(false);
  });

  test("sets fail-fast to true in output", () => {
    const config: MatrixConfig = {
      dimensions: { os: ["ubuntu-latest"] },
      failFast: true,
    };
    const result = generateMatrix(config);
    expect(result["fail-fast"]).toBe(true);
  });

  test("omits max-parallel when not specified", () => {
    const config: MatrixConfig = { dimensions: { os: ["ubuntu-latest"] } };
    const result = generateMatrix(config);
    expect(result["max-parallel"]).toBeUndefined();
  });

  test("omits fail-fast when not specified", () => {
    const config: MatrixConfig = { dimensions: { os: ["ubuntu-latest"] } };
    const result = generateMatrix(config);
    expect(result["fail-fast"]).toBeUndefined();
  });
});

describe("generateMatrix - max size validation", () => {
  test("throws when effective combinations exceed maxSize", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest", "macos-latest"],
        "node-version": ["16", "18", "20"],
        "python-version": ["3.9", "3.10", "3.11"],
      },
      maxSize: 10,
    };
    expect(() => generateMatrix(config)).toThrow(
      "Matrix size 27 exceeds maximum allowed size of 10"
    );
  });

  test("uses default max size of 256 when not specified", () => {
    // 16 combinations, well under 256 - should not throw
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest", "macos-latest", "ubuntu-20.04"],
        "node-version": ["16", "18", "20", "21"],
      },
    };
    expect(() => generateMatrix(config)).not.toThrow();
    const result = generateMatrix(config);
    expect(result.totalCombinations).toBe(16);
  });

  test("throws with effective count after includes when over maxSize", () => {
    const config: MatrixConfig = {
      dimensions: {
        os: ["ubuntu-latest", "windows-latest"],
      },
      include: [
        { os: "macos-latest" },
        { os: "macos-12" },
        { os: "macos-11" },
      ],
      maxSize: 4,
    };
    // 2 base + 3 new includes = 5, exceeds 4
    expect(() => generateMatrix(config)).toThrow(
      "Matrix size 5 exceeds maximum allowed size of 4"
    );
  });
});

describe("workflow structure tests", () => {
  const WORKFLOW_PATH = ".github/workflows/environment-matrix-generator.yml";

  test("workflow file exists", async () => {
    const file = Bun.file(WORKFLOW_PATH);
    expect(await file.exists()).toBe(true);
  });

  test("workflow has push trigger", async () => {
    const content = await Bun.file(WORKFLOW_PATH).text();
    expect(content).toContain("push:");
  });

  test("workflow has pull_request trigger", async () => {
    const content = await Bun.file(WORKFLOW_PATH).text();
    expect(content).toContain("pull_request:");
  });

  test("workflow has workflow_dispatch trigger", async () => {
    const content = await Bun.file(WORKFLOW_PATH).text();
    expect(content).toContain("workflow_dispatch:");
  });

  test("workflow has jobs section", async () => {
    const content = await Bun.file(WORKFLOW_PATH).text();
    expect(content).toContain("jobs:");
  });

  test("workflow runs bun test", async () => {
    const content = await Bun.file(WORKFLOW_PATH).text();
    expect(content).toContain("bun test");
  });

  test("workflow references main script", async () => {
    const content = await Bun.file(WORKFLOW_PATH).text();
    expect(content).toContain("src/main.ts");
  });

  test("main script file exists", async () => {
    const file = Bun.file("src/main.ts");
    expect(await file.exists()).toBe(true);
  });

  test("matrix generator source exists", async () => {
    const file = Bun.file("src/matrix-generator.ts");
    expect(await file.exists()).toBe(true);
  });

  test("fixture files exist", async () => {
    const fixtures = [
      "fixtures/basic.json",
      "fixtures/with-excludes.json",
      "fixtures/with-includes.json",
      "fixtures/max-parallel.json",
    ];
    for (const path of fixtures) {
      const file = Bun.file(path);
      expect(await file.exists()).toBe(true);
    }
  });

  test("workflow passes actionlint", () => {
    const check = Bun.spawnSync(["which", "actionlint"]);
    if (check.exitCode !== 0) {
      // actionlint not available in this environment — skip
      return;
    }
    const result = Bun.spawnSync(["actionlint", WORKFLOW_PATH]);
    const stderr = result.stderr ? new TextDecoder().decode(result.stderr) : "";
    expect(result.exitCode).toBe(0);
    expect(stderr).toBe("");
  });
});
