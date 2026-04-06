# RunTests.ps1 - Ensures Pester is installed and runs all tests.
# Called by: pwsh -File tests/RunTests.ps1

# Install Pester if not already present (for CI / fresh environments)
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [Version]"5.0.0" })) {
    Write-Host "Installing Pester 5.x..."
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
}

Import-Module Pester -MinimumVersion 5.0.0

# Run all tests in the tests directory
$config = New-PesterConfiguration
$config.Run.Path = "$PSScriptRoot"
$config.Output.Verbosity = "Detailed"
$config.Run.Exit = $true  # non-zero exit code on failure

Invoke-Pester -Configuration $config
