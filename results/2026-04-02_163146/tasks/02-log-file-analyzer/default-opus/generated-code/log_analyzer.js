#!/usr/bin/env node
/**
 * Log file analyzer — parses mixed syslog and JSON log formats, extracts
 * errors and warnings, and produces frequency tables with occurrence times.
 *
 * Developed using red/green TDD (see test_log_analyzer.js for the tests
 * that drove each function into existence).
 *
 * Usage:
 *   node log_analyzer.js <logfile> [output.json]
 */

const fs = require("node:fs");
const path = require("node:path");

// ---------------------------------------------------------------------------
// Cycle 1 (GREEN): Parse syslog-style lines
// Pattern: "2024-01-15 08:23:45 ERROR [auth] Some message text"
// ---------------------------------------------------------------------------
const SYSLOG_RE =
  /^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+(ERROR|WARNING|INFO|DEBUG|CRITICAL)\s+\[(\w+)\]\s+(.+)$/;

/**
 * Parse a syslog-format log line into a structured object.
 * Returns null if the line doesn't match the expected pattern.
 */
function parseSyslogLine(line) {
  const trimmed = line.trim();
  const m = trimmed.match(SYSLOG_RE);
  if (!m) return null;
  return {
    timestamp: m[1],
    level: m[2],
    source: m[3],
    message: m[4],
  };
}

// ---------------------------------------------------------------------------
// Cycle 2 (GREEN): Parse JSON-structured lines
// ---------------------------------------------------------------------------

/**
 * Normalise various timestamp formats to "YYYY-MM-DD HH:MM:SS".
 */
function normaliseTimestamp(ts) {
  // Handle ISO-8601 with Z or timezone offset
  // e.g. "2024-01-15T08:35:22Z" → "2024-01-15 08:35:22"
  const isoMatch = ts.match(
    /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/
  );
  if (isoMatch) {
    return `${isoMatch[1]}-${isoMatch[2]}-${isoMatch[3]} ${isoMatch[4]}:${isoMatch[5]}:${isoMatch[6]}`;
  }
  return ts;
}

/**
 * Parse a JSON-structured log line into a normalised object.
 * Returns null if the line is not valid JSON or lacks required fields.
 */
function parseJsonLine(line) {
  const trimmed = line.trim();
  if (!trimmed.startsWith("{")) return null;

  let data;
  try {
    data = JSON.parse(trimmed);
  } catch {
    return null;
  }

  // Require the four mandatory fields
  for (const key of ["timestamp", "level", "source", "message"]) {
    if (!(key in data)) return null;
  }

  return {
    timestamp: normaliseTimestamp(data.timestamp),
    level: data.level.toUpperCase(),
    source: data.source,
    message: data.message,
  };
}

// ---------------------------------------------------------------------------
// Cycle 3 (GREEN): Unified line parser — tries JSON first, then syslog
// ---------------------------------------------------------------------------

/**
 * Try both parsers; return the first successful result or null.
 */
function parseLine(line) {
  return parseJsonLine(line) || parseSyslogLine(line);
}

// ---------------------------------------------------------------------------
// Cycle 4 (GREEN): Filter only ERROR and WARNING entries
// ---------------------------------------------------------------------------

/**
 * Keep only entries whose level is ERROR or WARNING.
 */
function filterErrorsAndWarnings(entries) {
  return entries.filter(
    (e) => e.level === "ERROR" || e.level === "WARNING"
  );
}

// ---------------------------------------------------------------------------
// Cycle 5 (GREEN): Build frequency table with first/last timestamps
// ---------------------------------------------------------------------------

/**
 * Aggregate entries by (source, message) and track count + timestamps.
 * Returns an array sorted by count descending, then first_seen ascending.
 */
function buildFrequencyTable(entries) {
  const stats = new Map();

  for (const entry of entries) {
    const key = `${entry.source}\0${entry.message}`;

    if (!stats.has(key)) {
      stats.set(key, {
        source: entry.source,
        message: entry.message,
        level: entry.level,
        count: 0,
        first_seen: entry.timestamp,
        last_seen: entry.timestamp,
      });
    }

    const record = stats.get(key);
    record.count += 1;
    if (entry.timestamp < record.first_seen)
      record.first_seen = entry.timestamp;
    if (entry.timestamp > record.last_seen)
      record.last_seen = entry.timestamp;
  }

  return Array.from(stats.values()).sort((a, b) => {
    if (b.count !== a.count) return b.count - a.count;
    return a.first_seen < b.first_seen ? -1 : 1;
  });
}

// ---------------------------------------------------------------------------
// Cycle 6 (GREEN): Parse a full log file from disk
// ---------------------------------------------------------------------------

/**
 * Read a log file line-by-line, parse each line, skip unparseable ones.
 * Throws a clear error if the file doesn't exist.
 */
function parseLogFile(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Log file not found: ${filePath}`);
  }

  const content = fs.readFileSync(filePath, "utf-8");
  const lines = content.split("\n");
  const entries = [];

  for (const line of lines) {
    if (line.trim() === "") continue;
    const entry = parseLine(line);
    if (entry !== null) {
      entries.push(entry);
    }
  }

  return entries;
}

// ---------------------------------------------------------------------------
// Cycle 7 (GREEN): Render a human-readable table
// ---------------------------------------------------------------------------

/**
 * Format the frequency table as an aligned, bordered ASCII table.
 */
function formatTable(freqTable) {
  if (freqTable.length === 0) {
    return "No error or warning entries found.";
  }

  const headers = ["Level", "Source", "Message", "Count", "First Seen", "Last Seen"];

  // Build rows as string arrays
  const rows = freqTable.map((row) => [
    row.level,
    row.source,
    row.message,
    String(row.count),
    row.first_seen,
    row.last_seen,
  ]);

  // Compute column widths
  const widths = headers.map((h, i) =>
    Math.max(h.length, ...rows.map((r) => r[i].length))
  );

  const sep =
    "+-" + widths.map((w) => "-".repeat(w)).join("-+-") + "-+";
  const fmtRow = (cells) =>
    "| " +
    cells.map((c, i) => c.padEnd(widths[i])).join(" | ") +
    " |";

  const lines = [sep, fmtRow(headers), sep];
  for (const row of rows) {
    lines.push(fmtRow(row));
  }
  lines.push(sep);

  return lines.join("\n");
}

// ---------------------------------------------------------------------------
// Cycle 8 (GREEN): Full analysis pipeline
// ---------------------------------------------------------------------------

/**
 * Run the complete analysis: parse → filter → frequency table → output.
 * Optionally writes JSON results to jsonOutputPath.
 */
function analyzeLogFile(filePath, jsonOutputPath) {
  const entries = parseLogFile(filePath);
  const filtered = filterErrorsAndWarnings(entries);
  const freq = buildFrequencyTable(filtered);

  const result = {
    file: filePath,
    total_lines_parsed: entries.length,
    errors_and_warnings: filtered.length,
    unique_error_types: freq.length,
    frequency_table: freq,
  };

  if (jsonOutputPath) {
    fs.writeFileSync(jsonOutputPath, JSON.stringify(result, null, 2), "utf-8");
  }

  return result;
}

// ---------------------------------------------------------------------------
// CLI entry point
// ---------------------------------------------------------------------------

function main() {
  const args = process.argv.slice(2);

  if (args.length < 1) {
    console.error("Usage: node log_analyzer.js <logfile> [output.json]");
    process.exit(1);
  }

  const logPath = args[0];
  const jsonPath = args[1] || null;

  let result;
  try {
    result = analyzeLogFile(logPath, jsonPath);
  } catch (err) {
    console.error(`Error: ${err.message}`);
    process.exit(1);
  }

  // Print human-readable output
  console.log(`\nLog Analysis: ${logPath}`);
  console.log(`Total entries parsed: ${result.total_lines_parsed}`);
  console.log(`Errors/Warnings found: ${result.errors_and_warnings}`);
  console.log(`Unique error types: ${result.unique_error_types}`);
  console.log();
  console.log(formatTable(result.frequency_table));

  if (jsonPath) {
    console.log(`\nJSON output written to: ${jsonPath}`);
  }
}

// Export for testing
module.exports = {
  parseSyslogLine,
  parseJsonLine,
  parseLine,
  filterErrorsAndWarnings,
  buildFrequencyTable,
  parseLogFile,
  formatTable,
  analyzeLogFile,
};

// Run CLI if invoked directly
if (require.main === module) {
  main();
}
