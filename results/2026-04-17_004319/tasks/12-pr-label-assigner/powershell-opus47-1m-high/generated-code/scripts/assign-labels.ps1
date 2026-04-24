#!/usr/bin/env pwsh
#requires -Version 7.0

<#
.SYNOPSIS
    Compute PR labels from a changed-files list and a rules file.
.DESCRIPTION
    Thin CLI wrapper around the LabelAssigner module. Reads rules from
    -RulesPath (JSON), reads changed files from either -ChangedFilesPath (a
    JSON file or a newline-delimited text file) or -ChangedFiles (inline
    string array), and prints one label per line to stdout.
#>
[CmdletBinding(DefaultParameterSetName = 'FromFile')]
param(
    [Parameter(Mandatory)]
    [string] $RulesPath,

    [Parameter(ParameterSetName = 'FromFile')]
    [string] $ChangedFilesPath,

    [Parameter(ParameterSetName = 'FromArgs')]
    [string[]] $ChangedFiles
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $modulePath = Join-Path $PSScriptRoot '..' 'src' 'LabelAssigner.psm1'
    if (-not (Test-Path -LiteralPath $modulePath)) {
        throw "LabelAssigner module not found at: $modulePath"
    }
    Import-Module $modulePath -Force

    $rules = Import-LabelRules -Path $RulesPath

    # Resolve changed files from whichever parameter set was used.
    $paths = @()
    if ($PSCmdlet.ParameterSetName -eq 'FromFile' -and $ChangedFilesPath) {
        if (-not (Test-Path -LiteralPath $ChangedFilesPath)) {
            throw "Changed files list not found: $ChangedFilesPath"
        }
        $raw = Get-Content -LiteralPath $ChangedFilesPath -Raw
        # Support both JSON array and newline-delimited plaintext.
        $trimmed = $raw.TrimStart()
        if ($trimmed.StartsWith('[') -or $trimmed.StartsWith('"')) {
            $paths = @($raw | ConvertFrom-Json)
        } else {
            $paths = @($raw -split "`r?`n" | Where-Object { $_ -ne '' })
        }
    } elseif ($ChangedFiles) {
        $paths = @($ChangedFiles)
    }

    $labels = Get-PullRequestLabels -Paths $paths -Rules $rules
    foreach ($label in $labels) {
        Write-Output $label
    }
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
