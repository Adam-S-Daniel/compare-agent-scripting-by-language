# ErrorRetryPipeline.ps1
# A pipeline that processes items from a queue with exponential backoff retry,
# dead-letter queue for permanently failed items, and progress reporting.
#
# TDD approach: Each function was built incrementally — test first, then implementation.
# All queue and processing operations are mockable via scriptblock parameters.

# --- TDD Cycle 1: MockQueue ---
# Provides a simple FIFO queue with Enqueue, Dequeue, Peek, Count, IsEmpty, GetAll.
function New-MockQueue {
    <#
    .SYNOPSIS
        Creates a new mock queue object backed by a .NET generic list.
    #>
    $items = [System.Collections.Generic.Queue[object]]::new()

    return [PSCustomObject]@{
        # Enqueue an item at the tail
        Enqueue = { param($item) $items.Enqueue($item) }.GetNewClosure()

        # Dequeue an item from the head; throws if empty
        Dequeue = {
            if ($items.Count -eq 0) {
                throw 'Queue is empty — cannot dequeue.'
            }
            $items.Dequeue()
        }.GetNewClosure()

        # Peek at the head without removing; throws if empty
        Peek = {
            if ($items.Count -eq 0) {
                throw 'Queue is empty — cannot peek.'
            }
            $items.Peek()
        }.GetNewClosure()

        # Return the number of items in the queue
        Count = { $items.Count }.GetNewClosure()

        # Return $true if the queue is empty
        IsEmpty = { $items.Count -eq 0 }.GetNewClosure()

        # Return all items as an array (non-destructive)
        GetAll = { @($items.ToArray()) }.GetNewClosure()
    }
}

# --- TDD Cycle 2: Exponential backoff delay calculator ---
# Returns the delay in milliseconds for a given retry attempt using exponential backoff.
# Formula: min(baseDelayMs * 2^attempt, maxDelayMs)
function Get-ExponentialBackoffDelay {
    <#
    .SYNOPSIS
        Calculates exponential backoff delay for a given retry attempt.
    .PARAMETER Attempt
        Zero-based retry attempt number.
    .PARAMETER BaseDelayMs
        Base delay in milliseconds (default 100).
    .PARAMETER MaxDelayMs
        Maximum delay cap in milliseconds (default 30000).
    #>
    param(
        [Parameter(Mandatory)][int]$Attempt,
        [int]$BaseDelayMs = 100,
        [int]$MaxDelayMs = 30000
    )

    $delay = $BaseDelayMs * [Math]::Pow(2, $Attempt)
    return [Math]::Min([int]$delay, $MaxDelayMs)
}

# --- TDD Cycle 3: Invoke-WithRetry ---
# Executes a scriptblock with configurable exponential backoff retry.
# Returns a result object with Success, Result, Error, Attempts.
function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Invokes a scriptblock, retrying on failure with exponential backoff.
    .PARAMETER ScriptBlock
        The operation to execute. Receives the item as argument.
    .PARAMETER Item
        The item to process.
    .PARAMETER MaxRetries
        Maximum number of retry attempts (default 3). Total attempts = MaxRetries + 1.
    .PARAMETER BaseDelayMs
        Base delay in milliseconds for backoff (default 100).
    .PARAMETER MaxDelayMs
        Maximum delay cap in milliseconds (default 30000).
    .PARAMETER SleepAction
        Optional scriptblock to call instead of Start-Sleep, for testability.
        Receives delay in milliseconds as argument.
    #>
    param(
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [Parameter(Mandatory)]$Item,
        [int]$MaxRetries = 3,
        [int]$BaseDelayMs = 100,
        [int]$MaxDelayMs = 30000,
        [scriptblock]$SleepAction = $null
    )

    $attempts = 0
    $lastError = $null

    for ($i = 0; $i -le $MaxRetries; $i++) {
        $attempts++
        try {
            $result = & $ScriptBlock $Item
            return [PSCustomObject]@{
                Success  = $true
                Result   = $result
                Error    = $null
                Attempts = $attempts
            }
        }
        catch {
            $lastError = $_.Exception.Message
            # If we still have retries left, wait with exponential backoff
            if ($i -lt $MaxRetries) {
                $delay = Get-ExponentialBackoffDelay -Attempt $i -BaseDelayMs $BaseDelayMs -MaxDelayMs $MaxDelayMs
                if ($SleepAction) {
                    & $SleepAction $delay
                }
                else {
                    Start-Sleep -Milliseconds $delay
                }
            }
        }
    }

    # All retries exhausted
    return [PSCustomObject]@{
        Success  = $false
        Result   = $null
        Error    = $lastError
        Attempts = $attempts
    }
}

# --- TDD Cycle 4: Invoke-Pipeline ---
# Processes all items in a source queue through a processor scriptblock.
# Failed items (after all retries) go to the dead-letter queue.
# Returns a summary object with counts and details.
function Invoke-Pipeline {
    <#
    .SYNOPSIS
        Processes items from a queue with retry logic, dead-letter queue, and progress reporting.
    .PARAMETER SourceQueue
        A mock queue object (from New-MockQueue) containing items to process.
    .PARAMETER ProcessorScript
        A scriptblock that processes each item. Should throw on failure.
    .PARAMETER MaxRetries
        Maximum retry attempts per item (default 3).
    .PARAMETER BaseDelayMs
        Base backoff delay in milliseconds (default 100).
    .PARAMETER MaxDelayMs
        Maximum backoff delay cap in milliseconds (default 30000).
    .PARAMETER SleepAction
        Optional scriptblock for mocking sleep. Receives delay in ms.
    .PARAMETER OnProgress
        Optional scriptblock called after each item is processed.
        Receives a hashtable with keys: Processed, Failed, Retrying, Total, CurrentItem, Status.
    #>
    param(
        [Parameter(Mandatory)]$SourceQueue,
        [Parameter(Mandatory)][scriptblock]$ProcessorScript,
        [int]$MaxRetries = 3,
        [int]$BaseDelayMs = 100,
        [int]$MaxDelayMs = 30000,
        [scriptblock]$SleepAction = $null,
        [scriptblock]$OnProgress = $null
    )

    # Dead-letter queue for permanently failed items
    $deadLetterQueue = New-MockQueue

    # Tracking counters
    $totalItems = & $SourceQueue.Count
    $processed = 0
    $failed = 0
    $retried = 0
    $results = @()

    while (-not (& $SourceQueue.IsEmpty)) {
        $item = & $SourceQueue.Dequeue

        $retryResult = Invoke-WithRetry `
            -ScriptBlock $ProcessorScript `
            -Item $item `
            -MaxRetries $MaxRetries `
            -BaseDelayMs $BaseDelayMs `
            -MaxDelayMs $MaxDelayMs `
            -SleepAction $SleepAction

        if ($retryResult.Success) {
            $processed++
            $status = 'Success'
        }
        else {
            $failed++
            & $deadLetterQueue.Enqueue ([PSCustomObject]@{
                Item    = $item
                Error   = $retryResult.Error
                Attempts = $retryResult.Attempts
            })
            $status = 'Failed'
        }

        # Count items that required more than one attempt
        if ($retryResult.Attempts -gt 1) {
            $retried++
        }

        $results += [PSCustomObject]@{
            Item     = $item
            Success  = $retryResult.Success
            Attempts = $retryResult.Attempts
            Error    = $retryResult.Error
        }

        # Report progress if callback provided
        if ($OnProgress) {
            & $OnProgress @{
                Processed   = $processed
                Failed      = $failed
                Retrying    = $retried
                Total       = $totalItems
                CurrentItem = $item
                Status      = $status
            }
        }
    }

    # Build the final summary
    $summary = [PSCustomObject]@{
        TotalItems      = $totalItems
        Processed       = $processed
        Failed          = $failed
        Retried         = $retried
        DeadLetterQueue = $deadLetterQueue
        Results         = $results
    }

    return $summary
}
