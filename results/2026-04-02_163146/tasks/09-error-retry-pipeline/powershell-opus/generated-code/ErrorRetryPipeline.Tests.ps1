# ErrorRetryPipeline.Tests.ps1
# TDD tests for the error-retry pipeline.
# Each Describe block corresponds to a TDD cycle — the test was written FIRST (RED),
# then the minimum implementation was added to make it pass (GREEN), then refactored.
#
# NOTE: Scriptblocks that reference outer-scope variables use .GetNewClosure()
# to ensure correct scoping when invoked from within pipeline functions.
# Mutable collections use ArrayList (not array +=) so mutations are visible
# through the closure's captured reference.

BeforeAll {
    . "$PSScriptRoot/ErrorRetryPipeline.ps1"
}

# =============================================================================
# TDD Cycle 1: Queue operations (enqueue, dequeue, peek, count)
# Written FIRST to define the MockQueue interface before any implementation.
# =============================================================================
Describe 'MockQueue' {
    It 'starts empty' {
        $q = New-MockQueue
        (& $q.Count) | Should -Be 0
        (& $q.IsEmpty) | Should -BeTrue
    }

    It 'enqueues and dequeues items in FIFO order' {
        $q = New-MockQueue
        & $q.Enqueue 'a'
        & $q.Enqueue 'b'
        & $q.Enqueue 'c'
        (& $q.Count) | Should -Be 3
        (& $q.Dequeue) | Should -Be 'a'
        (& $q.Dequeue) | Should -Be 'b'
        (& $q.Dequeue) | Should -Be 'c'
        (& $q.IsEmpty) | Should -BeTrue
    }

    It 'throws on dequeue from empty queue' {
        $q = New-MockQueue
        { & $q.Dequeue } | Should -Throw '*empty*'
    }

    It 'peeks without removing' {
        $q = New-MockQueue
        & $q.Enqueue 'x'
        (& $q.Peek) | Should -Be 'x'
        (& $q.Count) | Should -Be 1
    }

    It 'returns all items via GetAll' {
        $q = New-MockQueue
        & $q.Enqueue 1
        & $q.Enqueue 2
        $all = & $q.GetAll
        $all.Count | Should -Be 2
        $all[0] | Should -Be 1
        $all[1] | Should -Be 2
    }
}

# =============================================================================
# TDD Cycle 2: Exponential backoff delay calculation
# Written FIRST to define the delay formula before implementing retry logic.
# =============================================================================
Describe 'Get-ExponentialBackoffDelay' {
    It 'returns base delay for attempt 0' {
        Get-ExponentialBackoffDelay -Attempt 0 -BaseDelayMs 100 | Should -Be 100
    }

    It 'doubles delay for each subsequent attempt' {
        Get-ExponentialBackoffDelay -Attempt 1 -BaseDelayMs 100 | Should -Be 200
        Get-ExponentialBackoffDelay -Attempt 2 -BaseDelayMs 100 | Should -Be 400
        Get-ExponentialBackoffDelay -Attempt 3 -BaseDelayMs 100 | Should -Be 800
    }

    It 'caps delay at MaxDelayMs' {
        Get-ExponentialBackoffDelay -Attempt 20 -BaseDelayMs 100 -MaxDelayMs 5000 | Should -Be 5000
    }

    It 'uses default MaxDelayMs of 30000' {
        Get-ExponentialBackoffDelay -Attempt 20 -BaseDelayMs 100 | Should -Be 30000
    }

    It 'works with custom base delay' {
        Get-ExponentialBackoffDelay -Attempt 0 -BaseDelayMs 50 | Should -Be 50
        Get-ExponentialBackoffDelay -Attempt 1 -BaseDelayMs 50 | Should -Be 100
    }
}

# =============================================================================
# TDD Cycle 3: Invoke-WithRetry — retry logic with exponential backoff
# Written FIRST to define the retry contract: success on first try, eventual
# success after retries, and exhaustion leading to failure.
# =============================================================================
Describe 'Invoke-WithRetry' {
    It 'succeeds on first attempt if scriptblock does not throw' {
        $result = Invoke-WithRetry -ScriptBlock { param($item) "processed-$item" } -Item 'A' -MaxRetries 3 -SleepAction {}
        $result.Success | Should -BeTrue
        $result.Result | Should -Be 'processed-A'
        $result.Attempts | Should -Be 1
        $result.Error | Should -BeNullOrEmpty
    }

    It 'retries and eventually succeeds' {
        # Fail twice, then succeed on 3rd attempt.
        # Use hashtable for mutable state so closure captures the reference.
        $callCount = @{ Value = 0 }
        $script = {
            param($item)
            $callCount.Value++
            if ($callCount.Value -lt 3) { throw "transient error" }
            "ok-$item"
        }.GetNewClosure()

        $result = Invoke-WithRetry -ScriptBlock $script -Item 'B' -MaxRetries 3 -SleepAction {}
        $result.Success | Should -BeTrue
        $result.Result | Should -Be 'ok-B'
        $result.Attempts | Should -Be 3
    }

    It 'fails after exhausting all retries' {
        $result = Invoke-WithRetry -ScriptBlock { param($i) throw "always fails" } -Item 'C' -MaxRetries 2 -SleepAction {}
        $result.Success | Should -BeFalse
        $result.Attempts | Should -Be 3  # 1 initial + 2 retries
        $result.Error | Should -BeLike '*always fails*'
    }

    It 'calls SleepAction with correct exponential delays between retries' {
        # Use ArrayList so .Add() mutates through the closure reference
        $delays = [System.Collections.ArrayList]::new()
        $sleepMock = { param($ms) [void]$delays.Add($ms) }.GetNewClosure()

        # Always fail so we get all backoff delays
        $null = Invoke-WithRetry -ScriptBlock { param($i) throw "fail" } -Item 'D' `
            -MaxRetries 3 -BaseDelayMs 100 -MaxDelayMs 30000 -SleepAction $sleepMock

        # Expect delays for attempts 0, 1, 2 (3 retries, sleep before each retry)
        $delays.Count | Should -Be 3
        $delays[0] | Should -Be 100   # 100 * 2^0
        $delays[1] | Should -Be 200   # 100 * 2^1
        $delays[2] | Should -Be 400   # 100 * 2^2
    }

    It 'respects MaxRetries = 0 (no retries)' {
        $result = Invoke-WithRetry -ScriptBlock { param($i) throw "no retry" } -Item 'E' -MaxRetries 0 -SleepAction {}
        $result.Success | Should -BeFalse
        $result.Attempts | Should -Be 1
    }
}

# =============================================================================
# TDD Cycle 4: Dead-letter queue — permanently failed items go to DLQ
# Written FIRST to define that failed items (after all retries) must be
# captured in a separate dead-letter queue with error details.
# =============================================================================
Describe 'Dead-letter queue behavior' {
    It 'moves permanently failed items to the dead-letter queue' {
        $source = New-MockQueue
        & $source.Enqueue 'item1'
        & $source.Enqueue 'item2'
        & $source.Enqueue 'item3'

        # item1 succeeds, item2 always fails, item3 succeeds
        $processor = {
            param($item)
            if ($item -eq 'item2') { throw "permanent failure for item2" }
            "done-$item"
        }

        $summary = Invoke-Pipeline -SourceQueue $source -ProcessorScript $processor `
            -MaxRetries 2 -SleepAction {}

        $summary.Failed | Should -Be 1
        $dlqItems = & $summary.DeadLetterQueue.GetAll
        $dlqItems.Count | Should -Be 1
        $dlqItems[0].Item | Should -Be 'item2'
        $dlqItems[0].Error | Should -BeLike '*permanent failure*'
        $dlqItems[0].Attempts | Should -Be 3  # 1 + 2 retries
    }

    It 'dead-letter queue is empty when all items succeed' {
        $source = New-MockQueue
        & $source.Enqueue 'ok1'
        & $source.Enqueue 'ok2'

        $summary = Invoke-Pipeline -SourceQueue $source `
            -ProcessorScript { param($item) "result-$item" } `
            -MaxRetries 1 -SleepAction {}

        $summary.Failed | Should -Be 0
        (& $summary.DeadLetterQueue.IsEmpty) | Should -BeTrue
    }
}

# =============================================================================
# TDD Cycle 5: Progress reporting
# Written FIRST to define the progress callback contract — it must be called
# after each item with cumulative counts and the current item status.
# =============================================================================
Describe 'Progress reporting' {
    It 'calls OnProgress callback after each item with correct cumulative data' {
        $source = New-MockQueue
        & $source.Enqueue 'p1'
        & $source.Enqueue 'p2'
        & $source.Enqueue 'p3'

        # Use ArrayList so .Add() mutates through the closure reference
        $progressReports = [System.Collections.ArrayList]::new()
        $onProgress = {
            param($report)
            [void]$progressReports.Add([PSCustomObject]$report)
        }.GetNewClosure()

        # p1 succeeds, p2 fails, p3 succeeds
        $processor = {
            param($item)
            if ($item -eq 'p2') { throw "fail p2" }
            "ok"
        }

        $null = Invoke-Pipeline -SourceQueue $source -ProcessorScript $processor `
            -MaxRetries 1 -SleepAction {} -OnProgress $onProgress

        $progressReports.Count | Should -Be 3

        # After p1: 1 processed, 0 failed
        $progressReports[0].Processed | Should -Be 1
        $progressReports[0].Failed | Should -Be 0
        $progressReports[0].CurrentItem | Should -Be 'p1'
        $progressReports[0].Status | Should -Be 'Success'
        $progressReports[0].Total | Should -Be 3

        # After p2: 1 processed, 1 failed
        $progressReports[1].Processed | Should -Be 1
        $progressReports[1].Failed | Should -Be 1
        $progressReports[1].CurrentItem | Should -Be 'p2'
        $progressReports[1].Status | Should -Be 'Failed'

        # After p3: 2 processed, 1 failed
        $progressReports[2].Processed | Should -Be 2
        $progressReports[2].Failed | Should -Be 1
        $progressReports[2].CurrentItem | Should -Be 'p3'
        $progressReports[2].Status | Should -Be 'Success'
    }

    It 'tracks items that required retries in progress reports' {
        $source = New-MockQueue
        & $source.Enqueue 'r1'

        # Fail once then succeed — requires 2 attempts
        $callCount = @{ Value = 0 }
        $processor = {
            param($item)
            $callCount.Value++
            if ($callCount.Value -lt 2) { throw "transient" }
            "ok"
        }.GetNewClosure()

        $progressReports = [System.Collections.ArrayList]::new()
        $onProgress = {
            param($r)
            [void]$progressReports.Add([PSCustomObject]$r)
        }.GetNewClosure()

        $null = Invoke-Pipeline -SourceQueue $source -ProcessorScript $processor `
            -MaxRetries 3 -SleepAction {} -OnProgress $onProgress

        $progressReports[0].Retrying | Should -Be 1
    }
}

# =============================================================================
# TDD Cycle 6: Final summary
# Written FIRST to define what the summary object must contain.
# =============================================================================
Describe 'Final summary' {
    It 'returns a complete summary with all counts' {
        $source = New-MockQueue
        & $source.Enqueue 'a'
        & $source.Enqueue 'b'
        & $source.Enqueue 'c'
        & $source.Enqueue 'd'

        # a: succeeds first try, b: fails once then succeeds, c: always fails, d: succeeds
        $attempts = @{}
        $processor = {
            param($item)
            if (-not $attempts.ContainsKey($item)) { $attempts[$item] = 0 }
            $attempts[$item]++
            if ($item -eq 'b' -and $attempts[$item] -lt 2) { throw "transient" }
            if ($item -eq 'c') { throw "permanent" }
            "done-$item"
        }.GetNewClosure()

        $summary = Invoke-Pipeline -SourceQueue $source -ProcessorScript $processor `
            -MaxRetries 2 -SleepAction {}

        $summary.TotalItems | Should -Be 4
        $summary.Processed | Should -Be 3   # a, b, d succeed
        $summary.Failed | Should -Be 1      # c fails
        $summary.Retried | Should -Be 2     # b and c required retries (>1 attempt)

        # Results array has details for each item
        $summary.Results.Count | Should -Be 4
    }

    It 'results array contains per-item details' {
        $source = New-MockQueue
        & $source.Enqueue 'x'

        $summary = Invoke-Pipeline -SourceQueue $source `
            -ProcessorScript { param($item) "val-$item" } `
            -MaxRetries 1 -SleepAction {}

        $summary.Results[0].Item | Should -Be 'x'
        $summary.Results[0].Success | Should -BeTrue
        $summary.Results[0].Attempts | Should -Be 1
        $summary.Results[0].Error | Should -BeNullOrEmpty
    }

    It 'results array captures error for failed items' {
        $source = New-MockQueue
        & $source.Enqueue 'bad'

        $summary = Invoke-Pipeline -SourceQueue $source `
            -ProcessorScript { param($item) throw "kaboom" } `
            -MaxRetries 0 -SleepAction {}

        $summary.Results[0].Item | Should -Be 'bad'
        $summary.Results[0].Success | Should -BeFalse
        $summary.Results[0].Error | Should -BeLike '*kaboom*'
    }
}

# =============================================================================
# TDD Cycle 7: Full pipeline integration test
# Written LAST as a comprehensive integration test exercising all components.
# =============================================================================
Describe 'Full pipeline integration' {
    It 'processes a realistic workload with mixed outcomes' {
        # Set up a queue of 10 items
        $source = New-MockQueue
        1..10 | ForEach-Object { & $source.Enqueue $_ }

        # Items 3 and 7 always fail; item 5 fails once then succeeds
        $attempts = @{}
        $processor = {
            param($item)
            if (-not $attempts.ContainsKey($item)) { $attempts[$item] = 0 }
            $attempts[$item]++
            if ($item -eq 3 -or $item -eq 7) { throw "permanent failure for $item" }
            if ($item -eq 5 -and $attempts[$item] -lt 2) { throw "transient failure for $item" }
            "result-$item"
        }.GetNewClosure()

        $progressLog = [System.Collections.ArrayList]::new()
        $onProgress = {
            param($r)
            [void]$progressLog.Add([PSCustomObject]$r)
        }.GetNewClosure()

        $summary = Invoke-Pipeline -SourceQueue $source -ProcessorScript $processor `
            -MaxRetries 3 -BaseDelayMs 10 -SleepAction {} -OnProgress $onProgress

        # 8 items processed successfully (1,2,4,5,6,8,9,10), 2 permanently failed (3,7)
        $summary.TotalItems | Should -Be 10
        $summary.Processed | Should -Be 8
        $summary.Failed | Should -Be 2

        # Dead-letter queue should have items 3 and 7
        $dlq = & $summary.DeadLetterQueue.GetAll
        $dlq.Count | Should -Be 2
        $dlq[0].Item | Should -Be 3
        $dlq[1].Item | Should -Be 7

        # Progress was reported for all 10 items
        $progressLog.Count | Should -Be 10

        # Final progress report should show cumulative totals
        $last = $progressLog[-1]
        $last.Processed | Should -Be 8
        $last.Failed | Should -Be 2
        $last.Total | Should -Be 10

        # Source queue should be empty after processing
        (& $source.IsEmpty) | Should -BeTrue
    }

    It 'handles empty queue gracefully' {
        $source = New-MockQueue
        $summary = Invoke-Pipeline -SourceQueue $source `
            -ProcessorScript { param($item) $item } `
            -MaxRetries 1 -SleepAction {}

        $summary.TotalItems | Should -Be 0
        $summary.Processed | Should -Be 0
        $summary.Failed | Should -Be 0
        $summary.Results.Count | Should -Be 0
        (& $summary.DeadLetterQueue.IsEmpty) | Should -BeTrue
    }

    It 'works with configurable max retries' {
        $source = New-MockQueue
        & $source.Enqueue 'test'

        $callCount = @{ Value = 0 }
        $processor = {
            param($item)
            $callCount.Value++
            throw "always fails"
        }.GetNewClosure()

        $summary = Invoke-Pipeline -SourceQueue $source -ProcessorScript $processor `
            -MaxRetries 5 -SleepAction {}

        # Should have attempted 6 times (1 initial + 5 retries)
        $summary.Results[0].Attempts | Should -Be 6
        $summary.Failed | Should -Be 1
    }
}
