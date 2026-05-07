// Test cases driven through the GitHub Actions workflow via `act`.
// Each case is a self-contained input + expected-output pair.
// The harness (act.test.ts) iterates these and asserts on the act output.

import type { Config } from "../../pr-label-assigner.ts";

export interface ActCase {
  /** Stable, filesystem-safe slug used in delimiters in act-result.txt */
  name: string;
  /** Description for human-readable output */
  description: string;
  /** Rule config written to fixtures/config.json before invoking act */
  config: Config;
  /** Mocked changed-files list, one path per line, written to fixtures/files.txt */
  files: string[];
  /** Exact labels we expect the workflow's `LABELS_OUTPUT=` line to contain */
  expectedLabels: string[];
}

// A small, intentionally varied set: covers the empty case, the
// multi-rule overlap case, the exclusive-group resolution case,
// and a multi-pattern OR-semantics case.
export const cases: ActCase[] = [
  {
    name: "01-multi-rule-overlap",
    description:
      "Multiple rules match different files; final set is the union, sorted by priority.",
    config: {
      rules: [
        {
          label: "documentation",
          patterns: ["docs/**", "*.md"],
          priority: 5,
        },
        { label: "api", patterns: ["src/api/**"], priority: 20 },
        { label: "tests", patterns: ["**/*.test.*"], priority: 10 },
      ],
    },
    files: [
      "docs/intro.md",
      "src/api/users.ts",
      "src/api/users.test.ts",
      "README.md",
    ],
    // priorities: api=20, tests=10, documentation=5
    expectedLabels: ["api", "tests", "documentation"],
  },
  {
    name: "02-no-matches",
    description:
      "No file matches any rule; the script must still succeed with an empty label set.",
    config: {
      rules: [
        { label: "documentation", patterns: ["docs/**"] },
        { label: "api", patterns: ["src/api/**"] },
      ],
    },
    files: ["LICENSE", "Makefile", "scripts/build.sh"],
    expectedLabels: [],
  },
  {
    name: "03-exclusive-size-group",
    description:
      "Both size/small and size/large match files; exclusive group keeps only the higher-priority size/large.",
    config: {
      rules: [
        { label: "size/small", patterns: ["small/**"], priority: 1 },
        { label: "size/large", patterns: ["large/**"], priority: 30 },
        { label: "tests", patterns: ["**/*.test.*"], priority: 10 },
      ],
      exclusiveGroups: [{ labels: ["size/small", "size/large"] }],
    },
    files: ["small/a.ts", "large/b.ts", "x.test.ts"],
    expectedLabels: ["size/large", "tests"],
  },
  {
    name: "04-multi-pattern-rule",
    description:
      "A single rule with several patterns matches via OR semantics across files.",
    config: {
      rules: [
        {
          label: "ci",
          patterns: [".github/workflows/**", "Dockerfile", "**/*.yml"],
          priority: 15,
        },
      ],
    },
    files: ["Dockerfile", "k8s/deploy.yml", ".github/workflows/release.yml"],
    expectedLabels: ["ci"],
  },
];
