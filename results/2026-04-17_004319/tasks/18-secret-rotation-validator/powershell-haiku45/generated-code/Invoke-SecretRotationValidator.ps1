#Requires -Version 7.0

param(
    [Parameter(Mandatory=$true, HelpMessage="Path to secrets configuration JSON file")]
    [string]$ConfigPath,

    [Parameter(HelpMessage="Warning threshold in days (default: 7)")]
    [int]$WarningDays = 7,

    [Parameter(HelpMessage="Output format: 'markdown' or 'json' (default: markdown)")]
    [ValidateSet("markdown", "json")]
    [string]$OutputFormat = "markdown",

    [Parameter(HelpMessage="Output file path (optional, outputs to console if not specified)")]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

try {
    # Import validator module
    . $PSScriptRoot/SecretRotationValidator.ps1

    # Create validator
    $validator = New-SecretRotationValidator -WarningDays $WarningDays
    Write-Verbose "Validator created with warning window: $WarningDays days"

    # Load secrets
    $secrets = @(Import-SecretsFromJson -ConfigPath $ConfigPath)
    Write-Verbose "Loaded $($secrets.Count) secrets from $ConfigPath"

    # Generate report
    $report = New-RotationReport -Validator $validator -Secrets $secrets

    # Format output
    $output = if ($OutputFormat -eq "json") {
        Format-RotationReportAsJson -Report $report
    }
    else {
        Format-RotationReportAsMarkdown -Report $report
    }

    # Output result
    if ($OutputPath) {
        $output | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Host "Report saved to: $OutputPath"
    }
    else {
        Write-Host $output
    }

    # Exit with status based on findings
    $exitCode = 0
    if ($report.Expired.Count -gt 0) {
        Write-Warning "$($report.Expired.Count) secret(s) expired!"
        $exitCode = 1
    }
    elseif ($report.Warning.Count -gt 0) {
        Write-Warning "$($report.Warning.Count) secret(s) expiring soon!"
        $exitCode = 0
    }

    exit $exitCode
}
catch {
    Write-Error "Error during validation: $_"
    exit 2
}
