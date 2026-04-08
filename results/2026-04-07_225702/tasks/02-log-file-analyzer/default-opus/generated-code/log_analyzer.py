"""
Log File Analyzer
─────────────────
Parses mixed-format log files (syslog + JSON), extracts errors/warnings,
and produces a frequency table with first/last occurrence timestamps.

Outputs both a human-readable table (stdout) and a JSON report file.
"""

import re
import json
import sys
from collections import defaultdict
from pathlib import Path


# Syslog pattern: "Mon DD HH:MM:SS hostname process[pid]: LEVEL: message"
SYSLOG_RE = re.compile(
    r'^(?P<timestamp>\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+'  # timestamp
    r'\S+\s+'                                                      # hostname
    r'\S+:\s+'                                                     # process[pid]:
    r'(?P<level>ERROR|WARNING|INFO|DEBUG|CRITICAL):\s+'            # level
    r'(?P<message>.+)$'                                            # message
)


def parse_syslog_line(line):
    """Parse a syslog-style log line. Returns dict with level/message/timestamp, or None."""
    m = SYSLOG_RE.match(line.strip())
    if not m:
        return None
    return {
        "timestamp": m.group("timestamp"),
        "level": m.group("level"),
        "message": m.group("message"),
    }


def parse_json_line(line):
    """Parse a JSON-structured log line. Returns dict with level/message/timestamp, or None."""
    try:
        data = json.loads(line.strip())
    except (json.JSONDecodeError, ValueError):
        return None
    # Require the three essential fields
    if not all(k in data for k in ("level", "message", "timestamp")):
        return None
    return {
        "timestamp": data["timestamp"],
        "level": data["level"],
        "message": data["message"],
    }


def parse_line(line):
    """Try syslog first, then JSON. Returns parsed dict or None for unparseable lines."""
    return parse_syslog_line(line) or parse_json_line(line)


# Only these levels are extracted for analysis
_ALERT_LEVELS = {"ERROR", "WARNING", "CRITICAL"}


def parse_log_file(path):
    """Read a log file and return a list of parsed error/warning entries.

    Raises FileNotFoundError for missing files.
    """
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"Log file not found: {path}")

    entries = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            parsed = parse_line(line)
            if parsed and parsed["level"] in _ALERT_LEVELS:
                entries.append(parsed)
    return entries


def build_frequency_table(entries):
    """Build a frequency table keyed by error message.

    Each entry in the returned dict has: count, level, first_seen, last_seen.
    Entries are processed in order, so first_seen/last_seen reflect log order.
    """
    table = {}
    for entry in entries:
        msg = entry["message"]
        if msg not in table:
            table[msg] = {
                "level": entry["level"],
                "count": 0,
                "first_seen": entry["timestamp"],
                "last_seen": entry["timestamp"],
            }
        table[msg]["count"] += 1
        table[msg]["last_seen"] = entry["timestamp"]
    return table


def format_table(table):
    """Render the frequency table as a human-readable text table, sorted by count descending."""
    if not table:
        return "No errors or warnings found."

    # Sort by count descending
    sorted_items = sorted(table.items(), key=lambda kv: kv[1]["count"], reverse=True)

    # Calculate column widths dynamically
    headers = ("Message", "Level", "Count", "First Seen", "Last Seen")
    rows = [
        (msg, info["level"], str(info["count"]), info["first_seen"], info["last_seen"])
        for msg, info in sorted_items
    ]
    widths = [
        max(len(h), max(len(r[i]) for r in rows))
        for i, h in enumerate(headers)
    ]

    sep = "+-" + "-+-".join("-" * w for w in widths) + "-+"
    fmt = "| " + " | ".join(f"{{:<{w}}}" for w in widths) + " |"

    lines = [sep, fmt.format(*headers), sep]
    for row in rows:
        lines.append(fmt.format(*row))
    lines.append(sep)
    return "\n".join(lines)


def write_json_report(table, output_path):
    """Write the frequency table as a structured JSON report file."""
    sorted_items = sorted(table.items(), key=lambda kv: kv[1]["count"], reverse=True)

    report = {
        "summary": {
            "total_entries": sum(info["count"] for info in table.values()),
            "unique_messages": len(table),
        },
        "errors": [
            {
                "message": msg,
                "level": info["level"],
                "count": info["count"],
                "first_seen": info["first_seen"],
                "last_seen": info["last_seen"],
            }
            for msg, info in sorted_items
        ],
    }

    output_path = Path(output_path)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    return output_path


def analyze(log_path, json_output_path):
    """Core analysis pipeline: parse -> frequency table -> output both formats.

    Prints the human-readable table to stdout and writes the JSON report.
    Calls sys.exit(1) with an error message if the log file is not found.
    """
    try:
        entries = parse_log_file(log_path)
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    table = build_frequency_table(entries)
    print(format_table(table))

    if table:
        write_json_report(table, json_output_path)
        print(f"\nJSON report written to: {json_output_path}")
    else:
        # Write an empty report for consistency
        write_json_report(table, json_output_path)


def main():
    """CLI entry point. Usage: python log_analyzer.py <logfile> [output.json]"""
    if len(sys.argv) < 2:
        print("Usage: python log_analyzer.py <logfile> [output.json]", file=sys.stderr)
        sys.exit(1)

    log_path = Path(sys.argv[1])
    json_output = Path(sys.argv[2]) if len(sys.argv) > 2 else log_path.with_suffix(".report.json")
    analyze(log_path, json_output)


if __name__ == "__main__":
    main()
