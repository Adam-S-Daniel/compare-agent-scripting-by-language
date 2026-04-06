# run-tests.ps1 - install Pester if needed and run all tests

if (-not (Get-Module -ListAvailable Pester | Where-Object { $_.Version -ge [version]'5.0' })) {
    Write-Host 'Installing Pester 5.x ...'
    Install-Module -Name Pester -Force -Scope CurrentUser -MinimumVersion 5.0
}

Import-Module Pester -MinimumVersion 5.0 -Force
Invoke-Pester -Path "$PSScriptRoot/ErrorRetryPipeline.Tests.ps1" -Output Detailed
