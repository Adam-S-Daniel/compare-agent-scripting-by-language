# SecretRotationValidator.psm1
# Validates secret rotation policies and generates urgency-grouped reports.
#
# TDD Cycle 1  — New-Secret:            create/validate a secret config object
# TDD Cycle 2  — Get-SecretStatus:      classify a single secret by urgency
# TDD Cycle 3  — Get-RotationReport:    process a list → grouped report
# TDD Cycle 4  — ConvertTo-JsonReport:  serialize report as JSON string
# TDD Cycle 5  — ConvertTo-MarkdownReport: serialize report as Markdown tables

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Cycle 1 — New-Secret
# ---------------------------------------------------------------------------

function New-Secret {
    <#
    .SYNOPSIS
        Creates a validated secret configuration hashtable.
    .DESCRIPTION
        Validates inputs and returns a hashtable representing a single secret
        with its rotation metadata.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory)][string]   $Name,
        [Parameter(Mandatory)][datetime] $LastRotated,
        [Parameter(Mandatory)][int]      $RotationPolicyDays,
        [Parameter(Mandatory)][string[]] $RequiredBy
    )

    # Guard: empty name
    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "Name must not be empty."
    }

    # Guard: policy must be positive
    if ($RotationPolicyDays -le 0) {
        throw "RotationPolicyDays must be greater than zero. Got: $RotationPolicyDays"
    }

    # Guard: at least one consuming service
    if ($RequiredBy.Count -eq 0) {
        throw "RequiredBy must contain at least one service name."
    }

    return @{
        Name               = $Name
        LastRotated        = $LastRotated
        RotationPolicyDays = $RotationPolicyDays
        RequiredBy         = $RequiredBy
    }
}

# ---------------------------------------------------------------------------
# Cycle 2 — Get-SecretStatus
# ---------------------------------------------------------------------------

function Get-SecretStatus {
    <#
    .SYNOPSIS
        Classifies a single secret as Expired, Warning, or Ok.
    .DESCRIPTION
        Computes the expiry date from LastRotated + RotationPolicyDays.
        Compares against ReferenceDate:
          - DaysUntilExpiry <= 0           → Expired
          - 0 < DaysUntilExpiry <= window  → Warning
          - DaysUntilExpiry > window       → Ok
        Returns a hashtable with Name, ExpiryDate, DaysUntilExpiry,
        RequiredBy, and Status.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory)][hashtable] $Secret,
        [Parameter(Mandatory)][datetime]  $ReferenceDate,
        [Parameter()][int]                $WarningWindowDays = 7
    )

    [datetime]$expiryDate    = $Secret.LastRotated.AddDays([int]$Secret.RotationPolicyDays)
    [int]$daysUntilExpiry    = [int]([math]::Floor(($expiryDate - $ReferenceDate).TotalDays))

    [string]$status = if ($daysUntilExpiry -le 0) {
        'Expired'
    }
    elseif ($daysUntilExpiry -le $WarningWindowDays) {
        'Warning'
    }
    else {
        'Ok'
    }

    return @{
        Name            = [string]$Secret.Name
        ExpiryDate      = $expiryDate
        DaysUntilExpiry = $daysUntilExpiry
        RequiredBy      = [string[]]$Secret.RequiredBy
        Status          = $status
    }
}

# ---------------------------------------------------------------------------
# Cycle 3 — Get-RotationReport
# ---------------------------------------------------------------------------

function Get-RotationReport {
    <#
    .SYNOPSIS
        Processes a list of secrets and returns a report grouped by urgency.
    .DESCRIPTION
        Calls Get-SecretStatus for each secret and partitions results into
        three arrays: Expired, Warning, and Ok.
        Returns a hashtable with Expired, Warning, Ok, and GeneratedAt keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory)][AllowEmptyCollection()][array] $Secrets,
        [Parameter(Mandatory)][datetime] $ReferenceDate,
        [Parameter()][int]               $WarningWindowDays = 7
    )

    [hashtable[]]$expired = @()
    [hashtable[]]$warning = @()
    [hashtable[]]$ok      = @()

    foreach ($secret in $Secrets) {
        [hashtable]$status = Get-SecretStatus -Secret $secret `
                                              -ReferenceDate $ReferenceDate `
                                              -WarningWindowDays $WarningWindowDays
        switch ($status.Status) {
            'Expired' { $expired += $status }
            'Warning' { $warning += $status }
            'Ok'      { $ok      += $status }
        }
    }

    return @{
        Expired     = $expired
        Warning     = $warning
        Ok          = $ok
        GeneratedAt = $ReferenceDate
    }
}

# ---------------------------------------------------------------------------
# Cycle 4 — ConvertTo-JsonReport
# ---------------------------------------------------------------------------

function ConvertTo-JsonReport {
    <#
    .SYNOPSIS
        Serializes a rotation report to a JSON string.
    .DESCRIPTION
        Converts the Expired/Warning/Ok arrays (and GeneratedAt) from the
        report hashtable into a JSON-formatted string using ConvertTo-Json.
        Dates are formatted as ISO-8601 strings for portability.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)][hashtable] $Report
    )

    # Build a PSCustomObject so ConvertTo-Json preserves key order and handles
    # arrays of hashtables correctly (hashtables alone serialize as objects).
    [PSCustomObject]$payload = [PSCustomObject]@{
        GeneratedAt = $Report.GeneratedAt.ToString('yyyy-MM-ddTHH:mm:ss')
        Expired     = @($Report.Expired | ForEach-Object { _ConvertStatusToJson $_ })
        Warning     = @($Report.Warning | ForEach-Object { _ConvertStatusToJson $_ })
        Ok          = @($Report.Ok      | ForEach-Object { _ConvertStatusToJson $_ })
    }

    return $payload | ConvertTo-Json -Depth 5
}

# Private helper — not exported; converts a single status hashtable to a
# JSON-friendly PSCustomObject with ISO-8601 dates.
function _ConvertStatusToJson {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory)][hashtable] $StatusEntry
    )

    return [PSCustomObject]@{
        Name            = [string]$StatusEntry.Name
        Status          = [string]$StatusEntry.Status
        ExpiryDate      = $StatusEntry.ExpiryDate.ToString('yyyy-MM-dd')
        DaysUntilExpiry = [int]$StatusEntry.DaysUntilExpiry
        RequiredBy      = [string[]]$StatusEntry.RequiredBy
    }
}

# ---------------------------------------------------------------------------
# Cycle 5 — ConvertTo-MarkdownReport
# ---------------------------------------------------------------------------

function ConvertTo-MarkdownReport {
    <#
    .SYNOPSIS
        Serializes a rotation report as a Markdown document with tables.
    .DESCRIPTION
        Produces a Markdown string with a header and one H2 section per
        urgency group (Expired, Warning, Ok).  Each section contains a
        pipe-delimited table with columns:
        Name | Status | DaysUntilExpiry | ExpiryDate | RequiredBy
        If a group is empty the section still appears but notes "None."
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)][hashtable] $Report
    )

    [string]$tableHeader = @'
| Name | Status | DaysUntilExpiry | ExpiryDate | RequiredBy |
|------|--------|-----------------|------------|------------|
'@

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    $null = $sb.AppendLine("# Secret Rotation Report")
    $null = $sb.AppendLine("Generated: $($Report.GeneratedAt.ToString('yyyy-MM-dd HH:mm:ss'))")
    $null = $sb.AppendLine()

    foreach ($group in @('Expired', 'Warning', 'Ok')) {
        $null = $sb.AppendLine("## $group")
        [array]$entries = @($Report[$group])

        if ($entries.Count -eq 0) {
            $null = $sb.AppendLine("_None._")
            $null = $sb.AppendLine()
            continue
        }

        $null = $sb.AppendLine($tableHeader)

        foreach ($entry in $entries) {
            [string]$requiredBy = ($entry.RequiredBy -join ', ')
            [string]$row = "| $($entry.Name) | $($entry.Status) | $($entry.DaysUntilExpiry) | $($entry.ExpiryDate.ToString('yyyy-MM-dd')) | $requiredBy |"
            $null = $sb.AppendLine($row)
        }

        $null = $sb.AppendLine()
    }

    return $sb.ToString()
}

# Export public functions only
Export-ModuleMember -Function New-Secret, Get-SecretStatus, Get-RotationReport,
                               ConvertTo-JsonReport, ConvertTo-MarkdownReport
