# Pipeline.psm1
# Error-retry pipeline with exponential backoff, dead-letter queue, and progress reporting.
# TDD-driven implementation using Pester. Strict mode enforced throughout.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Queue primitives
# ---------------------------------------------------------------------------

function New-Queue {
    <#
    .SYNOPSIS
        Creates a new named queue (backed by an ArrayList for O(1) removal from front).
    .DESCRIPTION
        Returns a hashtable representing the queue. All pipeline functions accept
        this shape, making it easy to swap in a mock or alternative backing store.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [object[]]$Items = @()
    )

    $list = [System.Collections.ArrayList]::new()
    foreach ($item in $Items) {
        $list.Add($item) | Out-Null
    }

    return @{
        Name  = $Name
        Items = $list
    }
}

function Add-QueueItem {
    <#
    .SYNOPSIS
        Appends an item to the end of a queue (enqueue).
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Queue,

        [Parameter(Mandatory)]
        [object]$Item
    )

    $Queue.Items.Add($Item) | Out-Null
}

function Get-QueueItem {
    <#
    .SYNOPSIS
        Removes and returns the first item from a queue (dequeue / FIFO).
        Returns $null when the queue is empty.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Queue
    )

    if ($Queue.Items.Count -eq 0) {
        return $null
    }

    $item = $Queue.Items[0]
    $Queue.Items.RemoveAt(0)
    return $item
}

# ---------------------------------------------------------------------------
# Retry logic with exponential backoff
# ---------------------------------------------------------------------------

function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Calls $Processor with $Item, retrying up to $MaxRetries times on failure.
        Delay between attempts grows exponentially: BaseDelayMs * 2^attempt.
    .OUTPUTS
        Hashtable with keys: Success [bool], Result [object], Attempts [int], Error [string]
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [object]$Item,

        [Parameter(Mandatory)]
        [scriptblock]$Processor,

        [Parameter(Mandatory)]
        [int]$MaxRetries,

        # Base delay in milliseconds; doubles on each subsequent retry.
        [Parameter(Mandatory)]
        [int]$BaseDelayMs
    )

    [int]$attempt = 0
    [string]$lastError = ''

    while ($attempt -le $MaxRetries) {
        # Apply backoff before retry attempts (not before the first attempt).
        if ($attempt -gt 0) {
            # Exponential: BaseDelayMs * 2^(attempt-1)
            [int]$delayMs = $BaseDelayMs * [int][math]::Pow(2, $attempt - 1)
            Start-Sleep -Milliseconds $delayMs
        }

        try {
            $result = & $Processor $Item
            return @{
                Success  = $true
                Result   = $result
                Attempts = $attempt + 1
                Error    = ''
            }
        }
        catch {
            $lastError = $_.Exception.Message
            $attempt++
        }
    }

    return @{
        Success  = $false
        Result   = $null
        Attempts = $attempt   # equals MaxRetries + 1 (initial + retries)
        Error    = $lastError
    }
}

# ---------------------------------------------------------------------------
# Main pipeline orchestrator
# ---------------------------------------------------------------------------

function Invoke-Pipeline {
    <#
    .SYNOPSIS
        Drains $InputQueue, processing each item via $Processor with retry.
        Permanently failed items land in $DeadLetterQueue.
        Calls $OnProgress scriptblock (if provided) after each item with a
        progress report hashtable.
    .OUTPUTS
        Summary hashtable: TotalProcessed, TotalFailed, TotalRetries, DeadLetterCount, Duration
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$InputQueue,

        [Parameter(Mandatory)]
        [hashtable]$DeadLetterQueue,

        [Parameter(Mandatory)]
        [scriptblock]$Processor,

        [Parameter(Mandatory)]
        [int]$MaxRetries,

        [Parameter(Mandatory)]
        [int]$BaseDelayMs,

        # Optional progress callback: { param($report) ... }
        # $report has keys: Processed, Failed, Retrying, CurrentItem
        [Parameter()]
        [scriptblock]$OnProgress = $null
    )

    [int]$totalProcessed = 0
    [int]$totalFailed    = 0
    [int]$totalRetries   = 0
    [System.Diagnostics.Stopwatch]$sw = [System.Diagnostics.Stopwatch]::StartNew()

    while ($InputQueue.Items.Count -gt 0) {
        $item = Get-QueueItem -Queue $InputQueue

        # Emit a "retrying" progress signal before processing so callers know
        # an item is in-flight.
        if ($null -ne $OnProgress) {
            & $OnProgress @{
                Processed   = $totalProcessed
                Failed      = $totalFailed
                Retrying    = $totalRetries
                CurrentItem = $item
            }
        }

        $outcome = Invoke-WithRetry -Item $item -Processor $Processor -MaxRetries $MaxRetries -BaseDelayMs $BaseDelayMs

        if ($outcome.Success) {
            $totalProcessed++
            # Retries = attempts beyond the first successful call
            $totalRetries += [int]($outcome.Attempts - 1)
        }
        else {
            $totalFailed++
            $totalRetries += [int]($outcome.Attempts - 1)

            # Place a dead-letter record (item + error) onto the DLQ.
            Add-QueueItem -Queue $DeadLetterQueue -Item @{
                Item  = $item
                Error = $outcome.Error
            }
        }

        # Final progress update after processing.
        if ($null -ne $OnProgress) {
            & $OnProgress @{
                Processed   = $totalProcessed
                Failed      = $totalFailed
                Retrying    = $totalRetries
                CurrentItem = $item
            }
        }
    }

    $sw.Stop()

    return @{
        TotalProcessed  = $totalProcessed
        TotalFailed     = $totalFailed
        TotalRetries    = $totalRetries
        DeadLetterCount = $DeadLetterQueue.Items.Count
        Duration        = $sw.Elapsed
    }
}

# ---------------------------------------------------------------------------
# Summary formatter
# ---------------------------------------------------------------------------

function Get-PipelineSummary {
    <#
    .SYNOPSIS
        Formats a pipeline summary hashtable as a human-readable multi-line string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$SummaryData
    )

    [string]$duration = $SummaryData.Duration.ToString('hh\:mm\:ss\.fff')

    return @"
=== Pipeline Summary ===
  Processed   : $($SummaryData.TotalProcessed)
  Failed      : $($SummaryData.TotalFailed)
  Retries     : $($SummaryData.TotalRetries)
  Dead-letter : $($SummaryData.DeadLetterCount)
  Duration    : $duration
========================
"@
}
