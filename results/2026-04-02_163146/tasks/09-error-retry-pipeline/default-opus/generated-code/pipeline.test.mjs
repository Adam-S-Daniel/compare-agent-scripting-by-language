/**
 * TDD tests for the error-retry pipeline.
 *
 * Approach: We build the pipeline incrementally using red/green/refactor cycles.
 * Each describe block corresponds to one TDD cycle. Tests were written FIRST (red),
 * then minimal code was added to pass (green), then refactored as needed.
 *
 * Uses Node 20's built-in test runner — zero external dependencies.
 */

import { describe, it, beforeEach, mock } from "node:test";
import assert from "node:assert/strict";

import {
  Queue,
  ExponentialBackoff,
  DeadLetterQueue,
  Pipeline,
} from "./pipeline.mjs";

// =============================================================================
// TDD CYCLE 1 (RED→GREEN): Basic Queue — FIFO enqueue/dequeue
// The simplest building block. We need a mockable queue to feed items into
// the pipeline and to serve as the dead-letter queue.
// =============================================================================

describe("Queue", () => {
  let q;

  beforeEach(() => {
    q = new Queue();
  });

  it("should enqueue and dequeue in FIFO order", () => {
    q.enqueue("a");
    q.enqueue("b");
    q.enqueue("c");

    assert.equal(q.dequeue(), "a");
    assert.equal(q.dequeue(), "b");
    assert.equal(q.dequeue(), "c");
  });

  it("should return undefined when dequeuing from empty queue", () => {
    assert.equal(q.dequeue(), undefined);
  });

  it("should report its size", () => {
    assert.equal(q.size(), 0);
    q.enqueue(1);
    q.enqueue(2);
    assert.equal(q.size(), 2);
    q.dequeue();
    assert.equal(q.size(), 1);
  });

  it("should report whether it is empty", () => {
    assert.equal(q.isEmpty(), true);
    q.enqueue("x");
    assert.equal(q.isEmpty(), false);
  });

  it("should return all items as an array snapshot", () => {
    q.enqueue("a");
    q.enqueue("b");
    assert.deepEqual(q.items(), ["a", "b"]);
  });

  it("should allow bulk-loading items via constructor", () => {
    const q2 = new Queue(["x", "y", "z"]);
    assert.equal(q2.size(), 3);
    assert.equal(q2.dequeue(), "x");
  });
});

// =============================================================================
// TDD CYCLE 2 (RED→GREEN): Exponential Backoff — compute delay for each retry
// The retry strategy needs to be pluggable. ExponentialBackoff computes the
// delay (in ms) for a given attempt number with configurable base and cap.
// =============================================================================

describe("ExponentialBackoff", () => {
  it("should compute delay as base * 2^attempt", () => {
    // Default base = 100ms
    const backoff = new ExponentialBackoff({ baseMs: 100 });
    assert.equal(backoff.delay(0), 100); // 100 * 2^0 = 100
    assert.equal(backoff.delay(1), 200); // 100 * 2^1 = 200
    assert.equal(backoff.delay(2), 400); // 100 * 2^2 = 400
    assert.equal(backoff.delay(3), 800); // 100 * 2^3 = 800
  });

  it("should cap the delay at maxMs", () => {
    const backoff = new ExponentialBackoff({ baseMs: 100, maxMs: 500 });
    assert.equal(backoff.delay(0), 100);
    assert.equal(backoff.delay(3), 500); // would be 800 but capped at 500
    assert.equal(backoff.delay(10), 500); // still capped
  });

  it("should use sensible defaults", () => {
    const backoff = new ExponentialBackoff();
    // Default: baseMs=100, maxMs=30000
    assert.equal(backoff.delay(0), 100);
    assert.equal(backoff.delay(20), 30000); // capped at default max
  });
});

// =============================================================================
// TDD CYCLE 3 (RED→GREEN): Dead-Letter Queue — record failed items with metadata
// Items that exhaust all retries go here with the error details.
// =============================================================================

describe("DeadLetterQueue", () => {
  it("should add failed items with error and attempt count", () => {
    const dlq = new DeadLetterQueue();
    const error = new Error("kaboom");
    dlq.add({ id: 1, data: "test" }, error, 3);

    const entries = dlq.entries();
    assert.equal(entries.length, 1);
    assert.deepEqual(entries[0].item, { id: 1, data: "test" });
    assert.equal(entries[0].error.message, "kaboom");
    assert.equal(entries[0].attempts, 3);
    assert.ok(entries[0].timestamp instanceof Date);
  });

  it("should report its size", () => {
    const dlq = new DeadLetterQueue();
    assert.equal(dlq.size(), 0);
    dlq.add("item1", new Error("e1"), 1);
    dlq.add("item2", new Error("e2"), 2);
    assert.equal(dlq.size(), 2);
  });

  it("should indicate whether it is empty", () => {
    const dlq = new DeadLetterQueue();
    assert.equal(dlq.isEmpty(), true);
    dlq.add("item", new Error("err"), 1);
    assert.equal(dlq.isEmpty(), false);
  });
});

// =============================================================================
// TDD CYCLE 4 (RED→GREEN): Pipeline — process all items successfully
// The simplest pipeline scenario: every item processes without error.
// =============================================================================

describe("Pipeline — all items succeed", () => {
  it("should process every item and report correct summary", async () => {
    const source = new Queue(["a", "b", "c"]);
    // Mock processor that always succeeds
    const processor = mock.fn(async (item) => `processed:${item}`);

    const pipeline = new Pipeline({
      source,
      processor,
      maxRetries: 3,
      backoff: new ExponentialBackoff({ baseMs: 0 }), // no delay in tests
    });

    const summary = await pipeline.run();

    assert.equal(summary.totalItems, 3);
    assert.equal(summary.processed, 3);
    assert.equal(summary.failed, 0);
    assert.equal(summary.retried, 0);
    assert.equal(summary.deadLettered, 0);
    assert.equal(processor.mock.calls.length, 3);
  });
});

// =============================================================================
// TDD CYCLE 5 (RED→GREEN): Pipeline — retry on transient failures
// Items that fail should be retried up to maxRetries times with backoff.
// =============================================================================

describe("Pipeline — retry on transient failure", () => {
  it("should retry a failing item and succeed on later attempt", async () => {
    const source = new Queue(["flaky"]);

    // Fail twice, then succeed on 3rd attempt
    let callCount = 0;
    const processor = async (item) => {
      callCount++;
      if (callCount <= 2) {
        throw new Error(`fail #${callCount}`);
      }
      return `ok:${item}`;
    };

    const pipeline = new Pipeline({
      source,
      processor,
      maxRetries: 5,
      backoff: new ExponentialBackoff({ baseMs: 0 }),
    });

    const summary = await pipeline.run();

    assert.equal(summary.processed, 1);
    assert.equal(summary.failed, 0);
    assert.equal(summary.retried, 2); // 2 retries before success
    assert.equal(summary.deadLettered, 0);
    assert.equal(callCount, 3); // called 3 times total
  });

  it("should apply exponential backoff between retries", async () => {
    const source = new Queue(["item"]);
    const delays = [];

    // Custom sleep function to capture delays without actually waiting
    const sleepFn = async (ms) => {
      delays.push(ms);
    };

    // Fail 3 times, then succeed
    let callCount = 0;
    const processor = async () => {
      callCount++;
      if (callCount <= 3) throw new Error("transient");
      return "ok";
    };

    const pipeline = new Pipeline({
      source,
      processor,
      maxRetries: 5,
      backoff: new ExponentialBackoff({ baseMs: 100 }),
      sleepFn,
    });

    await pipeline.run();

    // Should have 3 delay calls: 100, 200, 400
    assert.equal(delays.length, 3);
    assert.equal(delays[0], 100);
    assert.equal(delays[1], 200);
    assert.equal(delays[2], 400);
  });
});

// =============================================================================
// TDD CYCLE 6 (RED→GREEN): Pipeline — dead-letter queue for permanent failures
// Items that exhaust all retries should be moved to the dead-letter queue.
// =============================================================================

describe("Pipeline — dead-letter queue", () => {
  it("should move permanently failing items to dead-letter queue", async () => {
    const source = new Queue(["doomed"]);

    // Always fails
    const processor = async () => {
      throw new Error("permanent failure");
    };

    const pipeline = new Pipeline({
      source,
      processor,
      maxRetries: 3,
      backoff: new ExponentialBackoff({ baseMs: 0 }),
    });

    const summary = await pipeline.run();

    assert.equal(summary.processed, 0);
    assert.equal(summary.failed, 1); // 1 item permanently failed
    assert.equal(summary.deadLettered, 1);

    // Verify the DLQ contents
    const dlqEntries = pipeline.deadLetterQueue.entries();
    assert.equal(dlqEntries.length, 1);
    assert.equal(dlqEntries[0].item, "doomed");
    assert.equal(dlqEntries[0].error.message, "permanent failure");
    assert.equal(dlqEntries[0].attempts, 4); // 1 initial + 3 retries
  });

  it("should handle mix of successful and failing items", async () => {
    const source = new Queue(["ok1", "bad", "ok2"]);

    const processor = async (item) => {
      if (item === "bad") throw new Error("always fails");
      return `done:${item}`;
    };

    const pipeline = new Pipeline({
      source,
      processor,
      maxRetries: 2,
      backoff: new ExponentialBackoff({ baseMs: 0 }),
    });

    const summary = await pipeline.run();

    assert.equal(summary.totalItems, 3);
    assert.equal(summary.processed, 2);
    assert.equal(summary.failed, 1);
    assert.equal(summary.deadLettered, 1);
  });
});

// =============================================================================
// TDD CYCLE 7 (RED→GREEN): Pipeline — progress reporting
// The pipeline should emit progress events as items are processed.
// =============================================================================

describe("Pipeline — progress reporting", () => {
  it("should report progress for each item outcome", async () => {
    const source = new Queue(["a", "b"]);
    const processor = mock.fn(async (item) => item);
    const progressEvents = [];

    const pipeline = new Pipeline({
      source,
      processor,
      maxRetries: 3,
      backoff: new ExponentialBackoff({ baseMs: 0 }),
      onProgress: (event) => progressEvents.push(event),
    });

    await pipeline.run();

    // Should have 2 progress events (one per item, both succeed)
    assert.equal(progressEvents.length, 2);

    // Each event should have the expected shape
    for (const event of progressEvents) {
      assert.ok("item" in event);
      assert.ok("status" in event);
      assert.ok("processed" in event);
      assert.ok("failed" in event);
      assert.ok("retrying" in event);
      assert.ok("remaining" in event);
    }

    assert.equal(progressEvents[0].status, "processed");
    assert.equal(progressEvents[0].processed, 1);
    assert.equal(progressEvents[0].remaining, 1);

    assert.equal(progressEvents[1].status, "processed");
    assert.equal(progressEvents[1].processed, 2);
    assert.equal(progressEvents[1].remaining, 0);
  });

  it("should report retry progress events", async () => {
    const source = new Queue(["flaky"]);
    const progressEvents = [];

    let callCount = 0;
    const processor = async () => {
      callCount++;
      if (callCount === 1) throw new Error("retry me");
      return "ok";
    };

    const pipeline = new Pipeline({
      source,
      processor,
      maxRetries: 3,
      backoff: new ExponentialBackoff({ baseMs: 0 }),
      onProgress: (event) => progressEvents.push(event),
    });

    await pipeline.run();

    // Should have: 1 retry event + 1 processed event
    const retryEvents = progressEvents.filter((e) => e.status === "retrying");
    const processedEvents = progressEvents.filter(
      (e) => e.status === "processed"
    );
    assert.equal(retryEvents.length, 1);
    assert.equal(processedEvents.length, 1);
    assert.equal(retryEvents[0].attempt, 1);
  });

  it("should report dead-lettered progress events", async () => {
    const source = new Queue(["doomed"]);
    const progressEvents = [];

    const processor = async () => {
      throw new Error("always fails");
    };

    const pipeline = new Pipeline({
      source,
      processor,
      maxRetries: 1, // only 1 retry allowed
      backoff: new ExponentialBackoff({ baseMs: 0 }),
      onProgress: (event) => progressEvents.push(event),
    });

    await pipeline.run();

    const dlqEvents = progressEvents.filter(
      (e) => e.status === "dead-lettered"
    );
    assert.equal(dlqEvents.length, 1);
    assert.equal(dlqEvents[0].item, "doomed");
    assert.ok(dlqEvents[0].error instanceof Error);
  });
});

// =============================================================================
// TDD CYCLE 8 (RED→GREEN): Pipeline — final summary
// After all items are processed, the pipeline should return a summary object.
// =============================================================================

describe("Pipeline — final summary", () => {
  it("should include all summary fields and timing info", async () => {
    const source = new Queue(["a", "b"]);
    const processor = mock.fn(async (item) => item);

    const pipeline = new Pipeline({
      source,
      processor,
      maxRetries: 3,
      backoff: new ExponentialBackoff({ baseMs: 0 }),
    });

    const summary = await pipeline.run();

    assert.equal(summary.totalItems, 2);
    assert.equal(summary.processed, 2);
    assert.equal(summary.failed, 0);
    assert.equal(summary.retried, 0);
    assert.equal(summary.deadLettered, 0);
    assert.equal(typeof summary.durationMs, "number");
    assert.ok(summary.durationMs >= 0);
    assert.deepEqual(summary.deadLetteredItems, []);
  });

  it("should include dead-lettered items in the summary", async () => {
    const source = new Queue(["bad1", "bad2"]);
    const processor = async () => {
      throw new Error("nope");
    };

    const pipeline = new Pipeline({
      source,
      processor,
      maxRetries: 0, // no retries — immediately dead-letter
      backoff: new ExponentialBackoff({ baseMs: 0 }),
    });

    const summary = await pipeline.run();

    assert.equal(summary.deadLettered, 2);
    assert.equal(summary.deadLetteredItems.length, 2);
    assert.equal(summary.deadLetteredItems[0].item, "bad1");
    assert.equal(summary.deadLetteredItems[1].item, "bad2");
  });
});

// =============================================================================
// TDD CYCLE 9 (RED→GREEN): Mockability — all queue and processor operations
// Verify that the pipeline works with custom/mocked queue implementations.
// =============================================================================

describe("Pipeline — mockability", () => {
  it("should work with a custom queue implementation", async () => {
    // A custom queue wrapping an array — proves the pipeline interface is mockable
    const customQueue = {
      _items: ["x", "y"],
      dequeue() {
        return this._items.shift();
      },
      isEmpty() {
        return this._items.length === 0;
      },
      size() {
        return this._items.length;
      },
    };

    const processor = mock.fn(async (item) => item.toUpperCase());

    const pipeline = new Pipeline({
      source: customQueue,
      processor,
      maxRetries: 1,
      backoff: new ExponentialBackoff({ baseMs: 0 }),
    });

    const summary = await pipeline.run();
    assert.equal(summary.processed, 2);
    assert.equal(processor.mock.calls.length, 2);
  });

  it("should work with a mock processor that tracks calls", async () => {
    const source = new Queue(["item1", "item2"]);
    const results = [];
    const processor = async (item) => {
      results.push(item);
      return `result:${item}`;
    };

    const pipeline = new Pipeline({
      source,
      processor,
      maxRetries: 3,
      backoff: new ExponentialBackoff({ baseMs: 0 }),
    });

    await pipeline.run();
    assert.deepEqual(results, ["item1", "item2"]);
  });

  it("should allow mocking the sleep function for testing backoff", async () => {
    const source = new Queue(["item"]);
    const sleepCalls = [];

    let attempt = 0;
    const processor = async () => {
      attempt++;
      if (attempt <= 2) throw new Error("fail");
      return "ok";
    };

    const pipeline = new Pipeline({
      source,
      processor,
      maxRetries: 5,
      backoff: new ExponentialBackoff({ baseMs: 50 }),
      sleepFn: async (ms) => sleepCalls.push(ms),
    });

    await pipeline.run();
    // 2 retries = 2 sleep calls: 50, 100
    assert.deepEqual(sleepCalls, [50, 100]);
  });
});

// =============================================================================
// TDD CYCLE 10 (REFACTOR): Edge cases
// =============================================================================

describe("Pipeline — edge cases", () => {
  it("should handle empty queue gracefully", async () => {
    const source = new Queue();
    const processor = mock.fn(async (item) => item);

    const pipeline = new Pipeline({
      source,
      processor,
      maxRetries: 3,
      backoff: new ExponentialBackoff({ baseMs: 0 }),
    });

    const summary = await pipeline.run();
    assert.equal(summary.totalItems, 0);
    assert.equal(summary.processed, 0);
    assert.equal(summary.failed, 0);
    assert.equal(processor.mock.calls.length, 0);
  });

  it("should handle processor returning falsy values", async () => {
    const source = new Queue([1, 2]);
    // Returns null/0/false — should still count as success
    const processor = async () => null;

    const pipeline = new Pipeline({
      source,
      processor,
      maxRetries: 3,
      backoff: new ExponentialBackoff({ baseMs: 0 }),
    });

    const summary = await pipeline.run();
    assert.equal(summary.processed, 2);
    assert.equal(summary.failed, 0);
  });

  it("should handle maxRetries=0 (no retries at all)", async () => {
    const source = new Queue(["item"]);
    const processor = async () => {
      throw new Error("fail");
    };

    const pipeline = new Pipeline({
      source,
      processor,
      maxRetries: 0,
      backoff: new ExponentialBackoff({ baseMs: 0 }),
    });

    const summary = await pipeline.run();
    // Should fail immediately with no retries
    assert.equal(summary.processed, 0);
    assert.equal(summary.failed, 1);
    assert.equal(summary.retried, 0);
    assert.equal(summary.deadLettered, 1);
  });

  it("should handle non-Error thrown values", async () => {
    const source = new Queue(["item"]);
    const processor = async () => {
      throw "string error"; // eslint-disable-line no-throw-literal
    };

    const pipeline = new Pipeline({
      source,
      processor,
      maxRetries: 0,
      backoff: new ExponentialBackoff({ baseMs: 0 }),
    });

    const summary = await pipeline.run();
    assert.equal(summary.deadLettered, 1);
    const entry = pipeline.deadLetterQueue.entries()[0];
    // Non-Error thrown values should be wrapped in an Error
    assert.ok(entry.error instanceof Error);
    assert.ok(entry.error.message.includes("string error"));
  });
});
