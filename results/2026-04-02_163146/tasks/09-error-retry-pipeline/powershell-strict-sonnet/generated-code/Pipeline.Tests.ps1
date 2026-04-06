#Requires -Modules Pester
Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Import the module under test
$ModulePath = Join-Path $PSScriptRoot 'Pipeline.psm1'
if (Test-Path $ModulePath) {
    Import-Module $ModulePath -Force
}

Describe 'New-Queue' {
    It 'returns a hashtable with an Items array and a Name' {
        $queue = New-Queue -Name 'TestQueue'
        $queue | Should -Not -BeNullOrEmpty
        $queue.Name | Should -Be 'TestQueue'
        $queue.Items | Should -BeOfType [System.Collections.ArrayList]
        $queue.Items.Count | Should -Be 0
    }

    It 'initializes with provided items' {
        $queue = New-Queue -Name 'TestQueue' -Items @('a', 'b', 'c')
        $queue.Items.Count | Should -Be 3
    }
}

Describe 'Add-QueueItem' {
    It 'adds an item to the queue' {
        $queue = New-Queue -Name 'TestQueue'
        Add-QueueItem -Queue $queue -Item 'item1'
        $queue.Items.Count | Should -Be 1
        $queue.Items[0] | Should -Be 'item1'
    }

    It 'adds multiple items in order' {
        $queue = New-Queue -Name 'TestQueue'
        Add-QueueItem -Queue $queue -Item 'first'
        Add-QueueItem -Queue $queue -Item 'second'
        $queue.Items[0] | Should -Be 'first'
        $queue.Items[1] | Should -Be 'second'
    }
}

Describe 'Get-QueueItem' {
    It 'returns null when queue is empty' {
        $queue = New-Queue -Name 'TestQueue'
        $result = Get-QueueItem -Queue $queue
        $result | Should -BeNullOrEmpty
    }

    It 'dequeues and returns the first item (FIFO)' {
        $queue = New-Queue -Name 'TestQueue' -Items @('first', 'second')
        $item = Get-QueueItem -Queue $queue
        $item | Should -Be 'first'
        $queue.Items.Count | Should -Be 1
    }

    It 'removes item from queue after retrieval' {
        $queue = New-Queue -Name 'TestQueue' -Items @('only')
        Get-QueueItem -Queue $queue | Out-Null
        $queue.Items.Count | Should -Be 0
    }
}

Describe 'Invoke-WithRetry' {
    It 'returns result on first successful attempt' {
        $processor = { param($item) "processed:$item" }
        $result = Invoke-WithRetry -Item 'test' -Processor $processor -MaxRetries 3 -BaseDelayMs 1
        $result.Success | Should -Be $true
        $result.Result | Should -Be 'processed:test'
        $result.Attempts | Should -Be 1
    }

    It 'retries on failure and succeeds on second attempt' {
        $script:attemptCount = 0
        $processor = {
            param($item)
            $script:attemptCount++
            if ($script:attemptCount -lt 2) { throw "Transient error" }
            "processed:$item"
        }
        $result = Invoke-WithRetry -Item 'test' -Processor $processor -MaxRetries 3 -BaseDelayMs 1
        $result.Success | Should -Be $true
        $result.Attempts | Should -Be 2
        $script:attemptCount | Should -Be 2
    }

    It 'returns failure after exhausting max retries' {
        $processor = { param($item) throw "Always fails" }
        $result = Invoke-WithRetry -Item 'test' -Processor $processor -MaxRetries 2 -BaseDelayMs 1
        $result.Success | Should -Be $false
        $result.Attempts | Should -Be 3  # initial + 2 retries
        $result.Error | Should -Not -BeNullOrEmpty
    }

    It 'uses exponential backoff - delays increase between retries' {
        $script:attempt = 0
        $processor = { param($item) $script:attempt++; throw "Always fails" }

        # Capture Start-Sleep -Milliseconds values to verify exponential growth.
        $script:delays = [System.Collections.ArrayList]::new()
        Mock Start-Sleep { $script:delays.Add($Milliseconds) | Out-Null } -ModuleName Pipeline
        Invoke-WithRetry -Item 'test' -Processor $processor -MaxRetries 3 -BaseDelayMs 100 | Out-Null

        # Delays should be 100, 200, 400 (exponential)
        $script:delays.Count | Should -Be 3
        $script:delays[1] | Should -BeGreaterThan $script:delays[0]
        $script:delays[2] | Should -BeGreaterThan $script:delays[1]
    }
}

Describe 'Invoke-Pipeline' {
    BeforeEach {
        $script:processedItems = [System.Collections.ArrayList]::new()
        $script:failedItems = [System.Collections.ArrayList]::new()
    }

    It 'processes all items from the queue' {
        $queue = New-Queue -Name 'Input' -Items @('item1', 'item2', 'item3')
        $dlq = New-Queue -Name 'DeadLetter'
        $processor = { param($item) "processed:$item" }

        $summary = Invoke-Pipeline -InputQueue $queue -DeadLetterQueue $dlq -Processor $processor -MaxRetries 2 -BaseDelayMs 1

        $summary.TotalProcessed | Should -Be 3
        $summary.TotalFailed | Should -Be 0
        $queue.Items.Count | Should -Be 0
    }

    It 'sends permanently failed items to dead-letter queue' {
        $queue = New-Queue -Name 'Input' -Items @('good', 'bad', 'good2')
        $dlq = New-Queue -Name 'DeadLetter'
        $processor = {
            param($item)
            if ($item -eq 'bad') { throw "Cannot process bad item" }
            "processed:$item"
        }

        $summary = Invoke-Pipeline -InputQueue $queue -DeadLetterQueue $dlq -Processor $processor -MaxRetries 2 -BaseDelayMs 1

        $summary.TotalProcessed | Should -Be 2
        $summary.TotalFailed | Should -Be 1
        $dlq.Items.Count | Should -Be 1
        $dlq.Items[0].Item | Should -Be 'bad'
    }

    It 'reports progress during processing' {
        $queue = New-Queue -Name 'Input' -Items @('a', 'b', 'c')
        $dlq = New-Queue -Name 'DeadLetter'
        $processor = { param($item) "ok" }
        # Use $script: scope so the closure and assertion share the same variable.
        $script:progressReports = [System.Collections.ArrayList]::new()
        $onProgress = { param($report) $script:progressReports.Add($report) | Out-Null }

        Invoke-Pipeline -InputQueue $queue -DeadLetterQueue $dlq -Processor $processor -MaxRetries 1 -BaseDelayMs 1 -OnProgress $onProgress | Out-Null

        $script:progressReports.Count | Should -BeGreaterThan 0
        $script:progressReports[-1].Processed | Should -Be 3
    }

    It 'summary includes correct counts and dead-letter items' {
        $queue = New-Queue -Name 'Input' -Items @('ok', 'fail', 'ok2')
        $dlq = New-Queue -Name 'DeadLetter'
        $processor = { param($item) if ($item -eq 'fail') { throw "err" }; "done" }

        $summary = Invoke-Pipeline -InputQueue $queue -DeadLetterQueue $dlq -Processor $processor -MaxRetries 1 -BaseDelayMs 1

        $summary | Should -Not -BeNullOrEmpty
        $summary.TotalProcessed | Should -Be 2
        $summary.TotalFailed | Should -Be 1
        $summary.TotalRetries | Should -BeGreaterThanOrEqual 0
        $summary.DeadLetterCount | Should -Be 1
    }

    It 'tracks retry count in summary' {
        $script:callTracker = @{}
        $queue = New-Queue -Name 'Input' -Items @('flaky')
        $dlq = New-Queue -Name 'DeadLetter'
        $processor = {
            param($item)
            if (-not $script:callTracker.ContainsKey($item)) { $script:callTracker[$item] = 0 }
            $script:callTracker[$item]++
            if ($script:callTracker[$item] -lt 2) { throw "Transient" }
            "ok"
        }

        $summary = Invoke-Pipeline -InputQueue $queue -DeadLetterQueue $dlq -Processor $processor -MaxRetries 3 -BaseDelayMs 1

        $summary.TotalProcessed | Should -Be 1
        $summary.TotalRetries | Should -Be 1
    }
}

Describe 'Get-PipelineSummary' {
    It 'formats summary as a readable string' {
        $summaryData = @{
            TotalProcessed = 10
            TotalFailed    = 2
            TotalRetries   = 3
            DeadLetterCount = 2
            Duration       = [timespan]::FromSeconds(5)
        }
        $text = Get-PipelineSummary -SummaryData $summaryData
        $text | Should -Match 'Processed'
        $text | Should -Match '10'
        $text | Should -Match 'Failed'
        $text | Should -Match '2'
    }
}
