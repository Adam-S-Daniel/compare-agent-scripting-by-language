# ErrorRetryPipeline.Tests.ps1
# Pester tests for the Error Retry Pipeline.
# TDD approach: each test is written BEFORE the implementation code,
# then the minimum code to pass it is added, then we refactor.

# Load the module under test
$ModulePath = Join-Path $PSScriptRoot 'ErrorRetryPipeline.psm1'
Import-Module $ModulePath -Force

# ---------------------------------------------------------------------------
# SECTION 1: Queue operations
# ---------------------------------------------------------------------------
Describe 'New-Queue' {
    It 'creates a queue object with the supplied items' {
        $q = New-Queue -Items @('a', 'b', 'c')
        $q | Should -Not -BeNullOrEmpty
        $q.Items.Count | Should -Be 3
    }

    It 'creates an empty queue when no items are supplied' {
        $q = New-Queue -Items @()
        $q.Items.Count | Should -Be 0
    }
}

Describe 'Get-NextQueueItem' {
    It 'dequeues items in FIFO order' {
        $q = New-Queue -Items @('first', 'second', 'third')
        $item = Get-NextQueueItem -Queue $q
        $item | Should -Be 'first'
        $q.Items.Count | Should -Be 2
    }

    It 'returns $null when the queue is empty' {
        $q = New-Queue -Items @()
        $item = Get-NextQueueItem -Queue $q
        $item | Should -BeNullOrEmpty
    }
}

# ---------------------------------------------------------------------------
# SECTION 2: Dead-letter queue
# ---------------------------------------------------------------------------
Describe 'New-DeadLetterQueue' {
    It 'creates an empty dead-letter queue' {
        $dlq = New-DeadLetterQueue
        $dlq | Should -Not -BeNullOrEmpty
        $dlq.Items.Count | Should -Be 0
    }
}

Describe 'Add-ToDeadLetterQueue' {
    It 'adds a failed item with its error message to the DLQ' {
        $dlq = New-DeadLetterQueue
        Add-ToDeadLetterQueue -Queue $dlq -Item 'broken-item' -Reason 'Processing failed after 3 retries'
        $dlq.Items.Count | Should -Be 1
        $dlq.Items[0].Item   | Should -Be 'broken-item'
        $dlq.Items[0].Reason | Should -Be 'Processing failed after 3 retries'
    }
}

# ---------------------------------------------------------------------------
# SECTION 3: Item processor (mockable)
# ---------------------------------------------------------------------------
Describe 'Invoke-ProcessItem' {
    It 'calls the supplied processor scriptblock with the item' {
        # Use a hashtable (reference type) so the scriptblock can mutate shared state.
        # Plain array $called += $item would create a local copy inside the scriptblock.
        $state = @{ called = @() }
        $processor = { param($item) $state.called += $item; return $true }

        Invoke-ProcessItem -Item 'hello' -Processor $processor
        $state.called | Should -Contain 'hello'
    }

    It 'returns $true when the processor succeeds' {
        $processor = { param($item) return $true }
        $result = Invoke-ProcessItem -Item 'x' -Processor $processor
        $result | Should -Be $true
    }

    It 'returns $false when the processor throws' {
        $processor = { param($item) throw "simulated failure" }
        $result = Invoke-ProcessItem -Item 'x' -Processor $processor
        $result | Should -Be $false
    }
}

# ---------------------------------------------------------------------------
# SECTION 4: Exponential backoff retry
# ---------------------------------------------------------------------------
Describe 'Invoke-WithRetry' {
    It 'succeeds immediately if the processor returns $true on first attempt' {
        # $result.Attempts comes from Invoke-WithRetry's own counter, not the scriptblock var.
        $processor = { param($item) return $true }

        $result = Invoke-WithRetry -Item 'x' -Processor $processor -MaxRetries 3 -BaseDelayMs 0
        $result.Success  | Should -Be $true
        $result.Attempts | Should -Be 1
    }

    It 'retries up to MaxRetries times before giving up' {
        # Always fails — no shared state needed.
        $processor = { param($item) throw "always fails" }

        $result = Invoke-WithRetry -Item 'x' -Processor $processor -MaxRetries 3 -BaseDelayMs 0
        $result.Success  | Should -Be $false
        $result.Attempts | Should -Be 4  # 1 initial + 3 retries
    }

    It 'succeeds on a retry if the processor eventually returns $true' {
        # Use a hashtable so the counter persists across scriptblock invocations.
        # Plain integer variables are copied into a local scope on each invocation.
        $state = @{ attempts = 0 }
        # Fail twice, succeed on third attempt
        $processor = {
            param($item)
            $state.attempts++
            if ($state.attempts -lt 3) { throw "not yet" }
            return $true
        }

        $result = Invoke-WithRetry -Item 'x' -Processor $processor -MaxRetries 3 -BaseDelayMs 0
        $result.Success  | Should -Be $true
        $result.Attempts | Should -Be 3
    }

    It 'calculates exponential delay: 2^(attempt-1) * BaseDelayMs' {
        # We verify the delay values embedded in the result without actually sleeping.
        $processor = { param($item) throw "always fails" }

        $result = Invoke-WithRetry -Item 'x' -Processor $processor -MaxRetries 3 -BaseDelayMs 100
        # Delays for attempts 2,3,4 should be 100, 200, 400 ms
        $result.Delays | Should -Be @(100, 200, 400)
    }
}

# ---------------------------------------------------------------------------
# SECTION 5: Progress reporting
# ---------------------------------------------------------------------------
Describe 'New-PipelineProgress' {
    It 'creates a progress object with zero counters' {
        $progress = New-PipelineProgress -TotalItems 10
        $progress.Total     | Should -Be 10
        $progress.Processed | Should -Be 0
        $progress.Failed    | Should -Be 0
        $progress.Retrying  | Should -Be 0
    }
}

Describe 'Update-PipelineProgress' {
    It 'increments Processed counter' {
        $p = New-PipelineProgress -TotalItems 5
        Update-PipelineProgress -Progress $p -Event 'Processed'
        $p.Processed | Should -Be 1
    }

    It 'increments Failed counter' {
        $p = New-PipelineProgress -TotalItems 5
        Update-PipelineProgress -Progress $p -Event 'Failed'
        $p.Failed | Should -Be 1
    }

    It 'increments then decrements Retrying counter' {
        $p = New-PipelineProgress -TotalItems 5
        Update-PipelineProgress -Progress $p -Event 'RetryStart'
        $p.Retrying | Should -Be 1
        Update-PipelineProgress -Progress $p -Event 'RetryEnd'
        $p.Retrying | Should -Be 0
    }
}

# ---------------------------------------------------------------------------
# SECTION 6: Full pipeline orchestration
# ---------------------------------------------------------------------------
Describe 'Invoke-Pipeline' {
    It 'processes all items from the queue and reports a summary' {
        $items = @('item1', 'item2', 'item3')
        # All items succeed
        $processor = { param($item) return $true }

        $summary = Invoke-Pipeline -Items $items -Processor $processor -MaxRetries 2 -BaseDelayMs 0

        $summary.TotalItems      | Should -Be 3
        $summary.ProcessedItems  | Should -Be 3
        $summary.FailedItems     | Should -Be 0
        $summary.DeadLetterItems | Should -Be 0
    }

    It 'puts permanently-failed items into the dead-letter queue' {
        $items = @('good', 'bad', 'good2')
        # 'bad' always fails
        $processor = {
            param($item)
            if ($item -eq 'bad') { throw "item is bad" }
            return $true
        }

        $summary = Invoke-Pipeline -Items $items -Processor $processor -MaxRetries 2 -BaseDelayMs 0

        $summary.TotalItems      | Should -Be 3
        $summary.ProcessedItems  | Should -Be 2
        $summary.FailedItems     | Should -Be 1
        $summary.DeadLetterItems | Should -Be 1
        $summary.DeadLetterQueue[0].Item | Should -Be 'bad'
    }

    It 'retries a transiently-failing item and counts it as processed' {
        $callCounts = @{}
        $processor = {
            param($item)
            if (-not $callCounts.ContainsKey($item)) { $callCounts[$item] = 0 }
            $callCounts[$item]++
            # Fail twice then succeed
            if ($callCounts[$item] -lt 3) { throw "transient" }
            return $true
        }

        $summary = Invoke-Pipeline -Items @('flaky') -Processor $processor -MaxRetries 3 -BaseDelayMs 0

        $summary.ProcessedItems | Should -Be 1
        $summary.FailedItems    | Should -Be 0
    }

    It 'returns a human-readable summary string' {
        $processor = { param($item) return $true }
        $summary = Invoke-Pipeline -Items @('a', 'b') -Processor $processor -MaxRetries 1 -BaseDelayMs 0

        $summary.SummaryText | Should -Match 'Total'
        $summary.SummaryText | Should -Match '2'
    }
}
