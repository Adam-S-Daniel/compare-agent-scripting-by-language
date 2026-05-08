# SecretRotationValidator.ps1
# Validates secrets against rotation policies and generates a rotation report.
# Supports JSON and Markdown output formats.
#
# Usage (as script):
#   ./SecretRotationValidator.ps1 -ConfigPath ./fixtures/secrets-standard.json -OutputFormat Markdown
#   ./SecretRotationValidator.ps1 -ConfigPath ./fixtures/secrets-standard.json -OutputFormat JSON -WarningWindowDays 14
#
# Usage (dot-sourced in tests):
#   . ./SecretRotationValidator.ps1
#   $result = Get-SecretRotationStatus -Secrets $secrets -ReferenceDate "2024-06-01"

[CmdletBinding()]
param(
    [string] $ConfigPath,
    [string] $ReferenceDate       = (Get-Date -Format "yyyy-MM-dd"),
    [int]    $WarningWindowDays   = 30,
    [ValidateSet("JSON", "Markdown")]
    [string] $OutputFormat        = "Markdown"
)

# Classify each secret as EXPIRED, WARNING, or OK based on the rotation policy.
# Returns a hashtable with keys: Expired, Warning, Ok, ReferenceDate, WarningWindowDays.
function Get-SecretRotationStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Secrets,
        [string] $ReferenceDate     = (Get-Date -Format "yyyy-MM-dd"),
        [int]    $WarningWindowDays = 30
    )

    $refDate = [datetime]::ParseExact($ReferenceDate, "yyyy-MM-dd", $null)
    $expired = [System.Collections.ArrayList]::new()
    $warning = [System.Collections.ArrayList]::new()
    $ok      = [System.Collections.ArrayList]::new()

    foreach ($secret in $Secrets) {
        $lastRotated       = [datetime]::ParseExact($secret.LastRotated, "yyyy-MM-dd", $null)
        $daysSince         = ($refDate - $lastRotated).Days
        $daysUntilExpiry   = $secret.RotationPolicyDays - $daysSince

        $entry = [ordered]@{
            Name               = $secret.Name
            LastRotated        = $secret.LastRotated
            RotationPolicyDays = $secret.RotationPolicyDays
            RequiredBy         = @($secret.RequiredBy)
            DaysSinceRotation  = $daysSince
            DaysUntilExpiry    = $daysUntilExpiry
            Status             = ""
        }

        if ($daysSince -ge $secret.RotationPolicyDays) {
            $entry.Status = "EXPIRED"
            [void] $expired.Add($entry)
        } elseif ($daysUntilExpiry -le $WarningWindowDays) {
            $entry.Status = "WARNING"
            [void] $warning.Add($entry)
        } else {
            $entry.Status = "OK"
            [void] $ok.Add($entry)
        }
    }

    return [ordered]@{
        Expired          = $expired.ToArray()
        Warning          = $warning.ToArray()
        Ok               = $ok.ToArray()
        ReferenceDate    = $ReferenceDate
        WarningWindowDays = $WarningWindowDays
    }
}

# Format the rotation status report as JSON or Markdown.
function Format-RotationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Status,
        [ValidateSet("JSON", "Markdown")]
        [string] $OutputFormat = "Markdown"
    )

    if ($OutputFormat -eq "JSON") {
        return $Status | ConvertTo-Json -Depth 5
    }

    # Markdown table output
    $sb = [System.Text.StringBuilder]::new()

    [void] $sb.AppendLine("# Secret Rotation Report")
    [void] $sb.AppendLine("Reference Date: $($Status.ReferenceDate) | Warning Window: $($Status.WarningWindowDays) days")
    [void] $sb.AppendLine()

    # Summary table
    [void] $sb.AppendLine("## Summary")
    [void] $sb.AppendLine("| Urgency | Count |")
    [void] $sb.AppendLine("|---------|-------|")
    [void] $sb.AppendLine("| EXPIRED | $($Status.Expired.Count) |")
    [void] $sb.AppendLine("| WARNING | $($Status.Warning.Count) |")
    [void] $sb.AppendLine("| OK      | $($Status.Ok.Count) |")
    [void] $sb.AppendLine()

    # EXPIRED section
    if ($Status.Expired.Count -gt 0) {
        [void] $sb.AppendLine("## EXPIRED — Action Required")
        [void] $sb.AppendLine("| Name | Last Rotated | Policy (days) | Days Overdue | Required By |")
        [void] $sb.AppendLine("|------|-------------|---------------|--------------|-------------|")
        foreach ($s in $Status.Expired) {
            $daysOverdue = [Math]::Abs($s.DaysUntilExpiry)
            $requiredBy  = ($s.RequiredBy -join ", ")
            [void] $sb.AppendLine("| $($s.Name) | $($s.LastRotated) | $($s.RotationPolicyDays) | $daysOverdue | $requiredBy |")
        }
        [void] $sb.AppendLine()
    }

    # WARNING section
    if ($Status.Warning.Count -gt 0) {
        [void] $sb.AppendLine("## WARNING — Expiring Soon")
        [void] $sb.AppendLine("| Name | Last Rotated | Policy (days) | Days Until Expiry | Required By |")
        [void] $sb.AppendLine("|------|-------------|---------------|-------------------|-------------|")
        foreach ($s in $Status.Warning) {
            $requiredBy = ($s.RequiredBy -join ", ")
            [void] $sb.AppendLine("| $($s.Name) | $($s.LastRotated) | $($s.RotationPolicyDays) | $($s.DaysUntilExpiry) | $requiredBy |")
        }
        [void] $sb.AppendLine()
    }

    # OK section
    if ($Status.Ok.Count -gt 0) {
        [void] $sb.AppendLine("## OK — No Action Required")
        [void] $sb.AppendLine("| Name | Last Rotated | Policy (days) | Days Until Expiry | Required By |")
        [void] $sb.AppendLine("|------|-------------|---------------|-------------------|-------------|")
        foreach ($s in $Status.Ok) {
            $requiredBy = ($s.RequiredBy -join ", ")
            [void] $sb.AppendLine("| $($s.Name) | $($s.LastRotated) | $($s.RotationPolicyDays) | $($s.DaysUntilExpiry) | $requiredBy |")
        }
    }

    return $sb.ToString()
}

# Main entry point: load config from a JSON file and generate the report.
function Invoke-SecretRotationValidator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ConfigPath,
        [string] $ReferenceDate     = (Get-Date -Format "yyyy-MM-dd"),
        [int]    $WarningWindowDays = 30,
        [ValidateSet("JSON", "Markdown")]
        [string] $OutputFormat      = "Markdown"
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    $raw = Get-Content $ConfigPath -Raw | ConvertFrom-Json

    # Accept either an array at root or an object with a .Secrets property
    $rawSecrets = if ($raw -is [array]) { $raw } else { $raw.Secrets }

    # Convert PSCustomObject items to ordered hashtables so tests can index properties
    $secrets = $rawSecrets | ForEach-Object {
        [ordered]@{
            Name               = $_.Name
            LastRotated        = $_.LastRotated
            RotationPolicyDays = [int] $_.RotationPolicyDays
            RequiredBy         = @($_.RequiredBy)
        }
    }

    $status = Get-SecretRotationStatus -Secrets $secrets -ReferenceDate $ReferenceDate -WarningWindowDays $WarningWindowDays
    return Format-RotationReport -Status $status -OutputFormat $OutputFormat
}

# Run main logic only when invoked as a script (not dot-sourced by tests)
if ($ConfigPath) {
    Invoke-SecretRotationValidator -ConfigPath $ConfigPath -ReferenceDate $ReferenceDate -WarningWindowDays $WarningWindowDays -OutputFormat $OutputFormat
}
