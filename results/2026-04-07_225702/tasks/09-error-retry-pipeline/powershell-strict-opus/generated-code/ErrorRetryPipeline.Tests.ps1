BeforeAll {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    . "$PSScriptRoot/ErrorRetryPipeline.ps1"
}

Describe 'New-PipelineConfig' {
    It 'creates config with default values' {
        $config = New-PipelineConfig
        $config.MaxRetries | Should -Be 3
        $config.BaseDelayMs | Should -Be 100
        $config.BackoffMultiplier | Should -Be 2.0
    }

    It 'accepts custom max retries' {
        $config = New-PipelineConfig -MaxRetries 5
        $config.MaxRetries | Should -Be 5
    }

    It 'accepts custom base delay and multiplier' {
        $config = New-PipelineConfig -BaseDelayMs 200 -BackoffMultiplier 3.0
        $config.BaseDelayMs | Should -Be 200
        $config.BackoffMultiplier | Should -Be 3.0
    }
}

Describe 'New-MockQueue' {
    It 'creates a queue with the given items' {
        $queue = New-MockQueue -Items @('a', 'b', 'c')
        $queue.Count | Should -Be 3
    }

    It 'dequeues items in FIFO order' {
        $queue = New-MockQueue -Items @('first', 'second')
        $item = Get-QueueItem -Queue $queue
        $item | Should -Be 'first'
        $item = Get-QueueItem -Queue $queue
        $item | Should -Be 'second'
    }

    It 'returns $null when queue is empty' {
        $queue = New-MockQueue -Items @('only')
        $null = Get-QueueItem -Queue $queue
        $item = Get-QueueItem -Queue $queue
        $item | Should -BeNullOrEmpty
    }
}

Describe 'New-DeadLetterQueue' {
    It 'starts empty' {
        $dlq = New-DeadLetterQueue
        $dlq.Items.Count | Should -Be 0
    }

    It 'accepts failed items with error info' {
        $dlq = New-DeadLetterQueue
        Add-DeadLetterItem -DeadLetterQueue $dlq -Item 'bad-item' -ErrorMessage 'boom' -AttemptCount 3
        $dlq.Items.Count | Should -Be 1
        $dlq.Items[0].Item | Should -Be 'bad-item'
        $dlq.Items[0].ErrorMessage | Should -Be 'boom'
        $dlq.Items[0].AttemptCount | Should -Be 3
    }
}

Describe 'Get-RetryDelay' {
    It 'calculates exponential backoff delay' {
        $config = New-PipelineConfig -BaseDelayMs 100 -BackoffMultiplier 2.0
        # Attempt 0 => 100 * 2^0 = 100
        Get-RetryDelay -Config $config -AttemptNumber 0 | Should -Be 100
        # Attempt 1 => 100 * 2^1 = 200
        Get-RetryDelay -Config $config -AttemptNumber 1 | Should -Be 200
        # Attempt 2 => 100 * 2^2 = 400
        Get-RetryDelay -Config $config -AttemptNumber 2 | Should -Be 400
    }
}

Describe 'Invoke-ProcessItem' {
    It 'calls the processor scriptblock and returns result' {
        $processor = { param([string]$Item) return "processed-$Item" }
        $result = Invoke-ProcessItem -Item 'test' -Processor $processor
        $result | Should -Be 'processed-test'
    }

    It 'throws when processor fails' {
        $processor = { param([string]$Item) throw "failure on $Item" }
        { Invoke-ProcessItem -Item 'test' -Processor $processor } | Should -Throw
    }
}

Describe 'Invoke-RetryPipeline' {
    It 'processes all items successfully when no failures occur' {
        $queue = New-MockQueue -Items @('a', 'b', 'c')
        $processor = { param([string]$Item) return "done-$Item" }
        $config = New-PipelineConfig -MaxRetries 3 -BaseDelayMs 0

        $result = Invoke-RetryPipeline -Queue $queue -Processor $processor -Config $config

        $result.ProcessedCount | Should -Be 3
        $result.FailedCount | Should -Be 0
        $result.RetryCount | Should -Be 0
        $result.DeadLetterQueue.Items.Count | Should -Be 0
    }

    It 'retries failed items up to MaxRetries then dead-letters them' {
        # Processor that always fails
        $processor = { param([string]$Item) throw "always fails" }
        $queue = New-MockQueue -Items @('x')
        $config = New-PipelineConfig -MaxRetries 2 -BaseDelayMs 0

        $result = Invoke-RetryPipeline -Queue $queue -Processor $processor -Config $config

        $result.ProcessedCount | Should -Be 0
        $result.FailedCount | Should -Be 1
        # Initial attempt + 2 retries = total 3 attempts, so 2 retries
        $result.RetryCount | Should -Be 2
        $result.DeadLetterQueue.Items.Count | Should -Be 1
        $result.DeadLetterQueue.Items[0].Item | Should -Be 'x'
    }

    It 'succeeds on retry after transient failure' {
        # Use a script-scoped counter to track calls
        $script:callCount = 0
        $processor = {
            param([string]$Item)
            $script:callCount++
            if ($script:callCount -lt 3) {
                throw "transient error"
            }
            return "recovered-$Item"
        }
        $queue = New-MockQueue -Items @('flaky')
        $config = New-PipelineConfig -MaxRetries 5 -BaseDelayMs 0

        $result = Invoke-RetryPipeline -Queue $queue -Processor $processor -Config $config

        $result.ProcessedCount | Should -Be 1
        $result.FailedCount | Should -Be 0
        $result.RetryCount | Should -Be 2
    }

    It 'collects progress events' {
        $queue = New-MockQueue -Items @('a', 'b')
        $processor = { param([string]$Item) return "ok" }
        $config = New-PipelineConfig -BaseDelayMs 0

        $result = Invoke-RetryPipeline -Queue $queue -Processor $processor -Config $config

        $result.ProgressLog.Count | Should -BeGreaterThan 0
    }

    It 'produces a final summary' {
        $queue = New-MockQueue -Items @('good', 'bad')
        $failOnce = $true
        $processor = {
            param([string]$Item)
            if ($Item -eq 'bad') { throw "nope" }
            return "ok"
        }
        $config = New-PipelineConfig -MaxRetries 1 -BaseDelayMs 0

        $result = Invoke-RetryPipeline -Queue $queue -Processor $processor -Config $config

        $result.Summary | Should -Not -BeNullOrEmpty
        $result.Summary | Should -Match 'Processed: 1'
        $result.Summary | Should -Match 'Failed: 1'
    }

    It 'handles an empty queue gracefully' {
        $queue = New-MockQueue -Items @()
        $processor = { param([string]$Item) return $Item }
        $config = New-PipelineConfig -BaseDelayMs 0

        $result = Invoke-RetryPipeline -Queue $queue -Processor $processor -Config $config

        $result.ProcessedCount | Should -Be 0
        $result.FailedCount | Should -Be 0
        $result.RetryCount | Should -Be 0
    }

    It 'handles mixed success and failure across multiple items' {
        # Items 'fail1' and 'fail2' always fail; 'ok1' and 'ok2' succeed
        $processor = {
            param([string]$Item)
            if ($Item -like 'fail*') { throw "error on $Item" }
            return "processed-$Item"
        }
        $queue = New-MockQueue -Items @('ok1', 'fail1', 'ok2', 'fail2')
        $config = New-PipelineConfig -MaxRetries 2 -BaseDelayMs 0

        $result = Invoke-RetryPipeline -Queue $queue -Processor $processor -Config $config

        $result.ProcessedCount | Should -Be 2
        $result.FailedCount | Should -Be 2
        $result.DeadLetterQueue.Items.Count | Should -Be 2
    }
}
