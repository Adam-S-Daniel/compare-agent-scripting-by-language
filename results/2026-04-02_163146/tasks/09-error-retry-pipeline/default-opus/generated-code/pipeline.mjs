/**
 * Error-Retry Pipeline
 *
 * Processes items from a queue with exponential backoff retry and dead-letter
 * queue support. All queue and processing operations are mockable.
 *
 * Built using TDD — each component was developed test-first:
 *   1. Queue         — generic FIFO queue (mockable via duck-typing)
 *   2. ExponentialBackoff — configurable retry delay strategy
 *   3. DeadLetterQueue    — stores permanently failed items with metadata
 *   4. Pipeline           — orchestrates processing with retry and progress
 */

// =============================================================================
// Queue: A simple generic FIFO queue.
// Designed with a minimal interface so it can easily be replaced by a mock.
// Any object with dequeue(), isEmpty(), and size() methods works as a source.
// =============================================================================

export class Queue {
  /** @param {Array} [initialItems] - optional items to pre-load */
  constructor(initialItems = []) {
    this._data = [...initialItems];
  }

  /** Add an item to the back of the queue. */
  enqueue(item) {
    this._data.push(item);
  }

  /** Remove and return the item at the front, or undefined if empty. */
  dequeue() {
    return this._data.shift();
  }

  /** Number of items currently in the queue. */
  size() {
    return this._data.length;
  }

  /** Whether the queue has no items. */
  isEmpty() {
    return this._data.length === 0;
  }

  /** Return a snapshot of all items (does not mutate the queue). */
  items() {
    return [...this._data];
  }
}

// =============================================================================
// ExponentialBackoff: Computes the delay (ms) for a given retry attempt.
//   delay(attempt) = min(baseMs * 2^attempt, maxMs)
// =============================================================================

export class ExponentialBackoff {
  /**
   * @param {object} [opts]
   * @param {number} [opts.baseMs=100]  - base delay in milliseconds
   * @param {number} [opts.maxMs=30000] - maximum delay cap in milliseconds
   */
  constructor({ baseMs = 100, maxMs = 30000 } = {}) {
    this.baseMs = baseMs;
    this.maxMs = maxMs;
  }

  /** Compute delay for the given zero-based attempt number. */
  delay(attempt) {
    const computed = this.baseMs * Math.pow(2, attempt);
    return Math.min(computed, this.maxMs);
  }
}

// =============================================================================
// DeadLetterQueue: Records items that have permanently failed processing.
// Each entry includes the original item, the final error, and attempt count.
// =============================================================================

export class DeadLetterQueue {
  constructor() {
    this._entries = [];
  }

  /**
   * Record a permanently failed item.
   * @param {*} item      - the original queue item
   * @param {Error} error - the error from the last attempt
   * @param {number} attempts - total number of processing attempts
   */
  add(item, error, attempts) {
    this._entries.push({
      item,
      error,
      attempts,
      timestamp: new Date(),
    });
  }

  /** Return all dead-letter entries. */
  entries() {
    return [...this._entries];
  }

  /** Number of dead-lettered items. */
  size() {
    return this._entries.length;
  }

  /** Whether the dead-letter queue has any entries. */
  isEmpty() {
    return this._entries.length === 0;
  }
}

// =============================================================================
// Pipeline: Orchestrates queue processing with retry logic, dead-lettering,
// and progress reporting.
//
// All dependencies are injected, making the pipeline fully testable:
//   - source:    any object with dequeue(), isEmpty(), size()
//   - processor: async function(item) that processes a single item
//   - backoff:   any object with delay(attempt) returning ms
//   - sleepFn:   async function(ms) — defaults to real setTimeout, mockable
//   - onProgress: callback for progress events
// =============================================================================

/** Default sleep using setTimeout — replaced in tests. */
const defaultSleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

export class Pipeline {
  /**
   * @param {object} opts
   * @param {object} opts.source      - queue to read items from
   * @param {function} opts.processor - async function to process each item
   * @param {number} opts.maxRetries  - max retry attempts per item (0 = no retries)
   * @param {object} opts.backoff     - backoff strategy with delay(attempt)
   * @param {function} [opts.sleepFn] - async sleep function (for testing)
   * @param {function} [opts.onProgress] - progress callback
   */
  constructor({ source, processor, maxRetries, backoff, sleepFn, onProgress }) {
    this.source = source;
    this.processor = processor;
    this.maxRetries = maxRetries;
    this.backoff = backoff;
    this.sleepFn = sleepFn || defaultSleep;
    this.onProgress = onProgress || (() => {});
    this.deadLetterQueue = new DeadLetterQueue();
  }

  /**
   * Run the pipeline: drain the source queue, processing each item with
   * retry logic. Returns a summary when complete.
   */
  async run() {
    const startTime = Date.now();

    // Snapshot the total item count before we start draining
    const totalItems = this.source.size();

    let processed = 0;
    let failed = 0;
    let retried = 0;

    // Drain items from the source queue one at a time
    while (!this.source.isEmpty()) {
      const item = this.source.dequeue();
      let succeeded = false;
      let attempts = 0;
      let lastError = null;

      // Try processing: 1 initial attempt + up to maxRetries retries
      for (let attempt = 0; attempt <= this.maxRetries; attempt++) {
        attempts++;

        // If this is a retry (not the first attempt), apply backoff delay
        if (attempt > 0) {
          retried++;
          const delayMs = this.backoff.delay(attempt - 1);
          await this.sleepFn(delayMs);

          // Report retry progress
          this._emitProgress({
            item,
            status: "retrying",
            attempt,
            processed,
            failed,
            retrying: 1,
            remaining: this.source.size(),
          });
        }

        try {
          await this.processor(item);
          succeeded = true;
          break;
        } catch (err) {
          // Normalize non-Error thrown values into Error objects
          lastError = err instanceof Error ? err : new Error(String(err));
        }
      }

      if (succeeded) {
        processed++;
        this._emitProgress({
          item,
          status: "processed",
          processed,
          failed,
          retrying: 0,
          remaining: this.source.size(),
        });
      } else {
        // Exhausted all retries — move to dead-letter queue
        failed++;
        this.deadLetterQueue.add(item, lastError, attempts);
        this._emitProgress({
          item,
          status: "dead-lettered",
          error: lastError,
          processed,
          failed,
          retrying: 0,
          remaining: this.source.size(),
        });
      }
    }

    return {
      totalItems,
      processed,
      failed,
      retried,
      deadLettered: this.deadLetterQueue.size(),
      deadLetteredItems: this.deadLetterQueue.entries(),
      durationMs: Date.now() - startTime,
    };
  }

  /** Emit a progress event to the registered callback. */
  _emitProgress(event) {
    try {
      this.onProgress(event);
    } catch {
      // Never let a progress callback error crash the pipeline
    }
  }
}
