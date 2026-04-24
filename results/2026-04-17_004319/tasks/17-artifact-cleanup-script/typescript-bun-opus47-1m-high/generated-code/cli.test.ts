import { describe, expect, test } from "bun:test";
import { parseArgs, runCli } from "./cli";

// Tests for the thin CLI wrapper around cleanup. Keeps arg-parsing logic
// small and covered so a failing integration run points straight at it.

describe("parseArgs", () => {
  test("parses --input, --max-age-days, --max-total-size, --keep-latest, --dry-run, --now", () => {
    const args = parseArgs([
      "--input",
      "fx.json",
      "--max-age-days",
      "30",
      "--max-total-size",
      "1000",
      "--keep-latest",
      "3",
      "--dry-run",
      "--now",
      "2026-04-19T00:00:00Z",
    ]);
    expect(args.input).toBe("fx.json");
    expect(args.maxAgeDays).toBe(30);
    expect(args.maxTotalSizeBytes).toBe(1000);
    expect(args.keepLatestPerWorkflow).toBe(3);
    expect(args.dryRun).toBe(true);
    expect(args.now).toBe(Date.parse("2026-04-19T00:00:00Z"));
  });

  test("defaults dry-run to false", () => {
    const args = parseArgs(["--input", "fx.json"]);
    expect(args.dryRun).toBe(false);
  });

  test("throws on unknown flag", () => {
    expect(() => parseArgs(["--bogus"])).toThrow(/unknown flag/i);
  });

  test("throws when required input is missing", () => {
    expect(() => parseArgs([])).toThrow(/--input is required/);
  });
});

describe("runCli (integration with temp fixture)", () => {
  test("loads fixture, applies policy, prints summary; returns exit 0", async () => {
    const fixture = [
      {
        id: "old-1",
        name: "build",
        sizeBytes: 1000,
        createdAt: "2026-01-01T00:00:00Z",
        workflowRunId: "wf-A",
      },
      {
        id: "new-1",
        name: "build",
        sizeBytes: 500,
        createdAt: "2026-04-18T00:00:00Z",
        workflowRunId: "wf-A",
      },
    ];
    const path = `/tmp/cleanup-cli-${crypto.randomUUID()}.json`;
    await Bun.write(path, JSON.stringify(fixture));
    const lines: string[] = [];
    const code = await runCli(
      [
        "--input",
        path,
        "--max-age-days",
        "30",
        "--dry-run",
        "--now",
        "2026-04-19T00:00:00Z",
      ],
      (s) => lines.push(s)
    );
    const output = lines.join("\n");
    expect(code).toBe(0);
    expect(output).toContain("DRY RUN");
    expect(output).toContain("Artifacts to delete: 1");
    expect(output).toContain("Bytes reclaimed: 1000");
    expect(output).toContain("old-1");
  });

  test("returns non-zero on missing file", async () => {
    const lines: string[] = [];
    const code = await runCli(
      ["--input", "/tmp/does-not-exist-xyz.json"],
      (s) => lines.push(s)
    );
    expect(code).not.toBe(0);
    expect(lines.join("\n")).toMatch(/error/i);
  });
});
