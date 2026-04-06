"""
Tests for the process monitor.

Written following red/green TDD: each section corresponds to a TDD cycle
where the test was written first, run to see it fail (RED), then the
implementation was added to make it pass (GREEN), followed by refactoring.

All process data is mocked — no live system state is needed.
"""

import datetime
import pytest
from process_monitor import (
    ProcessInfo,
    filter_by_cpu,
    filter_by_memory,
    top_consumers,
    generate_alert_report,
    get_processes,
)


# ============================================================
# Shared mock data fixtures
# ============================================================

def make_sample_processes():
    """Reusable fixture: a list of mock process snapshots."""
    return [
        ProcessInfo(pid=1, name="idle", cpu_percent=0.1, memory_mb=10.0),
        ProcessInfo(pid=100, name="webapp", cpu_percent=55.0, memory_mb=512.0),
        ProcessInfo(pid=200, name="database", cpu_percent=30.0, memory_mb=1024.0),
        ProcessInfo(pid=300, name="worker", cpu_percent=80.0, memory_mb=256.0),
        ProcessInfo(pid=400, name="logger", cpu_percent=5.0, memory_mb=64.0),
    ]


# ============================================================
# Cycle 1: ProcessInfo data class
# ============================================================

def test_process_info_creation():
    """ProcessInfo holds all four fields."""
    p = ProcessInfo(pid=42, name="test", cpu_percent=12.5, memory_mb=128.0)
    assert p.pid == 42
    assert p.name == "test"
    assert p.cpu_percent == 12.5
    assert p.memory_mb == 128.0


def test_process_info_equality():
    """Two ProcessInfo with identical fields are equal."""
    a = ProcessInfo(pid=1, name="x", cpu_percent=0.0, memory_mb=0.0)
    b = ProcessInfo(pid=1, name="x", cpu_percent=0.0, memory_mb=0.0)
    assert a == b


# ============================================================
# Cycle 2: CPU threshold filtering
# ============================================================

def test_filter_by_cpu_threshold():
    """Processes at or above the CPU threshold are returned."""
    procs = make_sample_processes()
    result = filter_by_cpu(procs, threshold=50.0)
    names = [p.name for p in result]
    assert names == ["webapp", "worker"]


def test_filter_by_cpu_threshold_none_above():
    """When no process exceeds the threshold, return empty list."""
    procs = make_sample_processes()
    result = filter_by_cpu(procs, threshold=99.0)
    assert result == []


def test_filter_by_cpu_exact_boundary():
    """A process exactly at the threshold IS included."""
    procs = [ProcessInfo(pid=1, name="edge", cpu_percent=50.0, memory_mb=0.0)]
    result = filter_by_cpu(procs, threshold=50.0)
    assert len(result) == 1


def test_filter_by_cpu_empty_input():
    """Filtering an empty list returns an empty list."""
    assert filter_by_cpu([], threshold=10.0) == []


def test_filter_by_cpu_negative_threshold_raises():
    """Negative threshold is rejected with a clear error."""
    with pytest.raises(ValueError, match="non-negative"):
        filter_by_cpu([], threshold=-1.0)


# ============================================================
# Cycle 3: Memory threshold filtering
# ============================================================

def test_filter_by_memory_threshold():
    """Processes at or above the memory threshold are returned."""
    procs = make_sample_processes()
    result = filter_by_memory(procs, threshold_mb=500.0)
    names = [p.name for p in result]
    assert names == ["webapp", "database"]


def test_filter_by_memory_none_above():
    """When no process exceeds the threshold, return empty list."""
    procs = make_sample_processes()
    result = filter_by_memory(procs, threshold_mb=2000.0)
    assert result == []


def test_filter_by_memory_empty_input():
    assert filter_by_memory([], threshold_mb=100.0) == []


def test_filter_by_memory_negative_threshold_raises():
    with pytest.raises(ValueError, match="non-negative"):
        filter_by_memory([], threshold_mb=-5.0)


# ============================================================
# Cycle 4: Top-N consumers
# ============================================================

def test_top_consumers_cpu_default():
    """Top consumers by CPU returns highest-CPU processes first."""
    procs = make_sample_processes()
    result = top_consumers(procs, n=3, key="cpu")
    names = [p.name for p in result]
    assert names == ["worker", "webapp", "database"]


def test_top_consumers_memory():
    """Top consumers by memory returns highest-memory processes first."""
    procs = make_sample_processes()
    result = top_consumers(procs, n=2, key="memory")
    names = [p.name for p in result]
    assert names == ["database", "webapp"]


def test_top_consumers_n_larger_than_list():
    """If n exceeds the number of processes, return all of them sorted."""
    procs = make_sample_processes()
    result = top_consumers(procs, n=100, key="cpu")
    assert len(result) == len(procs)
    # Still sorted descending
    assert result[0].name == "worker"


def test_top_consumers_n_zero():
    """n=0 returns an empty list."""
    procs = make_sample_processes()
    assert top_consumers(procs, n=0, key="cpu") == []


def test_top_consumers_empty_input():
    assert top_consumers([], n=5, key="cpu") == []


def test_top_consumers_invalid_key_raises():
    with pytest.raises(ValueError, match="key must be"):
        top_consumers([], n=1, key="disk")


def test_top_consumers_negative_n_raises():
    with pytest.raises(ValueError, match="non-negative"):
        top_consumers([], n=-1, key="cpu")


# ============================================================
# Cycle 5: Alert report generation
# ============================================================

FIXED_TS = datetime.datetime(2026, 1, 15, 10, 30, 0)


def test_report_contains_header():
    """Report starts with a header and includes timestamp."""
    procs = make_sample_processes()
    report = generate_alert_report(procs, timestamp=FIXED_TS)
    assert "ALERT REPORT" in report
    assert "2026-01-15 10:30:00" in report


def test_report_contains_thresholds():
    """Report shows the configured thresholds."""
    procs = make_sample_processes()
    report = generate_alert_report(procs, cpu_threshold=75.0, memory_threshold_mb=800.0, timestamp=FIXED_TS)
    assert "75.0%" in report
    assert "800.0 MB" in report


def test_report_cpu_alerts():
    """Report lists processes that exceed CPU threshold as alerts."""
    procs = make_sample_processes()
    report = generate_alert_report(procs, cpu_threshold=50.0, timestamp=FIXED_TS)
    assert "[ALERT] PID 100 (webapp): CPU 55.0%" in report
    assert "[ALERT] PID 300 (worker): CPU 80.0%" in report
    # 'idle' should not appear in CPU alerts
    assert "PID 1 (idle): CPU" not in report


def test_report_memory_alerts():
    """Report lists processes that exceed memory threshold."""
    procs = make_sample_processes()
    report = generate_alert_report(procs, memory_threshold_mb=500.0, timestamp=FIXED_TS)
    assert "[ALERT] PID 100 (webapp): Memory 512.0 MB" in report
    assert "[ALERT] PID 200 (database): Memory 1024.0 MB" in report


def test_report_no_alerts():
    """When nothing exceeds thresholds, report says '(none)'."""
    procs = make_sample_processes()
    report = generate_alert_report(procs, cpu_threshold=99.0, memory_threshold_mb=9999.0, timestamp=FIXED_TS)
    assert "(none)" in report
    assert "Total alerts: 0" in report


def test_report_total_alert_count():
    """Total alerts counts unique PIDs across CPU and memory alerts."""
    procs = make_sample_processes()
    # webapp (pid=100) exceeds both thresholds, but should be counted once
    report = generate_alert_report(procs, cpu_threshold=50.0, memory_threshold_mb=500.0, timestamp=FIXED_TS)
    # cpu alerts: webapp (55%), worker (80%) => pids {100, 300}
    # mem alerts: webapp (512MB), database (1024MB) => pids {100, 200}
    # union: {100, 200, 300} => 3
    assert "Total alerts: 3" in report


def test_report_top_n_section():
    """Top consumers section shows the requested number of entries."""
    procs = make_sample_processes()
    report = generate_alert_report(procs, top_n=2, timestamp=FIXED_TS)
    assert "Top 2 CPU consumers" in report
    assert "Top 2 Memory consumers" in report


def test_report_empty_process_list():
    """Report handles an empty process list gracefully."""
    report = generate_alert_report([])
    assert "No process data available" in report


def test_report_total_processes_count():
    """Report shows the total number of processes scanned."""
    procs = make_sample_processes()
    report = generate_alert_report(procs, timestamp=FIXED_TS)
    assert "Total processes : 5" in report


# ============================================================
# Cycle 6: Mockable process data provider
# ============================================================

def test_get_processes_with_mock_provider():
    """get_processes uses the injected provider instead of live data."""
    mock_data = [
        ProcessInfo(pid=999, name="mock_proc", cpu_percent=42.0, memory_mb=128.0),
    ]

    def mock_provider():
        return mock_data

    result = get_processes(provider=mock_provider)
    assert len(result) == 1
    assert result[0].name == "mock_proc"
    assert result[0].pid == 999


def test_get_processes_provider_returns_empty():
    """A provider that returns no processes works correctly."""
    result = get_processes(provider=lambda: [])
    assert result == []


def test_get_processes_provider_error_propagates():
    """If the provider raises, the error propagates to the caller."""
    def bad_provider():
        raise RuntimeError("connection failed")

    with pytest.raises(RuntimeError, match="connection failed"):
        get_processes(provider=bad_provider)


# ============================================================
# Integration test: full pipeline with mock data
# ============================================================

def test_full_pipeline():
    """End-to-end: inject mock data, generate report, verify key content."""
    mock_procs = [
        ProcessInfo(pid=10, name="nginx", cpu_percent=15.0, memory_mb=200.0),
        ProcessInfo(pid=20, name="postgres", cpu_percent=60.0, memory_mb=2048.0),
        ProcessInfo(pid=30, name="redis", cpu_percent=90.0, memory_mb=100.0),
        ProcessInfo(pid=40, name="cron", cpu_percent=1.0, memory_mb=5.0),
    ]

    # Inject via provider
    processes = get_processes(provider=lambda: mock_procs)

    # Generate report
    report = generate_alert_report(
        processes,
        cpu_threshold=50.0,
        memory_threshold_mb=500.0,
        top_n=3,
        timestamp=FIXED_TS,
    )

    # CPU alerts: postgres (60%) and redis (90%)
    assert "[ALERT] PID 20 (postgres): CPU 60.0%" in report
    assert "[ALERT] PID 30 (redis): CPU 90.0%" in report
    # Memory alert: postgres (2048MB)
    assert "[ALERT] PID 20 (postgres): Memory 2048.0 MB" in report
    # nginx should NOT appear in alerts
    assert "PID 10 (nginx)" not in report
    # Top 3 CPU: redis, postgres, nginx
    assert "Total alerts: 2" in report  # pids {20, 30}
