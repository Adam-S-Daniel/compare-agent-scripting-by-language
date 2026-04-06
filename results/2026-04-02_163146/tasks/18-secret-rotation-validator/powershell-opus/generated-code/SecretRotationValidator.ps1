# SecretRotationValidator.ps1
# Module for validating secret rotation status and generating reports.
#
# Approach:
#   1. Get-SecretStatus   - Classifies a single secret as Expired/Warning/OK
#   2. Get-RotationReport - Processes multiple secrets and groups by urgency
#   3. ConvertTo-RotationMarkdown - Renders a report as a markdown table
#   4. ConvertTo-RotationJson    - Renders a report as JSON
#   5. Import-SecretsConfig      - Loads secrets from a JSON config file
#   6. Format-RotationOutput     - Dispatches to the correct formatter

function Get-SecretStatus {
    <#
    .SYNOPSIS
        Classifies a secret as Expired, Warning, or OK based on its rotation policy.
    .PARAMETER Secret
        A hashtable with Name, LastRotated (datetime), RotationDays (int), RequiredBy (string[]).
    .PARAMETER ReferenceDate
        The date to evaluate against (defaults to now).
    .PARAMETER WarningDays
        Number of days before expiry to trigger a warning (default 14).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Secret,

        [Parameter()]
        [datetime]$ReferenceDate = (Get-Date),

        [Parameter()]
        [int]$WarningDays = 14
    )

    # Calculate when the secret expires and how many days remain
    $expiryDate = ([datetime]$Secret.LastRotated).AddDays($Secret.RotationDays)
    $daysUntilExpiry = ($expiryDate - $ReferenceDate).Days

    # Determine status based on days until expiry relative to warning window
    if ($daysUntilExpiry -le 0) {
        $status = "Expired"
    }
    elseif ($daysUntilExpiry -le $WarningDays) {
        $status = "Warning"
    }
    else {
        $status = "OK"
    }

    # Build and return the result object
    [PSCustomObject]@{
        Name            = $Secret.Name
        LastRotated     = [datetime]$Secret.LastRotated
        RotationDays    = $Secret.RotationDays
        ExpiryDate      = $expiryDate
        DaysUntilExpiry = $daysUntilExpiry
        DaysOverdue     = if ($daysUntilExpiry -le 0) { [Math]::Abs($daysUntilExpiry) } else { 0 }
        Status          = $status
        RequiredBy      = $Secret.RequiredBy
    }
}

function Get-RotationReport {
    <#
    .SYNOPSIS
        Generates a rotation report grouping secrets by urgency.
    .PARAMETER Secrets
        Array of secret hashtables.
    .PARAMETER ReferenceDate
        The date to evaluate against.
    .PARAMETER WarningDays
        Warning window in days.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Secrets,

        [Parameter()]
        [datetime]$ReferenceDate = (Get-Date),

        [Parameter()]
        [int]$WarningDays = 14
    )

    # Classify each secret
    $results = foreach ($secret in $Secrets) {
        Get-SecretStatus -Secret $secret -ReferenceDate $ReferenceDate -WarningDays $WarningDays
    }

    # Group by status — ensure arrays even when empty
    $expired = @($results | Where-Object { $_.Status -eq "Expired" } | Sort-Object DaysOverdue -Descending)
    $warning = @($results | Where-Object { $_.Status -eq "Warning" } | Sort-Object DaysUntilExpiry)
    $ok      = @($results | Where-Object { $_.Status -eq "OK" }      | Sort-Object DaysUntilExpiry)

    # Build summary
    $summary = [PSCustomObject]@{
        TotalSecrets = $Secrets.Count
        ExpiredCount = $expired.Count
        WarningCount = $warning.Count
        OKCount      = $ok.Count
        ReportDate   = $ReferenceDate
        WarningDays  = $WarningDays
    }

    [PSCustomObject]@{
        Expired = $expired
        Warning = $warning
        OK      = $ok
        Summary = $summary
    }
}

function ConvertTo-RotationMarkdown {
    <#
    .SYNOPSIS
        Converts a rotation report to a markdown-formatted string with tables.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Report
    )

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("# Secret Rotation Report")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("**Report Date:** $($Report.Summary.ReportDate.ToString('yyyy-MM-dd'))")
    [void]$sb.AppendLine("**Warning Window:** $($Report.Summary.WarningDays) days")
    [void]$sb.AppendLine("")

    # Summary section
    [void]$sb.AppendLine("## Summary")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Metric | Count |")
    [void]$sb.AppendLine("| --- | --- |")
    [void]$sb.AppendLine("| Total Secrets | $($Report.Summary.TotalSecrets) |")
    [void]$sb.AppendLine("| Expired | $($Report.Summary.ExpiredCount) |")
    [void]$sb.AppendLine("| Warning | $($Report.Summary.WarningCount) |")
    [void]$sb.AppendLine("| OK | $($Report.Summary.OKCount) |")
    [void]$sb.AppendLine("")

    # Detail table with all secrets
    [void]$sb.AppendLine("## Details")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Name | Status | Last Rotated | Rotation Policy | Days Until Expiry | Required By |")
    [void]$sb.AppendLine("| --- | --- | --- | --- | --- | --- |")

    # Emit expired first, then warning, then ok
    $allEntries = @($Report.Expired) + @($Report.Warning) + @($Report.OK)
    foreach ($entry in $allEntries) {
        $services = ($entry.RequiredBy -join ", ")
        $daysDisplay = if ($entry.Status -eq "Expired") { "$($entry.DaysOverdue) overdue" } else { $entry.DaysUntilExpiry }
        [void]$sb.AppendLine("| $($entry.Name) | $($entry.Status) | $($entry.LastRotated.ToString('yyyy-MM-dd')) | $($entry.RotationDays) days | $daysDisplay | $services |")
    }

    [void]$sb.AppendLine("")

    # Notifications section grouped by urgency
    if ($Report.Expired.Count -gt 0) {
        [void]$sb.AppendLine("## Expired Secrets (Immediate Action Required)")
        [void]$sb.AppendLine("")
        foreach ($entry in $Report.Expired) {
            $services = ($entry.RequiredBy -join ", ")
            [void]$sb.AppendLine("- **$($entry.Name)**: $($entry.DaysOverdue) days overdue, affects: $services")
        }
        [void]$sb.AppendLine("")
    }

    if ($Report.Warning.Count -gt 0) {
        [void]$sb.AppendLine("## Warning (Rotation Needed Soon)")
        [void]$sb.AppendLine("")
        foreach ($entry in $Report.Warning) {
            $services = ($entry.RequiredBy -join ", ")
            [void]$sb.AppendLine("- **$($entry.Name)**: expires in $($entry.DaysUntilExpiry) days, affects: $services")
        }
        [void]$sb.AppendLine("")
    }

    $sb.ToString()
}

function ConvertTo-RotationJson {
    <#
    .SYNOPSIS
        Converts a rotation report to JSON format.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Report
    )

    # Build a clean structure suitable for JSON serialization
    $jsonObj = @{
        summary = @{
            totalSecrets = $Report.Summary.TotalSecrets
            expiredCount = $Report.Summary.ExpiredCount
            warningCount = $Report.Summary.WarningCount
            okCount      = $Report.Summary.OKCount
            reportDate   = $Report.Summary.ReportDate.ToString("yyyy-MM-dd")
            warningDays  = $Report.Summary.WarningDays
        }
        expired = @(foreach ($e in $Report.Expired) {
            @{
                name            = $e.Name
                lastRotated     = $e.LastRotated.ToString("yyyy-MM-dd")
                rotationDays    = $e.RotationDays
                expiryDate      = $e.ExpiryDate.ToString("yyyy-MM-dd")
                daysOverdue     = $e.DaysOverdue
                daysUntilExpiry = $e.DaysUntilExpiry
                status          = $e.Status
                requiredBy      = @($e.RequiredBy)
            }
        })
        warning = @(foreach ($w in $Report.Warning) {
            @{
                name            = $w.Name
                lastRotated     = $w.LastRotated.ToString("yyyy-MM-dd")
                rotationDays    = $w.RotationDays
                expiryDate      = $w.ExpiryDate.ToString("yyyy-MM-dd")
                daysUntilExpiry = $w.DaysUntilExpiry
                status          = $w.Status
                requiredBy      = @($w.RequiredBy)
            }
        })
        ok = @(foreach ($o in $Report.OK) {
            @{
                name            = $o.Name
                lastRotated     = $o.LastRotated.ToString("yyyy-MM-dd")
                rotationDays    = $o.RotationDays
                expiryDate      = $o.ExpiryDate.ToString("yyyy-MM-dd")
                daysUntilExpiry = $o.DaysUntilExpiry
                status          = $o.Status
                requiredBy      = @($o.RequiredBy)
            }
        })
    }

    $jsonObj | ConvertTo-Json -Depth 5
}

function Import-SecretsConfig {
    <#
    .SYNOPSIS
        Loads secret configuration from a JSON file and returns normalized hashtables.
    .PARAMETER Path
        Path to the JSON configuration file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Validate the file exists
    if (-not (Test-Path $Path)) {
        throw "Configuration file not found: $Path"
    }

    # Read and parse the JSON — use ErrorAction Stop to ensure parse errors are caught
    try {
        $raw = Get-Content -Path $Path -Raw -ErrorAction Stop
        $config = $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to parse configuration file: $Path - $($_.Exception.Message)"
    }

    # Normalize each secret entry into the expected hashtable format
    $secrets = foreach ($s in $config.secrets) {
        @{
            Name         = $s.name
            LastRotated  = [datetime]::Parse($s.lastRotated)
            RotationDays = [int]$s.rotationDays
            RequiredBy   = @($s.requiredBy)
        }
    }

    @($secrets)
}

function Format-RotationOutput {
    <#
    .SYNOPSIS
        High-level function: generates a report and formats it in the requested format.
    .PARAMETER Secrets
        Array of secret hashtables.
    .PARAMETER Format
        Output format: "markdown" or "json".
    .PARAMETER ReferenceDate
        Date to evaluate against.
    .PARAMETER WarningDays
        Warning window in days.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Secrets,

        [Parameter(Mandatory)]
        [string]$Format,

        [Parameter()]
        [datetime]$ReferenceDate = (Get-Date),

        [Parameter()]
        [int]$WarningDays = 14
    )

    $report = Get-RotationReport -Secrets $Secrets -ReferenceDate $ReferenceDate -WarningDays $WarningDays

    switch ($Format.ToLower()) {
        "markdown" { ConvertTo-RotationMarkdown -Report $report }
        "json"     { ConvertTo-RotationJson -Report $report }
        default    { throw "Unsupported output format: $Format. Supported formats: markdown, json" }
    }
}
