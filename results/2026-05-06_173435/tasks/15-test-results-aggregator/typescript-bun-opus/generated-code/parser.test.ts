import { describe, test, expect } from "bun:test";
import { parseJUnitXML, parseJSON, parseFile } from "./parser";
import { readFileSync } from "fs";
import { join } from "path";

const fixturesDir = join(import.meta.dir, "fixtures");

describe("parseJUnitXML", () => {
  test("parses test results from JUnit XML", () => {
    const xml = readFileSync(join(fixturesDir, "junit-run1.xml"), "utf-8");
    const run = parseJUnitXML(xml, "junit-run1.xml");

    expect(run.source).toBe("junit-run1.xml");
    expect(run.results).toHaveLength(5);
  });

  test("correctly identifies passed, failed, and skipped tests", () => {
    const xml = readFileSync(join(fixturesDir, "junit-run1.xml"), "utf-8");
    const run = parseJUnitXML(xml, "junit-run1.xml");

    const passed = run.results.filter((r) => r.status === "passed");
    const failed = run.results.filter((r) => r.status === "failed");
    const skipped = run.results.filter((r) => r.status === "skipped");

    expect(passed).toHaveLength(3);
    expect(failed).toHaveLength(1);
    expect(skipped).toHaveLength(1);
  });

  test("extracts test names and suite names", () => {
    const xml = readFileSync(join(fixturesDir, "junit-run1.xml"), "utf-8");
    const run = parseJUnitXML(xml, "junit-run1.xml");

    const loginTest = run.results.find(
      (r) => r.name === "login succeeds with valid credentials"
    );
    expect(loginTest).toBeDefined();
    expect(loginTest!.suite).toBe("AuthTests");
    expect(loginTest!.status).toBe("passed");
  });

  test("extracts durations", () => {
    const xml = readFileSync(join(fixturesDir, "junit-run1.xml"), "utf-8");
    const run = parseJUnitXML(xml, "junit-run1.xml");

    const loginTest = run.results.find(
      (r) => r.name === "login succeeds with valid credentials"
    );
    expect(loginTest!.duration).toBe(2.1);
  });

  test("extracts failure messages", () => {
    const xml = readFileSync(join(fixturesDir, "junit-run1.xml"), "utf-8");
    const run = parseJUnitXML(xml, "junit-run1.xml");

    const failedTest = run.results.find(
      (r) => r.name === "session expires after timeout"
    );
    expect(failedTest!.status).toBe("failed");
    expect(failedTest!.error).toContain("Expected session to be null");
  });

  test("handles run2 XML where all auth tests pass", () => {
    const xml = readFileSync(join(fixturesDir, "junit-run2.xml"), "utf-8");
    const run = parseJUnitXML(xml, "junit-run2.xml");

    const failed = run.results.filter((r) => r.status === "failed");
    expect(failed).toHaveLength(0);

    const passed = run.results.filter((r) => r.status === "passed");
    expect(passed).toHaveLength(4);
  });
});

describe("parseJSON", () => {
  test("parses test results from JSON format", () => {
    const json = readFileSync(join(fixturesDir, "results-run1.json"), "utf-8");
    const run = parseJSON(json, "results-run1.json");

    expect(run.source).toBe("results-run1.json");
    expect(run.results).toHaveLength(5);
  });

  test("correctly identifies statuses in JSON format", () => {
    const json = readFileSync(join(fixturesDir, "results-run1.json"), "utf-8");
    const run = parseJSON(json, "results-run1.json");

    const passed = run.results.filter((r) => r.status === "passed");
    const failed = run.results.filter((r) => r.status === "failed");
    const skipped = run.results.filter((r) => r.status === "skipped");

    expect(passed).toHaveLength(3);
    expect(failed).toHaveLength(1);
    expect(skipped).toHaveLength(1);
  });

  test("extracts error messages from JSON", () => {
    const json = readFileSync(join(fixturesDir, "results-run1.json"), "utf-8");
    const run = parseJSON(json, "results-run1.json");

    const failedTest = run.results.find(
      (r) => r.name === "DELETE /users requires auth"
    );
    expect(failedTest!.status).toBe("failed");
    expect(failedTest!.error).toBe("Expected 401 but got 403");
  });
});

describe("parseFile", () => {
  test("auto-detects JUnit XML format", async () => {
    const run = await parseFile(join(fixturesDir, "junit-run1.xml"));
    expect(run.source).toBe("junit-run1.xml");
    expect(run.results).toHaveLength(5);
  });

  test("auto-detects JSON format", async () => {
    const run = await parseFile(join(fixturesDir, "results-run1.json"));
    expect(run.source).toBe("results-run1.json");
    expect(run.results).toHaveLength(5);
  });

  test("throws for unsupported file format", async () => {
    expect(parseFile(join(fixturesDir, "bad.txt"))).rejects.toThrow();
  });
});
