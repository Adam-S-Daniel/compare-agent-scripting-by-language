Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------------
# Error Retry Pipeline
#
# Processes items from a mockable queue with exponential backoff retry.
# Items that exhaust all retries are sent to a dead-letter queue.
# Progress is reported throughout and a final summary is produced.
# ------------------------------------------------------------------

function New-PipelineConfig {
    <#
    .SYNOPSIS
        Creates a pipeline configuration object with retry parameters.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [int]$MaxRetries = 3,
        [int]$BaseDelayMs = 100,
        [double]$BackoffMultiplier = 2.0
    )

    return @{
        MaxRetries        = $MaxRetries
        BaseDelayMs       = $BaseDelayMs
        BackoffMultiplier = $BackoffMultiplier
    }
}

function New-MockQueue {
    <#
    .SYNOPSIS
        Creates a mock FIFO queue from an array of items.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string[]]$Items = @()
    )

    # Use a .NET Queue for true FIFO behaviour
    [System.Collections.Queue]$q = [System.Collections.Queue]::new()
    foreach ($item in $Items) {
        $q.Enqueue($item)
    }

    return @{
        Inner = $q
        Count = $q.Count
    }
}

function Get-QueueItem {
    <#
    .SYNOPSIS
        Dequeues the next item from a mock queue, or returns $null if empty.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [hashtable]$Queue
    )

    [System.Collections.Queue]$inner = $Queue.Inner
    if ($inner.Count -eq 0) {
        return $null
    }

    [string]$item = [string]$inner.Dequeue()
    $Queue.Count = $inner.Count
    return $item
}

function New-DeadLetterQueue {
    <#
    .SYNOPSIS
        Creates an empty dead-letter queue for permanently failed items.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return @{
        Items = [System.Collections.ArrayList]::new()
    }
}

function Add-DeadLetterItem {
    <#
    .SYNOPSIS
        Adds a failed item with its error info to the dead-letter queue.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [hashtable]$DeadLetterQueue,
        [string]$Item,
        [string]$ErrorMessage,
        [int]$AttemptCount
    )

    [void]$DeadLetterQueue.Items.Add(@{
        Item         = $Item
        ErrorMessage = $ErrorMessage
        AttemptCount = $AttemptCount
    })
}

function Get-RetryDelay {
    <#
    .SYNOPSIS
        Calculates exponential backoff delay: BaseDelayMs * Multiplier^AttemptNumber.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [hashtable]$Config,
        [int]$AttemptNumber
    )

    [double]$delay = [double]$Config.BaseDelayMs * [System.Math]::Pow([double]$Config.BackoffMultiplier, [double]$AttemptNumber)
    return [int]$delay
}

function Invoke-ProcessItem {
    <#
    .SYNOPSIS
        Invokes the processor scriptblock on a single item.
        Throws if the processor throws.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [string]$Item,
        [scriptblock]$Processor
    )

    return & $Processor $Item
}

function Invoke-RetryPipeline {
    <#
    .SYNOPSIS
        Main pipeline: drains a queue, processes each item with retries,
        dead-letters permanent failures, and returns a result summary.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [hashtable]$Queue,
        [scriptblock]$Processor,
        [hashtable]$Config
    )

    [int]$processedCount = 0
    [int]$failedCount = 0
    [int]$retryCount = 0
    [hashtable]$dlq = New-DeadLetterQueue
    [System.Collections.ArrayList]$progressLog = [System.Collections.ArrayList]::new()

    # Helper to record progress events
$addProgress = {
    param([string]$Message)
    [void]$progressLog.Add(@{
        Timestamp = [System.DateTime]::UtcNow
        Message   = $Message
    })
    Write-Verbose $Message
}

    # Drain the queue item by item
    while ($true) {
        [string]$item = Get-QueueItem -Queue $Queue
        if ($null -eq $item) { break }

        & $addProgress "Starting item: $item"

        [bool]$succeeded = $false
        [int]$attempts = 0
        [string]$lastError = ''

        # Initial attempt + up to MaxRetries retries
        while ($attempts -le [int]$Config.MaxRetries) {
            try {
                [void](Invoke-ProcessItem -Item $item -Processor $Processor)
                $succeeded = $true
                $processedCount++
                & $addProgress "Item succeeded: $item (attempt $($attempts + 1))"
                break
            }
            catch {
                $lastError = $_.Exception.Message
                $attempts++

                if ($attempts -le [int]$Config.MaxRetries) {
                    $retryCount++
                    [int]$delay = Get-RetryDelay -Config $Config -AttemptNumber ([int]($attempts - 1))
                    & $addProgress "Retrying item: $item (attempt $($attempts + 1), delay ${delay}ms)"

                    if ($delay -gt 0) {
                        Start-Sleep -Milliseconds $delay
                    }
                }
            }
        }

        if (-not $succeeded) {
            $failedCount++
            Add-DeadLetterItem -DeadLetterQueue $dlq -Item $item -ErrorMessage $lastError -AttemptCount $attempts
            & $addProgress "Dead-lettered item: $item after $attempts attempts - $lastError"
        }
    }

    # Build a human-readable summary
    [string]$summary = "Pipeline complete. Processed: $processedCount | Failed: $failedCount | Retries: $retryCount | Dead-lettered: $($dlq.Items.Count)"

    & $addProgress $summary

    return @{
        ProcessedCount  = $processedCount
        FailedCount     = $failedCount
        RetryCount      = $retryCount
        DeadLetterQueue = $dlq
        ProgressLog     = $progressLog
        Summary         = $summary
    }
}
