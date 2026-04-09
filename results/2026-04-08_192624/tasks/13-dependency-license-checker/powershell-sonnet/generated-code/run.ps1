# run.ps1 — CLI entry point for the Dependency License Checker
# Usage: pwsh run.ps1 -Manifest <path> -Config <path> [options]

param(
    [Parameter(Mandatory)][string]$Manifest,
    [string]$Config,
    [switch]$FailOnDenied
)

. "$PSScriptRoot/LicenseChecker.ps1"

# Built-in mock database used in CI (replace with real API calls in production)
$mockDatabase = @{
    # npm packages
    "express"         = "MIT"
    "lodash"          = "MIT"
    "react"           = "MIT"
    "react-dom"       = "MIT"
    "axios"           = "MIT"
    "chalk"           = "MIT"
    "moment"          = "MIT"
    "uuid"            = "MIT"
    "dotenv"          = "BSD-2-Clause"
    "commander"       = "MIT"
    "jest"            = "MIT"
    "typescript"      = "Apache-2.0"
    "webpack"         = "MIT"
    "gpl-package"     = "GPL-3.0"
    "unknown-lib"     = "UNKNOWN"
    # Python packages
    "requests"        = "Apache-2.0"
    "flask"           = "BSD-3-Clause"
    "django"          = "BSD-3-Clause"
    "numpy"           = "BSD-3-Clause"
    "pandas"          = "BSD-3-Clause"
    "scipy"           = "BSD-3-Clause"
    "pytest"          = "MIT"
    "setuptools"      = "MIT"
    "pip"             = "MIT"
    "gpl-lib"         = "GPL-2.0"
    "mystery-package" = "UNKNOWN"
}

# Load config (use defaults if not supplied)
if ($Config -and (Test-Path $Config)) {
    $licenseConfig = Get-LicenseConfig -Path $Config
} else {
    $licenseConfig = [PSCustomObject]@{
        AllowList = @("MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC")
        DenyList  = @("GPL-2.0", "GPL-3.0", "AGPL-3.0", "LGPL-2.1", "LGPL-3.0")
    }
}

try {
    $report = Invoke-LicenseCheck -ManifestPath $Manifest -Config $licenseConfig -MockDatabase $mockDatabase
    $output = Format-ComplianceReport -Report $report
    Write-Host $output

    $exitCode = Get-ComplianceExitCode -Report $report
    if ($FailOnDenied -and $exitCode -ne 0) {
        exit $exitCode
    }
    exit 0
} catch {
    Write-Error "License check failed: $_"
    exit 2
}
