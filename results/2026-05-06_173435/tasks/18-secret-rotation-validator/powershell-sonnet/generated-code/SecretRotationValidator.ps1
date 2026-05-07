#Requires -Version 5.1
# SecretRotationValidator.ps1
# Entry-point script: reads a JSON config, runs the rotation check, and
# outputs a report in the requested format (markdown or json).

param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $false)]
    [int]$WarningDays = 30,

    [Parameter(Mandatory = $false)]
    [ValidateSet("json", "markdown")]
    [string]$Format = "markdown",

    # Override today's date (yyyy-MM-dd) — used by tests and CI for reproducible output
    [Parameter(Mandatory = $false)]
    [string]$ReferenceDateStr = ""
)

# Load the shared module; $PSScriptRoot is the directory containing this script
Import-Module "$PSScriptRoot/SecretRotationValidator.psm1" -Force

$referenceDate = if ($ReferenceDateStr -ne "") {
    [datetime]::ParseExact($ReferenceDateStr, "yyyy-MM-dd", $null)
}
else {
    Get-Date
}

try {
    if (-not (Test-Path $ConfigPath)) {
        Write-Error "Config file not found: $ConfigPath"
        exit 1
    }

    $rawJson = Get-Content $ConfigPath -Raw
    $secrets  = $rawJson | ConvertFrom-Json

    if ($null -eq $secrets -or @($secrets).Count -eq 0) {
        Write-Error "No secrets found in config file: $ConfigPath"
        exit 1
    }

    $report = Get-RotationReport -Secrets @($secrets) -ReferenceDate $referenceDate -WarningDays $WarningDays

    if ($Format -eq "json") {
        Format-JsonReport -Report $report
    }
    else {
        Format-MarkdownReport -Report $report
    }
}
catch {
    Write-Error "Secret rotation validation failed: $_"
    exit 1
}
