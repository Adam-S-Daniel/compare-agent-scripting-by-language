# Process Monitor - TDD implementation
# Each feature was driven by a failing test (RED), then implemented minimally (GREEN),
# then cleaned up (REFACTOR).

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, List, Optional


# ============================================================
# Core data structure
# ============================================================

@dataclass
class ProcessInfo:
    """Immutable snapshot of a single process's resource usage."""
    pid: int
    name: str
    cpu_percent: float
    memory_mb: float


# ============================================================
# Alert report - output of the monitoring pipeline
# ============================================================

@dataclass
class AlertReport:
    """Summary of processes that exceeded resource thresholds."""
    offenders: List[ProcessInfo]   # processes exceeding any threshold
    top_cpu: List[ProcessInfo]     # top N CPU consumers (overall, not just offenders)
    top_memory: List[ProcessInfo]  # top N memory consumers (overall, not just offenders)
    summary: str                   # human-readable alert text


# ============================================================
# ProcessMonitor - the main analysis engine
# ============================================================

class ProcessMonitor:
    """
    Analyses a list of ProcessInfo snapshots.

    The list can come from:
    - A direct list  : ProcessMonitor(processes=[...])
    - A provider fn  : ProcessMonitor.from_provider(callable)
    - The live system: ProcessMonitor.from_provider(get_live_processes)
    """

    def __init__(self, processes: List[ProcessInfo]) -> None:
        self.processes = list(processes)

    # ------------------------------------------------------------------
    # Factory: dependency-injection via provider callable
    # ------------------------------------------------------------------

    @classmethod
    def from_provider(cls, provider: Callable[[], List[ProcessInfo]]) -> "ProcessMonitor":
        """Create a monitor by calling *provider* to obtain the process list.

        This makes it trivial to swap the live psutil source with mock data
        in tests:

            monitor = ProcessMonitor.from_provider(lambda: mock_data)
        """
        return cls(processes=provider())

    # ------------------------------------------------------------------
    # Filtering
    # ------------------------------------------------------------------

    def filter_by_threshold(
        self,
        cpu_threshold: Optional[float] = None,
        memory_threshold_mb: Optional[float] = None,
    ) -> List[ProcessInfo]:
        """Return processes that exceed *either* threshold (OR semantics).

        If neither threshold is supplied every process is returned.
        Duplicates are impossible because each process is evaluated once.
        """
        if cpu_threshold is None and memory_threshold_mb is None:
            return list(self.processes)

        results = []
        for proc in self.processes:
            exceeds_cpu = cpu_threshold is not None and proc.cpu_percent > cpu_threshold
            exceeds_mem = (
                memory_threshold_mb is not None
                and proc.memory_mb > memory_threshold_mb
            )
            if exceeds_cpu or exceeds_mem:
                results.append(proc)
        return results

    # ------------------------------------------------------------------
    # Ranking
    # ------------------------------------------------------------------

    def top_n(self, n: int, sort_by: str) -> List[ProcessInfo]:
        """Return the top *n* processes sorted by *sort_by* (descending).

        Args:
            n: How many processes to return (capped at list length).
            sort_by: Either ``"cpu"`` or ``"memory"``.

        Raises:
            ValueError: If *sort_by* is not ``"cpu"`` or ``"memory"``.
        """
        if sort_by not in ("cpu", "memory"):
            raise ValueError("sort_by must be 'cpu' or 'memory'")

        key = (lambda p: p.cpu_percent) if sort_by == "cpu" else (lambda p: p.memory_mb)
        return sorted(self.processes, key=key, reverse=True)[:n]

    # ------------------------------------------------------------------
    # Report generation
    # ------------------------------------------------------------------

    def generate_alert_report(
        self,
        cpu_threshold: float,
        memory_threshold_mb: float,
        top_n: int,
    ) -> AlertReport:
        """Produce a full AlertReport for the current process snapshot.

        Args:
            cpu_threshold: CPU% above which a process is flagged.
            memory_threshold_mb: Memory (MB) above which a process is flagged.
            top_n: How many top consumers to include in each ranked list.
        """
        offenders = self.filter_by_threshold(
            cpu_threshold=cpu_threshold,
            memory_threshold_mb=memory_threshold_mb,
        )
        top_cpu = self.top_n(n=top_n, sort_by="cpu")
        top_memory = self.top_n(n=top_n, sort_by="memory")

        summary = _build_summary(
            offenders=offenders,
            top_cpu=top_cpu,
            top_memory=top_memory,
            cpu_threshold=cpu_threshold,
            memory_threshold_mb=memory_threshold_mb,
        )

        return AlertReport(
            offenders=offenders,
            top_cpu=top_cpu,
            top_memory=top_memory,
            summary=summary,
        )


# ============================================================
# Summary builder (pure function - easy to test in isolation)
# ============================================================

def _build_summary(
    offenders: List[ProcessInfo],
    top_cpu: List[ProcessInfo],
    top_memory: List[ProcessInfo],
    cpu_threshold: float,
    memory_threshold_mb: float,
) -> str:
    """Build a human-readable alert report string."""
    lines = [
        "=== Process Monitor Alert Report ===",
        f"Thresholds: CPU > {cpu_threshold}% | Memory > {memory_threshold_mb} MB",
        "",
    ]

    if not offenders:
        lines.append("No offenders detected. All processes within thresholds.")
    else:
        lines.append(f"ALERT: {len(offenders)} process(es) exceeded thresholds:")
        for proc in offenders:
            lines.append(
                f"  [{proc.pid}] {proc.name}  CPU={proc.cpu_percent:.1f}%  MEM={proc.memory_mb:.1f} MB"
            )

    lines.append("")
    lines.append(f"Top CPU consumers:")
    for proc in top_cpu:
        lines.append(f"  [{proc.pid}] {proc.name}  {proc.cpu_percent:.1f}%")

    lines.append("")
    lines.append(f"Top Memory consumers:")
    for proc in top_memory:
        lines.append(f"  [{proc.pid}] {proc.name}  {proc.memory_mb:.1f} MB")

    return "\n".join(lines)


# ============================================================
# Live process provider (uses psutil; NOT called in tests)
# ============================================================

def get_live_processes() -> List[ProcessInfo]:
    """Read current process list from the OS via psutil.

    Returns:
        List of ProcessInfo objects for all accessible processes.

    Raises:
        ImportError: If psutil is not installed.
        RuntimeError: If process information cannot be read.
    """
    try:
        import psutil
    except ImportError as exc:
        raise ImportError(
            "psutil is required for live process monitoring. "
            "Install it with: pip install psutil"
        ) from exc

    results: List[ProcessInfo] = []
    for proc in psutil.process_iter(["pid", "name", "cpu_percent", "memory_info"]):
        try:
            info = proc.info
            results.append(
                ProcessInfo(
                    pid=int(info["pid"]),
                    name=str(info["name"] or "<unknown>"),
                    # cpu_percent may be 0.0 on first call (psutil initialises it)
                    cpu_percent=float(info["cpu_percent"] or 0.0),
                    memory_mb=float(
                        (info["memory_info"].rss if info["memory_info"] else 0) / (1024 ** 2)
                    ),
                )
            )
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            # Process disappeared or we lack permission - skip it
            continue

    return results


# ============================================================
# CLI entry point
# ============================================================

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Monitor processes and generate an alert report.")
    parser.add_argument("--cpu-threshold", type=float, default=50.0,
                        help="CPU%% threshold for alerts (default: 50.0)")
    parser.add_argument("--mem-threshold", type=float, default=500.0,
                        help="Memory threshold in MB for alerts (default: 500.0)")
    parser.add_argument("--top-n", type=int, default=5,
                        help="Number of top consumers to show (default: 5)")
    args = parser.parse_args()

    monitor = ProcessMonitor.from_provider(get_live_processes)
    report = monitor.generate_alert_report(
        cpu_threshold=args.cpu_threshold,
        memory_threshold_mb=args.mem_threshold,
        top_n=args.top_n,
    )
    print(report.summary)
