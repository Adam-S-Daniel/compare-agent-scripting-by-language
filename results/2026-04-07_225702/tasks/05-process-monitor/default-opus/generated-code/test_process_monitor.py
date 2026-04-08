# TDD tests for process monitor
# Red/Green/Refactor: each test was written before the implementation code.

import pytest
from process_monitor import (
    Process, parse_processes, filter_by_thresholds, top_consumers,
    generate_alert_report, monitor, get_live_process_data,
)


# --- Fixtures: mock process data used across tests ---

MOCK_PROCESSES = [
    Process(pid=1, name="idle", cpu_percent=0.1, mem_percent=0.2),
    Process(pid=100, name="webserver", cpu_percent=25.0, mem_percent=8.0),
    Process(pid=200, name="database", cpu_percent=10.0, mem_percent=45.0),
    Process(pid=300, name="miner", cpu_percent=95.0, mem_percent=60.0),
    Process(pid=400, name="editor", cpu_percent=5.0, mem_percent=3.0),
]


# --- Cycle 1: Parse raw dicts into Process objects ---

def test_parse_processes_returns_process_objects():
    raw = [
        {"pid": 1, "name": "init", "cpu_percent": 0.1, "mem_percent": 0.5},
        {"pid": 42, "name": "python", "cpu_percent": 55.0, "mem_percent": 12.3},
    ]
    result = parse_processes(raw)
    assert len(result) == 2
    assert result[0].pid == 1
    assert result[0].name == "init"
    assert result[0].cpu_percent == 0.1
    assert result[0].mem_percent == 0.5
    assert result[1].pid == 42


def test_parse_processes_rejects_missing_fields():
    raw = [{"pid": 1, "name": "init"}]  # missing cpu_percent, mem_percent
    with pytest.raises(ValueError, match="missing required fields"):
        parse_processes(raw)


# --- Cycle 2: Filter processes by CPU and memory thresholds ---

def test_filter_by_cpu_threshold():
    result = filter_by_thresholds(MOCK_PROCESSES, cpu_threshold=20.0)
    pids = [p.pid for p in result]
    assert 100 in pids  # 25% cpu
    assert 300 in pids  # 95% cpu
    assert 1 not in pids  # 0.1% cpu


def test_filter_by_mem_threshold():
    result = filter_by_thresholds(MOCK_PROCESSES, mem_threshold=40.0)
    pids = [p.pid for p in result]
    assert 200 in pids  # 45% mem
    assert 300 in pids  # 60% mem
    assert 100 not in pids  # 8% mem


def test_filter_by_both_thresholds():
    # OR logic: process matches if it exceeds EITHER threshold
    result = filter_by_thresholds(MOCK_PROCESSES, cpu_threshold=20.0, mem_threshold=40.0)
    pids = [p.pid for p in result]
    assert 100 in pids  # high cpu
    assert 200 in pids  # high mem
    assert 300 in pids  # both high
    assert 1 not in pids


def test_filter_with_no_thresholds_returns_all():
    result = filter_by_thresholds(MOCK_PROCESSES)
    assert len(result) == len(MOCK_PROCESSES)


# --- Cycle 3: Top N resource consumers ---

def test_top_consumers_by_cpu():
    result = top_consumers(MOCK_PROCESSES, n=2, sort_by="cpu")
    assert len(result) == 2
    assert result[0].pid == 300  # 95% cpu
    assert result[1].pid == 100  # 25% cpu


def test_top_consumers_by_mem():
    result = top_consumers(MOCK_PROCESSES, n=2, sort_by="mem")
    assert len(result) == 2
    assert result[0].pid == 300  # 60% mem
    assert result[1].pid == 200  # 45% mem


def test_top_consumers_n_larger_than_list():
    result = top_consumers(MOCK_PROCESSES, n=100, sort_by="cpu")
    assert len(result) == len(MOCK_PROCESSES)


def test_top_consumers_invalid_sort_key():
    with pytest.raises(ValueError, match="sort_by must be"):
        top_consumers(MOCK_PROCESSES, n=3, sort_by="disk")


# --- Cycle 4: Generate alert report ---

def test_generate_alert_report_structure():
    alerts = [MOCK_PROCESSES[3]]  # miner: 95% cpu, 60% mem
    report = generate_alert_report(
        alerts, cpu_threshold=50.0, mem_threshold=50.0,
    )
    assert "PROCESS ALERT REPORT" in report
    assert "miner" in report
    assert "PID: 300" in report
    assert "CPU: 95.0%" in report
    assert "MEM: 60.0%" in report
    assert "CPU threshold: 50.0%" in report
    assert "MEM threshold: 50.0%" in report


def test_generate_alert_report_no_alerts():
    report = generate_alert_report([], cpu_threshold=99.0, mem_threshold=99.0)
    assert "No processes exceeded" in report


def test_generate_alert_report_multiple_processes():
    alerts = [MOCK_PROCESSES[3], MOCK_PROCESSES[2]]  # miner, database
    report = generate_alert_report(alerts, cpu_threshold=5.0)
    assert "miner" in report
    assert "database" in report
    # Should show count
    assert "2 process(es)" in report


# --- Cycle 5: Mockable data source and end-to-end monitor ---

MOCK_RAW_DATA = [
    {"pid": 1, "name": "idle", "cpu_percent": 0.1, "mem_percent": 0.2},
    {"pid": 100, "name": "webserver", "cpu_percent": 25.0, "mem_percent": 8.0},
    {"pid": 200, "name": "database", "cpu_percent": 10.0, "mem_percent": 45.0},
    {"pid": 300, "name": "miner", "cpu_percent": 95.0, "mem_percent": 60.0},
    {"pid": 400, "name": "editor", "cpu_percent": 5.0, "mem_percent": 3.0},
]


def mock_data_source():
    """A mock that replaces get_live_process_data for testing."""
    return MOCK_RAW_DATA


def test_monitor_end_to_end_with_mock():
    """Full pipeline: inject mock data source, get a report back."""
    report = monitor(
        data_source=mock_data_source,
        cpu_threshold=20.0,
        mem_threshold=40.0,
        top_n=3,
        sort_by="cpu",
    )
    # Should contain the top offenders
    assert "miner" in report
    assert "PROCESS ALERT REPORT" in report


def test_monitor_with_no_offenders():
    report = monitor(
        data_source=mock_data_source,
        cpu_threshold=99.0,
        mem_threshold=99.0,
        top_n=5,
    )
    assert "No processes exceeded" in report


def test_monitor_defaults_to_live_source():
    """get_live_process_data exists and returns a list of dicts."""
    # Just verify it's callable and returns the right shape
    data = get_live_process_data()
    assert isinstance(data, list)
    # Each entry should have the required keys
    if data:  # might be empty on minimal systems
        assert REQUIRED_FIELDS <= data[0].keys()


# Import the constant for the live-source test
from process_monitor import REQUIRED_FIELDS
