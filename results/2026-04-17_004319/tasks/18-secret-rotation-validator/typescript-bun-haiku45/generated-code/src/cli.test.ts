import { describe, it, expect } from "bun:test";
import { parseArgs, CLIConfig } from "./cli";

describe("CLI argument parsing", () => {
  it("should parse input file argument", () => {
    const args = ["node", "script.ts", "secrets.json"];
    const config = parseArgs(args);
    expect(config.inputFile).toBe("secrets.json");
  });

  it("should parse format argument", () => {
    const args = ["node", "script.ts", "secrets.json", "--format", "json"];
    const config = parseArgs(args);
    expect(config.format).toBe("json");
  });

  it("should default to markdown format", () => {
    const args = ["node", "script.ts", "secrets.json"];
    const config = parseArgs(args);
    expect(config.format).toBe("markdown");
  });

  it("should parse warning days argument", () => {
    const args = ["node", "script.ts", "secrets.json", "--warning-days", "21"];
    const config = parseArgs(args);
    expect(config.warningDays).toBe(21);
  });

  it("should default warning days to 14", () => {
    const args = ["node", "script.ts", "secrets.json"];
    const config = parseArgs(args);
    expect(config.warningDays).toBe(14);
  });

  it("should parse reference date argument", () => {
    const args = ["node", "script.ts", "secrets.json", "--reference-date", "2026-05-01"];
    const config = parseArgs(args);
    expect(config.referenceDate).toEqual(new Date("2026-05-01"));
  });

  it("should handle missing input file", () => {
    const args = ["node", "script.ts"];
    expect(() => parseArgs(args)).toThrow();
  });

  it("should validate format values", () => {
    const args = ["node", "script.ts", "secrets.json", "--format", "invalid"];
    expect(() => parseArgs(args)).toThrow();
  });
});
