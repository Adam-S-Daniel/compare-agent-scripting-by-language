// PR Label Assigner Tests
// TDD approach: tests written before implementation to drive the design.
// Each describe block corresponds to one TDD red/green/refactor cycle.

import { test, expect, describe } from "bun:test";
import { existsSync, readFileSync } from "fs";
import { execSync } from "child_process";
import { parse as parseYaml } from "yaml";
import { assignLabels } from "./label-assigner";
import type { LabelConfig } from "./label-assigner";

// ── Cycle 1: Basic single-rule glob matching ───────────────────────────────
describe("basic glob matching", () => {
  test("docs/** matches documentation files", () => {
    const files = ["docs/README.md", "docs/api.md", "docs/guide/intro.md"];
    const config: LabelConfig = {
      rules: [{ pattern: "docs/**", label: "documentation", priority: 1 }],
    };
    expect(assignLabels(files, config)).toEqual(["documentation"]);
  });

  test("src/api/** matches api files", () => {
    const files = ["src/api/routes.ts", "src/api/middleware.ts"];
    const config: LabelConfig = {
      rules: [{ pattern: "src/api/**", label: "api", priority: 1 }],
    };
    expect(assignLabels(files, config)).toEqual(["api"]);
  });

  test("**/*.test.* matches test files in any subdirectory", () => {
    const files = ["src/utils.test.ts", "src/api/routes.test.ts"];
    const config: LabelConfig = {
      rules: [{ pattern: "**/*.test.*", label: "tests", priority: 1 }],
    };
    expect(assignLabels(files, config)).toEqual(["tests"]);
  });

  test("no files matching returns empty array", () => {
    const files = ["random/file.txt", "another.json"];
    const config: LabelConfig = {
      rules: [{ pattern: "docs/**", label: "documentation", priority: 1 }],
    };
    expect(assignLabels(files, config)).toEqual([]);
  });

  test("empty file list returns empty array", () => {
    const config: LabelConfig = {
      rules: [{ pattern: "docs/**", label: "documentation", priority: 1 }],
    };
    expect(assignLabels([], config)).toEqual([]);
  });
});

// ── Cycle 2: Multiple labels from multiple rules ───────────────────────────
describe("multiple labels per PR", () => {
  test("docs + api files get both labels", () => {
    const files = ["docs/README.md", "src/api/routes.ts"];
    const config: LabelConfig = {
      rules: [
        { pattern: "docs/**", label: "documentation", priority: 1 },
        { pattern: "src/api/**", label: "api", priority: 2 },
      ],
    };
    // Labels are sorted alphabetically in output
    expect(assignLabels(files, config)).toEqual(["api", "documentation"]);
  });

  test("single file matching multiple rules gets multiple labels", () => {
    const files = ["src/api/routes.test.ts"];
    const config: LabelConfig = {
      rules: [
        { pattern: "src/api/**", label: "api", priority: 1 },
        { pattern: "**/*.test.*", label: "tests", priority: 2 },
      ],
    };
    expect(assignLabels(files, config)).toEqual(["api", "tests"]);
  });

  test("labels are deduplicated when multiple files match same rule", () => {
    const files = ["docs/README.md", "docs/api.md", "docs/guide/intro.md"];
    const config: LabelConfig = {
      rules: [
        { pattern: "docs/**", label: "documentation", priority: 1 },
        { pattern: "docs/api.md", label: "documentation", priority: 2 },
      ],
    };
    expect(assignLabels(files, config)).toEqual(["documentation"]);
  });
});

// ── Cycle 3: Priority ordering ─────────────────────────────────────────────
describe("priority ordering", () => {
  test("multiple rules matching same file — all labels applied", () => {
    const files = ["src/api/routes.ts"];
    const config: LabelConfig = {
      rules: [
        { pattern: "src/**", label: "backend", priority: 10 },
        { pattern: "src/api/**", label: "api", priority: 1 },
      ],
    };
    // Both rules fire; output is alphabetically sorted
    expect(assignLabels(files, config)).toEqual(["api", "backend"]);
  });

  test("all matching rules contribute labels regardless of priority", () => {
    const files = ["src/api/user.test.ts"];
    const config: LabelConfig = {
      rules: [
        { pattern: "src/api/**", label: "api", priority: 1 },
        { pattern: "src/**", label: "backend", priority: 2 },
        { pattern: "**/*.test.*", label: "tests", priority: 3 },
      ],
    };
    expect(assignLabels(files, config)).toEqual(["api", "backend", "tests"]);
  });

  test("rules with same priority both apply", () => {
    const files = ["docs/api.md"];
    const config: LabelConfig = {
      rules: [
        { pattern: "docs/**", label: "documentation", priority: 1 },
        { pattern: "**/*.md", label: "markdown", priority: 1 },
      ],
    };
    expect(assignLabels(files, config)).toEqual(["documentation", "markdown"]);
  });
});

// ── Cycle 4: Full default config fixture tests ────────────────────────────
// These tests use a shared fixture config and output parseable lines for act.
describe("default config fixtures", () => {
  const FIXTURE_CONFIG: LabelConfig = {
    rules: [
      { pattern: "docs/**", label: "documentation", priority: 1 },
      { pattern: "*.md", label: "documentation", priority: 1 },
      { pattern: "src/api/**", label: "api", priority: 2 },
      { pattern: "**/*.test.*", label: "tests", priority: 3 },
      { pattern: "**/*.spec.*", label: "tests", priority: 3 },
      { pattern: ".github/**", label: "ci/cd", priority: 4 },
    ],
  };

  test("fixture: docs-only => [documentation]", () => {
    const files = ["docs/README.md", "docs/api.md"];
    const labels = assignLabels(files, FIXTURE_CONFIG);
    console.log(`[FIXTURE:docs-only] LABELS: ${labels.join(",") || "(none)"}`);
    expect(labels).toEqual(["documentation"]);
  });

  test("fixture: mixed-docs-api => [api, documentation]", () => {
    const files = ["docs/README.md", "src/api/routes.ts"];
    const labels = assignLabels(files, FIXTURE_CONFIG);
    console.log(`[FIXTURE:mixed-docs-api] LABELS: ${labels.join(",") || "(none)"}`);
    expect(labels).toEqual(["api", "documentation"]);
  });

  test("fixture: test-files => [tests]", () => {
    const files = ["src/utils.test.ts", "src/api.test.ts"];
    const labels = assignLabels(files, FIXTURE_CONFIG);
    console.log(`[FIXTURE:test-files] LABELS: ${labels.join(",") || "(none)"}`);
    expect(labels).toEqual(["tests"]);
  });

  test("fixture: multi-label-single-file => [api, tests]", () => {
    const files = ["src/api/routes.test.ts"];
    const labels = assignLabels(files, FIXTURE_CONFIG);
    console.log(`[FIXTURE:multi-label-single-file] LABELS: ${labels.join(",") || "(none)"}`);
    expect(labels).toEqual(["api", "tests"]);
  });

  test("fixture: no-match => (none)", () => {
    const files = ["random/file.txt", "build/output.bin"];
    const labels = assignLabels(files, FIXTURE_CONFIG);
    console.log(`[FIXTURE:no-match] LABELS: ${labels.join(",") || "(none)"}`);
    expect(labels).toEqual([]);
  });

  test("fixture: ci-files => [ci/cd]", () => {
    const files = [".github/workflows/ci.yml", ".github/dependabot.yml"];
    const labels = assignLabels(files, FIXTURE_CONFIG);
    console.log(`[FIXTURE:ci-files] LABELS: ${labels.join(",") || "(none)"}`);
    expect(labels).toEqual(["ci/cd"]);
  });
});

// ── Cycle 5: Workflow structure tests ─────────────────────────────────────
describe("workflow structure", () => {
  const WORKFLOW_PATH = ".github/workflows/pr-label-assigner.yml";

  test("workflow file exists", () => {
    expect(existsSync(WORKFLOW_PATH)).toBe(true);
  });

  test("workflow file references label-assigner.ts", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf8");
    expect(content).toContain("label-assigner.ts");
  });

  test("workflow has push trigger", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf8");
    const workflow = parseYaml(content);
    const triggers = Object.keys(workflow.on ?? {});
    expect(triggers).toContain("push");
  });

  test("workflow has assign-labels job", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf8");
    const workflow = parseYaml(content);
    expect(workflow.jobs).toBeDefined();
    expect(Object.keys(workflow.jobs)).toContain("assign-labels");
  });

  test("workflow job has checkout step", () => {
    const content = readFileSync(WORKFLOW_PATH, "utf8");
    const workflow = parseYaml(content);
    const steps: Array<{ uses?: string }> = workflow.jobs["assign-labels"].steps;
    const hasCheckout = steps.some((s) => s.uses?.startsWith("actions/checkout"));
    expect(hasCheckout).toBe(true);
  });

  test("actionlint passes on workflow file", () => {
    let exitCode = 0;
    let errorOutput = "";
    try {
      execSync(`actionlint ${WORKFLOW_PATH}`, { stdio: "pipe" });
    } catch (e: any) {
      exitCode = e.status ?? 1;
      errorOutput = (e.stdout?.toString() ?? "") + (e.stderr?.toString() ?? "");
    }
    if (exitCode !== 0) {
      console.error("actionlint errors:", errorOutput);
    }
    expect(exitCode).toBe(0);
  });
});
