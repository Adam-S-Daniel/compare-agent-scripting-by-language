#!/usr/bin/env pwsh
# CLI wrapper so the workflow can invoke the label assigner in one line.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FilesPath,
    [Parameter(Mandatory)][string]$RulesPath,
    [switch]$HighestPriorityOnly
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..' 'src' 'LabelAssigner.psm1') -Force

Invoke-LabelAssigner -FilesPath $FilesPath -RulesPath $RulesPath -HighestPriorityOnly:$HighestPriorityOnly
