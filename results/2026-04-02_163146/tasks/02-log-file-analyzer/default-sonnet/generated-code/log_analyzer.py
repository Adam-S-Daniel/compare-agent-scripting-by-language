"""
log_analyzer.py
===============
Parse mixed-format log files (syslog-style + JSON lines), extract
error/warning entries, build a frequency table, and output results as
a human-readable table and a JSON report file.

Development followed red/green TDD:
  1. Write a failing test in test_log_analyzer.py.
  2. Write the minimum code here to make it pass.
  3. Refactor.
  4. Repeat for each piece of functionality.
"""

import json
import re
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Syslog date-time prefix: "Jan 15 10:23:45"
_SYSLOG_TS_RE = re.compile(
    r"^(?P<month>[A-Za-z]{3})\s+(?P<day>\d{1,2})\s+(?P<time>\d{2}:\d{2}:\d{2})"
    r"\s+\S+"                    # hostname (ignored)
    r"\s+(?P<service>[^\[:\s]+)" # service name (stops at '[', ':', or space)
    r"(?:\[\d+\])?"              # optional [pid]
    r":\s+"                      # colon separator
    r"(?P<level>ERROR|WARNING|WARN|INFO|DEBUG|NOTICE|CRITICAL)"
    r"\s+(?P<message>.+)$"
)

_MONTH_MAP = {
    "Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6,
    "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12,
}

# Maximum length for a message-derived error key (no explicit error_type)
_MAX_KEY_LEN = 60


# ---------------------------------------------------------------------------
# RED/GREEN CYCLE 1 — Syslog line parser
# ---------------------------------------------------------------------------

def parse_syslog_line(line: str) -> Optional[dict]:
    """Parse a syslog-style log line into a normalised dict.

    Returns a dict with keys:
        timestamp (datetime), level (str), service (str),
        message (str), error_type (None), raw (str)
    Returns None if the line does not match the syslog pattern.
    """
    if not line.strip():
        return None

    m = _SYSLOG_TS_RE.match(line.strip())
    if not m:
        return None

    month = _MONTH_MAP.get(m.group("month").capitalize())
    if month is None:
        return None

    day = int(m.group("day"))
    hour, minute, second = map(int, m.group("time").split(":"))
    year = datetime.now().year  # syslog omits the year; default to current

    try:
        ts = datetime(year, month, day, hour, minute, second)
    except ValueError:
        return None

    level = m.group("level")
    # Normalise WARN → WARNING
    if level == "WARN":
        level = "WARNING"

    return {
        "timestamp": ts,
        "level": level,
        "service": m.group("service"),
        "message": m.group("message").strip(),
        "error_type": None,
        "raw": line,
    }


# ---------------------------------------------------------------------------
# RED/GREEN CYCLE 2 — JSON line parser
# ---------------------------------------------------------------------------

def parse_json_line(line: str) -> Optional[dict]:
    """Parse a JSON-structured log line into a normalised dict.

    Expected JSON keys: timestamp, level, service, message, error_type.
    Returns None if the line is not valid JSON or lacks required keys.
    """
    stripped = line.strip()
    if not stripped.startswith("{"):
        return None  # Fast-path: not a JSON object line

    try:
        obj = json.loads(stripped)
    except json.JSONDecodeError:
        return None

    # Require at minimum a level and a message
    if "level" not in obj or "message" not in obj:
        return None

    # Parse timestamp — accept ISO 8601 strings
    raw_ts = obj.get("timestamp", "")
    try:
        # Handle trailing 'Z' by replacing with +00:00
        ts = datetime.fromisoformat(raw_ts.replace("Z", "+00:00"))
        # Strip timezone info so all timestamps are naive (consistent with syslog)
        ts = ts.replace(tzinfo=None)
    except (ValueError, AttributeError):
        ts = datetime.now()

    level = obj.get("level", "").upper()
    if level == "WARN":
        level = "WARNING"

    return {
        "timestamp": ts,
        "level": level,
        "service": obj.get("service", "unknown"),
        "message": obj.get("message", ""),
        "error_type": obj.get("error_type"),  # May be None / null
        "raw": line,
    }


# ---------------------------------------------------------------------------
# RED/GREEN CYCLE 3 — Mixed-format log file parser
# ---------------------------------------------------------------------------

def parse_log_file(path: str) -> list:
    """Read a log file and parse every line using JSON-first, syslog-second.

    Raises FileNotFoundError if the file does not exist.
    Lines that match neither format are silently skipped.
    Returns a list of normalised entry dicts.
    """
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Log file not found: {path}")

    entries = []
    with p.open(encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line.strip():
                continue

            # Try JSON first (cheaper check: must start with '{')
            entry = parse_json_line(line)
            if entry is None:
                entry = parse_syslog_line(line)
            if entry is not None:
                entries.append(entry)

    return entries


# ---------------------------------------------------------------------------
# RED/GREEN CYCLE 4 — Error/warning extraction
# ---------------------------------------------------------------------------

def extract_errors_warnings(entries: list) -> list:
    """Return only entries whose level is ERROR or WARNING."""
    return [e for e in entries if e.get("level") in ("ERROR", "WARNING")]


# ---------------------------------------------------------------------------
# RED/GREEN CYCLE 5 — Frequency table builder
# ---------------------------------------------------------------------------

def _error_key(entry: dict) -> str:
    """Derive a grouping key for a log entry.

    Prefer the explicit error_type field; fall back to a truncated message.
    """
    et = entry.get("error_type")
    if et:
        return str(et)
    msg = entry.get("message", "unknown")
    return msg[:_MAX_KEY_LEN]


def build_frequency_table(entries: list) -> list:
    """Group entries by (level, error_key) and compute statistics.

    Returns a list of dicts:
        error_key (str), level (str), count (int),
        first_seen (datetime), last_seen (datetime)
    Sorted by count descending, then error_key ascending.
    """
    # Accumulator: key → (count, first_seen, last_seen)
    groups: dict = defaultdict(lambda: {"count": 0, "first_seen": None, "last_seen": None})

    for entry in entries:
        key = (_error_key(entry), entry.get("level", "UNKNOWN"))
        g = groups[key]
        g["count"] += 1
        ts = entry.get("timestamp")
        if ts is not None:
            if g["first_seen"] is None or ts < g["first_seen"]:
                g["first_seen"] = ts
            if g["last_seen"] is None or ts > g["last_seen"]:
                g["last_seen"] = ts

    rows = []
    for (error_key, level), stats in groups.items():
        rows.append({
            "error_key": error_key,
            "level": level,
            "count": stats["count"],
            "first_seen": stats["first_seen"],
            "last_seen": stats["last_seen"],
        })

    # Primary sort: count descending; secondary: error_key ascending (stable)
    rows.sort(key=lambda r: (-r["count"], r["error_key"]))
    return rows


# ---------------------------------------------------------------------------
# RED/GREEN CYCLE 6 — Human-readable table formatter
# ---------------------------------------------------------------------------

def format_table(rows: list) -> str:
    """Format frequency-table rows as a plain-text table string.

    Columns: Error Key | Level | Count | First Seen | Last Seen
    Returns a human-readable string.  If rows is empty, returns a
    'no entries' message.
    """
    if not rows:
        return "No entries found."

    # Column headers
    headers = ["Error Key", "Level", "Count", "First Seen", "Last Seen"]

    # Format timestamps
    def fmt_ts(ts):
        if ts is None:
            return "—"
        return ts.strftime("%Y-%m-%d %H:%M:%S")

    # Build cell matrix
    data = []
    for r in rows:
        data.append([
            r["error_key"],
            r["level"],
            str(r["count"]),
            fmt_ts(r["first_seen"]),
            fmt_ts(r["last_seen"]),
        ])

    # Calculate column widths
    col_widths = [len(h) for h in headers]
    for row in data:
        for i, cell in enumerate(row):
            col_widths[i] = max(col_widths[i], len(cell))

    def make_row(cells):
        return " | ".join(c.ljust(col_widths[i]) for i, c in enumerate(cells))

    separator = "-+-".join("-" * w for w in col_widths)

    lines = [
        make_row(headers),
        separator,
    ]
    for row in data:
        lines.append(make_row(row))

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# RED/GREEN CYCLE 7 — JSON report writer
# ---------------------------------------------------------------------------

def write_json_report(rows: list, path: str) -> None:
    """Write frequency-table rows to a JSON file.

    The output JSON has the shape:
        {
            "generated_at": "<ISO timestamp>",
            "total_entries": <int>,
            "entries": [ { ...row with ISO timestamp strings... }, ... ]
        }

    Raises OSError / FileNotFoundError if the path is not writable.
    """
    def fmt_ts(ts):
        if ts is None:
            return None
        return ts.isoformat()

    serialisable = []
    for r in rows:
        serialisable.append({
            "error_key": r["error_key"],
            "level": r["level"],
            "count": r["count"],
            "first_seen": fmt_ts(r["first_seen"]),
            "last_seen": fmt_ts(r["last_seen"]),
        })

    report = {
        "generated_at": datetime.now().isoformat(),
        "total_entries": len(rows),
        "entries": serialisable,
    }

    # Let open() raise naturally for bad paths
    out = Path(path)
    with out.open("w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main(argv=None):
    """CLI: python log_analyzer.py <logfile> [output.json]

    Reads the log file, extracts errors/warnings, prints a frequency table,
    and writes a JSON report.
    """
    args = argv if argv is not None else sys.argv[1:]
    if not args:
        print("Usage: log_analyzer.py <logfile> [output_report.json]", file=sys.stderr)
        sys.exit(1)

    log_path = args[0]
    json_path = args[1] if len(args) > 1 else "log_report.json"

    try:
        all_entries = parse_log_file(log_path)
    except FileNotFoundError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

    filtered = extract_errors_warnings(all_entries)
    table = build_frequency_table(filtered)

    print(f"\nLog Analysis — {log_path}")
    print(f"Total lines parsed : {len(all_entries)}")
    print(f"Errors + warnings  : {len(filtered)}")
    print()
    print(format_table(table))
    print()

    write_json_report(table, json_path)
    print(f"JSON report written to: {json_path}")


if __name__ == "__main__":
    main()
