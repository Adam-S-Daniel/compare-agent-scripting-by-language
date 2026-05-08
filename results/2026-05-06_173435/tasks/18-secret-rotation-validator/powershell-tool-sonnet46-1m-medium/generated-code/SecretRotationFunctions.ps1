# SecretRotationFunctions.ps1
# Core functions for the Secret Rotation Validator.
# Dot-source this file in tests and in the main entry-point script.

# Compute the rotation status of a single secret.
# Returns a hashtable with keys: Status, ExpiryDate, and either DaysOverdue or DaysUntilExpiry.
function Get-SecretStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LastRotated,

        [Parameter(Mandatory)]
        [int]$PolicyDays,

        [int]$WarningDays = 14,

        # Accept reference date as a string ("yyyy-MM-dd") so callers (and tests) can
        # inject a fixed date; defaults to today when omitted or empty.
        [string]$ReferenceDate = ""
    )

    $refDate = if ($ReferenceDate -ne "") {
        [datetime]::ParseExact($ReferenceDate, "yyyy-MM-dd", $null)
    } else {
        (Get-Date).Date
    }

    $lastRotatedDate = [datetime]::ParseExact($LastRotated, "yyyy-MM-dd", $null)
    $expiryDate      = $lastRotatedDate.AddDays($PolicyDays)

    # Positive = days remaining; negative = days past expiry
    $daysUntilExpiry = ($expiryDate - $refDate).Days

    if ($daysUntilExpiry -lt 0) {
        return @{
            Status      = "Expired"
            ExpiryDate  = $expiryDate.ToString("yyyy-MM-dd")
            DaysOverdue = -$daysUntilExpiry
        }
    } elseif ($daysUntilExpiry -le $WarningDays) {
        return @{
            Status           = "Warning"
            ExpiryDate       = $expiryDate.ToString("yyyy-MM-dd")
            DaysUntilExpiry  = $daysUntilExpiry
        }
    } else {
        return @{
            Status           = "OK"
            ExpiryDate       = $expiryDate.ToString("yyyy-MM-dd")
            DaysUntilExpiry  = $daysUntilExpiry
        }
    }
}

# Build the full rotation report grouped by urgency.
# Returns an ordered hashtable with keys: GeneratedAt, Expired, Warning, OK.
function Get-RotationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Secrets,

        [int]$WarningDays = 14,

        [string]$ReferenceDate = ""
    )

    $refDate = if ($ReferenceDate -ne "") {
        [datetime]::ParseExact($ReferenceDate, "yyyy-MM-dd", $null)
    } else {
        (Get-Date).Date
    }

    # Use typed lists so ConvertTo-Json always serialises these as arrays (never null)
    $expired = [System.Collections.Generic.List[hashtable]]::new()
    $warning = [System.Collections.Generic.List[hashtable]]::new()
    $ok      = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($secret in $Secrets) {
        $status = Get-SecretStatus `
            -LastRotated   $secret.lastRotated `
            -PolicyDays    $secret.rotationPolicyDays `
            -WarningDays   $WarningDays `
            -ReferenceDate $refDate.ToString("yyyy-MM-dd")

        $entry = @{
            Name        = $secret.name
            LastRotated = $secret.lastRotated
            PolicyDays  = $secret.rotationPolicyDays
            RequiredBy  = $secret.requiredBy
            Status      = $status.Status
            ExpiryDate  = $status.ExpiryDate
        }

        if ($status.ContainsKey("DaysOverdue")) {
            $entry.DaysOverdue = $status.DaysOverdue
        }
        if ($status.ContainsKey("DaysUntilExpiry")) {
            $entry.DaysUntilExpiry = $status.DaysUntilExpiry
        }

        switch ($status.Status) {
            "Expired" { $expired.Add($entry) }
            "Warning" { $warning.Add($entry) }
            "OK"      { $ok.Add($entry)      }
        }
    }

    return [ordered]@{
        GeneratedAt = $refDate.ToString("yyyy-MM-dd")
        Expired     = $expired
        Warning     = $warning
        OK          = $ok
    }
}

# Render the report as a Markdown table document.
function Format-ReportAsMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Report
    )

    $sb = [System.Text.StringBuilder]::new()

    $null = $sb.AppendLine("# Secret Rotation Report")
    $null = $sb.AppendLine("Generated: $($Report.GeneratedAt)")
    $null = $sb.AppendLine()

    # Summary counts
    $null = $sb.AppendLine("## Summary")
    $null = $sb.AppendLine("| Status  | Count |")
    $null = $sb.AppendLine("|---------|-------|")
    $null = $sb.AppendLine("| Expired | $($Report.Expired.Count) |")
    $null = $sb.AppendLine("| Warning | $($Report.Warning.Count) |")
    $null = $sb.AppendLine("| OK      | $($Report.OK.Count) |")
    $null = $sb.AppendLine()

    if ($Report.Expired.Count -gt 0) {
        $null = $sb.AppendLine("## EXPIRED - Immediate Action Required")
        $null = $sb.AppendLine("| Secret | Last Rotated | Expired On | Days Overdue | Required By |")
        $null = $sb.AppendLine("|--------|-------------|------------|-------------|-------------|")
        foreach ($s in $Report.Expired) {
            $rb = ($s.RequiredBy -join ", ")
            $null = $sb.AppendLine("| $($s.Name) | $($s.LastRotated) | $($s.ExpiryDate) | $($s.DaysOverdue) | $rb |")
        }
        $null = $sb.AppendLine()
    }

    if ($Report.Warning.Count -gt 0) {
        $null = $sb.AppendLine("## WARNING - Rotation Due Soon")
        $null = $sb.AppendLine("| Secret | Last Rotated | Expires On | Days Remaining | Required By |")
        $null = $sb.AppendLine("|--------|-------------|------------|----------------|-------------|")
        foreach ($s in $Report.Warning) {
            $rb = ($s.RequiredBy -join ", ")
            $null = $sb.AppendLine("| $($s.Name) | $($s.LastRotated) | $($s.ExpiryDate) | $($s.DaysUntilExpiry) | $rb |")
        }
        $null = $sb.AppendLine()
    }

    if ($Report.OK.Count -gt 0) {
        $null = $sb.AppendLine("## OK - No Action Required")
        $null = $sb.AppendLine("| Secret | Last Rotated | Expires On | Days Remaining | Required By |")
        $null = $sb.AppendLine("|--------|-------------|------------|----------------|-------------|")
        foreach ($s in $Report.OK) {
            $rb = ($s.RequiredBy -join ", ")
            $null = $sb.AppendLine("| $($s.Name) | $($s.LastRotated) | $($s.ExpiryDate) | $($s.DaysUntilExpiry) | $rb |")
        }
    }

    return $sb.ToString()
}

# Render the report as a JSON string.
function Format-ReportAsJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Report
    )

    return $Report | ConvertTo-Json -Depth 10
}
