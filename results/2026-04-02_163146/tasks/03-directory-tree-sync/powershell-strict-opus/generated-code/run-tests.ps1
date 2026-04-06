#!/usr/bin/env pwsh
Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'
Invoke-Pester -Path './DirectoryTreeSync.Tests.ps1' -Output Detailed
