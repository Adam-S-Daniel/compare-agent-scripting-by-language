"""
Error Retry Pipeline — Implementation
======================================
Follows red/green TDD: each class/function was written to satisfy a
pre-existing failing test in test_pipeline.py.

Architecture:
  MockQueue        – injectable queue abstraction (can swap for real broker)
  RetryPolicy      – configurable exponential backoff parameters
  ProgressReporter – tracks and emits real-time pipeline state
  PipelineResult   – immutable value object returned by Pipeline.run()
  Pipeline         – orchestrates dequeue → process → retry → DLQ loop
"""

from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Any, Callable, List, Optional


# ─────────────────────────────────────────────────────────────────────────────
# MockQueue
# ─────────────────────────────────────────────────────────────────────────────

class MockQueue:
    """A simple in-memory FIFO queue for testing.

    Pre-loaded with `items` at construction time so tests are fully
    deterministic. Real production code would swap this for an SQS/RabbitMQ
    client that implements the same dequeue/enqueue/size interface.
    """

    def __init__(self, items: List[Any]) -> None:
        # Use a list as the internal buffer; pop(0) gives FIFO semantics.
        self._items: List[Any] = list(items)

    def dequeue(self) -> Optional[Any]:
        """Remove and return the next item, or None when the queue is empty."""
        if not self._items:
            return None
        return self._items.pop(0)

    def enqueue(self, item: Any) -> None:
        """Add an item to the back of the queue."""
        self._items.append(item)

    def size(self) -> int:
        """Return the current number of items waiting in the queue."""
        return len(self._items)


# ─────────────────────────────────────────────────────────────────────────────
# RetryPolicy — exponential backoff
# ─────────────────────────────────────────────────────────────────────────────

class RetryPolicy:
    """Calculates exponential backoff wait times and enforces retry limits.

    Formula: wait = min(base_delay * 2^(attempt-1), max_delay)
    Jitter adds a small random component to avoid thundering-herd problems;
    tests disable jitter for deterministic assertions.

    Args:
        max_retries: Maximum number of retry attempts (not counting the first try).
        base_delay:  Base wait time in seconds (default 1 second).
        max_delay:   Upper bound on wait time in seconds (default 60 seconds).
        jitter:      When True, adds random noise to each wait time.
    """

    def __init__(
        self,
        max_retries: int = 3,
        base_delay: float = 1.0,
        max_delay: float = 60.0,
        jitter: bool = True,
    ) -> None:
        self.max_retries = max_retries
        self.base_delay = base_delay
        self.max_delay = max_delay
        self.jitter = jitter

    def should_retry(self, attempt: int) -> bool:
        """Return True if another retry attempt is allowed."""
        return attempt <= self.max_retries

    def wait_seconds(self, attempt: int) -> float:
        """Return how long to sleep before the given retry attempt number."""
        # Exponential growth: 1s, 2s, 4s, 8s, …
        delay = self.base_delay * (2 ** (attempt - 1))
        delay = min(delay, self.max_delay)

        if self.jitter:
            import random
            # Add up to 10% random noise to spread retries across time
            delay += random.uniform(0, delay * 0.1)

        return delay


# ─────────────────────────────────────────────────────────────────────────────
# ProgressReporter
# ─────────────────────────────────────────────────────────────────────────────

class ProgressReporter:
    """Tracks and surfaces real-time pipeline metrics.

    Counters are updated synchronously on each event so callers always
    see the current state. An optional callback allows callers to hook in
    logging, UI updates, or metrics emission.

    Args:
        on_progress: Optional callable invoked after each state change.
                     Receives (event_name, item) arguments.
    """

    def __init__(self, on_progress: Optional[Callable] = None) -> None:
        self.processed: int = 0
        self.failed: int = 0
        self.retrying: int = 0
        self._on_progress = on_progress

    def record_processed(self, item: Any) -> None:
        """Mark an item as successfully processed."""
        self.processed += 1
        self._emit("processed", item)

    def record_failed(self, item: Any) -> None:
        """Mark an item as permanently failed (sent to DLQ)."""
        self.failed += 1
        self._emit("failed", item)

    def record_retry_start(self, item: Any) -> None:
        """Signal that an item is about to be retried."""
        self.retrying += 1
        self._emit("retry_start", item)

    def record_retry_end(self, item: Any) -> None:
        """Signal that a retry attempt has finished (success or another failure)."""
        self.retrying -= 1
        self._emit("retry_end", item)

    def summary(self) -> str:
        """Return a human-readable one-liner of current counters."""
        return (
            f"Processed: {self.processed} | "
            f"Failed: {self.failed} | "
            f"Retrying: {self.retrying}"
        )

    def _emit(self, event: str, item: Any) -> None:
        if self._on_progress is not None:
            self._on_progress(event, item)


# ─────────────────────────────────────────────────────────────────────────────
# PipelineResult — immutable outcome value object
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class PipelineResult:
    """Immutable summary of a completed pipeline run.

    Attributes:
        processed:         Number of items successfully processed.
        failed:            Number of items permanently failed.
        dead_letter_queue: List of {'item': …, 'error': …} dicts.
        duration_seconds:  Total wall-clock time of the run.
    """

    processed: int
    failed: int
    dead_letter_queue: List[dict]
    duration_seconds: float

    def summary(self) -> str:
        """Format a multi-line human-readable summary of the run."""
        lines = [
            "═" * 50,
            "  PIPELINE RUN SUMMARY",
            "═" * 50,
            f"  Processed successfully : {self.processed}",
            f"  Failed (sent to DLQ)   : {self.failed}",
            f"  Elapsed time           : {self.duration_seconds:.1f}s",
        ]
        if self.dead_letter_queue:
            lines.append("")
            lines.append("  Dead-letter queue:")
            for entry in self.dead_letter_queue:
                lines.append(f"    • {entry['item']}  →  {entry['error']}")
        lines.append("═" * 50)
        return "\n".join(lines)


# ─────────────────────────────────────────────────────────────────────────────
# Pipeline — main orchestrator
# ─────────────────────────────────────────────────────────────────────────────

class Pipeline:
    """Processes every item from a queue with configurable retry and DLQ logic.

    Algorithm per item:
      1. Call processor(item).
      2. On success → reporter.record_processed(item).
      3. On exception → check retry policy.
         a. If retries remain → sleep(backoff), retry (incrementing attempt).
         b. If retries exhausted → add to dead_letter_queue, record_failed.

    Args:
        queue:        Any object with dequeue() / enqueue() / size() methods.
        processor:    Callable(item) → any; raises on failure.
        retry_policy: RetryPolicy instance controlling backoff behaviour.
        reporter:     ProgressReporter for real-time progress updates.
    """

    def __init__(
        self,
        queue: MockQueue,
        processor: Callable,
        retry_policy: RetryPolicy,
        reporter: ProgressReporter,
    ) -> None:
        self._queue = queue
        self._processor = processor
        self._policy = retry_policy
        self._reporter = reporter

    def run(self) -> PipelineResult:
        """Drain the queue, applying retries and DLQ as needed.

        Returns a PipelineResult with final counts and DLQ contents.
        """
        dead_letter: List[dict] = []
        start = time.time()

        while True:
            item = self._queue.dequeue()
            if item is None:
                # Queue is exhausted — we're done.
                break

            self._process_with_retry(item, dead_letter)

        duration = time.time() - start

        return PipelineResult(
            processed=self._reporter.processed,
            failed=self._reporter.failed,
            dead_letter_queue=dead_letter,
            duration_seconds=duration,
        )

    def _process_with_retry(self, item: Any, dead_letter: List[dict]) -> None:
        """Attempt to process a single item, retrying on transient failures."""
        attempt = 1
        last_error: Optional[Exception] = None

        while True:
            try:
                self._processor(item)
                # Success: if we retried, close out the retry counter.
                if attempt > 1:
                    self._reporter.record_retry_end(item)
                self._reporter.record_processed(item)
                return
            except Exception as exc:
                last_error = exc

                if self._policy.should_retry(attempt):
                    # Transient failure — log retry, sleep, then try again.
                    self._reporter.record_retry_start(item)
                    wait = self._policy.wait_seconds(attempt)
                    time.sleep(wait)
                    attempt += 1
                    # Note: record_retry_end is called when the item ultimately
                    # succeeds (above) or is sent to the DLQ (below).
                else:
                    # Exhausted all retries — send to dead-letter queue.
                    if attempt > 1:
                        self._reporter.record_retry_end(item)
                    self._reporter.record_failed(item)
                    dead_letter.append({
                        "item": item,
                        "error": str(last_error),
                    })
                    return


# ─────────────────────────────────────────────────────────────────────────────
# CLI entry point (optional — demonstrates the pipeline with a mock workload)
# ─────────────────────────────────────────────────────────────────────────────

def _demo() -> None:
    """Run the pipeline against a small demo workload with visible output."""
    import random

    random.seed(42)

    # Simulate a queue of 10 work items
    items = [f"job-{i:02d}" for i in range(10)]

    # Processor that randomly fails ~30% of the time
    def flaky_processor(item: str) -> None:
        if random.random() < 0.3:
            raise RuntimeError(f"Transient failure while processing {item!r}")
        print(f"  ✓ processed {item}")

    queue = MockQueue(items)
    policy = RetryPolicy(max_retries=3, base_delay=0.1, max_delay=1.0)

    def on_progress(event: str, item: Any) -> None:
        if event == "retry_start":
            print(f"  ↩ retrying {item}…")
        elif event == "failed":
            print(f"  ✗ permanently failed {item}")

    reporter = ProgressReporter(on_progress=on_progress)
    pipeline = Pipeline(queue=queue, processor=flaky_processor,
                        retry_policy=policy, reporter=reporter)

    print("Starting pipeline demo…")
    result = pipeline.run()
    print()
    print(result.summary())


if __name__ == "__main__":
    _demo()
