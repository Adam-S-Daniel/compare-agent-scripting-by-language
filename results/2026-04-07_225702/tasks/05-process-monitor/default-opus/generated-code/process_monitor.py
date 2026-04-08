"""
Process monitor: reads process info, filters by resource thresholds,
identifies top N consumers, and generates alert reports.

All process data flows through a mockable interface so tests never
depend on live system state.
"""

from dataclasses import dataclass
from typing import Callable
import argparse
import os
import sys

REQUIRED_FIELDS = {"pid", "name", "cpu_percent", "mem_percent"}


@dataclass
class Process:
    """Represents a single process snapshot."""
    pid: int
    name: str
    cpu_percent: float
    mem_percent: float


def parse_processes(raw: list[dict]) -> list[Process]:
    """Convert raw dicts into validated Process objects.

    Raises ValueError if any dict is missing required fields.
    """
    results = []
    for entry in raw:
        missing = REQUIRED_FIELDS - entry.keys()
        if missing:
            raise ValueError(
                f"missing required fields: {', '.join(sorted(missing))}"
            )
        results.append(Process(
            pid=entry["pid"],
            name=entry["name"],
            cpu_percent=float(entry["cpu_percent"]),
            mem_percent=float(entry["mem_percent"]),
        ))
    return results


def filter_by_thresholds(
    processes: list[Process],
    cpu_threshold: float | None = None,
    mem_threshold: float | None = None,
) -> list[Process]:
    """Return processes exceeding at least one of the given thresholds.

    If no thresholds are set, returns all processes.
    Uses OR logic: a process is included if it exceeds either threshold.
    """
    if cpu_threshold is None and mem_threshold is None:
        return list(processes)

    result = []
    for p in processes:
        if cpu_threshold is not None and p.cpu_percent >= cpu_threshold:
            result.append(p)
        elif mem_threshold is not None and p.mem_percent >= mem_threshold:
            result.append(p)
    return result


_SORT_KEYS = {
    "cpu": lambda p: p.cpu_percent,
    "mem": lambda p: p.mem_percent,
}


def top_consumers(
    processes: list[Process], n: int, sort_by: str = "cpu",
) -> list[Process]:
    """Return the top N processes sorted descending by the chosen metric."""
    if sort_by not in _SORT_KEYS:
        raise ValueError(f"sort_by must be one of {list(_SORT_KEYS)}, got '{sort_by}'")
    return sorted(processes, key=_SORT_KEYS[sort_by], reverse=True)[:n]


def generate_alert_report(
    alerts: list[Process],
    cpu_threshold: float | None = None,
    mem_threshold: float | None = None,
) -> str:
    """Generate a human-readable alert report for the given processes."""
    lines = ["=" * 40, "PROCESS ALERT REPORT", "=" * 40, ""]

    # Show active thresholds
    thresholds = []
    if cpu_threshold is not None:
        thresholds.append(f"CPU threshold: {cpu_threshold}%")
    if mem_threshold is not None:
        thresholds.append(f"MEM threshold: {mem_threshold}%")
    if thresholds:
        lines.append("Thresholds: " + ", ".join(thresholds))
        lines.append("")

    if not alerts:
        lines.append("No processes exceeded the configured thresholds.")
        return "\n".join(lines)

    lines.append(f"{len(alerts)} process(es) triggered alerts:")
    lines.append("-" * 40)

    for p in alerts:
        lines.append(f"  PID: {p.pid}  Name: {p.name}")
        lines.append(f"    CPU: {p.cpu_percent}%  MEM: {p.mem_percent}%")

    lines.append("=" * 40)
    return "\n".join(lines)


def get_live_process_data() -> list[dict]:
    """Read process data from /proc (Linux).

    This is the default data source; tests inject a mock instead.
    Returns a list of dicts with pid, name, cpu_percent, mem_percent.
    """
    processes = []
    try:
        # Read /proc/stat for total CPU to compute per-process percentages.
        # For a snapshot, we approximate CPU% from /proc/[pid]/stat fields.
        total_mem = 1  # fallback
        with open("/proc/meminfo") as f:
            for line in f:
                if line.startswith("MemTotal:"):
                    total_mem = int(line.split()[1]) * 1024  # bytes
                    break

        for entry in os.listdir("/proc"):
            if not entry.isdigit():
                continue
            pid = int(entry)
            try:
                # Read process name
                with open(f"/proc/{pid}/comm") as f:
                    name = f.read().strip()
                # Read RSS for memory (field index 23 in /proc/[pid]/stat)
                with open(f"/proc/{pid}/stat") as f:
                    stat_fields = f.read().split()
                # utime + stime for rough CPU indication
                utime = int(stat_fields[13])
                stime = int(stat_fields[14])
                rss_pages = int(stat_fields[23])
                rss_bytes = rss_pages * os.sysconf("SC_PAGE_SIZE")
                mem_percent = round((rss_bytes / total_mem) * 100, 1)
                # CPU% is approximate (cumulative ticks, not a rate).
                # For a real monitor you'd sample twice; this is a best-effort snapshot.
                cpu_ticks = utime + stime
                clock_ticks = os.sysconf("SC_CLK_TCK")
                cpu_seconds = cpu_ticks / clock_ticks
                cpu_percent = round(cpu_seconds, 1)  # rough proxy

                processes.append({
                    "pid": pid,
                    "name": name,
                    "cpu_percent": cpu_percent,
                    "mem_percent": mem_percent,
                })
            except (FileNotFoundError, PermissionError, IndexError):
                # Process disappeared or we lack permissions — skip it
                continue
    except Exception as e:
        raise RuntimeError(f"Failed to read process data: {e}") from e

    return processes


def monitor(
    data_source: Callable[[], list[dict]] = get_live_process_data,
    cpu_threshold: float | None = None,
    mem_threshold: float | None = None,
    top_n: int = 10,
    sort_by: str = "cpu",
) -> str:
    """Full monitoring pipeline: read -> parse -> filter -> rank -> report.

    The data_source parameter accepts any callable returning list[dict],
    making the entire pipeline testable with mock data.
    """
    raw = data_source()
    processes = parse_processes(raw)
    filtered = filter_by_thresholds(processes, cpu_threshold, mem_threshold)
    ranked = top_consumers(filtered, n=top_n, sort_by=sort_by)
    return generate_alert_report(ranked, cpu_threshold, mem_threshold)


def main():
    """CLI entry point with configurable thresholds and top-N."""
    parser = argparse.ArgumentParser(description="Process resource monitor")
    parser.add_argument("--cpu", type=float, default=None,
                        help="CPU%% threshold (e.g. 50.0)")
    parser.add_argument("--mem", type=float, default=None,
                        help="Memory%% threshold (e.g. 50.0)")
    parser.add_argument("--top", type=int, default=10,
                        help="Number of top consumers to show (default: 10)")
    parser.add_argument("--sort", choices=["cpu", "mem"], default="cpu",
                        help="Sort by cpu or mem (default: cpu)")
    args = parser.parse_args()

    try:
        report = monitor(
            cpu_threshold=args.cpu,
            mem_threshold=args.mem,
            top_n=args.top,
            sort_by=args.sort,
        )
        print(report)
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
