# PR Label Assigner - Command-line entry point for GitHub Actions
# Usage: pwsh Invoke-PRLabelAssigner.ps1 -ConfigFile <path> -ChangedFiles <files> -OutputFormat <json|text>

param(
    [string] $ConfigFile = "./label-rules.json",
    [string[]] $ChangedFiles,
    [string] $OutputFormat = "json"
)

# Load the core module
. (Join-Path $PSScriptRoot "PR-LabelAssigner.ps1")

try {
    # Read configuration from JSON
    if (-not (Test-Path $ConfigFile)) {
        Write-Error "Configuration file not found: $ConfigFile"
        exit 1
    }

    $config = Get-Content $ConfigFile | ConvertFrom-Json
    $rules = $config.rules

    if (-not $rules) {
        Write-Error "No rules found in configuration file"
        exit 1
    }

    # Get assigned labels
    $labels = Get-AssignedLabels -ChangedFiles $ChangedFiles -LabelRules $rules

    # Output results
    if ($OutputFormat -eq "json") {
        @{
            labels = $labels
            count = $labels.Count
            timestamp = (Get-Date -AsUTC).ToString("o")
        } | ConvertTo-Json -Compress
    } else {
        # Text output
        Write-Host "Assigned Labels:"
        if ($labels.Count -eq 0) {
            Write-Host "  (none)"
        } else {
            foreach ($label in $labels) {
                Write-Host "  - $label"
            }
        }
    }

    exit 0
}
catch {
    Write-Error "Error processing labels: $_"
    exit 1
}
