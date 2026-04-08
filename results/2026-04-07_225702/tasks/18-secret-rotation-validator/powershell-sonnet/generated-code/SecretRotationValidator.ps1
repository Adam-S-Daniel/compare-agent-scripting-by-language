# SecretRotationValidator.ps1
# Secret rotation analysis and reporting module.
#
# TDD approach:
#   1. Tests were written first (red — all failed against this empty file).
#   2. This implementation was written to make each test group pass (green).
#   3. Code was then refactored for clarity without breaking tests.
#
# Public API:
#   Get-SecretStatus            — classify a single secret
#   Invoke-SecretRotationAnalysis — analyse a collection and group by urgency
#   Format-RotationReport       — render a report as Markdown or JSON
#   New-RotationReport          — end-to-end pipeline (config → formatted output)

# ---------------------------------------------------------------------------
# Get-SecretStatus
# ---------------------------------------------------------------------------
# Given a single secret hashtable, the reference date, and a warning window
# (in days), returns a new hashtable that adds:
#   - ExpiryDate      : [datetime] when the secret must be rotated by
#   - DaysUntilExpiry : [int] positive = days remaining, negative = overdue
#   - Status          : "expired" | "warning" | "ok"
function Get-SecretStatus {
    param(
        [hashtable] $Secret,
        [datetime]  $ReferenceDate,
        [int]       $WarningWindowDays = 30
    )

    # Ensure LastRotated is a [datetime] (callers may pass a string)
    $lastRotated = $Secret.LastRotated
    if ($lastRotated -is [string]) {
        $lastRotated = [datetime]::Parse($lastRotated)
    }

    $expiryDate       = $lastRotated.AddDays($Secret.RotationPolicyDays)
    $daysUntilExpiry  = [int][math]::Floor(($expiryDate - $ReferenceDate).TotalDays)

    # Classification rules:
    #   expired  — already past (or exactly at) the deadline
    #   warning  — within the warning window but not yet expired
    #   ok       — more than WarningWindowDays away from expiry
    $status = if ($daysUntilExpiry -le 0) {
        "expired"
    } elseif ($daysUntilExpiry -le $WarningWindowDays) {
        "warning"
    } else {
        "ok"
    }

    return @{
        Name               = $Secret.Name
        LastRotated        = $lastRotated
        RotationPolicyDays = $Secret.RotationPolicyDays
        ExpiryDate         = $expiryDate
        DaysUntilExpiry    = $daysUntilExpiry
        Status             = $status
        RequiredBy         = $Secret.RequiredBy
    }
}

# ---------------------------------------------------------------------------
# Invoke-SecretRotationAnalysis
# ---------------------------------------------------------------------------
# Processes every secret in the provided array and groups results into three
# urgency buckets: Expired, Warning, Ok.  Also computes a Summary.
function Invoke-SecretRotationAnalysis {
    param(
        [array]    $Secrets,
        [datetime] $ReferenceDate,
        [int]      $WarningWindowDays = 30
    )

    $expired = @()
    $warning = @()
    $ok      = @()

    foreach ($secret in $Secrets) {
        $statusEntry = Get-SecretStatus `
            -Secret            $secret `
            -ReferenceDate     $ReferenceDate `
            -WarningWindowDays $WarningWindowDays

        switch ($statusEntry.Status) {
            "expired" { $expired += $statusEntry }
            "warning" { $warning += $statusEntry }
            "ok"      { $ok      += $statusEntry }
        }
    }

    return @{
        Expired = $expired
        Warning = $warning
        Ok      = $ok
        Summary = @{
            Total        = $Secrets.Count
            ExpiredCount = $expired.Count
            WarningCount = $warning.Count
            OkCount      = $ok.Count
        }
    }
}

# ---------------------------------------------------------------------------
# Format-RotationReport
# ---------------------------------------------------------------------------
# Renders the analysis report in the requested format.
# Supported formats: "Markdown", "JSON"
function Format-RotationReport {
    param(
        [hashtable] $Report,
        [string]    $Format
    )

    switch ($Format) {
        "Markdown" { return _Format-Markdown $Report }
        "JSON"     { return _Format-Json     $Report }
        default    { throw "Unsupported format '$Format'. Valid values: Markdown, JSON" }
    }
}

# ---------------------------------------------------------------------------
# _Format-Markdown  (private helper)
# ---------------------------------------------------------------------------
function _Format-Markdown {
    param([hashtable] $Report)

    $sb = [System.Text.StringBuilder]::new()

    # --- Header ---
    [void]$sb.AppendLine("# Secret Rotation Report")
    [void]$sb.AppendLine("")

    # --- Summary ---
    [void]$sb.AppendLine("## Summary")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Metric  | Count |")
    [void]$sb.AppendLine("|---------|-------|")
    [void]$sb.AppendLine("| Total   | $($Report.Summary.Total) |")
    [void]$sb.AppendLine("| Expired | $($Report.Summary.ExpiredCount) |")
    [void]$sb.AppendLine("| Warning | $($Report.Summary.WarningCount) |")
    [void]$sb.AppendLine("| OK      | $($Report.Summary.OkCount) |")
    [void]$sb.AppendLine("")

    # Reusable helper: append one urgency section as a Markdown table
    $appendSection = {
        param([string]$Title, [array]$Entries)

        [void]$sb.AppendLine("## $Title")
        [void]$sb.AppendLine("")

        if ($Entries.Count -eq 0) {
            [void]$sb.AppendLine("_None_")
            [void]$sb.AppendLine("")
            return
        }

        [void]$sb.AppendLine("| Name | Last Rotated | Policy (days) | Days Until Expiry | Required By |")
        [void]$sb.AppendLine("|------|-------------|---------------|-------------------|-------------|")

        foreach ($entry in $Entries) {
            $lastRotatedStr = $entry.LastRotated.ToString("yyyy-MM-dd")
            $requiredBy     = ($entry.RequiredBy -join ", ")
            $daysCol        = $entry.DaysUntilExpiry

            [void]$sb.AppendLine("| $($entry.Name) | $lastRotatedStr | $($entry.RotationPolicyDays) | $daysCol | $requiredBy |")
        }
        [void]$sb.AppendLine("")
    }

    & $appendSection "Expired" $Report.Expired
    & $appendSection "Warning" $Report.Warning
    & $appendSection "Ok"      $Report.Ok

    return $sb.ToString()
}

# ---------------------------------------------------------------------------
# _Format-Json  (private helper)
# ---------------------------------------------------------------------------
function _Format-Json {
    param([hashtable] $Report)

    # Convert each entry to a plain object that serialises cleanly
    $convertEntry = {
        param($entry)
        [ordered]@{
            name                 = $entry.Name
            last_rotated         = $entry.LastRotated.ToString("yyyy-MM-dd")
            rotation_policy_days = $entry.RotationPolicyDays
            expiry_date          = $entry.ExpiryDate.ToString("yyyy-MM-dd")
            days_until_expiry    = $entry.DaysUntilExpiry
            status               = $entry.Status
            required_by          = $entry.RequiredBy
        }
    }

    $obj = [ordered]@{
        summary = [ordered]@{
            total         = $Report.Summary.Total
            expired_count = $Report.Summary.ExpiredCount
            warning_count = $Report.Summary.WarningCount
            ok_count      = $Report.Summary.OkCount
        }
        expired = @($Report.Expired | ForEach-Object { & $convertEntry $_ })
        warning = @($Report.Warning | ForEach-Object { & $convertEntry $_ })
        ok      = @($Report.Ok      | ForEach-Object { & $convertEntry $_ })
    }

    return $obj | ConvertTo-Json -Depth 5
}

# ---------------------------------------------------------------------------
# New-RotationReport  (end-to-end pipeline)
# ---------------------------------------------------------------------------
# Accepts a config hashtable, analyses the secrets, and returns formatted output.
#
# Config structure:
#   @{
#       Secrets = @(
#           @{ Name = ...; LastRotated = ...; RotationPolicyDays = ...; RequiredBy = @(...) }
#           ...
#       )
#       WarningWindowDays = 30   # optional, default 30
#   }
function New-RotationReport {
    param(
        [hashtable] $Config,
        [string]    $Format        = "Markdown",
        [datetime]  $ReferenceDate = [datetime]::Today
    )

    # Validate config has Secrets key
    if (-not $Config.ContainsKey("Secrets")) {
        throw "Config must contain a 'Secrets' key."
    }

    $warningWindowDays = if ($Config.ContainsKey("WarningWindowDays")) {
        [int]$Config.WarningWindowDays
    } else {
        30
    }

    $report = Invoke-SecretRotationAnalysis `
        -Secrets           $Config.Secrets `
        -ReferenceDate     $ReferenceDate `
        -WarningWindowDays $warningWindowDays

    return Format-RotationReport -Report $report -Format $Format
}
