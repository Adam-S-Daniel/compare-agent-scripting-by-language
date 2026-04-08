# TDD tests for error-retry pipeline
# Red/Green cycle: each test section was written BEFORE its implementation

import pytest
from unittest.mock import MagicMock, call


# ── Cycle 1: Exponential backoff retry ──────────────────────────────────────

def test_retry_calls_processor_until_success():
    """A failing processor should be retried up to max_retries times."""
    from pipeline import retry_with_backoff

    processor = MagicMock(side_effect=[Exception("fail"), Exception("fail"), "ok"])
    result = retry_with_backoff(processor, "item1", max_retries=3, base_delay=0)
    assert result == "ok"
    assert processor.call_count == 3


def test_retry_exhausts_retries_and_raises():
    """After max_retries failures, the last exception propagates."""
    from pipeline import retry_with_backoff

    processor = MagicMock(side_effect=Exception("permanent"))
    with pytest.raises(Exception, match="permanent"):
        retry_with_backoff(processor, "item", max_retries=3, base_delay=0)
    assert processor.call_count == 3


def test_retry_succeeds_on_first_try():
    """No retries needed when processor succeeds immediately."""
    from pipeline import retry_with_backoff

    processor = MagicMock(return_value="done")
    result = retry_with_backoff(processor, "x", max_retries=5, base_delay=0)
    assert result == "done"
    assert processor.call_count == 1


def test_retry_backoff_delays_increase_exponentially():
    """Delays between retries should follow exponential backoff."""
    from pipeline import retry_with_backoff
    from unittest.mock import patch

    processor = MagicMock(side_effect=[Exception("e"), Exception("e"), "ok"])
    with patch("pipeline.time.sleep") as mock_sleep:
        retry_with_backoff(processor, "item", max_retries=3, base_delay=1.0)

    # Expected delays: 1*2^0=1, 1*2^1=2
    assert mock_sleep.call_args_list == [call(1.0), call(2.0)]


# ── Cycle 2: Dead-letter queue ──────────────────────────────────────────────

def test_dead_letter_queue_receives_permanently_failed_items():
    """Items that exhaust all retries go to the dead-letter queue."""
    from pipeline import DeadLetterQueue

    dlq = DeadLetterQueue()
    err = ValueError("bad data")
    dlq.add("item_x", err)
    assert len(dlq) == 1
    assert dlq.items[0] == ("item_x", err)


def test_dead_letter_queue_is_iterable():
    """DLQ should be iterable for inspection/reporting."""
    from pipeline import DeadLetterQueue

    dlq = DeadLetterQueue()
    dlq.add("a", Exception("e1"))
    dlq.add("b", Exception("e2"))
    items = list(dlq)
    assert len(items) == 2
    assert items[0][0] == "a"
    assert items[1][0] == "b"


# ── Cycle 3: Progress reporter ──────────────────────────────────────────────

def test_progress_reporter_tracks_counts():
    """Reporter should track processed, failed, and retrying counts."""
    from pipeline import ProgressReporter

    pr = ProgressReporter()
    pr.record_success("a")
    pr.record_success("b")
    pr.record_retry("c", attempt=1)
    pr.record_failure("d", Exception("err"))

    assert pr.processed == 2
    assert pr.failed == 1
    assert pr.retrying == 1


def test_progress_reporter_summary():
    """Summary should include all counts."""
    from pipeline import ProgressReporter

    pr = ProgressReporter()
    pr.record_success("a")
    pr.record_failure("b", Exception("err"))
    pr.record_retry("c", attempt=2)

    summary = pr.summary()
    assert summary["processed"] == 1
    assert summary["failed"] == 1
    assert summary["retrying"] == 1
    assert summary["total"] == 3


def test_progress_reporter_calls_callback():
    """An optional callback should be invoked on each event."""
    from pipeline import ProgressReporter

    events = []
    pr = ProgressReporter(callback=lambda event: events.append(event))
    pr.record_success("a")
    pr.record_retry("b", attempt=1)
    pr.record_failure("c", Exception("e"))

    assert len(events) == 3
    assert events[0]["type"] == "success"
    assert events[1]["type"] == "retry"
    assert events[2]["type"] == "failure"


# ── Cycle 4: Full pipeline integration ──────────────────────────────────────

def test_pipeline_processes_all_items_successfully():
    """With a reliable processor, all items succeed and DLQ is empty."""
    from pipeline import Pipeline

    queue = ["a", "b", "c"]
    processor = MagicMock(side_effect=lambda x: x.upper())

    p = Pipeline(queue, processor, max_retries=3, base_delay=0)
    result = p.run()

    assert result["processed"] == 3
    assert result["failed"] == 0
    assert len(p.dlq) == 0


def test_pipeline_sends_permanent_failures_to_dlq():
    """Items that always fail end up in the dead-letter queue."""
    from pipeline import Pipeline

    queue = ["good", "bad"]

    def flaky(item):
        if item == "bad":
            raise RuntimeError(f"Cannot process {item}")
        return item

    p = Pipeline(queue, flaky, max_retries=2, base_delay=0)
    result = p.run()

    assert result["processed"] == 1
    assert result["failed"] == 1
    assert len(p.dlq) == 1
    assert p.dlq.items[0][0] == "bad"


def test_pipeline_retries_then_succeeds():
    """Items that fail transiently should succeed after retries."""
    from pipeline import Pipeline

    attempt_counts = {}

    def flaky(item):
        attempt_counts[item] = attempt_counts.get(item, 0) + 1
        if item == "flaky" and attempt_counts[item] < 3:
            raise RuntimeError("transient")
        return item

    p = Pipeline(["ok", "flaky"], flaky, max_retries=3, base_delay=0)
    result = p.run()

    assert result["processed"] == 2
    assert result["failed"] == 0
    assert len(p.dlq) == 0


def test_pipeline_uses_mock_queue():
    """Queue can be any iterable — supports mocked/custom queues."""
    from pipeline import Pipeline

    mock_queue = MagicMock()
    mock_queue.__iter__ = MagicMock(return_value=iter(["x", "y"]))
    processor = MagicMock(return_value="done")

    p = Pipeline(mock_queue, processor, max_retries=1, base_delay=0)
    result = p.run()

    assert result["processed"] == 2
    mock_queue.__iter__.assert_called_once()


def test_pipeline_progress_events():
    """Pipeline should emit progress events during processing."""
    from pipeline import Pipeline

    events = []
    queue = ["a", "fail_always"]

    def processor(item):
        if item == "fail_always":
            raise Exception("nope")
        return item

    p = Pipeline(queue, processor, max_retries=2, base_delay=0,
                 progress_callback=lambda e: events.append(e))
    p.run()

    types = [e["type"] for e in events]
    assert "success" in types
    assert "failure" in types


def test_pipeline_summary_includes_all_fields():
    """Final summary should have processed, failed, retrying, total, and dlq_count."""
    from pipeline import Pipeline

    p = Pipeline(["a"], lambda x: x, max_retries=1, base_delay=0)
    result = p.run()

    for key in ("processed", "failed", "retrying", "total", "dlq_count"):
        assert key in result, f"Missing key: {key}"
