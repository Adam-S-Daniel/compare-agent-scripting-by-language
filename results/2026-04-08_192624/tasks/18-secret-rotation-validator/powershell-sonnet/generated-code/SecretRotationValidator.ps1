# Secret Rotation Validator
# Identifies secrets that are expired or expiring within a warning window.
# Supports multiple output formats: markdown table, JSON.
#
# Core data flow:
#   config (JSON) -> Get-RotationReport -> [Format-*] -> output string

#region Secret Classification

function Get-SecretStatus {
    <#
    .SYNOPSIS
        Computes the rotation status of a single secret.
    .PARAMETER Secret
        Hashtable/PSObject with: name, lastRotated (yyyy-MM-dd), rotationPolicyDays, requiredBy.
    .PARAMETER ReferenceDate
        Date to evaluate against (defaults to today). Fixed for testability.
    .PARAMETER WarningWindowDays
        Days before expiry to start issuing WARNING status (default: 14).
    #>
    param(
        [Parameter(Mandatory)][object]$Secret,
        [datetime]$ReferenceDate = (Get-Date),
        [int]$WarningWindowDays = 14
    )

    $lastRotated   = [datetime]::ParseExact($Secret.lastRotated, "yyyy-MM-dd", $null)
    $deadline      = $lastRotated.AddDays($Secret.rotationPolicyDays)
    $daysRemaining = ([int](($deadline - $ReferenceDate).TotalDays))
    $daysOverdue   = -$daysRemaining  # positive when past deadline

    # Classify: expired (<=0 remaining), warning (within window), ok otherwise
    $status = if ($daysRemaining -le 0) {
        "EXPIRED"
    } elseif ($daysRemaining -le $WarningWindowDays) {
        "WARNING"
    } else {
        "OK"
    }

    [PSCustomObject]@{
        Name               = $Secret.name
        LastRotated        = $lastRotated.ToString("yyyy-MM-dd")
        RotationPolicyDays = $Secret.rotationPolicyDays
        Deadline           = $deadline.ToString("yyyy-MM-dd")
        DaysRemaining      = [Math]::Max(0, $daysRemaining)
        DaysOverdue        = [Math]::Max(0, $daysOverdue)
        Status             = $status
        RequiredBy         = @($Secret.requiredBy)
    }
}

#endregion

#region Report Generation

function Get-RotationReport {
    <#
    .SYNOPSIS
        Processes all secrets in a config and groups them by urgency.
    .PARAMETER Config
        PSObject parsed from the config JSON (has .secrets and .warningWindowDays).
    .PARAMETER ReferenceDate
        Date to evaluate against (defaults to today).
    #>
    param(
        [Parameter(Mandatory)][object]$Config,
        [datetime]$ReferenceDate = (Get-Date)
    )

    $warningWindow = if ($Config.warningWindowDays) { $Config.warningWindowDays } else { 14 }

    $statuses = $Config.secrets | ForEach-Object {
        Get-SecretStatus -Secret $_ -ReferenceDate $ReferenceDate -WarningWindowDays $warningWindow
    }

    [PSCustomObject]@{
        Expired       = @($statuses | Where-Object { $_.Status -eq "EXPIRED" })
        Warning       = @($statuses | Where-Object { $_.Status -eq "WARNING" })
        OK            = @($statuses | Where-Object { $_.Status -eq "OK" })
        GeneratedAt   = $ReferenceDate.ToString("yyyy-MM-dd")
        WarningWindow = $warningWindow
    }
}

#endregion

#region Output Formatters

function Format-RotationReportMarkdown {
    <#
    .SYNOPSIS
        Formats a rotation report as a GitHub-flavored markdown document.
    #>
    param([Parameter(Mandatory)][object]$Report)

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("# Secret Rotation Report")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("**Generated:** $($Report.GeneratedAt)  ")
    $null = $sb.AppendLine("**Warning window:** $($Report.WarningWindow) days")
    $null = $sb.AppendLine("")

    # Summary
    $total = $Report.Expired.Count + $Report.Warning.Count + $Report.OK.Count
    $null = $sb.AppendLine("## Summary")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Category | Count |")
    $null = $sb.AppendLine("|----------|-------|")
    $null = $sb.AppendLine("| Expired  | $($Report.Expired.Count) |")
    $null = $sb.AppendLine("| Warning  | $($Report.Warning.Count) |")
    $null = $sb.AppendLine("| OK       | $($Report.OK.Count) |")
    $null = $sb.AppendLine("| **Total**| **$total** |")
    $null = $sb.AppendLine("")

    # Table header helper
    $tableHeader = @(
        "| Name | Status | Last Rotated | Deadline | Days | Required By |",
        "|------|--------|-------------|----------|------|-------------|"
    )

    # Helper: format a single row
    function Format-Row($s) {
        $days = if ($s.Status -eq "EXPIRED") { "-$($s.DaysOverdue)" } else { "$($s.DaysRemaining)" }
        $rb = ($s.RequiredBy -join ", ")
        "| $($s.Name) | $($s.Status) | $($s.LastRotated) | $($s.Deadline) | $days | $rb |"
    }

    # Expired section
    $null = $sb.AppendLine("## Expired Secrets")
    $null = $sb.AppendLine("")
    if ($Report.Expired.Count -gt 0) {
        $tableHeader | ForEach-Object { $null = $sb.AppendLine($_) }
        $Report.Expired | ForEach-Object { $null = $sb.AppendLine((Format-Row $_)) }
    } else {
        $null = $sb.AppendLine("_No expired secrets._")
    }
    $null = $sb.AppendLine("")

    # Warning section
    $null = $sb.AppendLine("## Warning Secrets")
    $null = $sb.AppendLine("")
    if ($Report.Warning.Count -gt 0) {
        $tableHeader | ForEach-Object { $null = $sb.AppendLine($_) }
        $Report.Warning | ForEach-Object { $null = $sb.AppendLine((Format-Row $_)) }
    } else {
        $null = $sb.AppendLine("_No secrets approaching expiry._")
    }
    $null = $sb.AppendLine("")

    # OK section
    $null = $sb.AppendLine("## OK Secrets")
    $null = $sb.AppendLine("")
    if ($Report.OK.Count -gt 0) {
        $tableHeader | ForEach-Object { $null = $sb.AppendLine($_) }
        $Report.OK | ForEach-Object { $null = $sb.AppendLine((Format-Row $_)) }
    } else {
        $null = $sb.AppendLine("_No secrets in healthy state._")
    }

    $sb.ToString()
}

function Format-RotationReportJson {
    <#
    .SYNOPSIS
        Formats a rotation report as a JSON string.
    #>
    param([Parameter(Mandatory)][object]$Report)

    $total = $Report.Expired.Count + $Report.Warning.Count + $Report.OK.Count

    $obj = [ordered]@{
        generatedAt   = $Report.GeneratedAt
        warningWindow = $Report.WarningWindow
        summary       = [ordered]@{
            total        = $total
            expiredCount = $Report.Expired.Count
            warningCount = $Report.Warning.Count
            okCount      = $Report.OK.Count
        }
        expired = @($Report.Expired | ForEach-Object {
            [ordered]@{
                name               = $_.Name
                lastRotated        = $_.LastRotated
                deadline           = $_.Deadline
                daysOverdue        = $_.DaysOverdue
                rotationPolicyDays = $_.RotationPolicyDays
                requiredBy         = @($_.RequiredBy)
                status             = $_.Status
            }
        })
        warning = @($Report.Warning | ForEach-Object {
            [ordered]@{
                name               = $_.Name
                lastRotated        = $_.LastRotated
                deadline           = $_.Deadline
                daysRemaining      = $_.DaysRemaining
                rotationPolicyDays = $_.RotationPolicyDays
                requiredBy         = @($_.RequiredBy)
                status             = $_.Status
            }
        })
        ok = @($Report.OK | ForEach-Object {
            [ordered]@{
                name               = $_.Name
                lastRotated        = $_.LastRotated
                deadline           = $_.Deadline
                daysRemaining      = $_.DaysRemaining
                rotationPolicyDays = $_.RotationPolicyDays
                requiredBy         = @($_.RequiredBy)
                status             = $_.Status
            }
        })
    }

    $obj | ConvertTo-Json -Depth 5
}

#endregion

#region Main Entry Point

function Invoke-SecretRotationValidator {
    <#
    .SYNOPSIS
        Main entry point: loads config, generates report, returns formatted output.
    .PARAMETER ConfigPath
        Path to the JSON config file containing secrets.
    .PARAMETER OutputFormat
        Output format: "Markdown" (default) or "JSON".
    .PARAMETER WarningWindowDays
        Override the warning window (default taken from config or 14).
    .PARAMETER ReferenceDate
        Date to evaluate against (defaults to today).
    #>
    param(
        [Parameter(Mandatory)][string]$ConfigPath,
        [ValidateSet("Markdown", "JSON")][string]$OutputFormat = "Markdown",
        [int]$WarningWindowDays = 0,
        [datetime]$ReferenceDate = (Get-Date)
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    if ($PSBoundParameters.ContainsKey('WarningWindowDays') -and $WarningWindowDays -gt 0) {
        $config | Add-Member -NotePropertyName warningWindowDays -NotePropertyValue $WarningWindowDays -Force
    }

    $report = Get-RotationReport -Config $config -ReferenceDate $ReferenceDate

    switch ($OutputFormat) {
        "JSON"     { Format-RotationReportJson -Report $report }
        "Markdown" { Format-RotationReportMarkdown -Report $report }
    }
}

#endregion

# When run directly (not dot-sourced), execute the validator with CLI args.
# Detect: if script is invoked directly (not sourced with .) the caller will set
# $MyInvocation.ScriptName to the script's own path.
if ($MyInvocation.ScriptName -eq $MyInvocation.MyCommand.Path) {
    # Parse simple named args from $args for direct invocation
    $cliConfig  = "./fixtures/secrets-fixture.json"
    $cliFmt     = "Markdown"
    $cliWarning = 0
    for ($i = 0; $i -lt $args.Count; $i++) {
        switch ($args[$i]) {
            "-ConfigPath"        { $cliConfig  = $args[++$i] }
            "-OutputFormat"      { $cliFmt     = $args[++$i] }
            "-WarningWindowDays" { $cliWarning = [int]$args[++$i] }
        }
    }
    Invoke-SecretRotationValidator -ConfigPath $cliConfig -OutputFormat $cliFmt `
        -WarningWindowDays $cliWarning
}
