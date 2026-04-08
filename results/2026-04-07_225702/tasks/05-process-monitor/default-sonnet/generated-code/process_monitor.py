"""
process_monitor.py — Process monitoring library.

Design decisions:
  - ProcessInfo is a plain dataclass: cheap to construct and easy to mock.
  - read_processes accepts an optional `provider` callable so callers (and
    tests) can inject any data source without patching global state.
  - filter_by_threshold uses OR logic: a process is flagged if it exceeds
    *any* of the supplied thresholds.
  - top_n_consumers ranks by cpu_percent + memory_percent (combined load).
  - generate_alert_report returns a structured dict so callers can consume
    the data programmatically; a "formatted" key also holds a human-readable
    summary.
"""

from __future__ import annotations

import textwrap
from dataclasses import dataclass, field
from typing import Callable, List, Optional


# ── Data model ────────────────────────────────────────────────────────────────

@dataclass
class ProcessInfo:
    """Immutable snapshot of a single process's resource usage."""

    pid: int
    name: str
    cpu_percent: float
    memory_percent: float

    def __repr__(self) -> str:
        return (
            f"ProcessInfo(pid={self.pid}, name={self.name!r}, "
            f"cpu={self.cpu_percent:.1f}%, mem={self.memory_percent:.1f}%)"
        )


# ── Default provider: reads live data via psutil ──────────────────────────────

def _live_provider() -> List[ProcessInfo]:
    """Production data source.  Requires psutil; imported lazily so the rest
    of the module is testable without it installed."""
    try:
        import psutil  # type: ignore
    except ImportError as exc:
        raise RuntimeError(
            "psutil is required for live process reading. "
            "Install it with: pip install psutil"
        ) from exc

    processes: List[ProcessInfo] = []
    for proc in psutil.process_iter(["pid", "name", "cpu_percent", "memory_percent"]):
        try:
            info = proc.info
            processes.append(
                ProcessInfo(
                    pid=info["pid"],
                    name=info["name"] or "<unknown>",
                    cpu_percent=info["cpu_percent"] or 0.0,
                    memory_percent=info["memory_percent"] or 0.0,
                )
            )
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            # Process disappeared or we lack permission — skip gracefully.
            continue
    return processes


# ── Public API ────────────────────────────────────────────────────────────────

def read_processes(
    provider: Optional[Callable[[], List[ProcessInfo]]] = None,
) -> List[ProcessInfo]:
    """Return a list of ProcessInfo objects from `provider`.

    Args:
        provider: Callable that returns a list of ProcessInfo.
                  Defaults to the live psutil-based reader.
                  Pass a mock in tests to avoid touching the real OS.

    Raises:
        RuntimeError: if the provider raises any exception.
    """
    if provider is None:
        provider = _live_provider

    try:
        return provider()
    except Exception as exc:
        raise RuntimeError(f"Failed to read process list: {exc}") from exc


def filter_by_threshold(
    processes: List[ProcessInfo],
    cpu_threshold: Optional[float],
    memory_threshold: Optional[float],
) -> List[ProcessInfo]:
    """Keep processes whose CPU% or memory% exceeds the given thresholds.

    Either threshold can be None to disable that axis of filtering.
    OR semantics: a process is kept when it exceeds *at least one* threshold.
    When both are None, all processes are returned unchanged.

    Raises:
        ValueError: if a threshold is outside [0, 100].
    """
    # Validate thresholds before doing any work.
    for label, value in (("cpu_threshold", cpu_threshold), ("memory_threshold", memory_threshold)):
        if value is not None and not (0.0 <= value <= 100.0):
            raise ValueError(
                f"{label} must be between 0 and 100, got {value}"
            )

    # No thresholds → no filtering.
    if cpu_threshold is None and memory_threshold is None:
        return list(processes)

    result = []
    for proc in processes:
        cpu_breach = cpu_threshold is not None and proc.cpu_percent > cpu_threshold
        mem_breach = memory_threshold is not None and proc.memory_percent > memory_threshold
        if cpu_breach or mem_breach:
            result.append(proc)
    return result


def top_n_consumers(processes: List[ProcessInfo], n: int) -> List[ProcessInfo]:
    """Return the top `n` processes ranked by combined CPU + memory usage.

    Args:
        processes: source list (not mutated).
        n:         number of results to return; clamped to len(processes).

    Raises:
        ValueError: if n < 1.
    """
    if n < 1:
        raise ValueError(f"n must be a positive integer, got {n}")

    sorted_procs = sorted(
        processes,
        key=lambda p: p.cpu_percent + p.memory_percent,
        reverse=True,
    )
    return sorted_procs[:n]


def generate_alert_report(
    alert_processes: List[ProcessInfo],
    cpu_threshold: Optional[float],
    memory_threshold: Optional[float],
) -> dict:
    """Build a structured alert report for the supplied processes.

    Returns a dict with:
        alert_count  – number of alerting processes
        alerts       – list of dicts, one per process, each containing:
                         pid, name, cpu_percent, memory_percent, reasons
        formatted    – human-readable multi-line string summary
    """
    alerts = []
    for proc in alert_processes:
        reasons = []
        if cpu_threshold is not None and proc.cpu_percent > cpu_threshold:
            reasons.append(
                f"CPU {proc.cpu_percent:.1f}% > threshold {cpu_threshold:.1f}%"
            )
        if memory_threshold is not None and proc.memory_percent > memory_threshold:
            reasons.append(
                f"Memory {proc.memory_percent:.1f}% > threshold {memory_threshold:.1f}%"
            )
        # If no threshold matched (e.g., both None), still include the process
        # but with an empty reasons list.
        alerts.append(
            {
                "pid": proc.pid,
                "name": proc.name,
                "cpu_percent": proc.cpu_percent,
                "memory_percent": proc.memory_percent,
                "reasons": reasons,
            }
        )

    # ── Build human-readable summary ─────────────────────────────────────────
    if not alerts:
        formatted = "No alerts — all processes within thresholds."
    else:
        lines = [
            f"ALERT REPORT — {len(alerts)} process(es) exceed thresholds",
            "=" * 60,
        ]
        for entry in alerts:
            lines.append(
                f"  [{entry['pid']}] {entry['name']}"
                f"  CPU={entry['cpu_percent']:.1f}%"
                f"  MEM={entry['memory_percent']:.1f}%"
            )
            for reason in entry["reasons"]:
                lines.append(f"      ! {reason}")
        formatted = "\n".join(lines)

    return {
        "alert_count": len(alerts),
        "alerts": alerts,
        "formatted": formatted,
    }
