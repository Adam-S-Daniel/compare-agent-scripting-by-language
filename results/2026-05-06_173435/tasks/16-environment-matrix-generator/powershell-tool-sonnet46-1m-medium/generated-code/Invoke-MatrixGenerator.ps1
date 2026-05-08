# Invoke-MatrixGenerator.ps1
# CLI entry point: reads a JSON config file and outputs the build matrix as JSON.
# Usage: ./Invoke-MatrixGenerator.ps1 -ConfigFile ./path/to/config.json [-OutputFile out.json]

param(
    [Parameter(Mandatory)]
    [string]$ConfigFile,

    [string]$OutputFile
)

. "$PSScriptRoot/New-BuildMatrix.ps1"

if (-not (Test-Path $ConfigFile)) {
    Write-Error "Config file not found: $ConfigFile"
    exit 1
}

try {
    $raw = Get-Content -Raw $ConfigFile
    $configObj = $raw | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse config file '$ConfigFile': $_"
    exit 1
}

# ConvertFrom-Json returns PSCustomObject; convert recursively to hashtables
# so New-BuildMatrix can use .ContainsKey() and [] access.
#
# Note: in PowerShell pipelines, $_ -is [PSCustomObject] returns $true even for
# primitive types (string, int) because they get wrapped in PSObject. We use
# PSObject.BaseObject to check the actual underlying type.
function ConvertTo-Hashtable {
    param([Parameter(ValueFromPipeline)][object]$InputObject)

    if ($null -eq $InputObject) { return $null }

    $base = $InputObject.PSObject.BaseObject

    # Primitives (strings, value types) — return as-is
    if ($base -is [string] -or $base.GetType().IsValueType) {
        return $base
    }

    # Arrays / collections — recurse into each element
    if ($base -is [System.Collections.IEnumerable]) {
        return @($base | ForEach-Object { ConvertTo-Hashtable $_ })
    }

    # PSCustomObject (from ConvertFrom-Json) — convert to hashtable
    $ht = @{}
    foreach ($prop in $InputObject.PSObject.Properties) {
        $ht[$prop.Name] = ConvertTo-Hashtable $prop.Value
    }
    return $ht
}

$config = ConvertTo-Hashtable $configObj

try {
    $matrix = New-BuildMatrix -Config $config
    $json   = $matrix | ConvertTo-Json -Depth 10
} catch {
    Write-Error "Failed to generate matrix: $_"
    exit 1
}

Write-Host $json

if ($OutputFile) {
    try {
        $json | Out-File -FilePath $OutputFile -Encoding utf8 -NoNewline
        Write-Host "Matrix written to: $OutputFile"
    } catch {
        Write-Error "Failed to write output file '$OutputFile': $_"
        exit 1
    }
}
