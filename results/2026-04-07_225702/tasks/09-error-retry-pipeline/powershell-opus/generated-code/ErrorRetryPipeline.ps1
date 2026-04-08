# ErrorRetryPipeline.ps1
# A pipeline that processes items from a queue with exponential backoff retry,
# dead-letter queue for permanently failed items, and progress reporting.

# --- Mock Queue (wrapper around System.Collections.Queue for testability) ---

function New-MockQueue {
    # Returns a queue object that our helper functions operate on.
    # Use Write-Output -NoEnumerate to prevent PowerShell from unwrapping the collection.
    Write-Output -NoEnumerate ([System.Collections.Queue]::new())
}

function Add-QueueItem {
    param(
        [Parameter(Mandatory)][System.Collections.Queue]$Queue,
        [Parameter(Mandatory)]$Item
    )
    $Queue.Enqueue($Item)
}

function Get-QueueItem {
    param(
        [Parameter(Mandatory)][System.Collections.Queue]$Queue
    )
    if ($Queue.Count -eq 0) { return $null }
    $Queue.Dequeue()
}

function Get-QueueCount {
    param(
        [Parameter(Mandatory)][System.Collections.Queue]$Queue
    )
    $Queue.Count
}

# --- Retry with Exponential Backoff ---

function Invoke-WithRetry {
    # Executes $Action up to ($MaxRetries + 1) times total.
    # On each failure, waits BaseDelayMs * 2^attemptIndex before retrying.
    # OnDelay is a hook for testing — it receives the delay in ms instead of sleeping.
    # RetryCounter is an optional [ref] that gets incremented on each retry.
    param(
        [Parameter(Mandatory)][scriptblock]$Action,
        [int]$MaxRetries = 3,
        [int]$BaseDelayMs = 1000,
        [scriptblock]$OnDelay = $null,
        # Untyped so callers can omit it; pass [ref]$var to track retries.
        $RetryCounter = $null
    )

    for ($i = 0; $i -le $MaxRetries; $i++) {
        try {
            return (& $Action)
        } catch {
            if ($i -eq $MaxRetries) {
                throw $_.Exception
            }
            if ($null -ne $RetryCounter) { $RetryCounter.Value++ }
            $delayMs = $BaseDelayMs * [Math]::Pow(2, $i)
            if ($OnDelay) {
                & $OnDelay $delayMs
            } else {
                Start-Sleep -Milliseconds $delayMs
            }
        }
    }
}

# --- Pipeline Processor ---

function Invoke-Pipeline {
    # Drains items from $Queue, running each through $Processor with retry logic.
    # Items that fail after all retries are sent to a dead-letter queue.
    # Returns a result object with counts, results, dead-letter queue, and summary.
    param(
        [Parameter(Mandatory)][System.Collections.Queue]$Queue,
        [Parameter(Mandatory)][scriptblock]$Processor,
        [int]$MaxRetries = 3,
        [int]$BaseDelayMs = 1000,
        [scriptblock]$OnProgress = $null
    )

    $deadLetterQueue = New-MockQueue
    $results = [System.Collections.Generic.List[object]]::new()
    $processed = 0
    $failed = 0
    $retried = 0
    $totalItems = Get-QueueCount -Queue $Queue

    while ((Get-QueueCount -Queue $Queue) -gt 0) {
        $item = Get-QueueItem -Queue $Queue
        $itemRetries = 0

        try {
            $output = Invoke-WithRetry -Action {
                & $Processor $item
            } -MaxRetries $MaxRetries -BaseDelayMs $BaseDelayMs -RetryCounter ([ref]$itemRetries)

            $processed++
            $retried += $itemRetries
            $results.Add([PSCustomObject]@{
                Item   = $item
                Result = $output
                Status = 'Success'
            })
        } catch {
            $failed++
            $retried += $itemRetries
            Add-QueueItem -Queue $deadLetterQueue -Item ([PSCustomObject]@{
                Item    = $item
                Error   = $_.Exception.Message
                Retries = $MaxRetries
            })
        }

        # Report progress after each item
        if ($OnProgress) {
            $msg = "Item '$item': processed=$processed, failed=$failed, retrying=$retried, remaining=$(Get-QueueCount -Queue $Queue)"
            & $OnProgress $msg
        }
    }

    $summary = "Pipeline complete — Processed: $processed, Failed: $failed, Retried: $retried, Dead-lettered: $(Get-QueueCount -Queue $deadLetterQueue)"

    [PSCustomObject]@{
        Processed       = $processed
        Failed          = $failed
        Retried         = $retried
        DeadLetterCount = Get-QueueCount -Queue $deadLetterQueue
        DeadLetterQueue = $deadLetterQueue
        Results         = $results
        Summary         = $summary
    }
}
