# RunTests.ps1
# Ensures Pester is available, then runs the test suite.
# Usage: pwsh -File RunTests.ps1

# Install Pester if not already present
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [version]'5.0' })) {
    Write-Host "Installing Pester 5..."
    Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser
}

Import-Module Pester -MinimumVersion 5.0

# Run the tests with detailed output
$result = Invoke-Pester -Path "$PSScriptRoot/PRLabelAssigner.Tests.ps1" -Output Detailed -PassThru

exit $result.FailedCount
