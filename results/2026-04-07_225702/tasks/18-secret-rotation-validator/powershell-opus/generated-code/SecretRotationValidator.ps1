# Secret Rotation Validator
# Evaluates secret configurations against rotation policies and generates
# reports grouped by urgency (Expired, Warning, OK) in Markdown or JSON.

function Get-SecretStatus {
    <#
    .SYNOPSIS
        Determines the rotation status of a single secret.
    .PARAMETER Secret
        Hashtable with keys: Name, LastRotated (date string), RotationDays (int), RequiredBy (string array).
    .PARAMETER ReferenceDate
        The date to evaluate against (defaults to today).
    .PARAMETER WarningDays
        Number of days before expiry to trigger a warning (default 7).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Secret,
        [datetime]$ReferenceDate = (Get-Date).Date,
        [int]$WarningDays = 7
    )

    $lastRotated = [datetime]::Parse($Secret.LastRotated)
    $expiryDate  = $lastRotated.AddDays($Secret.RotationDays)
    $daysUntilExpiry = ($expiryDate - $ReferenceDate).Days

    # Determine urgency: expired if at or past expiry, warning if within window
    if ($daysUntilExpiry -le 0) {
        $urgency = "Expired"
    } elseif ($daysUntilExpiry -le $WarningDays) {
        $urgency = "Warning"
    } else {
        $urgency = "OK"
    }

    [PSCustomObject]@{
        Name            = $Secret.Name
        LastRotated     = $lastRotated
        RotationDays    = $Secret.RotationDays
        ExpiryDate      = $expiryDate
        DaysUntilExpiry = $daysUntilExpiry
        Urgency         = $urgency
        RequiredBy      = $Secret.RequiredBy
    }
}

function Get-RotationReport {
    <#
    .SYNOPSIS
        Evaluates all secrets and groups them by urgency with summary counts.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Secrets,
        [datetime]$ReferenceDate = (Get-Date).Date,
        [int]$WarningDays = 7
    )

    $results = foreach ($s in $Secrets) {
        Get-SecretStatus -Secret $s -ReferenceDate $ReferenceDate -WarningDays $WarningDays
    }

    # Group by urgency — use @() to guarantee arrays even with 0 or 1 items
    $expired = @($results | Where-Object { $_.Urgency -eq "Expired" })
    $warning = @($results | Where-Object { $_.Urgency -eq "Warning" })
    $ok      = @($results | Where-Object { $_.Urgency -eq "OK" })

    [PSCustomObject]@{
        Expired = $expired
        Warning = $warning
        OK      = $ok
        All     = @($results)
        Summary = [PSCustomObject]@{
            Total   = $Secrets.Count
            Expired = $expired.Count
            Warning = $warning.Count
            OK      = $ok.Count
        }
    }
}

function Format-RotationReport {
    <#
    .SYNOPSIS
        Formats a rotation report as JSON or Markdown.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Report,
        [ValidateSet("JSON", "Markdown")]
        [string]$Format = "Markdown"
    )

    if ($Format -eq "JSON") {
        return Format-AsJson -Report $Report
    } else {
        return Format-AsMarkdown -Report $Report
    }
}

function Format-AsJson {
    param($Report)

    # Build a clean structure for JSON serialization
    $output = @{
        summary = @{
            total   = $Report.Summary.Total
            expired = $Report.Summary.Expired
            warning = $Report.Summary.Warning
            ok      = $Report.Summary.OK
        }
        secrets = @(
            foreach ($s in $Report.All) {
                @{
                    name            = $s.Name
                    lastRotated     = $s.LastRotated.ToString("yyyy-MM-dd")
                    rotationDays    = $s.RotationDays
                    expiryDate      = $s.ExpiryDate.ToString("yyyy-MM-dd")
                    daysUntilExpiry = $s.DaysUntilExpiry
                    urgency         = $s.Urgency
                    requiredBy      = $s.RequiredBy
                }
            }
        )
    }

    $output | ConvertTo-Json -Depth 4
}

function Format-AsMarkdown {
    param($Report)

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("# Secret Rotation Report")
    [void]$sb.AppendLine()

    # Summary section
    [void]$sb.AppendLine("## Summary")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("- **Total**: $($Report.Summary.Total)")
    [void]$sb.AppendLine("- **Expired**: $($Report.Summary.Expired)")
    [void]$sb.AppendLine("- **Warning**: $($Report.Summary.Warning)")
    [void]$sb.AppendLine("- **OK**: $($Report.Summary.OK)")
    [void]$sb.AppendLine()

    # Table header
    [void]$sb.AppendLine("| Name | Urgency | Last Rotated | Expiry Date | Days Until Expiry | Required By |")
    [void]$sb.AppendLine("|------|---------|--------------|-------------|-------------------|-------------|")

    # Rows sorted by urgency: Expired first, then Warning, then OK
    $urgencyOrder = @{ "Expired" = 0; "Warning" = 1; "OK" = 2 }
    $sorted = $Report.All | Sort-Object { $urgencyOrder[$_.Urgency] }, DaysUntilExpiry

    foreach ($s in $sorted) {
        $services = ($s.RequiredBy -join ", ")
        $row = "| $($s.Name) | $($s.Urgency) | $($s.LastRotated.ToString('yyyy-MM-dd')) | $($s.ExpiryDate.ToString('yyyy-MM-dd')) | $($s.DaysUntilExpiry) | $services |"
        [void]$sb.AppendLine($row)
    }

    $sb.ToString()
}

function Import-SecretConfig {
    <#
    .SYNOPSIS
        Loads secret configurations from a JSON file.
    .PARAMETER Path
        Path to the JSON config file containing an array of secret definitions.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Secret config file not found: $Path"
    }

    try {
        $content = Get-Content -Path $Path -Raw
        $parsed = $content | ConvertFrom-Json
    } catch [System.ArgumentException] {
        throw "Failed to parse secret config: invalid JSON in $Path"
    } catch {
        # Re-throw parse errors with a clearer message
        if ($_.Exception.Message -match "Json|parse|convert") {
            throw "Failed to parse secret config: invalid JSON in $Path"
        }
        throw
    }

    # Convert PSObjects back to hashtables for consistent handling
    # Wrap $parsed in @() to handle single-item arrays (ConvertFrom-Json unwraps them)
    # Use Write-Output -NoEnumerate to prevent PowerShell from unrolling single-element arrays
    $results = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($item in @($parsed)) {
        $results.Add(@{
            Name         = $item.Name
            LastRotated  = $item.LastRotated
            RotationDays = [int]$item.RotationDays
            RequiredBy   = @($item.RequiredBy)
        })
    }
    Write-Output -NoEnumerate $results.ToArray()
}
