param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = 'label-config.json',

    [Parameter(Mandatory = $false)]
    [string[]]$Files,

    [Parameter(Mandatory = $false)]
    [switch]$ListRules
)

. $PSScriptRoot/PrLabelAssigner.ps1

function Get-LabelsFromConfig {
    [CmdletBinding()]
    param(
        [string]$ConfigFile,
        [string[]]$Files
    )

    if (-not (Test-Path $ConfigFile)) {
        Write-Error "Config file not found: $ConfigFile"
        return @()
    }

    try {
        $config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to parse config file: $_"
        return @()
    }

    if (-not $config.rules) {
        Write-Error "Config file must contain 'rules' array"
        return @()
    }

    # Convert PSObject to hashtables for Get-PrLabels
    $rules = @()
    foreach ($rule in $config.rules) {
        $rules += @{
            pattern  = $rule.pattern
            labels   = @($rule.labels)
            priority = if ($rule.priority) { $rule.priority } else { 1 }
        }
    }

    return Get-PrLabels -Files $Files -Rules $rules
}

if ($ListRules) {
    if (-not (Test-Path $ConfigFile)) {
        Write-Error "Config file not found: $ConfigFile"
        exit 1
    }

    try {
        $config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
        Write-Host "Label Rules:"
        foreach ($rule in $config.rules) {
            $priority = if ($rule.priority) { $rule.priority } else { 1 }
            Write-Host "  Pattern: $($rule.pattern), Priority: $priority"
            Write-Host "    Labels: $($rule.labels -join ', ')"
        }
    }
    catch {
        Write-Error "Failed to parse config file: $_"
        exit 1
    }
    exit 0
}

if (-not $Files -or $Files.Count -eq 0) {
    Write-Error "No files provided"
    exit 1
}

$labels = Get-LabelsFromConfig -ConfigFile $ConfigFile -Files $Files

if ($labels.Count -gt 0) {
    Write-Host "Applied Labels:"
    foreach ($label in $labels) {
        Write-Host "  - $label"
    }
    Write-Output $labels -NoEnumerate
}
else {
    Write-Host "No labels applied"
    exit 0
}
