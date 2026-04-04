# run-tests.ps1 — installs Pester if needed, then runs the test suite
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge '5.0' })) {
    Write-Host "Installing Pester 5.x..." -ForegroundColor Yellow
    Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser -MinimumVersion 5.0
}
Import-Module Pester -MinimumVersion 5.0
Set-Location $PSScriptRoot
Invoke-Pester -Path ./DirectorySync.Tests.ps1 -Output Detailed
