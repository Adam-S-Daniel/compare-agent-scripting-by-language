# SecretRotationValidator.psm1
#
# Core logic for the secret-rotation validator, built test-first with Pester.
# Public functions:
#   Get-SecretStatus             - classify a single secret
#   Get-RotationReport           - classify a collection and group by urgency
#   ConvertTo-MarkdownReport     - render a report as Markdown
#   ConvertTo-JsonReport         - render a report as JSON
#   Invoke-SecretRotationValidator - end-to-end entry point used by the script
#
# The module keeps side-effects (file IO, console writes) out of the core
# classification logic so it is trivially testable with in-memory objects.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-SecretStatus {
    <#
    .SYNOPSIS
        Classify a secret as 'expired', 'warning', or 'ok'.
    .DESCRIPTION
        Given a secret with LastRotated/RotationPolicyDays, the current time,
        and a warning window, returns an object with Status and
        DaysUntilRotation (negative means overdue).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]   $Secret,
        [Parameter(Mandatory)] [datetime] $Now,
        [Parameter(Mandatory)] [int]      $WarningDays
    )

    # Pull values tolerant of either PascalCase (native PS objects) or
    # camelCase (JSON -> ConvertFrom-Json).
    $name        = _Get-Prop $Secret 'Name','name'
    $lastRotated = _Get-Prop $Secret 'LastRotated','lastRotated'
    $policyDays  = _Get-Prop $Secret 'RotationPolicyDays','rotationPolicyDays'
    $requiredBy  = _Get-Prop $Secret 'RequiredBy','requiredBy'

    if ($null -eq $requiredBy) { $requiredBy = @() }

    # Parse LastRotated with a clear error message — users edit these by hand.
    # Note: [ref] target must be of a definite type under strict mode, so the
    # ref variable is pre-initialized to DateTime.MinValue.
    $parsed = [datetime]::MinValue
    if ($null -eq $lastRotated -or
        -not [datetime]::TryParse([string]$lastRotated, [ref]$parsed)) {
        throw "Secret '$name' has an unparseable LastRotated value: '$lastRotated'"
    }

    if (-not ($policyDays -is [int] -or $policyDays -is [long] -or $policyDays -is [double])) {
        throw "Secret '$name' has a missing or non-numeric RotationPolicyDays"
    }
    $policyDaysInt = [int]$policyDays
    if ($policyDaysInt -le 0) {
        throw "Secret '$name' has a non-positive RotationPolicyDays ($policyDaysInt)"
    }

    $dueDate = $parsed.AddDays($policyDaysInt)
    # Truncate to whole days so "4 days away" reads naturally regardless of the
    # time-of-day on $Now.
    $daysUntilRotation = [int][math]::Floor(($dueDate.Date - $Now.Date).TotalDays)

    $status = if ($daysUntilRotation -lt 0) {
        'expired'
    } elseif ($daysUntilRotation -le $WarningDays) {
        'warning'
    } else {
        'ok'
    }

    [pscustomobject]@{
        Name               = [string]$name
        LastRotated        = $parsed.ToString('yyyy-MM-dd')
        RotationPolicyDays = $policyDaysInt
        RequiredBy         = @($requiredBy)
        DueDate            = $dueDate.ToString('yyyy-MM-dd')
        DaysUntilRotation  = $daysUntilRotation
        Status             = $status
    }
}

function Get-RotationReport {
    <#
    .SYNOPSIS
        Classify a list of secrets, group by urgency, include metadata.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Secrets,
        [Parameter(Mandatory)] [datetime] $Now,
        [Parameter(Mandatory)] [int]      $WarningDays
    )

    $classified = @()
    foreach ($s in $Secrets) {
        $classified += Get-SecretStatus -Secret $s -Now $Now -WarningDays $WarningDays
    }

    # Most-overdue first / soonest-due first respectively.
    $expired = @($classified | Where-Object Status -eq 'expired' |
                 Sort-Object DaysUntilRotation)
    $warning = @($classified | Where-Object Status -eq 'warning' |
                 Sort-Object DaysUntilRotation)
    $ok      = @($classified | Where-Object Status -eq 'ok' |
                 Sort-Object DaysUntilRotation)

    [pscustomobject]@{
        GeneratedAt  = $Now
        WarningDays  = $WarningDays
        TotalSecrets = $classified.Count
        Expired      = $expired
        Warning      = $warning
        Ok           = $ok
    }
}

function ConvertTo-MarkdownReport {
    <#
    .SYNOPSIS
        Render a rotation report as a Markdown document.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Report
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Secret Rotation Report')
    $lines.Add('')
    $lines.Add("_Generated: $($Report.GeneratedAt.ToString('yyyy-MM-dd HH:mm:ssZ'))_")
    $lines.Add("_Warning window: $($Report.WarningDays) days_")
    $lines.Add("_Total secrets: $($Report.TotalSecrets)_")
    $lines.Add('')

    if ($Report.TotalSecrets -eq 0) {
        $lines.Add('_No secrets found._')
        return ($lines -join "`n")
    }

    foreach ($group in @(
        @{ Name='Expired'; Items=$Report.Expired },
        @{ Name='Warning'; Items=$Report.Warning },
        @{ Name='OK';      Items=$Report.Ok }
    )) {
        if ($group.Items.Count -eq 0) { continue }
        $lines.Add("## $($group.Name) ($($group.Items.Count))")
        $lines.Add('')
        $lines.Add('| Name | Last Rotated | Days Until Rotation | Required By |')
        $lines.Add('|------|--------------|---------------------|-------------|')
        foreach ($s in $group.Items) {
            $requiredBy = ($s.RequiredBy -join ', ')
            $lines.Add("| $($s.Name) | $($s.LastRotated) | $($s.DaysUntilRotation) | $requiredBy |")
        }
        $lines.Add('')
    }

    ($lines -join "`n").TrimEnd()
}

function ConvertTo-JsonReport {
    <#
    .SYNOPSIS
        Render a rotation report as a JSON string with camelCase fields.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Report
    )

    $project = {
        param($s)
        [pscustomobject]@{
            name               = $s.Name
            lastRotated        = $s.LastRotated
            rotationPolicyDays = $s.RotationPolicyDays
            requiredBy         = @($s.RequiredBy)
            dueDate            = $s.DueDate
            daysUntilRotation  = $s.DaysUntilRotation
            status             = $s.Status
        }
    }

    $payload = [pscustomobject]@{
        generatedAt  = $Report.GeneratedAt.ToString('o')
        warningDays  = $Report.WarningDays
        totalSecrets = $Report.TotalSecrets
        expired      = @($Report.Expired | ForEach-Object { & $project $_ })
        warning      = @($Report.Warning | ForEach-Object { & $project $_ })
        ok           = @($Report.Ok      | ForEach-Object { & $project $_ })
    }

    $payload | ConvertTo-Json -Depth 6
}

function Invoke-SecretRotationValidator {
    <#
    .SYNOPSIS
        Read a secrets config from disk and return the chosen report format.
    .PARAMETER Path
        Path to a JSON file containing an array of secret objects with
        name, lastRotated, rotationPolicyDays, requiredBy fields.
    .PARAMETER WarningDays
        Days before expiry to flag a secret as 'warning'.
    .PARAMETER Format
        'markdown' or 'json'.
    .PARAMETER Now
        Override current time (used by tests for determinism).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]   $Path,
        [Parameter(Mandatory)] [int]      $WarningDays,
        [ValidateSet('markdown','json')] [string] $Format = 'markdown',
        [datetime] $Now = (Get-Date)
    )

    if (-not (Test-Path -Path $Path)) {
        throw "Secrets config not found: $Path"
    }

    $raw = Get-Content -Path $Path -Raw
    $secrets = $null
    try {
        $secrets = $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to parse JSON from '$Path': $($_.Exception.Message)"
    }

    # Accept either a bare array or `{ secrets: [...] }`.
    if ($secrets -is [pscustomobject] -and $secrets.PSObject.Properties.Name -contains 'secrets') {
        $secrets = $secrets.secrets
    }
    if ($null -eq $secrets) { $secrets = @() }
    $secrets = @($secrets)

    $report = Get-RotationReport -Secrets $secrets -Now $Now -WarningDays $WarningDays

    switch ($Format) {
        'markdown' { return (ConvertTo-MarkdownReport -Report $report) }
        'json'     { return (ConvertTo-JsonReport     -Report $report) }
    }
}

# Internal helper: return the first property value whose name is in $Candidates,
# or $null if none match. Tolerates both pscustomobject and hashtable inputs.
function _Get-Prop {
    param([object] $Obj, [string[]] $Candidates)
    if ($null -eq $Obj) { return $null }
    if ($Obj -is [hashtable]) {
        foreach ($c in $Candidates) { if ($Obj.ContainsKey($c)) { return $Obj[$c] } }
        return $null
    }
    $names = $Obj.PSObject.Properties.Name
    foreach ($c in $Candidates) {
        if ($names -contains $c) { return $Obj.$c }
    }
    return $null
}

Export-ModuleMember -Function Get-SecretStatus, Get-RotationReport,
    ConvertTo-MarkdownReport, ConvertTo-JsonReport, Invoke-SecretRotationValidator
