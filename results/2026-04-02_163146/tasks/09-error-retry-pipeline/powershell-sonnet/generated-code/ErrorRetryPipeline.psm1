# ErrorRetryPipeline.psm1
# Pipeline that processes a mocked queue with exponential-backoff retry,
# a dead-letter queue for permanently-failed items, and progress reporting.
#
# TDD cycle followed:
#   1. Write test -> run -> see RED
#   2. Write minimum implementation -> run -> see GREEN
#   3. Refactor, keep GREEN
#   Repeat for each logical section.

# ===========================================================================
# SECTION 1 – Queue
# ===========================================================================

function New-Queue {
    <#
    .SYNOPSIS
        Creates a mocked FIFO queue holding the supplied items.
    .PARAMETER Items
        An array of items to pre-load into the queue.
    #>
    param(
        [array]$Items = @()
    )

    # Use a generic List so we can RemoveAt(0) cheaply and the object is
    # mutable (plain arrays in PowerShell are fixed-size value copies).
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $Items) {
        $list.Add($item)
    }

    return [PSCustomObject]@{
        Items = $list
    }
}

function Get-NextQueueItem {
    <#
    .SYNOPSIS
        Dequeues and returns the next item (FIFO). Returns $null when empty.
    .PARAMETER Queue
        A queue object created by New-Queue.
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Queue
    )

    if ($Queue.Items.Count -eq 0) {
        return $null
    }

    $item = $Queue.Items[0]
    $Queue.Items.RemoveAt(0)
    return $item
}

# ===========================================================================
# SECTION 2 – Dead-letter queue
# ===========================================================================

function New-DeadLetterQueue {
    <#
    .SYNOPSIS
        Creates an empty dead-letter queue (DLQ) for permanently-failed items.
    #>
    $list = [System.Collections.Generic.List[object]]::new()
    return [PSCustomObject]@{
        Items = $list
    }
}

function Add-ToDeadLetterQueue {
    <#
    .SYNOPSIS
        Records a permanently-failed item together with the failure reason.
    .PARAMETER Queue
        DLQ created by New-DeadLetterQueue.
    .PARAMETER Item
        The item that failed.
    .PARAMETER Reason
        Human-readable explanation of why the item was dead-lettered.
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Queue,

        [Parameter(Mandatory)]
        $Item,

        [Parameter(Mandatory)]
        [string]$Reason
    )

    $entry = [PSCustomObject]@{
        Item   = $Item
        Reason = $Reason
    }
    $Queue.Items.Add($entry)
}

# ===========================================================================
# SECTION 3 – Item processor (thin wrapper that makes the scriptblock mockable)
# ===========================================================================

function Invoke-ProcessItem {
    <#
    .SYNOPSIS
        Calls $Processor with $Item.  Returns $true on success, $false on any
        exception.  Keeping the processor as a scriptblock parameter means
        tests can substitute any behaviour without touching production code.
    .PARAMETER Item
        The item to process.
    .PARAMETER Processor
        A scriptblock that accepts a single parameter (the item) and returns
        $true, or throws on failure.
    #>
    param(
        [Parameter(Mandatory)]
        $Item,

        [Parameter(Mandatory)]
        [scriptblock]$Processor
    )

    try {
        $result = & $Processor $Item
        # Treat explicit $false as failure too (defensive)
        if ($result -eq $false) { return $false }
        return $true
    }
    catch {
        return $false
    }
}

# ===========================================================================
# SECTION 4 – Exponential backoff retry
# ===========================================================================

function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Attempts to process $Item up to (1 + $MaxRetries) times with
        exponential back-off between retries.

        Delay formula:  BaseDelayMs * 2^(attemptIndex-1)
          attempt 2 -> BaseDelayMs * 1
          attempt 3 -> BaseDelayMs * 2
          attempt 4 -> BaseDelayMs * 4
          …

    .OUTPUTS
        A PSCustomObject with:
          Success  [bool]   – whether the item was eventually processed
          Attempts [int]    – total number of invocation attempts made
          Delays   [int[]]  – list of delays used between retries (ms)
          Error    [string] – last error message if Success is $false
    #>
    param(
        [Parameter(Mandatory)]
        $Item,

        [Parameter(Mandatory)]
        [scriptblock]$Processor,

        [int]$MaxRetries  = 3,
        [int]$BaseDelayMs = 1000
    )

    $attempts = 0
    $delays   = [System.Collections.Generic.List[int]]::new()
    $lastError = $null

    for ($retry = 0; $retry -le $MaxRetries; $retry++) {
        $attempts++

        $ok = Invoke-ProcessItem -Item $Item -Processor $Processor
        if ($ok) {
            return [PSCustomObject]@{
                Success  = $true
                Attempts = $attempts
                Delays   = $delays.ToArray()
                Error    = $null
            }
        }
        else {
            # Record the last synthetic error message (processor returned $false or threw)
            $lastError = "Item '$Item' failed on attempt $attempts"
        }

        # If there are retries remaining, wait with exponential back-off.
        if ($retry -lt $MaxRetries) {
            # delay = BaseDelayMs * 2^retry  (retry=0 → 1x, retry=1 → 2x, …)
            $delayMs = $BaseDelayMs * [Math]::Pow(2, $retry)
            $delays.Add([int]$delayMs)
            if ($delayMs -gt 0) {
                Start-Sleep -Milliseconds $delayMs
            }
        }
    }

    return [PSCustomObject]@{
        Success  = $false
        Attempts = $attempts
        Delays   = $delays.ToArray()
        Error    = $lastError
    }
}

# ===========================================================================
# SECTION 5 – Progress reporting
# ===========================================================================

function New-PipelineProgress {
    <#
    .SYNOPSIS
        Creates a mutable progress-tracking object.
    .PARAMETER TotalItems
        Total number of items that will be processed.
    #>
    param(
        [Parameter(Mandatory)]
        [int]$TotalItems
    )

    return [PSCustomObject]@{
        Total     = $TotalItems
        Processed = 0
        Failed    = 0
        Retrying  = 0
    }
}

function Update-PipelineProgress {
    <#
    .SYNOPSIS
        Updates the progress object based on a named event.
    .PARAMETER Progress
        Progress object from New-PipelineProgress.
    .PARAMETER Event
        One of: 'Processed', 'Failed', 'RetryStart', 'RetryEnd'
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Progress,

        [Parameter(Mandatory)]
        [ValidateSet('Processed', 'Failed', 'RetryStart', 'RetryEnd')]
        [string]$Event
    )

    switch ($Event) {
        'Processed'  { $Progress.Processed++ }
        'Failed'     { $Progress.Failed++    }
        'RetryStart' { $Progress.Retrying++  }
        'RetryEnd'   { $Progress.Retrying--  }
    }
}

function Write-PipelineProgress {
    <#
    .SYNOPSIS
        Writes current progress to the console (non-blocking informational output).
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Progress,

        [string]$CurrentItem = ''
    )

    $pct = if ($Progress.Total -gt 0) {
        [Math]::Round(($Progress.Processed + $Progress.Failed) / $Progress.Total * 100, 1)
    } else { 0 }

    $msg = "[{0}%] Processed={1} Failed={2} Retrying={3}" -f $pct, $Progress.Processed, $Progress.Failed, $Progress.Retrying
    if ($CurrentItem) { $msg += " | Current: $CurrentItem" }
    Write-Verbose $msg
}

# ===========================================================================
# SECTION 6 – Full pipeline orchestration
# ===========================================================================

function Invoke-Pipeline {
    <#
    .SYNOPSIS
        Runs the full error-retry pipeline:
          1. Drains the queue of items.
          2. For each item, attempts processing with exponential-backoff retry.
          3. Permanently-failed items are sent to the dead-letter queue.
          4. Emits progress during processing.
          5. Returns a summary object.

    .PARAMETER Items
        Array of items to process (the mocked queue source).
    .PARAMETER Processor
        Scriptblock accepting one parameter (item). Returns $true on success or
        throws/returns $false on failure. Fully mockable.
    .PARAMETER MaxRetries
        Maximum number of retry attempts after the initial failure. Default 3.
    .PARAMETER BaseDelayMs
        Base delay in milliseconds for exponential backoff. Default 1000.
        Set to 0 in tests to avoid real sleeps.

    .OUTPUTS
        PSCustomObject with:
          TotalItems      [int]
          ProcessedItems  [int]
          FailedItems     [int]
          DeadLetterItems [int]
          DeadLetterQueue [PSCustomObject[]]  – items + reasons
          SummaryText     [string]
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Items,

        [Parameter(Mandatory)]
        [scriptblock]$Processor,

        [int]$MaxRetries  = 3,
        [int]$BaseDelayMs = 1000
    )

    # Build queue and DLQ
    $queue    = New-Queue -Items $Items
    $dlq      = New-DeadLetterQueue
    $progress = New-PipelineProgress -TotalItems $Items.Count

    while ($queue.Items.Count -gt 0) {
        $item = Get-NextQueueItem -Queue $queue

        Write-PipelineProgress -Progress $progress -CurrentItem "$item"

        # Signal that we are about to attempt (possibly with retries)
        Update-PipelineProgress -Progress $progress -Event 'RetryStart'

        $retryResult = Invoke-WithRetry `
            -Item        $item        `
            -Processor   $Processor   `
            -MaxRetries  $MaxRetries  `
            -BaseDelayMs $BaseDelayMs

        Update-PipelineProgress -Progress $progress -Event 'RetryEnd'

        if ($retryResult.Success) {
            Update-PipelineProgress -Progress $progress -Event 'Processed'
            Write-Verbose "  OK  '$item' (attempts: $($retryResult.Attempts))"
        }
        else {
            Update-PipelineProgress -Progress $progress -Event 'Failed'
            $reason = "Failed after $($retryResult.Attempts) attempt(s): $($retryResult.Error)"
            Add-ToDeadLetterQueue -Queue $dlq -Item $item -Reason $reason
            Write-Verbose "  FAIL '$item' -> dead-letter queue. Reason: $reason"
        }

        Write-PipelineProgress -Progress $progress
    }

    # Build the final summary
    $summaryText = @"
=== Pipeline Summary ===
Total items    : $($progress.Total)
Processed (OK) : $($progress.Processed)
Failed (DLQ)   : $($progress.Failed)
Dead-letter Q  : $($dlq.Items.Count) item(s)
"@

    if ($dlq.Items.Count -gt 0) {
        $summaryText += "`nDead-letter details:"
        foreach ($entry in $dlq.Items) {
            $summaryText += "`n  - '$($entry.Item)': $($entry.Reason)"
        }
    }

    return [PSCustomObject]@{
        TotalItems      = $progress.Total
        ProcessedItems  = $progress.Processed
        FailedItems     = $progress.Failed
        DeadLetterItems = $dlq.Items.Count
        DeadLetterQueue = $dlq.Items.ToArray()
        SummaryText     = $summaryText
    }
}
