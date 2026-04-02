# Root module — delegates to src/CsvReportGenerator.psm1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

[string]$srcModule = Join-Path -Path $PSScriptRoot -ChildPath 'src/CsvReportGenerator.psm1'
Import-Module -Name $srcModule -Force
