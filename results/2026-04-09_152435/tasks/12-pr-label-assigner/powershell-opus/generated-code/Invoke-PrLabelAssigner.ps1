# Invoke-PrLabelAssigner.ps1
# CLI entry point for PR Label Assigner
# Usage: ./Invoke-PrLabelAssigner.ps1 -ConfigPath <path> -FilePaths <file1>,<file2>,...

param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $true)]
    [string[]]$FilePaths
)

# Import core functions
. "$PSScriptRoot/PrLabelAssigner.ps1"

# Validate config file exists
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Config file not found: $ConfigPath"
    exit 1
}

# Parse config
try {
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
}
catch {
    Write-Error "Failed to parse config file: $_"
    exit 1
}

# Get labels
try {
    $labels = Get-PrLabels -Config $config -FilePaths $FilePaths
}
catch {
    Write-Error "Failed to assign labels: $_"
    exit 1
}

# Output results
if ($labels.Count -eq 0) {
    Write-Output "No labels matched"
}
else {
    Write-Output "Labels: $($labels -join ', ')"
}
