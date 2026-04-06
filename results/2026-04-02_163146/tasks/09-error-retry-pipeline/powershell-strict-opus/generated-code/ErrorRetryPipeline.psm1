# ErrorRetryPipeline.psm1
# A pipeline that processes items from a queue with exponential backoff retry,
# dead-letter queue for permanent failures, and progress reporting.
# All queue and processing operations are mockable via scriptblock parameters.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-ProcessingQueue {
    <#
    .SYNOPSIS
        Creates a new processing queue from an array of items.
    .DESCRIPTION
        Returns a hashtable representing a queue with items and a position tracker.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Items
    )

    [hashtable]$queue = @{
        Items    = [System.Collections.ArrayList]::new([object[]]$Items)
        Position = [int]0
    }
    return $queue
}

function Get-NextQueueItem {
    <#
    .SYNOPSIS
        Dequeues the next item from a processing queue.
    .DESCRIPTION
        Returns the next item and advances the position, or $null if exhausted.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Queue
    )

    [int]$pos = $Queue.Position
    if ($pos -ge $Queue.Items.Count) {
        return $null
    }
    [object]$item = $Queue.Items[$pos]
    $Queue.Position = $pos + 1
    return $item
}

function New-DeadLetterQueue {
    <#
    .SYNOPSIS
        Creates a new dead-letter queue for permanently failed items.
    .DESCRIPTION
        Returns a hashtable with an items list and an Add method for recording failures.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    [hashtable]$dlq = @{
        Items = [System.Collections.ArrayList]::new()
    }
    return $dlq
}

function Add-DeadLetterItem {
    <#
    .SYNOPSIS
        Adds a failed item and its error to the dead-letter queue.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$DeadLetterQueue,

        [Parameter(Mandatory = $true)]
        [object]$Item,

        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage,

        [Parameter(Mandatory = $true)]
        [int]$Attempts
    )

    [hashtable]$entry = @{
        Item         = $Item
        ErrorMessage = $ErrorMessage
        Attempts     = $Attempts
        Timestamp    = [datetime]::UtcNow
    }
    [void]$DeadLetterQueue.Items.Add($entry)
}

function Get-ExponentialBackoffDelay {
    <#
    .SYNOPSIS
        Calculates exponential backoff delay in milliseconds.
    .DESCRIPTION
        Returns delay = BaseDelayMs * 2^(attempt-1), capped at MaxDelayMs.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Attempt,

        [Parameter(Mandatory = $false)]
        [int]$BaseDelayMs = 100,

        [Parameter(Mandatory = $false)]
        [int]$MaxDelayMs = 10000
    )

    # Exponential: base * 2^(attempt-1)
    [double]$delay = $BaseDelayMs * [Math]::Pow(2, ($Attempt - 1))
    [int]$result = [Math]::Min([int]$delay, $MaxDelayMs)
    return $result
}

function Invoke-ItemWithRetry {
    <#
    .SYNOPSIS
        Processes a single item with exponential backoff retry.
    .DESCRIPTION
        Calls the ProcessAction scriptblock. On failure, retries up to MaxRetries
        times with exponential backoff. Returns a result hashtable.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Item,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ProcessAction,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$BaseDelayMs = 100,

        [Parameter(Mandatory = $false)]
        [int]$MaxDelayMs = 10000,

        [Parameter(Mandatory = $false)]
        [scriptblock]$DelayAction = $null
    )

    # Default delay action uses Start-Sleep
    if ($null -eq $DelayAction) {
        $DelayAction = {
            param([int]$Ms)
            Start-Sleep -Milliseconds $Ms
        }
    }

    [int]$attempt = 0
    [string]$lastError = ''

    while ($attempt -le $MaxRetries) {
        $attempt++
        try {
            # Invoke the processing action with the item
            [object]$result = & $ProcessAction $Item
            return @{
                Success  = [bool]$true
                Item     = $Item
                Result   = $result
                Attempts = [int]$attempt
                Error    = [string]''
            }
        }
        catch {
            $lastError = $_.Exception.Message

            # If we haven't exhausted retries, wait with exponential backoff
            if ($attempt -le $MaxRetries) {
                [int]$delayMs = Get-ExponentialBackoffDelay -Attempt $attempt -BaseDelayMs $BaseDelayMs -MaxDelayMs $MaxDelayMs
                & $DelayAction $delayMs
            }
        }
    }

    # All retries exhausted — return failure
    return @{
        Success  = [bool]$false
        Item     = $Item
        Result   = $null
        Attempts = [int]$attempt
        Error    = [string]$lastError
    }
}

function New-ProgressTracker {
    <#
    .SYNOPSIS
        Creates a new progress tracker for pipeline processing.
    .DESCRIPTION
        Tracks processed, failed, retrying counts and detailed event log.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [int]$TotalItems
    )

    [hashtable]$tracker = @{
        TotalItems = [int]$TotalItems
        Processed  = [int]0
        Failed     = [int]0
        Retrying   = [int]0
        Events     = [System.Collections.ArrayList]::new()
    }
    return $tracker
}

function Update-Progress {
    <#
    .SYNOPSIS
        Records a progress event in the tracker.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Tracker,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Processed', 'Failed', 'Retrying')]
        [string]$EventType,

        [Parameter(Mandatory = $true)]
        [object]$Item,

        [Parameter(Mandatory = $false)]
        [string]$Message = ''
    )

    switch ($EventType) {
        'Processed' { $Tracker.Processed++ }
        'Failed'    { $Tracker.Failed++ }
        'Retrying'  { $Tracker.Retrying++ }
    }

    [hashtable]$event = @{
        EventType = [string]$EventType
        Item      = $Item
        Message   = [string]$Message
        Timestamp = [datetime]::UtcNow
    }
    [void]$Tracker.Events.Add($event)
}

function Get-PipelineSummary {
    <#
    .SYNOPSIS
        Generates a summary report from a progress tracker and dead-letter queue.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Tracker,

        [Parameter(Mandatory = $true)]
        [hashtable]$DeadLetterQueue
    )

    [hashtable]$summary = @{
        TotalItems       = [int]$Tracker.TotalItems
        Processed        = [int]$Tracker.Processed
        Failed           = [int]$Tracker.Failed
        RetryAttempts    = [int]$Tracker.Retrying
        DeadLetterCount  = [int]$DeadLetterQueue.Items.Count
        DeadLetterItems  = [object[]]@($DeadLetterQueue.Items.ToArray())
        SuccessRate      = if ($Tracker.TotalItems -gt 0) {
            [double]($Tracker.Processed / $Tracker.TotalItems * 100)
        } else {
            [double]0.0
        }
    }
    return $summary
}

function Invoke-ProcessingPipeline {
    <#
    .SYNOPSIS
        Main pipeline function: processes all items from a queue with retry and dead-letter.
    .DESCRIPTION
        Dequeues items, processes each with retry logic, reports progress,
        and sends permanently failed items to the dead-letter queue.
        Returns a final summary.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Queue,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ProcessAction,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$BaseDelayMs = 100,

        [Parameter(Mandatory = $false)]
        [int]$MaxDelayMs = 10000,

        [Parameter(Mandatory = $false)]
        [scriptblock]$DelayAction = $null,

        [Parameter(Mandatory = $false)]
        [scriptblock]$ProgressCallback = $null
    )

    # Default no-op delay for testing (avoids real sleeps)
    if ($null -eq $DelayAction) {
        $DelayAction = {
            param([int]$Ms)
            Start-Sleep -Milliseconds $Ms
        }
    }

    [hashtable]$dlq = New-DeadLetterQueue
    [int]$totalItems = $Queue.Items.Count - $Queue.Position
    [hashtable]$tracker = New-ProgressTracker -TotalItems $totalItems

    # Process each item from the queue
    while ($true) {
        [object]$item = Get-NextQueueItem -Queue $Queue
        if ($null -eq $item) {
            break
        }

        [hashtable]$result = Invoke-ItemWithRetry `
            -Item $item `
            -ProcessAction $ProcessAction `
            -MaxRetries $MaxRetries `
            -BaseDelayMs $BaseDelayMs `
            -MaxDelayMs $MaxDelayMs `
            -DelayAction $DelayAction

        if ($result.Success) {
            Update-Progress -Tracker $tracker -EventType 'Processed' -Item $item -Message 'Success'
        }
        else {
            Update-Progress -Tracker $tracker -EventType 'Failed' -Item $item -Message $result.Error
            Add-DeadLetterItem -DeadLetterQueue $dlq -Item $item -ErrorMessage $result.Error -Attempts $result.Attempts
        }

        # Record retry attempts (attempts > 1 means retries occurred)
        if ($result.Attempts -gt 1) {
            [int]$retryCount = $result.Attempts - 1
            for ([int]$i = 0; $i -lt $retryCount; $i++) {
                Update-Progress -Tracker $tracker -EventType 'Retrying' -Item $item -Message "Retry $($i + 1)"
            }
        }

        # Invoke progress callback if provided
        if ($null -ne $ProgressCallback) {
            & $ProgressCallback $tracker
        }
    }

    [hashtable]$summary = Get-PipelineSummary -Tracker $tracker -DeadLetterQueue $dlq
    return $summary
}

# Export all public functions
Export-ModuleMember -Function @(
    'New-ProcessingQueue'
    'Get-NextQueueItem'
    'New-DeadLetterQueue'
    'Add-DeadLetterItem'
    'Get-ExponentialBackoffDelay'
    'Invoke-ItemWithRetry'
    'New-ProgressTracker'
    'Update-Progress'
    'Get-PipelineSummary'
    'Invoke-ProcessingPipeline'
)
