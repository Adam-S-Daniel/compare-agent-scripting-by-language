# CLI entry point for Secret Rotation Validator

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigPath,

    [int]$WarningWindow = 7,

    [ValidateSet("json", "markdown")]
    [string]$OutputFormat = "markdown"
)

# Import the validator functions
. $PSScriptRoot/Invoke-SecretRotationValidator.ps1

try {
    # Validate config file exists
    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    # Load configuration
    $config = @()
    if ($ConfigPath.EndsWith('.json')) {
        $config = @(Get-Content $ConfigPath | ConvertFrom-Json)
    }
    elseif ($ConfigPath.EndsWith('.csv')) {
        $config = @(Import-Csv $ConfigPath)
    }
    else {
        throw "Unsupported config format. Use .json or .csv"
    }

    # Validate config is not empty
    if ($config.Count -eq 0) {
        throw "No secrets found in configuration"
    }

    # Ensure config is an array
    if ($config -isnot [array]) {
        $config = @($config)
    }

    # Run validator
    $result = Invoke-SecretRotationValidator -Secrets $config -WarningWindow $WarningWindow -OutputFormat $OutputFormat

    # Output result (use Write-Output for JSON so it can be piped/captured)
    if ($OutputFormat -eq 'json') {
        Write-Output $result
    } else {
        Write-Host $result
    }

    # Check for expired secrets and exit with appropriate code
    $jsonResult = Invoke-SecretRotationValidator -Secrets $config -WarningWindow $WarningWindow -OutputFormat json | ConvertFrom-Json
    if ($jsonResult.expired.Count -gt 0) {
        exit 1
    }
    exit 0
}
catch {
    Write-Error $_
    exit 2
}
