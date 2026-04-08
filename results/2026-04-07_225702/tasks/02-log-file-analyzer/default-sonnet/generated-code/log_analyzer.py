# Log File Analyzer
#
# Parses log files containing two formats:
#   1. Syslog-style: "Jan 15 10:23:45 hostname process[pid]: LEVEL: type: message"
#   2. JSON-structured: {"timestamp": "...", "level": "...", "type": "...", "message": "..."}
#
# Provides:
#   - parse_syslog_line / parse_json_line — single-line parsers
#   - parse_log_file — reads a file, delegates each line to the appropriate parser
#   - filter_errors_and_warnings — keeps only ERROR/WARNING entries
#   - build_frequency_table — counts occurrences per error type with timestamps
#   - format_table — human-readable ASCII table
#   - write_json_report — writes frequency table as JSON
#   - main — orchestrates everything for CLI use

import json
import re
import sys
from collections import defaultdict
from typing import Optional


# ---------------------------------------------------------------------------
# Syslog parser
#
# Expected format:
#   Mon DD HH:MM:SS hostname process[pid]: LEVEL: ErrorType: rest of message
#   OR
#   Mon DD HH:MM:SS hostname process[pid]: LEVEL: rest of message  (no explicit type)
#
# Examples:
#   Jan 15 10:23:45 myhost myapp[1234]: ERROR: DBConnectionError: could not connect
#   Feb  3 08:01:12 myhost nginx[5678]: WARNING: slow response time 5.2s
# ---------------------------------------------------------------------------

# Pattern breakdown:
#   ^(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})  — timestamp  "Jan 15 10:23:45"
#   \s+\S+                                     — hostname
#   \s+\S+:                                    — process[pid]:
#   \s+(ERROR|WARNING|INFO|DEBUG|CRITICAL)     — log level
#   :\s+(.*)$                                  — rest of message
_SYSLOG_RE = re.compile(
    r"^(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})"  # timestamp
    r"\s+\S+"                                    # hostname
    r"\s+\S+:"                                   # process[pid]:
    r"\s+(ERROR|WARNING|INFO|DEBUG|CRITICAL)"    # level
    r":\s+(.*)$",                                # message
    re.IGNORECASE,
)

# Match "TypeName: rest" at the start of the message portion
_TYPE_IN_MESSAGE_RE = re.compile(r"^([A-Za-z][A-Za-z0-9_]*):\s*(.*)$")


def parse_syslog_line(line: str) -> Optional[dict]:
    """Parse a single syslog-style log line.

    Returns a dict with keys {timestamp, level, type, message} or None
    if the line does not match the expected format.
    """
    if not line or not line.strip():
        return None

    m = _SYSLOG_RE.match(line.strip())
    if not m:
        return None

    timestamp, level, rest = m.group(1), m.group(2).upper(), m.group(3)

    # Try to split "ErrorType: actual message" from the rest
    type_match = _TYPE_IN_MESSAGE_RE.match(rest)
    if type_match:
        error_type = type_match.group(1)
        message = type_match.group(2)
    else:
        # No explicit type token — use the level as the type
        error_type = level
        message = rest

    return {
        "timestamp": timestamp,
        "level": level,
        "type": error_type,
        "message": message,
    }


# ---------------------------------------------------------------------------
# JSON parser
#
# Expected format (any valid JSON object with at minimum a "level" key):
#   {"timestamp": "...", "level": "ERROR", "type": "...", "message": "..."}
# ---------------------------------------------------------------------------

def parse_json_line(line: str) -> Optional[dict]:
    """Parse a single JSON-structured log line.

    Returns a dict with keys {timestamp, level, type, message} or None
    if the line is not valid JSON or is missing the required "level" key.
    """
    if not line or not line.strip():
        return None

    try:
        obj = json.loads(line.strip())
    except json.JSONDecodeError:
        return None

    if not isinstance(obj, dict) or "level" not in obj:
        return None

    return {
        "timestamp": obj.get("timestamp", ""),
        "level": obj["level"].upper(),
        "type": obj.get("type", obj["level"].upper()),
        "message": obj.get("message", ""),
    }


# ---------------------------------------------------------------------------
# File parser — tries each format, skips lines that match neither
# ---------------------------------------------------------------------------

def parse_log_file(path: str) -> list:
    """Read a log file and parse every line.

    Tries the JSON parser first (cheaper to detect), then syslog.
    Silently skips lines that match neither format.

    Raises FileNotFoundError if the file does not exist.
    """
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            lines = fh.readlines()
    except FileNotFoundError:
        raise FileNotFoundError(f"Log file not found: {path}")

    entries = []
    for raw in lines:
        line = raw.rstrip("\n")
        entry = parse_json_line(line) or parse_syslog_line(line)
        if entry is not None:
            entries.append(entry)
    return entries


# ---------------------------------------------------------------------------
# Filter
# ---------------------------------------------------------------------------

def filter_errors_and_warnings(entries: list) -> list:
    """Return only entries whose level is ERROR or WARNING."""
    return [e for e in entries if e.get("level", "").upper() in ("ERROR", "WARNING")]


# ---------------------------------------------------------------------------
# Frequency table
#
# Each row: {type, level, count, first_seen, last_seen}
# Sorted by count descending.
# ---------------------------------------------------------------------------

def build_frequency_table(entries: list) -> list:
    """Build a frequency table grouped by error type.

    For each unique (type, level) combination, records:
      - count        : number of occurrences
      - first_seen   : earliest timestamp string
      - last_seen    : latest timestamp string

    The table is sorted by count descending.
    """
    if not entries:
        return []

    # Group by type; keep the level from the first occurrence
    groups: dict = defaultdict(lambda: {"count": 0, "level": "", "timestamps": []})

    for entry in entries:
        key = entry["type"]
        groups[key]["count"] += 1
        if not groups[key]["level"]:
            groups[key]["level"] = entry["level"]
        ts = entry.get("timestamp", "")
        if ts:
            groups[key]["timestamps"].append(ts)

    table = []
    for type_name, data in groups.items():
        timestamps = sorted(data["timestamps"]) if data["timestamps"] else [""]
        table.append({
            "type": type_name,
            "level": data["level"],
            "count": data["count"],
            "first_seen": timestamps[0],
            "last_seen": timestamps[-1],
        })

    table.sort(key=lambda r: r["count"], reverse=True)
    return table


# ---------------------------------------------------------------------------
# Human-readable table formatter
# ---------------------------------------------------------------------------

def format_table(table: list) -> str:
    """Format the frequency table as a human-readable ASCII table.

    Columns: Type | Level | Count | First Seen | Last Seen
    """
    headers = ["Type", "Level", "Count", "First Seen", "Last Seen"]

    if not table:
        # Return a minimal header with a "no entries" notice
        header_line = " | ".join(headers)
        sep = "-" * len(header_line)
        return f"{header_line}\n{sep}\n(no entries)\n"

    # Compute column widths
    rows = [
        [r["type"], r["level"], str(r["count"]), r["first_seen"], r["last_seen"]]
        for r in table
    ]
    col_widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            col_widths[i] = max(col_widths[i], len(cell))

    def fmt_row(cells):
        return " | ".join(c.ljust(col_widths[i]) for i, c in enumerate(cells))

    sep_line = "-+-".join("-" * w for w in col_widths)
    lines = [fmt_row(headers), sep_line]
    for row in rows:
        lines.append(fmt_row(row))

    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# JSON report writer
# ---------------------------------------------------------------------------

def write_json_report(table: list, path: str) -> None:
    """Write the frequency table as a JSON file.

    Raises an appropriate exception if the file cannot be written.
    """
    try:
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(table, fh, indent=2)
    except OSError as exc:
        raise OSError(f"Cannot write JSON report to {path}: {exc}") from exc


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main(argv=None):
    """CLI: log_analyzer.py <logfile> [--json-out <path>]

    Parses the log file, prints a human-readable table, and optionally
    writes a JSON report.
    """
    if argv is None:
        argv = sys.argv[1:]

    if not argv:
        print("Usage: log_analyzer.py <logfile> [--json-out <path>]", file=sys.stderr)
        sys.exit(1)

    log_path = argv[0]
    json_out = None
    if "--json-out" in argv:
        idx = argv.index("--json-out")
        if idx + 1 < len(argv):
            json_out = argv[idx + 1]
        else:
            print("Error: --json-out requires a path argument.", file=sys.stderr)
            sys.exit(1)

    try:
        entries = parse_log_file(log_path)
    except FileNotFoundError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

    filtered = filter_errors_and_warnings(entries)
    table = build_frequency_table(filtered)

    print(f"Parsed {len(entries)} log entries, {len(filtered)} errors/warnings.\n")
    print(format_table(table))

    if json_out:
        try:
            write_json_report(table, json_out)
            print(f"JSON report written to: {json_out}")
        except OSError as exc:
            print(f"Error writing JSON report: {exc}", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    main()
