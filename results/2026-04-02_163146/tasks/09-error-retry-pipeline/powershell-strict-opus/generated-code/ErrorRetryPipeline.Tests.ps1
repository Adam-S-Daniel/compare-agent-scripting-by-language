# ErrorRetryPipeline.Tests.ps1
# Pester tests for the error-retry pipeline module.
# Follows red/green TDD methodology — each Describe block is one TDD cycle.
# Tests are structured so that each cycle builds on the previous.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    # Import the module under test
    [string]$modulePath = Join-Path $PSScriptRoot 'ErrorRetryPipeline.psm1'
    Import-Module $modulePath -Force
}

# =============================================================================
# TDD Cycle 1: Queue creation and basic dequeuing operations
# RED:   Wrote tests for New-ProcessingQueue and Get-NextQueueItem — failed (no module)
# GREEN: Implemented New-ProcessingQueue and Get-NextQueueItem
# =============================================================================
Describe 'New-ProcessingQueue' {
    It 'creates a queue from an array of items' {
        [string[]]$items = @('item1', 'item2', 'item3')
        [hashtable]$queue = New-ProcessingQueue -Items $items

        $queue | Should -Not -BeNullOrEmpty
        $queue.Items.Count | Should -Be 3
        $queue.Items[0] | Should -Be 'item1'
    }

    It 'creates an empty queue when no items provided' {
        [object[]]$items = @()
        [hashtable]$queue = New-ProcessingQueue -Items $items

        $queue.Items.Count | Should -Be 0
    }

    It 'initializes position tracker at zero' {
        [string[]]$items = @('a', 'b', 'c')
        [hashtable]$queue = New-ProcessingQueue -Items $items

        $queue.Position | Should -Be 0
    }
}

Describe 'Get-NextQueueItem' {
    It 'returns the first item from the queue' {
        [string[]]$items = @('first', 'second', 'third')
        [hashtable]$queue = New-ProcessingQueue -Items $items

        [object]$item = Get-NextQueueItem -Queue $queue
        $item | Should -Be 'first'
    }

    It 'advances the position after each call' {
        [string[]]$items = @('first', 'second')
        [hashtable]$queue = New-ProcessingQueue -Items $items

        $null = Get-NextQueueItem -Queue $queue
        [object]$item = Get-NextQueueItem -Queue $queue
        $item | Should -Be 'second'
    }

    It 'returns $null when queue is exhausted' {
        [string[]]$items = @('only')
        [hashtable]$queue = New-ProcessingQueue -Items $items

        $null = Get-NextQueueItem -Queue $queue
        [object]$result = Get-NextQueueItem -Queue $queue
        $result | Should -BeNullOrEmpty
    }
}

# =============================================================================
# TDD Cycle 2: Successful item processing via Invoke-ItemWithRetry
# RED:   Wrote test for processing a good item — failed (function didn't exist)
# GREEN: Implemented Invoke-ItemWithRetry with scriptblock processing
# =============================================================================
Describe 'Invoke-ItemWithRetry - successful processing' {
    It 'processes an item successfully on first attempt' {
        # Mock processor that always succeeds
        [scriptblock]$processor = {
            param([object]$Item)
            return "processed-$Item"
        }
        # No-op delay to avoid real waits
        [scriptblock]$noDelay = { param([int]$Ms) }

        [hashtable]$result = Invoke-ItemWithRetry -Item 'testItem' `
            -ProcessAction $processor -DelayAction $noDelay

        $result.Success | Should -BeTrue
        $result.Item | Should -Be 'testItem'
        $result.Result | Should -Be 'processed-testItem'
        $result.Attempts | Should -Be 1
        $result.Error | Should -Be ''
    }

    It 'returns the result from the processing action' {
        [scriptblock]$processor = {
            param([object]$Item)
            return @{ Value = [int]42; Source = [string]$Item }
        }
        [scriptblock]$noDelay = { param([int]$Ms) }

        [hashtable]$result = Invoke-ItemWithRetry -Item 'data' `
            -ProcessAction $processor -DelayAction $noDelay

        $result.Success | Should -BeTrue
        $result.Result.Value | Should -Be 42
    }
}

# =============================================================================
# TDD Cycle 3: Retry with exponential backoff on failure
# RED:   Wrote tests for retry behavior — failed (no retry logic)
# GREEN: Implemented exponential backoff in Invoke-ItemWithRetry
# =============================================================================
Describe 'Get-ExponentialBackoffDelay' {
    It 'calculates delay for first attempt as base delay' {
        [int]$delay = Get-ExponentialBackoffDelay -Attempt 1 -BaseDelayMs 100
        $delay | Should -Be 100
    }

    It 'doubles delay for each subsequent attempt' {
        [int]$delay1 = Get-ExponentialBackoffDelay -Attempt 1 -BaseDelayMs 100
        [int]$delay2 = Get-ExponentialBackoffDelay -Attempt 2 -BaseDelayMs 100
        [int]$delay3 = Get-ExponentialBackoffDelay -Attempt 3 -BaseDelayMs 100

        $delay1 | Should -Be 100
        $delay2 | Should -Be 200
        $delay3 | Should -Be 400
    }

    It 'caps delay at MaxDelayMs' {
        [int]$delay = Get-ExponentialBackoffDelay -Attempt 20 -BaseDelayMs 100 -MaxDelayMs 5000
        $delay | Should -Be 5000
    }
}

Describe 'Invoke-ItemWithRetry - retry behavior' {
    It 'retries on failure and succeeds on second attempt' {
        # Track call count in a hashtable (reference type)
        [hashtable]$state = @{ CallCount = [int]0 }
        [scriptblock]$flakyProcessor = {
            param([object]$Item)
            $state.CallCount++
            if ($state.CallCount -eq 1) {
                throw "Transient error"
            }
            return "ok-$Item"
        }
        [scriptblock]$noDelay = { param([int]$Ms) }

        [hashtable]$result = Invoke-ItemWithRetry -Item 'flaky' `
            -ProcessAction $flakyProcessor -MaxRetries 3 -DelayAction $noDelay

        $result.Success | Should -BeTrue
        $result.Attempts | Should -Be 2
        $result.Result | Should -Be 'ok-flaky'
    }

    It 'invokes delay between retries with correct backoff values' {
        [System.Collections.ArrayList]$delays = [System.Collections.ArrayList]::new()
        [hashtable]$state = @{ CallCount = [int]0 }

        [scriptblock]$alwaysFails = {
            param([object]$Item)
            $state.CallCount++
            throw "Error $($state.CallCount)"
        }
        [scriptblock]$trackDelay = {
            param([int]$Ms)
            [void]$delays.Add($Ms)
        }

        $null = Invoke-ItemWithRetry -Item 'x' `
            -ProcessAction $alwaysFails -MaxRetries 3 `
            -BaseDelayMs 100 -DelayAction $trackDelay

        # 3 retries = 3 delays (after attempt 1, 2, and 3; attempt 4 is the last)
        $delays.Count | Should -Be 3
        $delays[0] | Should -Be 100   # 100 * 2^0
        $delays[1] | Should -Be 200   # 100 * 2^1
        $delays[2] | Should -Be 400   # 100 * 2^2
    }
}

# =============================================================================
# TDD Cycle 4: Dead-letter queue for permanently failed items
# RED:   Wrote tests for DLQ — failed (no DLQ functions)
# GREEN: Implemented New-DeadLetterQueue and Add-DeadLetterItem
# =============================================================================
Describe 'Dead-letter queue' {
    It 'creates an empty dead-letter queue' {
        [hashtable]$dlq = New-DeadLetterQueue
        $dlq.Items.Count | Should -Be 0
    }

    It 'adds failed items with error details' {
        [hashtable]$dlq = New-DeadLetterQueue
        Add-DeadLetterItem -DeadLetterQueue $dlq -Item 'badItem' `
            -ErrorMessage 'Processing failed' -Attempts 4

        $dlq.Items.Count | Should -Be 1
        $dlq.Items[0].Item | Should -Be 'badItem'
        $dlq.Items[0].ErrorMessage | Should -Be 'Processing failed'
        $dlq.Items[0].Attempts | Should -Be 4
    }

    It 'accumulates multiple failed items' {
        [hashtable]$dlq = New-DeadLetterQueue
        Add-DeadLetterItem -DeadLetterQueue $dlq -Item 'fail1' -ErrorMessage 'err1' -Attempts 3
        Add-DeadLetterItem -DeadLetterQueue $dlq -Item 'fail2' -ErrorMessage 'err2' -Attempts 4

        $dlq.Items.Count | Should -Be 2
    }
}

Describe 'Invoke-ItemWithRetry - permanent failure' {
    It 'returns failure after exhausting all retries' {
        [scriptblock]$alwaysFails = {
            param([object]$Item)
            throw "Permanent error for $Item"
        }
        [scriptblock]$noDelay = { param([int]$Ms) }

        [hashtable]$result = Invoke-ItemWithRetry -Item 'doomed' `
            -ProcessAction $alwaysFails -MaxRetries 2 -DelayAction $noDelay

        $result.Success | Should -BeFalse
        $result.Item | Should -Be 'doomed'
        $result.Attempts | Should -Be 3  # 1 initial + 2 retries
        $result.Error | Should -BeLike '*Permanent error*'
    }
}

# =============================================================================
# TDD Cycle 5: Progress reporting
# RED:   Wrote tests for progress tracker — failed (no tracker functions)
# GREEN: Implemented New-ProgressTracker and Update-Progress
# =============================================================================
Describe 'Progress tracking' {
    It 'creates a tracker with correct total' {
        [hashtable]$tracker = New-ProgressTracker -TotalItems 10

        $tracker.TotalItems | Should -Be 10
        $tracker.Processed | Should -Be 0
        $tracker.Failed | Should -Be 0
        $tracker.Retrying | Should -Be 0
    }

    It 'increments processed count' {
        [hashtable]$tracker = New-ProgressTracker -TotalItems 5
        Update-Progress -Tracker $tracker -EventType 'Processed' -Item 'item1'

        $tracker.Processed | Should -Be 1
    }

    It 'increments failed count' {
        [hashtable]$tracker = New-ProgressTracker -TotalItems 5
        Update-Progress -Tracker $tracker -EventType 'Failed' -Item 'item1' -Message 'error'

        $tracker.Failed | Should -Be 1
    }

    It 'increments retrying count' {
        [hashtable]$tracker = New-ProgressTracker -TotalItems 5
        Update-Progress -Tracker $tracker -EventType 'Retrying' -Item 'item1'

        $tracker.Retrying | Should -Be 1
    }

    It 'records events in the event log' {
        [hashtable]$tracker = New-ProgressTracker -TotalItems 3
        Update-Progress -Tracker $tracker -EventType 'Processed' -Item 'a' -Message 'ok'
        Update-Progress -Tracker $tracker -EventType 'Failed' -Item 'b' -Message 'err'

        $tracker.Events.Count | Should -Be 2
        $tracker.Events[0].EventType | Should -Be 'Processed'
        $tracker.Events[1].EventType | Should -Be 'Failed'
        $tracker.Events[1].Message | Should -Be 'err'
    }
}

# =============================================================================
# TDD Cycle 6: Final summary generation
# RED:   Wrote tests for Get-PipelineSummary — failed (function didn't exist)
# GREEN: Implemented Get-PipelineSummary
# =============================================================================
Describe 'Get-PipelineSummary' {
    It 'generates correct summary from tracker and DLQ' {
        [hashtable]$tracker = New-ProgressTracker -TotalItems 10
        $tracker.Processed = [int]7
        $tracker.Failed = [int]3
        $tracker.Retrying = [int]5
        [hashtable]$dlq = New-DeadLetterQueue
        Add-DeadLetterItem -DeadLetterQueue $dlq -Item 'f1' -ErrorMessage 'e1' -Attempts 4
        Add-DeadLetterItem -DeadLetterQueue $dlq -Item 'f2' -ErrorMessage 'e2' -Attempts 4
        Add-DeadLetterItem -DeadLetterQueue $dlq -Item 'f3' -ErrorMessage 'e3' -Attempts 4

        [hashtable]$summary = Get-PipelineSummary -Tracker $tracker -DeadLetterQueue $dlq

        $summary.TotalItems | Should -Be 10
        $summary.Processed | Should -Be 7
        $summary.Failed | Should -Be 3
        $summary.RetryAttempts | Should -Be 5
        $summary.DeadLetterCount | Should -Be 3
        $summary.SuccessRate | Should -Be 70.0
    }

    It 'handles zero total items without division error' {
        [hashtable]$tracker = New-ProgressTracker -TotalItems 0
        [hashtable]$dlq = New-DeadLetterQueue

        [hashtable]$summary = Get-PipelineSummary -Tracker $tracker -DeadLetterQueue $dlq

        $summary.SuccessRate | Should -Be 0.0
        $summary.TotalItems | Should -Be 0
    }

    It 'includes dead-letter item details in summary' {
        [hashtable]$tracker = New-ProgressTracker -TotalItems 1
        $tracker.Failed = [int]1
        [hashtable]$dlq = New-DeadLetterQueue
        Add-DeadLetterItem -DeadLetterQueue $dlq -Item 'bad' -ErrorMessage 'boom' -Attempts 3

        [hashtable]$summary = Get-PipelineSummary -Tracker $tracker -DeadLetterQueue $dlq

        $summary.DeadLetterItems.Count | Should -Be 1
        $summary.DeadLetterItems[0].Item | Should -Be 'bad'
        $summary.DeadLetterItems[0].ErrorMessage | Should -Be 'boom'
    }
}

# =============================================================================
# TDD Cycle 7: Configurable max retries and full pipeline integration
# RED:   Wrote tests for configurable retries and Invoke-ProcessingPipeline — failed
# GREEN: Implemented Invoke-ProcessingPipeline with all features
# =============================================================================
Describe 'Invoke-ItemWithRetry - configurable max retries' {
    It 'respects MaxRetries=0 (no retries, immediate failure)' {
        [scriptblock]$alwaysFails = {
            param([object]$Item)
            throw "fail"
        }
        [scriptblock]$noDelay = { param([int]$Ms) }

        [hashtable]$result = Invoke-ItemWithRetry -Item 'x' `
            -ProcessAction $alwaysFails -MaxRetries 0 -DelayAction $noDelay

        $result.Success | Should -BeFalse
        $result.Attempts | Should -Be 1
    }

    It 'respects MaxRetries=1 (one retry allowed)' {
        [hashtable]$state = @{ CallCount = [int]0 }
        [scriptblock]$failsTwice = {
            param([object]$Item)
            $state.CallCount++
            if ($state.CallCount -le 2) { throw "fail $($state.CallCount)" }
            return "ok"
        }
        [scriptblock]$noDelay = { param([int]$Ms) }

        # With MaxRetries=1, we get 2 total attempts — both fail
        [hashtable]$result = Invoke-ItemWithRetry -Item 'x' `
            -ProcessAction $failsTwice -MaxRetries 1 -DelayAction $noDelay

        $result.Success | Should -BeFalse
        $result.Attempts | Should -Be 2
    }

    It 'succeeds if recovery happens within retry limit' {
        [hashtable]$state = @{ CallCount = [int]0 }
        [scriptblock]$failsOnce = {
            param([object]$Item)
            $state.CallCount++
            if ($state.CallCount -eq 1) { throw "transient" }
            return "recovered"
        }
        [scriptblock]$noDelay = { param([int]$Ms) }

        [hashtable]$result = Invoke-ItemWithRetry -Item 'x' `
            -ProcessAction $failsOnce -MaxRetries 1 -DelayAction $noDelay

        $result.Success | Should -BeTrue
        $result.Attempts | Should -Be 2
        $result.Result | Should -Be 'recovered'
    }
}

# =============================================================================
# Full pipeline integration tests
# =============================================================================
Describe 'Invoke-ProcessingPipeline' {
    It 'processes all items successfully when nothing fails' {
        [string[]]$items = @('a', 'b', 'c')
        [hashtable]$queue = New-ProcessingQueue -Items $items

        [scriptblock]$processor = {
            param([object]$Item)
            return "done-$Item"
        }
        [scriptblock]$noDelay = { param([int]$Ms) }

        [hashtable]$summary = Invoke-ProcessingPipeline -Queue $queue `
            -ProcessAction $processor -DelayAction $noDelay

        $summary.TotalItems | Should -Be 3
        $summary.Processed | Should -Be 3
        $summary.Failed | Should -Be 0
        $summary.DeadLetterCount | Should -Be 0
        $summary.SuccessRate | Should -Be 100.0
    }

    It 'sends permanently failed items to dead-letter queue' {
        [string[]]$items = @('good', 'bad', 'good2')
        [hashtable]$queue = New-ProcessingQueue -Items $items

        [scriptblock]$processor = {
            param([object]$Item)
            if ($Item -eq 'bad') { throw "Cannot process bad" }
            return "ok-$Item"
        }
        [scriptblock]$noDelay = { param([int]$Ms) }

        [hashtable]$summary = Invoke-ProcessingPipeline -Queue $queue `
            -ProcessAction $processor -MaxRetries 2 -DelayAction $noDelay

        $summary.Processed | Should -Be 2
        $summary.Failed | Should -Be 1
        $summary.DeadLetterCount | Should -Be 1
        $summary.DeadLetterItems[0].Item | Should -Be 'bad'
    }

    It 'reports retries in the summary' {
        [hashtable]$state = @{ Attempts = @{} }
        [string[]]$items = @('flaky')
        [hashtable]$queue = New-ProcessingQueue -Items $items

        [scriptblock]$processor = {
            param([object]$Item)
            if (-not $state.Attempts.ContainsKey($Item)) {
                $state.Attempts[$Item] = [int]0
            }
            $state.Attempts[$Item]++
            if ([int]$state.Attempts[$Item] -le 2) {
                throw "transient"
            }
            return "ok"
        }
        [scriptblock]$noDelay = { param([int]$Ms) }

        [hashtable]$summary = Invoke-ProcessingPipeline -Queue $queue `
            -ProcessAction $processor -MaxRetries 3 -DelayAction $noDelay

        $summary.Processed | Should -Be 1
        $summary.Failed | Should -Be 0
        $summary.RetryAttempts | Should -BeGreaterThan 0
    }

    It 'invokes progress callback after each item' {
        [System.Collections.ArrayList]$callbacks = [System.Collections.ArrayList]::new()
        [string[]]$items = @('x', 'y')
        [hashtable]$queue = New-ProcessingQueue -Items $items

        [scriptblock]$processor = {
            param([object]$Item)
            return $Item
        }
        [scriptblock]$noDelay = { param([int]$Ms) }
        [scriptblock]$onProgress = {
            param([hashtable]$Tracker)
            [void]$callbacks.Add($Tracker.Processed)
        }

        $null = Invoke-ProcessingPipeline -Queue $queue `
            -ProcessAction $processor -DelayAction $noDelay `
            -ProgressCallback $onProgress

        $callbacks.Count | Should -Be 2
        $callbacks[0] | Should -Be 1
        $callbacks[1] | Should -Be 2
    }

    It 'handles an empty queue gracefully' {
        [object[]]$items = @()
        [hashtable]$queue = New-ProcessingQueue -Items $items

        [scriptblock]$processor = {
            param([object]$Item)
            return $Item
        }
        [scriptblock]$noDelay = { param([int]$Ms) }

        [hashtable]$summary = Invoke-ProcessingPipeline -Queue $queue `
            -ProcessAction $processor -DelayAction $noDelay

        $summary.TotalItems | Should -Be 0
        $summary.Processed | Should -Be 0
        $summary.Failed | Should -Be 0
        $summary.SuccessRate | Should -Be 0.0
    }

    It 'uses configurable MaxRetries in the pipeline' {
        [string[]]$items = @('stubborn')
        [hashtable]$queue = New-ProcessingQueue -Items $items

        [scriptblock]$alwaysFails = {
            param([object]$Item)
            throw "nope"
        }
        [scriptblock]$noDelay = { param([int]$Ms) }

        [hashtable]$summary = Invoke-ProcessingPipeline -Queue $queue `
            -ProcessAction $alwaysFails -MaxRetries 5 -DelayAction $noDelay

        $summary.Failed | Should -Be 1
        $summary.DeadLetterCount | Should -Be 1
        # With MaxRetries=5: 1 initial + 5 retries = 6 total attempts
        $summary.DeadLetterItems[0].Attempts | Should -Be 6
    }

    It 'processes mixed success and failure items correctly' {
        [string[]]$items = @('ok1', 'fail1', 'ok2', 'fail2', 'ok3')
        [hashtable]$queue = New-ProcessingQueue -Items $items

        [scriptblock]$processor = {
            param([object]$Item)
            if ([string]$Item -like 'fail*') {
                throw "Error processing $Item"
            }
            return "result-$Item"
        }
        [scriptblock]$noDelay = { param([int]$Ms) }

        [hashtable]$summary = Invoke-ProcessingPipeline -Queue $queue `
            -ProcessAction $processor -MaxRetries 1 -DelayAction $noDelay

        $summary.TotalItems | Should -Be 5
        $summary.Processed | Should -Be 3
        $summary.Failed | Should -Be 2
        $summary.DeadLetterCount | Should -Be 2
        $summary.SuccessRate | Should -Be 60.0
    }
}
