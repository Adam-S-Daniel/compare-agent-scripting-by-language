"""
Error Retry Pipeline - TDD Implementation
==========================================
Tests written BEFORE implementation using red/green TDD methodology.

Test order follows TDD cycles:
1. MockQueue (dequeue/enqueue basics)
2. Exponential backoff retry logic
3. Dead-letter queue behavior
4. Progress reporter
5. Full pipeline integration
"""

import unittest
import time
from unittest.mock import MagicMock, patch, call


# ─────────────────────────────────────────────────────────────────────────────
# CYCLE 1: MockQueue — write test first (RED), then implement (GREEN)
# ─────────────────────────────────────────────────────────────────────────────

class TestMockQueue(unittest.TestCase):
    """Tests for the MockQueue abstraction.

    The queue must be dequeue-able, enqueue-able, and report its size.
    All items are pre-loaded so tests are deterministic.
    """

    def test_dequeue_returns_item(self):
        """Dequeuing from a non-empty queue returns the first item."""
        from pipeline import MockQueue
        q = MockQueue(["item_a", "item_b"])
        self.assertEqual(q.dequeue(), "item_a")

    def test_dequeue_empty_returns_none(self):
        """Dequeuing from an empty queue returns None (signals 'done')."""
        from pipeline import MockQueue
        q = MockQueue([])
        self.assertIsNone(q.dequeue())

    def test_enqueue_adds_item(self):
        """Enqueueing an item makes it retrievable."""
        from pipeline import MockQueue
        q = MockQueue([])
        q.enqueue("new_item")
        self.assertEqual(q.dequeue(), "new_item")

    def test_size_reflects_contents(self):
        """size() returns the current number of items."""
        from pipeline import MockQueue
        q = MockQueue(["a", "b", "c"])
        self.assertEqual(q.size(), 3)
        q.dequeue()
        self.assertEqual(q.size(), 2)


# ─────────────────────────────────────────────────────────────────────────────
# CYCLE 2: RetryPolicy — exponential backoff calculation
# ─────────────────────────────────────────────────────────────────────────────

class TestRetryPolicy(unittest.TestCase):
    """Tests for the exponential backoff retry policy.

    The policy calculates wait times and tracks attempt counts.
    Sleep is injected so tests run instantly without real delays.
    """

    def test_wait_time_doubles_each_attempt(self):
        """Each successive retry doubles the wait time (exponential backoff)."""
        from pipeline import RetryPolicy
        policy = RetryPolicy(max_retries=5, base_delay=1.0, jitter=False)
        self.assertAlmostEqual(policy.wait_seconds(attempt=1), 1.0)
        self.assertAlmostEqual(policy.wait_seconds(attempt=2), 2.0)
        self.assertAlmostEqual(policy.wait_seconds(attempt=3), 4.0)
        self.assertAlmostEqual(policy.wait_seconds(attempt=4), 8.0)

    def test_max_retries_respected(self):
        """should_retry returns False once max_retries is exceeded."""
        from pipeline import RetryPolicy
        policy = RetryPolicy(max_retries=3, base_delay=0.0, jitter=False)
        self.assertTrue(policy.should_retry(attempt=1))
        self.assertTrue(policy.should_retry(attempt=2))
        self.assertTrue(policy.should_retry(attempt=3))
        self.assertFalse(policy.should_retry(attempt=4))

    def test_wait_time_is_capped_at_max_delay(self):
        """Wait time never exceeds max_delay even with many retries."""
        from pipeline import RetryPolicy
        policy = RetryPolicy(max_retries=20, base_delay=1.0, max_delay=10.0, jitter=False)
        self.assertLessEqual(policy.wait_seconds(attempt=10), 10.0)
        self.assertLessEqual(policy.wait_seconds(attempt=20), 10.0)


# ─────────────────────────────────────────────────────────────────────────────
# CYCLE 3: ProgressReporter
# ─────────────────────────────────────────────────────────────────────────────

class TestProgressReporter(unittest.TestCase):
    """Tests for the progress reporter that tracks pipeline state.

    The reporter accumulates counters and formats a summary.
    """

    def test_initial_state_is_zero(self):
        """Reporter starts with all counters at zero."""
        from pipeline import ProgressReporter
        reporter = ProgressReporter()
        self.assertEqual(reporter.processed, 0)
        self.assertEqual(reporter.failed, 0)
        self.assertEqual(reporter.retrying, 0)

    def test_record_processed_increments_counter(self):
        """Calling record_processed increments the processed counter."""
        from pipeline import ProgressReporter
        reporter = ProgressReporter()
        reporter.record_processed("item_a")
        self.assertEqual(reporter.processed, 1)

    def test_record_failed_increments_counter(self):
        """Calling record_failed increments the failed counter."""
        from pipeline import ProgressReporter
        reporter = ProgressReporter()
        reporter.record_failed("item_b")
        self.assertEqual(reporter.failed, 1)

    def test_record_retrying_increments_and_decrements(self):
        """retrying counter goes up when retry starts, down when it ends."""
        from pipeline import ProgressReporter
        reporter = ProgressReporter()
        reporter.record_retry_start("item_c")
        self.assertEqual(reporter.retrying, 1)
        reporter.record_retry_end("item_c")
        self.assertEqual(reporter.retrying, 0)

    def test_summary_contains_all_counts(self):
        """Summary string contains processed, failed, retrying counts."""
        from pipeline import ProgressReporter
        reporter = ProgressReporter()
        reporter.record_processed("a")
        reporter.record_processed("b")
        reporter.record_failed("c")
        summary = reporter.summary()
        self.assertIn("2", summary)   # processed count
        self.assertIn("1", summary)   # failed count

    def test_progress_callback_is_called(self):
        """An optional callback is invoked on each state change."""
        from pipeline import ProgressReporter
        callback = MagicMock()
        reporter = ProgressReporter(on_progress=callback)
        reporter.record_processed("x")
        callback.assert_called_once()


# ─────────────────────────────────────────────────────────────────────────────
# CYCLE 4: Pipeline — integration with retry + DLQ
# ─────────────────────────────────────────────────────────────────────────────

class TestPipeline(unittest.TestCase):
    """Integration tests for the full pipeline.

    Uses a MockQueue and a controllable processor function.
    sleep is patched out so tests finish instantly.
    """

    def _make_pipeline(self, items, processor_fn, max_retries=3, base_delay=0.0):
        """Helper: construct a Pipeline with mocked dependencies."""
        from pipeline import Pipeline, MockQueue, RetryPolicy, ProgressReporter
        queue = MockQueue(items)
        policy = RetryPolicy(max_retries=max_retries, base_delay=base_delay, jitter=False)
        reporter = ProgressReporter()
        return Pipeline(queue=queue, processor=processor_fn,
                        retry_policy=policy, reporter=reporter)

    @patch("pipeline.time.sleep")
    def test_successful_items_are_processed(self, mock_sleep):
        """All items succeed: processed count equals item count, DLQ empty."""
        processor = MagicMock(return_value=True)
        pipeline = self._make_pipeline(["a", "b", "c"], processor)
        result = pipeline.run()
        self.assertEqual(result.processed, 3)
        self.assertEqual(result.failed, 0)
        self.assertEqual(len(result.dead_letter_queue), 0)

    @patch("pipeline.time.sleep")
    def test_permanently_failing_items_go_to_dlq(self, mock_sleep):
        """Items that fail all retries land in the dead-letter queue."""
        processor = MagicMock(side_effect=RuntimeError("processing error"))
        pipeline = self._make_pipeline(["x"], processor, max_retries=2)
        result = pipeline.run()
        self.assertEqual(result.processed, 0)
        self.assertEqual(result.failed, 1)
        self.assertEqual(len(result.dead_letter_queue), 1)
        self.assertEqual(result.dead_letter_queue[0]["item"], "x")

    @patch("pipeline.time.sleep")
    def test_item_succeeds_after_retries(self, mock_sleep):
        """An item that fails twice then succeeds is counted as processed."""
        call_count = {"n": 0}

        def flaky(item):
            call_count["n"] += 1
            if call_count["n"] < 3:
                raise RuntimeError("transient error")
            return True

        pipeline = self._make_pipeline(["item"], flaky, max_retries=5)
        result = pipeline.run()
        self.assertEqual(result.processed, 1)
        self.assertEqual(result.failed, 0)

    @patch("pipeline.time.sleep")
    def test_sleep_is_called_with_backoff_delays(self, mock_sleep):
        """time.sleep is called with exponentially increasing delays."""
        attempts = {"n": 0}

        def fail_twice(item):
            attempts["n"] += 1
            if attempts["n"] <= 2:
                raise RuntimeError("fail")
            return True

        pipeline = self._make_pipeline(["item"], fail_twice, max_retries=5, base_delay=1.0)
        pipeline.run()
        # First retry waits 1s, second retry waits 2s
        mock_sleep.assert_any_call(1.0)
        mock_sleep.assert_any_call(2.0)

    @patch("pipeline.time.sleep")
    def test_dlq_records_error_message(self, mock_sleep):
        """Dead-letter entries include the item and the last error message."""
        def always_fails(item):
            raise ValueError(f"bad value for {item}")

        pipeline = self._make_pipeline(["bad_item"], always_fails, max_retries=1)
        result = pipeline.run()
        dlq_entry = result.dead_letter_queue[0]
        self.assertIn("bad_item", str(dlq_entry["item"]))
        self.assertIn("error", dlq_entry)

    @patch("pipeline.time.sleep")
    def test_mixed_items_summary(self, mock_sleep):
        """Summary string reports correct counts for a mixed-outcome run."""
        items = ["ok1", "ok2", "fail1"]

        def processor(item):
            if item.startswith("fail"):
                raise RuntimeError("forced failure")
            return True

        pipeline = self._make_pipeline(items, processor, max_retries=1)
        result = pipeline.run()
        summary = result.summary()
        self.assertIn("2", summary)   # 2 processed
        self.assertIn("1", summary)   # 1 failed

    @patch("pipeline.time.sleep")
    def test_multiple_items_multiple_failures(self, mock_sleep):
        """Multiple items failing all retries all end up in the DLQ."""
        def always_fail(item):
            raise RuntimeError("always")

        pipeline = self._make_pipeline(["a", "b", "c"], always_fail, max_retries=2)
        result = pipeline.run()
        self.assertEqual(len(result.dead_letter_queue), 3)
        self.assertEqual(result.failed, 3)


# ─────────────────────────────────────────────────────────────────────────────
# CYCLE 5: PipelineResult — summary formatting
# ─────────────────────────────────────────────────────────────────────────────

class TestPipelineResult(unittest.TestCase):
    """Tests for the PipelineResult returned by Pipeline.run()."""

    def test_result_has_duration(self):
        """Result includes the total wall-clock duration in seconds."""
        from pipeline import PipelineResult
        result = PipelineResult(processed=5, failed=1,
                                dead_letter_queue=[{"item": "x", "error": "e"}],
                                duration_seconds=3.14)
        self.assertAlmostEqual(result.duration_seconds, 3.14)

    def test_summary_includes_duration(self):
        """Summary string mentions elapsed time."""
        from pipeline import PipelineResult
        result = PipelineResult(processed=2, failed=0,
                                dead_letter_queue=[],
                                duration_seconds=1.5)
        summary = result.summary()
        self.assertIn("1.5", summary)

    def test_summary_lists_dlq_items(self):
        """Summary describes each dead-letter item."""
        from pipeline import PipelineResult
        result = PipelineResult(processed=0, failed=1,
                                dead_letter_queue=[{"item": "bad", "error": "oops"}],
                                duration_seconds=0.1)
        summary = result.summary()
        self.assertIn("bad", summary)


if __name__ == "__main__":
    unittest.main(verbosity=2)
