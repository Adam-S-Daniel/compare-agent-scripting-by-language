# Generate-Matrix.ps1
# Thin CLI wrapper around MatrixGenerator.psm1 for use from CI workflows.
#
# Usage:
#   pwsh ./Generate-Matrix.ps1 -ConfigPath ./config.json
#   pwsh ./Generate-Matrix.ps1 -ConfigPath ./config.json -OutputPath ./matrix.json
#
# Exits 0 on success and writes the strategy JSON to stdout (and -OutputPath if given).
# Exits 1 on any validation/parse error with the message on stderr.

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ConfigPath,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'MatrixGenerator.psm1'
Import-Module $modulePath -Force

try {
    $json = Invoke-MatrixGeneration -ConfigPath $ConfigPath
}
catch {
    [Console]::Error.WriteLine("ERROR: $($_.Exception.Message)")
    exit 1
}

# Always print to stdout so it's pipeable; optionally also write to a file.
Write-Output $json
if ($OutputPath) {
    Set-Content -LiteralPath $OutputPath -Value $json -Encoding utf8
}
exit 0
