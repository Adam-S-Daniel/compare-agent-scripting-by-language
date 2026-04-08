"""
Process Monitor Tests — TDD approach.

Each test is written BEFORE the implementation it covers.
Tests use mock process data so they never depend on live system state.
"""

import unittest
from unittest.mock import patch, MagicMock

# ── RED: import the module we haven't written yet ─────────────────────────────
from process_monitor import (
    ProcessInfo,
    read_processes,
    filter_by_threshold,
    top_n_consumers,
    generate_alert_report,
)

# ── Fixtures ──────────────────────────────────────────────────────────────────
# Reusable mock process data shared across all tests.
MOCK_PROCESSES = [
    ProcessInfo(pid=1001, name="web-server",  cpu_percent=85.0, memory_percent=40.0),
    ProcessInfo(pid=1002, name="database",    cpu_percent=60.0, memory_percent=75.0),
    ProcessInfo(pid=1003, name="log-agent",   cpu_percent=10.0, memory_percent=5.0),
    ProcessInfo(pid=1004, name="cache",       cpu_percent=30.0, memory_percent=20.0),
    ProcessInfo(pid=1005, name="idle-worker", cpu_percent=1.0,  memory_percent=2.0),
]


class TestProcessInfo(unittest.TestCase):
    """ProcessInfo is a simple data container; verify its fields are accessible."""

    def test_process_info_fields(self):
        # RED: ProcessInfo does not exist yet — this will fail.
        p = ProcessInfo(pid=42, name="test-proc", cpu_percent=12.5, memory_percent=8.3)
        self.assertEqual(p.pid, 42)
        self.assertEqual(p.name, "test-proc")
        self.assertAlmostEqual(p.cpu_percent, 12.5)
        self.assertAlmostEqual(p.memory_percent, 8.3)

    def test_process_info_repr_contains_name(self):
        p = ProcessInfo(pid=42, name="test-proc", cpu_percent=12.5, memory_percent=8.3)
        self.assertIn("test-proc", repr(p))


class TestReadProcesses(unittest.TestCase):
    """read_processes must accept an optional provider callable so it can be
    injected with mock data — no live psutil calls in tests."""

    def test_returns_list_of_process_info(self):
        # RED: read_processes does not exist yet.
        # We inject a fake provider that returns our fixture data.
        def mock_provider():
            return MOCK_PROCESSES

        result = read_processes(provider=mock_provider)

        self.assertIsInstance(result, list)
        self.assertEqual(len(result), 5)
        self.assertIsInstance(result[0], ProcessInfo)

    def test_propagates_provider_error_with_message(self):
        # If the provider raises, read_processes should raise RuntimeError
        # with a human-readable message.
        def broken_provider():
            raise OSError("permission denied")

        with self.assertRaises(RuntimeError) as ctx:
            read_processes(provider=broken_provider)

        self.assertIn("Failed to read process list", str(ctx.exception))

    def test_returns_empty_list_when_provider_returns_none_items(self):
        result = read_processes(provider=lambda: [])
        self.assertEqual(result, [])


class TestFilterByThreshold(unittest.TestCase):
    """filter_by_threshold keeps only processes that exceed at least one
    configurable threshold (cpu_threshold or memory_threshold)."""

    def test_filters_by_cpu_threshold(self):
        # RED: filter_by_threshold does not exist yet.
        result = filter_by_threshold(
            MOCK_PROCESSES, cpu_threshold=50.0, memory_threshold=None
        )
        # web-server (85%) and database (60%) exceed 50% CPU
        names = {p.name for p in result}
        self.assertIn("web-server", names)
        self.assertIn("database", names)
        self.assertNotIn("log-agent", names)
        self.assertNotIn("idle-worker", names)

    def test_filters_by_memory_threshold(self):
        result = filter_by_threshold(
            MOCK_PROCESSES, cpu_threshold=None, memory_threshold=30.0
        )
        # database (75%) and web-server (40%) exceed 30% memory
        names = {p.name for p in result}
        self.assertIn("database", names)
        self.assertIn("web-server", names)
        self.assertNotIn("cache", names)   # 20% < 30%

    def test_filters_by_both_thresholds(self):
        # A process must exceed AT LEAST ONE threshold (OR logic)
        result = filter_by_threshold(
            MOCK_PROCESSES, cpu_threshold=50.0, memory_threshold=30.0
        )
        names = {p.name for p in result}
        # web-server: cpu 85>50 ✓ OR mem 40>30 ✓ → keep
        # database:   cpu 60>50 ✓ OR mem 75>30 ✓ → keep
        # cache:      cpu 30<50  AND mem 20<30  → exclude
        self.assertIn("web-server", names)
        self.assertIn("database", names)
        self.assertNotIn("cache", names)

    def test_no_thresholds_returns_all(self):
        # When both thresholds are None, nothing is filtered out.
        result = filter_by_threshold(MOCK_PROCESSES, cpu_threshold=None, memory_threshold=None)
        self.assertEqual(len(result), len(MOCK_PROCESSES))

    def test_raises_on_invalid_threshold(self):
        with self.assertRaises(ValueError):
            filter_by_threshold(MOCK_PROCESSES, cpu_threshold=-1.0, memory_threshold=None)
        with self.assertRaises(ValueError):
            filter_by_threshold(MOCK_PROCESSES, cpu_threshold=None, memory_threshold=101.0)


class TestTopNConsumers(unittest.TestCase):
    """top_n_consumers returns the N processes with the highest combined
    resource usage (cpu + memory), sorted descending."""

    def test_returns_top_n(self):
        # RED: top_n_consumers does not exist yet.
        result = top_n_consumers(MOCK_PROCESSES, n=2)
        self.assertEqual(len(result), 2)

    def test_sorted_by_combined_usage_descending(self):
        result = top_n_consumers(MOCK_PROCESSES, n=3)
        # web-server: 85+40=125, database: 60+75=135, cache: 30+20=50
        # Sorted: database(135), web-server(125), cache(50)
        self.assertEqual(result[0].name, "database")
        self.assertEqual(result[1].name, "web-server")

    def test_n_larger_than_list_returns_all(self):
        result = top_n_consumers(MOCK_PROCESSES, n=100)
        self.assertEqual(len(result), len(MOCK_PROCESSES))

    def test_raises_on_non_positive_n(self):
        with self.assertRaises(ValueError):
            top_n_consumers(MOCK_PROCESSES, n=0)


class TestGenerateAlertReport(unittest.TestCase):
    """generate_alert_report returns a structured dict (and optionally a
    formatted string) describing which processes are alerting and why."""

    def _alert_processes(self):
        return [MOCK_PROCESSES[0], MOCK_PROCESSES[1]]  # web-server, database

    def test_report_contains_alert_count(self):
        # RED: generate_alert_report does not exist yet.
        report = generate_alert_report(self._alert_processes(), cpu_threshold=50.0, memory_threshold=30.0)
        self.assertIn("alert_count", report)
        self.assertEqual(report["alert_count"], 2)

    def test_report_contains_process_entries(self):
        report = generate_alert_report(self._alert_processes(), cpu_threshold=50.0, memory_threshold=30.0)
        self.assertIn("alerts", report)
        self.assertEqual(len(report["alerts"]), 2)

    def test_report_entry_has_required_fields(self):
        report = generate_alert_report(self._alert_processes(), cpu_threshold=50.0, memory_threshold=30.0)
        entry = report["alerts"][0]
        for field in ("pid", "name", "cpu_percent", "memory_percent", "reasons"):
            self.assertIn(field, entry)

    def test_report_reasons_explain_which_threshold_breached(self):
        report = generate_alert_report(self._alert_processes(), cpu_threshold=50.0, memory_threshold=30.0)
        # web-server breaches CPU; database breaches both
        web_entry = next(e for e in report["alerts"] if e["name"] == "web-server")
        self.assertTrue(any("cpu" in r.lower() for r in web_entry["reasons"]))

    def test_report_formatted_string(self):
        report = generate_alert_report(self._alert_processes(), cpu_threshold=50.0, memory_threshold=30.0)
        text = report["formatted"]
        self.assertIn("web-server", text)
        self.assertIn("database", text)

    def test_empty_alert_list_produces_no_alerts_message(self):
        report = generate_alert_report([], cpu_threshold=50.0, memory_threshold=30.0)
        self.assertEqual(report["alert_count"], 0)
        self.assertIn("No alerts", report["formatted"])


if __name__ == "__main__":
    unittest.main()
