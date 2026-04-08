# Error-retry pipeline with exponential backoff, dead-letter queue,
# and progress reporting. All queue/processing operations are mockable.

import time
import random


def retry_with_backoff(processor, item, *, max_retries=3, base_delay=1.0):
    """Call processor(item) with exponential backoff on failure.

    Returns the processor result on success.
    Raises the last exception after max_retries attempts.
    """
    last_error = None
    for attempt in range(max_retries):
        try:
            return processor(item)
        except Exception as e:
            last_error = e
            if attempt < max_retries - 1:
                time.sleep(base_delay * (2 ** attempt))
    raise last_error


class DeadLetterQueue:
    """Collects items that permanently failed processing."""

    def __init__(self):
        self.items: list[tuple] = []

    def add(self, item, error: Exception):
        self.items.append((item, error))

    def __len__(self):
        return len(self.items)

    def __iter__(self):
        return iter(self.items)


class ProgressReporter:
    """Tracks pipeline progress: successes, retries, and failures."""

    def __init__(self, callback=None):
        self.processed = 0
        self.failed = 0
        self.retrying = 0
        self._callback = callback

    def _emit(self, event: dict):
        if self._callback:
            self._callback(event)

    def record_success(self, item):
        self.processed += 1
        self._emit({"type": "success", "item": item})

    def record_retry(self, item, attempt: int):
        self.retrying += 1
        self._emit({"type": "retry", "item": item, "attempt": attempt})

    def record_failure(self, item, error: Exception):
        self.failed += 1
        self._emit({"type": "failure", "item": item, "error": str(error)})

    def summary(self) -> dict:
        return {
            "processed": self.processed,
            "failed": self.failed,
            "retrying": self.retrying,
            "total": self.processed + self.failed + self.retrying,
        }


class Pipeline:
    """Processes items from a queue with retry, DLQ, and progress tracking.

    All dependencies (queue, processor) are injected for testability.
    """

    def __init__(self, queue, processor, *, max_retries=3, base_delay=1.0,
                 progress_callback=None):
        self.queue = queue
        self.processor = processor
        self.max_retries = max_retries
        self.base_delay = base_delay
        self.dlq = DeadLetterQueue()
        self.reporter = ProgressReporter(callback=progress_callback)

    def run(self) -> dict:
        """Process all items in the queue and return a final summary."""
        for item in self.queue:
            self._process_item(item)
        summary = self.reporter.summary()
        summary["dlq_count"] = len(self.dlq)
        return summary

    def _process_item(self, item):
        """Try processing a single item with retries; send to DLQ on failure."""
        last_error = None
        for attempt in range(self.max_retries):
            try:
                self.processor(item)
                self.reporter.record_success(item)
                return
            except Exception as e:
                last_error = e
                if attempt < self.max_retries - 1:
                    self.reporter.record_retry(item, attempt + 1)
                    time.sleep(self.base_delay * (2 ** attempt))

        # All retries exhausted — move to dead-letter queue
        self.reporter.record_failure(item, last_error)
        self.dlq.add(item, last_error)


# ── Demo: run with a randomly-failing mock processor ────────────────────────

if __name__ == "__main__":
    def mock_processor(item):
        """Simulates a processor that fails ~40% of the time."""
        if random.random() < 0.4:
            raise RuntimeError(f"Random failure processing '{item}'")
        return item

    def on_progress(event):
        print(f"  [{event['type'].upper()}] {event.get('item', '')}")

    mock_queue = [f"task-{i}" for i in range(10)]

    print("Starting pipeline with 10 items, max 3 retries, base_delay=0.1s\n")
    p = Pipeline(mock_queue, mock_processor, max_retries=3, base_delay=0.1,
                 progress_callback=on_progress)
    summary = p.run()

    print(f"\n{'='*40}")
    print("Final Summary:")
    for k, v in summary.items():
        print(f"  {k}: {v}")

    if p.dlq:
        print("\nDead-Letter Queue:")
        for item, err in p.dlq:
            print(f"  {item}: {err}")
