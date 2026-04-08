BeforeAll {
    . "$PSScriptRoot/ErrorRetryPipeline.ps1"
}

Describe 'MockQueue' {
    It 'enqueues and dequeues items in FIFO order' {
        $q = New-MockQueue
        Add-QueueItem -Queue $q -Item 'a'
        Add-QueueItem -Queue $q -Item 'b'

        Get-QueueItem -Queue $q | Should -Be 'a'
        Get-QueueItem -Queue $q | Should -Be 'b'
    }

    It 'returns $null when empty' {
        $q = New-MockQueue
        Get-QueueItem -Queue $q | Should -BeNullOrEmpty
    }

    It 'reports count correctly' {
        $q = New-MockQueue
        Get-QueueCount -Queue $q | Should -Be 0
        Add-QueueItem -Queue $q -Item 'x'
        Get-QueueCount -Queue $q | Should -Be 1
    }
}

Describe 'Invoke-WithRetry' {
    It 'succeeds on first try when action does not throw' {
        $callCount = 0
        $result = Invoke-WithRetry -Action {
            $script:callCount++
            'ok'
        } -MaxRetries 3
        $result | Should -Be 'ok'
        $script:callCount | Should -Be 1
    }

    It 'retries on failure and succeeds eventually' {
        $script:attempt = 0
        $result = Invoke-WithRetry -Action {
            $script:attempt++
            if ($script:attempt -lt 3) { throw "transient error" }
            'recovered'
        } -MaxRetries 5 -BaseDelayMs 0
        $result | Should -Be 'recovered'
        $script:attempt | Should -Be 3
    }

    It 'throws after exhausting max retries' {
        { Invoke-WithRetry -Action { throw "permanent" } -MaxRetries 2 -BaseDelayMs 0 } |
            Should -Throw '*permanent*'
    }

    It 'uses exponential backoff delays' {
        # Track the delays that were actually used
        $script:delays = @()
        $script:attempt = 0
        try {
            Invoke-WithRetry -Action { throw "fail" } -MaxRetries 3 -BaseDelayMs 100 -OnDelay {
                param($ms)
                $script:delays += $ms
            }
        } catch {}

        # Expect delays of 100, 200, 400 (base * 2^attempt)
        $script:delays.Count | Should -Be 3
        $script:delays[0] | Should -Be 100
        $script:delays[1] | Should -Be 200
        $script:delays[2] | Should -Be 400
    }
}

Describe 'Invoke-Pipeline' {
    It 'processes all items successfully when processor never fails' {
        $q = New-MockQueue
        Add-QueueItem -Queue $q -Item 'item1'
        Add-QueueItem -Queue $q -Item 'item2'
        Add-QueueItem -Queue $q -Item 'item3'

        $result = Invoke-Pipeline -Queue $q -Processor { param($item) "done:$item" } -MaxRetries 3 -BaseDelayMs 0

        $result.Processed | Should -Be 3
        $result.Failed | Should -Be 0
        $result.DeadLetterCount | Should -Be 0
        $result.Results.Count | Should -Be 3
    }

    It 'sends permanently failed items to the dead-letter queue' {
        $q = New-MockQueue
        Add-QueueItem -Queue $q -Item 'good'
        Add-QueueItem -Queue $q -Item 'bad'

        $processor = {
            param($item)
            if ($item -eq 'bad') { throw "processing failed for $item" }
            "done:$item"
        }

        $result = Invoke-Pipeline -Queue $q -Processor $processor -MaxRetries 2 -BaseDelayMs 0

        $result.Processed | Should -Be 1
        $result.Failed | Should -Be 1
        $result.DeadLetterCount | Should -Be 1
        # Dead-letter queue should contain the failed item with error info
        $dlItem = Get-QueueItem -Queue $result.DeadLetterQueue
        $dlItem.Item | Should -Be 'bad'
        $dlItem.Error | Should -BeLike '*processing failed*'
    }

    It 'retries transient failures before succeeding' {
        $q = New-MockQueue
        Add-QueueItem -Queue $q -Item 'flaky'

        $script:flakyAttempt = 0
        $processor = {
            param($item)
            $script:flakyAttempt++
            if ($script:flakyAttempt -lt 3) { throw "transient" }
            "done:$item"
        }

        $result = Invoke-Pipeline -Queue $q -Processor $processor -MaxRetries 5 -BaseDelayMs 0

        $result.Processed | Should -Be 1
        $result.Failed | Should -Be 0
        $result.Retried | Should -BeGreaterThan 0
    }

    It 'reports progress via callback' {
        $q = New-MockQueue
        Add-QueueItem -Queue $q -Item 'a'
        Add-QueueItem -Queue $q -Item 'b'

        $script:progressMessages = @()
        $onProgress = {
            param($msg)
            $script:progressMessages += $msg
        }

        Invoke-Pipeline -Queue $q -Processor { param($item) $item } `
            -MaxRetries 2 -BaseDelayMs 0 -OnProgress $onProgress

        # Should have progress updates for each item
        $script:progressMessages.Count | Should -BeGreaterOrEqual 2
    }

    It 'produces a final summary' {
        $q = New-MockQueue
        Add-QueueItem -Queue $q -Item 'ok1'
        Add-QueueItem -Queue $q -Item 'ok2'

        $result = Invoke-Pipeline -Queue $q -Processor { param($item) $item } `
            -MaxRetries 2 -BaseDelayMs 0

        # Summary should be a formatted string
        $result.Summary | Should -BeLike '*Processed: 2*'
        $result.Summary | Should -BeLike '*Failed: 0*'
    }

    It 'handles an empty queue gracefully' {
        $q = New-MockQueue

        $result = Invoke-Pipeline -Queue $q -Processor { param($item) $item } `
            -MaxRetries 2 -BaseDelayMs 0

        $result.Processed | Should -Be 0
        $result.Failed | Should -Be 0
        $result.Summary | Should -BeLike '*Processed: 0*'
    }
}

Describe 'Invoke-Pipeline — integration with mock random failures' {
    It 'handles a mix of successes and failures deterministically' {
        # Simulate a processor where specific items always fail
        $q = New-MockQueue
        1..10 | ForEach-Object { Add-QueueItem -Queue $q -Item "job-$_" }

        # Items 3, 7 always fail; rest succeed
        $alwaysFail = @('job-3', 'job-7')
        $processor = {
            param($item)
            if ($item -in $alwaysFail) { throw "permanent failure: $item" }
            "result:$item"
        }

        $result = Invoke-Pipeline -Queue $q -Processor $processor -MaxRetries 2 -BaseDelayMs 0

        $result.Processed | Should -Be 8
        $result.Failed | Should -Be 2
        $result.DeadLetterCount | Should -Be 2
        ($result.Processed + $result.Failed) | Should -Be 10
        $result.Summary | Should -BeLike '*Processed: 8*'
        $result.Summary | Should -BeLike '*Failed: 2*'
    }

    It 'tracks retries correctly for items that eventually succeed' {
        $q = New-MockQueue
        Add-QueueItem -Queue $q -Item 'eventually-ok'

        # Fail twice, then succeed on 3rd attempt
        $script:attempts = 0
        $processor = {
            param($item)
            $script:attempts++
            if ($script:attempts -le 2) { throw "not yet" }
            "success"
        }

        $result = Invoke-Pipeline -Queue $q -Processor $processor -MaxRetries 5 -BaseDelayMs 0

        $result.Processed | Should -Be 1
        $result.Failed | Should -Be 0
        $result.Retried | Should -Be 2
        $result.Summary | Should -BeLike '*Retried: 2*'
    }

    It 'uses a mockable processor scriptblock (dependency injection)' {
        # Demonstrates that the Processor parameter is fully injectable
        $q = New-MockQueue
        Add-QueueItem -Queue $q -Item @{ Id = 1; Data = 'test' }

        $mockProcessor = {
            param($item)
            [PSCustomObject]@{ Id = $item.Id; Transformed = $item.Data.ToUpper() }
        }

        $result = Invoke-Pipeline -Queue $q -Processor $mockProcessor -MaxRetries 1 -BaseDelayMs 0

        $result.Processed | Should -Be 1
        $result.Results[0].Result.Transformed | Should -Be 'TEST'
    }
}
