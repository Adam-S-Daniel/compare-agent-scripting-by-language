# Process Monitor Tests - TDD approach
# We write failing tests first, then implement the minimum code to pass them.
# All tests use mock data - no live system state.

import pytest

# Detect whether psutil is available so we can conditionally skip live tests
try:
    import psutil as _psutil
    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False

from process_monitor import ProcessInfo, ProcessMonitor, AlertReport


# ============================================================
# RED: First failing test - ProcessInfo dataclass existence
# ============================================================

class TestProcessInfo:
    """Tests for the ProcessInfo data structure."""

    def test_process_info_creation(self):
        """ProcessInfo should hold PID, name, cpu_percent, memory_mb."""
        proc = ProcessInfo(pid=1234, name="chrome", cpu_percent=45.2, memory_mb=512.0)
        assert proc.pid == 1234
        assert proc.name == "chrome"
        assert proc.cpu_percent == 45.2
        assert proc.memory_mb == 512.0

    def test_process_info_requires_all_fields(self):
        """ProcessInfo should require all four fields."""
        with pytest.raises(TypeError):
            ProcessInfo(pid=1)  # missing name, cpu_percent, memory_mb


class TestProcessMonitorInit:
    """Tests for ProcessMonitor initialization with mock data."""

    def test_monitor_accepts_process_list(self):
        """ProcessMonitor should accept a list of ProcessInfo objects."""
        processes = [
            ProcessInfo(pid=1, name="init", cpu_percent=0.1, memory_mb=10.0),
            ProcessInfo(pid=2, name="bash", cpu_percent=1.5, memory_mb=20.0),
        ]
        monitor = ProcessMonitor(processes=processes)
        assert len(monitor.processes) == 2

    def test_monitor_accepts_empty_list(self):
        """ProcessMonitor should handle an empty process list gracefully."""
        monitor = ProcessMonitor(processes=[])
        assert monitor.processes == []


class TestProcessFiltering:
    """Tests for filtering processes by resource usage thresholds."""

    SAMPLE_PROCESSES = [
        ProcessInfo(pid=1, name="idle",    cpu_percent=0.1,  memory_mb=10.0),
        ProcessInfo(pid=2, name="bash",    cpu_percent=5.0,  memory_mb=50.0),
        ProcessInfo(pid=3, name="chrome",  cpu_percent=55.0, memory_mb=800.0),
        ProcessInfo(pid=4, name="python",  cpu_percent=30.0, memory_mb=200.0),
        ProcessInfo(pid=5, name="mysqld",  cpu_percent=10.0, memory_mb=1200.0),
    ]

    def test_filter_by_cpu_threshold(self):
        """Processes exceeding the CPU threshold should be returned."""
        monitor = ProcessMonitor(processes=self.SAMPLE_PROCESSES)
        high_cpu = monitor.filter_by_threshold(cpu_threshold=20.0)
        names = [p.name for p in high_cpu]
        assert "chrome" in names   # 55% > 20%
        assert "python" in names   # 30% > 20%
        assert "bash" not in names # 5% < 20%
        assert "idle" not in names # 0.1% < 20%

    def test_filter_by_memory_threshold(self):
        """Processes exceeding the memory threshold should be returned."""
        monitor = ProcessMonitor(processes=self.SAMPLE_PROCESSES)
        high_mem = monitor.filter_by_threshold(memory_threshold_mb=500.0)
        names = [p.name for p in high_mem]
        assert "chrome" in names   # 800 MB > 500
        assert "mysqld" in names   # 1200 MB > 500
        assert "python" not in names  # 200 MB < 500

    def test_filter_by_both_thresholds_uses_OR_logic(self):
        """A process exceeding EITHER threshold should appear in results."""
        monitor = ProcessMonitor(processes=self.SAMPLE_PROCESSES)
        results = monitor.filter_by_threshold(cpu_threshold=20.0, memory_threshold_mb=500.0)
        names = [p.name for p in results]
        # chrome: high CPU AND high memory
        assert "chrome" in names
        # python: high CPU only
        assert "python" in names
        # mysqld: high memory only
        assert "mysqld" in names
        # bash and idle: neither
        assert "bash" not in names
        assert "idle" not in names

    def test_filter_with_no_thresholds_returns_all(self):
        """Calling filter with no thresholds should return all processes."""
        monitor = ProcessMonitor(processes=self.SAMPLE_PROCESSES)
        results = monitor.filter_by_threshold()
        assert len(results) == len(self.SAMPLE_PROCESSES)

    def test_filter_deduplicates_results(self):
        """A process matching both thresholds should only appear once."""
        monitor = ProcessMonitor(processes=self.SAMPLE_PROCESSES)
        results = monitor.filter_by_threshold(cpu_threshold=20.0, memory_threshold_mb=500.0)
        pids = [p.pid for p in results]
        # chrome (pid=3) matches both - should appear exactly once
        assert pids.count(3) == 1


class TestTopNConsumers:
    """Tests for identifying top N resource consumers."""

    SAMPLE_PROCESSES = [
        ProcessInfo(pid=1, name="idle",    cpu_percent=0.1,  memory_mb=10.0),
        ProcessInfo(pid=2, name="bash",    cpu_percent=5.0,  memory_mb=50.0),
        ProcessInfo(pid=3, name="chrome",  cpu_percent=55.0, memory_mb=800.0),
        ProcessInfo(pid=4, name="python",  cpu_percent=30.0, memory_mb=200.0),
        ProcessInfo(pid=5, name="mysqld",  cpu_percent=10.0, memory_mb=1200.0),
    ]

    def test_top_n_by_cpu(self):
        """top_n should return N processes sorted by CPU usage descending."""
        monitor = ProcessMonitor(processes=self.SAMPLE_PROCESSES)
        top2 = monitor.top_n(n=2, sort_by="cpu")
        assert len(top2) == 2
        assert top2[0].name == "chrome"   # highest CPU: 55%
        assert top2[1].name == "python"   # second: 30%

    def test_top_n_by_memory(self):
        """top_n should return N processes sorted by memory usage descending."""
        monitor = ProcessMonitor(processes=self.SAMPLE_PROCESSES)
        top2 = monitor.top_n(n=2, sort_by="memory")
        assert len(top2) == 2
        assert top2[0].name == "mysqld"  # highest memory: 1200 MB
        assert top2[1].name == "chrome"  # second: 800 MB

    def test_top_n_greater_than_list_returns_all(self):
        """Requesting more than available should return all processes."""
        monitor = ProcessMonitor(processes=self.SAMPLE_PROCESSES)
        result = monitor.top_n(n=100, sort_by="cpu")
        assert len(result) == len(self.SAMPLE_PROCESSES)

    def test_top_n_invalid_sort_raises_error(self):
        """An invalid sort_by value should raise a ValueError."""
        monitor = ProcessMonitor(processes=self.SAMPLE_PROCESSES)
        with pytest.raises(ValueError, match="sort_by must be 'cpu' or 'memory'"):
            monitor.top_n(n=3, sort_by="invalid")

    def test_top_n_zero_returns_empty(self):
        """Requesting top 0 should return an empty list."""
        monitor = ProcessMonitor(processes=self.SAMPLE_PROCESSES)
        result = monitor.top_n(n=0, sort_by="cpu")
        assert result == []


class TestAlertReport:
    """Tests for alert report generation."""

    SAMPLE_PROCESSES = [
        ProcessInfo(pid=3, name="chrome",  cpu_percent=55.0, memory_mb=800.0),
        ProcessInfo(pid=4, name="python",  cpu_percent=30.0, memory_mb=200.0),
        ProcessInfo(pid=5, name="mysqld",  cpu_percent=10.0, memory_mb=1200.0),
    ]

    def test_alert_report_is_alertreport_instance(self):
        """generate_alert_report should return an AlertReport object."""
        monitor = ProcessMonitor(processes=self.SAMPLE_PROCESSES)
        report = monitor.generate_alert_report(
            cpu_threshold=20.0,
            memory_threshold_mb=500.0,
            top_n=3,
        )
        assert isinstance(report, AlertReport)

    def test_alert_report_contains_offenders(self):
        """AlertReport should list processes exceeding thresholds."""
        monitor = ProcessMonitor(processes=self.SAMPLE_PROCESSES)
        report = monitor.generate_alert_report(
            cpu_threshold=20.0,
            memory_threshold_mb=500.0,
            top_n=3,
        )
        offender_names = [p.name for p in report.offenders]
        assert "chrome" in offender_names
        assert "python" in offender_names
        assert "mysqld" in offender_names

    def test_alert_report_contains_top_cpu(self):
        """AlertReport should include the top N CPU consumers."""
        monitor = ProcessMonitor(processes=self.SAMPLE_PROCESSES)
        report = monitor.generate_alert_report(
            cpu_threshold=20.0,
            memory_threshold_mb=500.0,
            top_n=2,
        )
        assert len(report.top_cpu) == 2
        assert report.top_cpu[0].name == "chrome"

    def test_alert_report_contains_top_memory(self):
        """AlertReport should include the top N memory consumers."""
        monitor = ProcessMonitor(processes=self.SAMPLE_PROCESSES)
        report = monitor.generate_alert_report(
            cpu_threshold=20.0,
            memory_threshold_mb=500.0,
            top_n=2,
        )
        assert len(report.top_memory) == 2
        assert report.top_memory[0].name == "mysqld"

    def test_alert_report_has_summary_text(self):
        """AlertReport.summary should be a non-empty string."""
        monitor = ProcessMonitor(processes=self.SAMPLE_PROCESSES)
        report = monitor.generate_alert_report(
            cpu_threshold=20.0,
            memory_threshold_mb=500.0,
            top_n=3,
        )
        assert isinstance(report.summary, str)
        assert len(report.summary) > 0

    def test_alert_report_summary_contains_key_info(self):
        """Summary text should mention thresholds and top consumer names."""
        monitor = ProcessMonitor(processes=self.SAMPLE_PROCESSES)
        report = monitor.generate_alert_report(
            cpu_threshold=20.0,
            memory_threshold_mb=500.0,
            top_n=3,
        )
        # Should mention the top CPU hog
        assert "chrome" in report.summary
        # Should mention the top memory hog
        assert "mysqld" in report.summary

    def test_alert_report_no_offenders_when_below_thresholds(self):
        """When all processes are below thresholds, offenders list is empty."""
        low_processes = [
            ProcessInfo(pid=1, name="idle", cpu_percent=0.1, memory_mb=10.0),
        ]
        monitor = ProcessMonitor(processes=low_processes)
        report = monitor.generate_alert_report(
            cpu_threshold=50.0,
            memory_threshold_mb=500.0,
            top_n=3,
        )
        assert report.offenders == []
        assert "No offenders" in report.summary


class TestProcessProvider:
    """Tests for the live process provider (using dependency injection for mocking)."""

    def test_monitor_can_use_custom_provider(self):
        """ProcessMonitor should accept a callable provider for dependency injection."""
        # This enables swapping the real psutil source with mock data in tests
        mock_data = [
            ProcessInfo(pid=99, name="mock_proc", cpu_percent=99.0, memory_mb=999.0),
        ]

        def mock_provider():
            return mock_data

        monitor = ProcessMonitor.from_provider(mock_provider)
        assert len(monitor.processes) == 1
        assert monitor.processes[0].name == "mock_proc"

    @pytest.mark.skipif(not PSUTIL_AVAILABLE, reason="psutil not installed")
    def test_live_provider_returns_process_list(self):
        """The live provider should return a list of ProcessInfo objects."""
        # Uses the real system - just validates structure, not values
        from process_monitor import get_live_processes
        processes = get_live_processes()
        assert isinstance(processes, list)
        assert len(processes) > 0
        for p in processes:
            assert isinstance(p, ProcessInfo)
            assert isinstance(p.pid, int)
            assert isinstance(p.name, str)
            assert isinstance(p.cpu_percent, float)
            assert isinstance(p.memory_mb, float)
