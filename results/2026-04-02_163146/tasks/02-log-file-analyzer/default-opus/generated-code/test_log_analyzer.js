#!/usr/bin/env node
/**
 * Tests for log_analyzer.js — written following red/green TDD methodology.
 *
 * Each describe block corresponds to a TDD cycle:
 *   1. RED:   Write the test first (it fails because the code doesn't exist).
 *   2. GREEN: Write the minimum implementation to make it pass.
 *   3. REFACTOR: Clean up without breaking tests.
 *
 * Uses Node.js built-in test runner (node:test) and assertions (node:assert).
 * Run with: node --test test_log_analyzer.js
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");
const fs = require("node:fs");
const os = require("node:os");

const {
  parseSyslogLine,
  parseJsonLine,
  parseLine,
  filterErrorsAndWarnings,
  buildFrequencyTable,
  parseLogFile,
  formatTable,
  analyzeLogFile,
} = require("./log_analyzer");

const FIXTURES = path.join(__dirname, "fixtures");

// ---------------------------------------------------------------------------
// Cycle 1: Parse syslog-style log lines
// ---------------------------------------------------------------------------
describe("parseSyslogLine", () => {
  it("parses an ERROR line", () => {
    const line =
      "2024-01-15 08:23:45 ERROR [auth] Failed login attempt for user admin";
    const result = parseSyslogLine(line);
    assert.deepStrictEqual(result, {
      timestamp: "2024-01-15 08:23:45",
      level: "ERROR",
      source: "auth",
      message: "Failed login attempt for user admin",
    });
  });

  it("parses a WARNING line", () => {
    const line = "2024-01-15 09:10:02 WARNING [disk] Disk usage above 85%";
    const result = parseSyslogLine(line);
    assert.equal(result.level, "WARNING");
    assert.equal(result.source, "disk");
  });

  it("parses an INFO line", () => {
    const line = "2024-01-15 10:00:00 INFO [app] Server started on port 8080";
    const result = parseSyslogLine(line);
    assert.equal(result.level, "INFO");
  });

  it("returns null for non-matching lines", () => {
    assert.equal(parseSyslogLine("random garbage"), null);
  });

  it("returns null for empty string", () => {
    assert.equal(parseSyslogLine(""), null);
  });

  it("handles leading/trailing whitespace", () => {
    const line = "  2024-01-15 08:23:45 ERROR [auth] Trimmed  ";
    const result = parseSyslogLine(line);
    assert.equal(result.message, "Trimmed");
  });
});

// ---------------------------------------------------------------------------
// Cycle 2: Parse JSON-structured log lines
// ---------------------------------------------------------------------------
describe("parseJsonLine", () => {
  it("parses a valid JSON error entry", () => {
    const line = JSON.stringify({
      timestamp: "2024-01-15T08:35:22Z",
      level: "ERROR",
      source: "database",
      message: "Connection timeout after 30s",
    });
    const result = parseJsonLine(line);
    assert.equal(result.level, "ERROR");
    assert.equal(result.source, "database");
    // ISO timestamp normalised to YYYY-MM-DD HH:MM:SS
    assert.equal(result.timestamp, "2024-01-15 08:35:22");
  });

  it("upper-cases the level field", () => {
    const line = JSON.stringify({
      timestamp: "2024-01-15T09:10:05Z",
      level: "warning",
      source: "memory",
      message: "Heap usage above 90%",
    });
    assert.equal(parseJsonLine(line).level, "WARNING");
  });

  it("returns null for invalid JSON", () => {
    assert.equal(parseJsonLine('{"incomplete'), null);
  });

  it("returns null when required fields are missing", () => {
    const line = JSON.stringify({
      timestamp: "2024-01-15T09:00:00Z",
      level: "ERROR",
      message: "missing source",
    });
    assert.equal(parseJsonLine(line), null);
  });

  it("returns null for non-JSON lines", () => {
    assert.equal(
      parseJsonLine("2024-01-15 08:23:45 ERROR [auth] Not JSON"),
      null
    );
  });

  it("returns null for empty string", () => {
    assert.equal(parseJsonLine(""), null);
  });
});

// ---------------------------------------------------------------------------
// Cycle 3: Unified line parser (tries JSON then syslog)
// ---------------------------------------------------------------------------
describe("parseLine", () => {
  it("parses syslog lines", () => {
    const line = "2024-01-15 08:23:45 ERROR [auth] Login failed";
    assert.equal(parseLine(line).source, "auth");
  });

  it("parses JSON lines", () => {
    const line = JSON.stringify({
      timestamp: "2024-01-15T10:00:00Z",
      level: "ERROR",
      source: "api",
      message: "Rate limit",
    });
    assert.equal(parseLine(line).source, "api");
  });

  it("returns null for garbage", () => {
    assert.equal(parseLine("not a log line"), null);
  });
});

// ---------------------------------------------------------------------------
// Cycle 4: Filter errors and warnings
// ---------------------------------------------------------------------------
describe("filterErrorsAndWarnings", () => {
  it("keeps only ERROR and WARNING entries", () => {
    const entries = [
      { level: "ERROR", timestamp: "t1", source: "a", message: "m1" },
      { level: "INFO", timestamp: "t2", source: "b", message: "m2" },
      { level: "WARNING", timestamp: "t3", source: "c", message: "m3" },
      { level: "DEBUG", timestamp: "t4", source: "d", message: "m4" },
    ];
    const result = filterErrorsAndWarnings(entries);
    assert.equal(result.length, 2);
    assert.equal(result[0].level, "ERROR");
    assert.equal(result[1].level, "WARNING");
  });

  it("returns empty array when no matches", () => {
    const entries = [
      { level: "INFO", timestamp: "t1", source: "a", message: "m1" },
    ];
    assert.deepStrictEqual(filterErrorsAndWarnings(entries), []);
  });

  it("returns empty array for empty input", () => {
    assert.deepStrictEqual(filterErrorsAndWarnings([]), []);
  });
});

// ---------------------------------------------------------------------------
// Cycle 5: Build frequency table with first/last timestamps
// ---------------------------------------------------------------------------
describe("buildFrequencyTable", () => {
  it("counts duplicate entries", () => {
    const entries = [
      {
        level: "ERROR",
        timestamp: "2024-01-15 08:23:45",
        source: "auth",
        message: "Login failed",
      },
      {
        level: "ERROR",
        timestamp: "2024-01-15 08:40:15",
        source: "auth",
        message: "Login failed",
      },
      {
        level: "ERROR",
        timestamp: "2024-01-15 10:15:00",
        source: "auth",
        message: "Login failed",
      },
    ];
    const freq = buildFrequencyTable(entries);
    assert.equal(freq.length, 1);
    assert.equal(freq[0].count, 3);
  });

  it("tracks first and last occurrence timestamps", () => {
    const entries = [
      {
        level: "ERROR",
        timestamp: "2024-01-15 08:23:45",
        source: "auth",
        message: "Login failed",
      },
      {
        level: "ERROR",
        timestamp: "2024-01-15 10:15:00",
        source: "auth",
        message: "Login failed",
      },
    ];
    const freq = buildFrequencyTable(entries);
    assert.equal(freq[0].first_seen, "2024-01-15 08:23:45");
    assert.equal(freq[0].last_seen, "2024-01-15 10:15:00");
  });

  it("groups by source and message", () => {
    const entries = [
      {
        level: "ERROR",
        timestamp: "t1",
        source: "auth",
        message: "Login failed",
      },
      {
        level: "WARNING",
        timestamp: "t2",
        source: "disk",
        message: "Low space",
      },
      {
        level: "ERROR",
        timestamp: "t3",
        source: "auth",
        message: "Login failed",
      },
    ];
    const freq = buildFrequencyTable(entries);
    assert.equal(freq.length, 2);
    // Highest count first
    assert.equal(freq[0].count, 2);
    assert.equal(freq[0].source, "auth");
  });

  it("sorts by count descending", () => {
    const entries = [
      { level: "ERROR", timestamp: "t1", source: "a", message: "m1" },
      { level: "ERROR", timestamp: "t2", source: "b", message: "m2" },
      { level: "ERROR", timestamp: "t3", source: "b", message: "m2" },
      { level: "ERROR", timestamp: "t4", source: "b", message: "m2" },
    ];
    const freq = buildFrequencyTable(entries);
    assert.equal(freq[0].count, 3);
    assert.equal(freq[1].count, 1);
  });

  it("returns empty array for empty input", () => {
    assert.deepStrictEqual(buildFrequencyTable([]), []);
  });
});

// ---------------------------------------------------------------------------
// Cycle 6: Parse a full log file from disk
// ---------------------------------------------------------------------------
describe("parseLogFile", () => {
  it("parses sample.log (mixed syslog + JSON)", () => {
    const entries = parseLogFile(path.join(FIXTURES, "sample.log"));
    assert.ok(entries.length > 0);
    const sources = new Set(entries.map((e) => e.source));
    assert.ok(sources.has("auth")); // syslog entry
    assert.ok(sources.has("database")); // JSON entry
  });

  it("parses json_only.log", () => {
    const entries = parseLogFile(path.join(FIXTURES, "json_only.log"));
    assert.equal(entries.length, 4);
    assert.ok(entries.every((e) => e.source === "cache"));
  });

  it("parses syslog_only.log", () => {
    const entries = parseLogFile(path.join(FIXTURES, "syslog_only.log"));
    assert.equal(entries.length, 5);
  });

  it("skips unparseable lines gracefully", () => {
    const entries = parseLogFile(path.join(FIXTURES, "malformed.log"));
    // 6 total lines: 2 garbage + 1 broken JSON = 3 skipped, 3 valid
    assert.equal(entries.length, 3);
  });

  it("returns empty array for empty file", () => {
    const entries = parseLogFile(path.join(FIXTURES, "empty.log"));
    assert.deepStrictEqual(entries, []);
  });

  it("throws for missing file with a clear message", () => {
    assert.throws(
      () => parseLogFile("/nonexistent/path/missing.log"),
      (err) => {
        assert.ok(err instanceof Error);
        assert.ok(err.message.includes("missing.log"));
        return true;
      }
    );
  });
});

// ---------------------------------------------------------------------------
// Cycle 7: Format human-readable table
// ---------------------------------------------------------------------------
describe("formatTable", () => {
  it("shows a message for empty input", () => {
    assert.equal(formatTable([]), "No error or warning entries found.");
  });

  it("includes column headers", () => {
    const freq = [
      {
        level: "ERROR",
        source: "auth",
        message: "fail",
        count: 1,
        first_seen: "2024-01-01 00:00:00",
        last_seen: "2024-01-01 00:00:00",
      },
    ];
    const table = formatTable(freq);
    assert.ok(table.includes("Level"));
    assert.ok(table.includes("Source"));
    assert.ok(table.includes("Message"));
    assert.ok(table.includes("Count"));
    assert.ok(table.includes("First Seen"));
    assert.ok(table.includes("Last Seen"));
  });

  it("includes data values", () => {
    const freq = [
      {
        level: "ERROR",
        source: "auth",
        message: "Login failed",
        count: 5,
        first_seen: "2024-01-01 08:00:00",
        last_seen: "2024-01-01 10:00:00",
      },
    ];
    const table = formatTable(freq);
    assert.ok(table.includes("auth"));
    assert.ok(table.includes("Login failed"));
    assert.ok(table.includes("5"));
  });

  it("has border rows starting with +", () => {
    const freq = [
      {
        level: "ERROR",
        source: "x",
        message: "y",
        count: 1,
        first_seen: "ts",
        last_seen: "ts",
      },
    ];
    const lines = formatTable(freq).split("\n");
    assert.ok(lines[0].startsWith("+"));
    assert.ok(lines[lines.length - 1].startsWith("+"));
  });
});

// ---------------------------------------------------------------------------
// Cycle 8: Full analysis pipeline with JSON output
// ---------------------------------------------------------------------------
describe("analyzeLogFile", () => {
  it("analyses sample.log correctly", () => {
    const result = analyzeLogFile(path.join(FIXTURES, "sample.log"));
    assert.equal(result.total_lines_parsed, 15);
    assert.ok(result.errors_and_warnings > 0);
    assert.ok(result.unique_error_types > 0);
    assert.ok(Array.isArray(result.frequency_table));
  });

  it("top error in sample.log is auth failed login (count=3)", () => {
    const result = analyzeLogFile(path.join(FIXTURES, "sample.log"));
    const top = result.frequency_table[0];
    assert.equal(top.source, "auth");
    assert.equal(top.count, 3);
  });

  it("writes valid JSON output file", () => {
    const tmpPath = path.join(
      os.tmpdir(),
      `log_test_${Date.now()}.json`
    );
    try {
      analyzeLogFile(path.join(FIXTURES, "sample.log"), tmpPath);
      const data = JSON.parse(fs.readFileSync(tmpPath, "utf-8"));
      assert.ok("frequency_table" in data);
      assert.ok("total_lines_parsed" in data);
      assert.ok(Array.isArray(data.frequency_table));
    } finally {
      if (fs.existsSync(tmpPath)) fs.unlinkSync(tmpPath);
    }
  });

  it("handles empty log file", () => {
    const result = analyzeLogFile(path.join(FIXTURES, "empty.log"));
    assert.equal(result.total_lines_parsed, 0);
    assert.equal(result.errors_and_warnings, 0);
    assert.deepStrictEqual(result.frequency_table, []);
  });

  it("handles malformed log gracefully", () => {
    const result = analyzeLogFile(path.join(FIXTURES, "malformed.log"));
    assert.equal(result.total_lines_parsed, 3);
    assert.equal(result.errors_and_warnings, 3);
  });

  it("throws for missing file", () => {
    assert.throws(() => analyzeLogFile("/no/such/file.log"));
  });
});

// ---------------------------------------------------------------------------
// Cycle 9: Edge cases and robustness
// ---------------------------------------------------------------------------
describe("edge cases", () => {
  it("JSON with extra fields still parses", () => {
    const line = JSON.stringify({
      timestamp: "2024-01-15T08:00:00Z",
      level: "ERROR",
      source: "x",
      message: "y",
      extra: 42,
    });
    const result = parseJsonLine(line);
    assert.ok(result !== null);
    assert.equal(result.level, "ERROR");
  });

  it("CRITICAL level parses but is filtered out", () => {
    const line = "2024-01-15 08:00:00 CRITICAL [core] System meltdown";
    const entry = parseSyslogLine(line);
    assert.ok(entry !== null);
    assert.equal(entry.level, "CRITICAL");
    // CRITICAL is not ERROR or WARNING, so should be filtered out
    const filtered = filterErrorsAndWarnings([entry]);
    assert.equal(filtered.length, 0);
  });

  it("single entry frequency table has matching first/last seen", () => {
    const entries = [
      {
        level: "ERROR",
        timestamp: "2024-01-15 08:00:00",
        source: "s",
        message: "m",
      },
    ];
    const freq = buildFrequencyTable(entries);
    assert.equal(freq.length, 1);
    assert.equal(freq[0].first_seen, freq[0].last_seen);
  });

  it("table with multiple rows has correct line count", () => {
    const freq = [
      {
        level: "ERROR",
        source: "a",
        message: "m1",
        count: 5,
        first_seen: "t1",
        last_seen: "t2",
      },
      {
        level: "WARNING",
        source: "b",
        message: "m2",
        count: 2,
        first_seen: "t3",
        last_seen: "t4",
      },
      {
        level: "ERROR",
        source: "c",
        message: "m3",
        count: 1,
        first_seen: "t5",
        last_seen: "t5",
      },
    ];
    const lines = formatTable(freq).split("\n");
    // 3 separator + 1 header + 3 data = 7
    assert.equal(lines.length, 7);
  });
});
