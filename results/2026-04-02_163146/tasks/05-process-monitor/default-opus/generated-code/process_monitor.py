"""
Process Monitor — reads process info, filters by resource thresholds,
identifies top N consumers, and generates alert reports.

Built with red/green TDD methodology. Process data collection is injectable
so tests can use mock data instead of live system state.

Design:
  - ProcessInfo: dataclass holding pid, name, cpu_percent, memory_mb
  - filter_by_cpu / filter_by_memory: threshold-based filters
  - top_consumers: returns top N processes by a chosen metric
  - generate_alert_report: produces a human-readable alert string
  - get_processes: default provider that reads live system data (via psutil
    if available, otherwise /proc on Linux). Accepts an optional override
    callable for dependency injection in tests.
"""

from dataclasses import dataclass
from typing import List, Callable, Optional
import datetime


@dataclass
class ProcessInfo:
    """Immutable snapshot of a single process's resource usage."""
    pid: int
    name: str
    cpu_percent: float  # 0-100 scale
    memory_mb: float


# --- Filtering ---

def filter_by_cpu(processes: List[ProcessInfo], threshold: float) -> List[ProcessInfo]:
    """Return processes whose CPU usage meets or exceeds *threshold* percent."""
    if threshold < 0:
        raise ValueError(f"CPU threshold must be non-negative, got {threshold}")
    return [p for p in processes if p.cpu_percent >= threshold]


def filter_by_memory(processes: List[ProcessInfo], threshold_mb: float) -> List[ProcessInfo]:
    """Return processes whose memory usage meets or exceeds *threshold_mb* MB."""
    if threshold_mb < 0:
        raise ValueError(f"Memory threshold must be non-negative, got {threshold_mb}")
    return [p for p in processes if p.memory_mb >= threshold_mb]


# --- Top-N consumers ---

def top_consumers(
    processes: List[ProcessInfo],
    n: int = 5,
    key: str = "cpu",
) -> List[ProcessInfo]:
    """
    Return the top *n* processes sorted descending by *key*.

    key: "cpu" or "memory"
    """
    if n < 0:
        raise ValueError(f"n must be non-negative, got {n}")
    valid_keys = {"cpu", "memory"}
    if key not in valid_keys:
        raise ValueError(f"key must be one of {valid_keys}, got '{key}'")

    sort_attr = "cpu_percent" if key == "cpu" else "memory_mb"
    sorted_procs = sorted(processes, key=lambda p: getattr(p, sort_attr), reverse=True)
    return sorted_procs[:n]


# --- Alert report generation ---

def generate_alert_report(
    processes: List[ProcessInfo],
    cpu_threshold: float = 50.0,
    memory_threshold_mb: float = 500.0,
    top_n: int = 5,
    timestamp: Optional[datetime.datetime] = None,
) -> str:
    """
    Generate a human-readable alert report.

    The report contains:
      1. Header with timestamp and threshold configuration.
      2. Top N CPU consumers.
      3. Top N memory consumers.
      4. Processes exceeding CPU threshold.
      5. Processes exceeding memory threshold.
      6. Summary line.
    """
    if not processes:
        return "ALERT REPORT\n============\nNo process data available.\n"

    ts = timestamp or datetime.datetime.now()
    ts_str = ts.strftime("%Y-%m-%d %H:%M:%S")

    lines: List[str] = []
    lines.append("ALERT REPORT")
    lines.append("=" * 60)
    lines.append(f"Timestamp       : {ts_str}")
    lines.append(f"CPU threshold   : {cpu_threshold:.1f}%")
    lines.append(f"Memory threshold: {memory_threshold_mb:.1f} MB")
    lines.append(f"Total processes : {len(processes)}")
    lines.append("")

    # Top CPU consumers
    top_cpu = top_consumers(processes, n=top_n, key="cpu")
    lines.append(f"--- Top {top_n} CPU consumers ---")
    lines.append(f"{'PID':>8}  {'CPU%':>6}  {'Mem MB':>8}  {'Name'}")
    for p in top_cpu:
        lines.append(f"{p.pid:>8}  {p.cpu_percent:>6.1f}  {p.memory_mb:>8.1f}  {p.name}")
    lines.append("")

    # Top memory consumers
    top_mem = top_consumers(processes, n=top_n, key="memory")
    lines.append(f"--- Top {top_n} Memory consumers ---")
    lines.append(f"{'PID':>8}  {'CPU%':>6}  {'Mem MB':>8}  {'Name'}")
    for p in top_mem:
        lines.append(f"{p.pid:>8}  {p.cpu_percent:>6.1f}  {p.memory_mb:>8.1f}  {p.name}")
    lines.append("")

    # Alerts — processes exceeding thresholds
    cpu_alerts = filter_by_cpu(processes, cpu_threshold)
    mem_alerts = filter_by_memory(processes, memory_threshold_mb)

    lines.append("--- CPU alerts ---")
    if cpu_alerts:
        for p in cpu_alerts:
            lines.append(f"  [ALERT] PID {p.pid} ({p.name}): CPU {p.cpu_percent:.1f}%")
    else:
        lines.append("  (none)")
    lines.append("")

    lines.append("--- Memory alerts ---")
    if mem_alerts:
        for p in mem_alerts:
            lines.append(f"  [ALERT] PID {p.pid} ({p.name}): Memory {p.memory_mb:.1f} MB")
    else:
        lines.append("  (none)")
    lines.append("")

    total_alerts = len(set(p.pid for p in cpu_alerts) | set(p.pid for p in mem_alerts))
    lines.append(f"Total alerts: {total_alerts}")
    lines.append("=" * 60)

    return "\n".join(lines) + "\n"


# --- Process data provider (mockable) ---

# Type alias for the process data source function.
ProcessProvider = Callable[[], List[ProcessInfo]]


def _read_live_processes() -> List[ProcessInfo]:
    """
    Read process data from the live system.

    Tries psutil first; falls back to parsing /proc on Linux.
    Raises RuntimeError if neither method works.
    """
    # Attempt psutil
    try:
        import psutil  # type: ignore
        result = []
        for proc in psutil.process_iter(["pid", "name", "cpu_percent", "memory_info"]):
            try:
                info = proc.info
                mem_mb = info["memory_info"].rss / (1024 * 1024) if info["memory_info"] else 0.0
                result.append(ProcessInfo(
                    pid=info["pid"],
                    name=info["name"] or "<unknown>",
                    cpu_percent=info["cpu_percent"] or 0.0,
                    memory_mb=round(mem_mb, 1),
                ))
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        return result
    except ImportError:
        pass

    # Fallback: parse /proc on Linux
    import os
    import re

    if not os.path.isdir("/proc"):
        raise RuntimeError(
            "Cannot read process data: psutil is not installed and /proc is not available. "
            "Install psutil (`pip install psutil`) or run on a Linux system."
        )

    page_size = os.sysconf("SC_PAGE_SIZE")
    result = []
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        pid = int(entry)
        try:
            # Read process name from /proc/<pid>/comm
            with open(f"/proc/{pid}/comm") as f:
                name = f.read().strip()
            # Read memory from /proc/<pid>/statm (resident pages in field 1)
            with open(f"/proc/{pid}/statm") as f:
                fields = f.read().split()
                resident_pages = int(fields[1])
                mem_mb = round((resident_pages * page_size) / (1024 * 1024), 1)
            # Read CPU from /proc/<pid>/stat — simplified: use utime+stime
            # Note: real CPU% requires two samples; we approximate with 0.0 here
            # since accurate CPU% needs periodic sampling or psutil.
            cpu_percent = 0.0
            result.append(ProcessInfo(pid=pid, name=name, cpu_percent=cpu_percent, memory_mb=mem_mb))
        except (FileNotFoundError, PermissionError, IndexError):
            continue
    return result


def get_processes(provider: Optional[ProcessProvider] = None) -> List[ProcessInfo]:
    """
    Return a list of ProcessInfo snapshots.

    If *provider* is given, use it (for testing / dependency injection).
    Otherwise read from the live system.
    """
    if provider is not None:
        return provider()
    return _read_live_processes()


# --- CLI entry point ---

def main() -> None:
    """Run the monitor and print the alert report."""
    import argparse

    parser = argparse.ArgumentParser(description="Process resource monitor and alerter")
    parser.add_argument("--cpu-threshold", type=float, default=50.0,
                        help="CPU%% threshold for alerts (default: 50)")
    parser.add_argument("--memory-threshold", type=float, default=500.0,
                        help="Memory MB threshold for alerts (default: 500)")
    parser.add_argument("--top-n", type=int, default=5,
                        help="Number of top consumers to show (default: 5)")
    args = parser.parse_args()

    try:
        processes = get_processes()
    except RuntimeError as e:
        print(f"Error: {e}")
        return

    report = generate_alert_report(
        processes,
        cpu_threshold=args.cpu_threshold,
        memory_threshold_mb=args.memory_threshold,
        top_n=args.top_n,
    )
    print(report)


if __name__ == "__main__":
    main()
