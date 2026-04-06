#Requires -Version 7.0
Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Demonstrates the PR Label Assigner with several mock PR scenarios.
.DESCRIPTION
    This script shows how Get-PRLabels works against realistic mock PR file lists.
    Run it with: pwsh -File Invoke-PRLabelDemo.ps1
#>

Import-Module (Join-Path $PSScriptRoot 'PrLabelAssigner.psm1') -Force

# ---------------------------------------------------------------------------
# Define a realistic label rule configuration (highest priority first)
# ---------------------------------------------------------------------------
[hashtable[]]$LabelRules = @(
    @{ Pattern = 'docs/**';         Label = 'documentation'; Priority = 10 }
    @{ Pattern = '.github/**';      Label = 'ci/cd';         Priority = 10 }
    @{ Pattern = 'src/api/**';      Label = 'api';           Priority = 9  }
    @{ Pattern = '*.test.*';        Label = 'tests';         Priority = 8  }
    @{ Pattern = '**/*.test.*';     Label = 'tests';         Priority = 8  }
    @{ Pattern = '**/*.spec.*';     Label = 'tests';         Priority = 8  }
    @{ Pattern = 'src/**';          Label = 'source';        Priority = 5  }
    @{ Pattern = '*.md';            Label = 'documentation'; Priority = 3  }
    @{ Pattern = '*.yml';           Label = 'ci/cd';         Priority = 3  }
    @{ Pattern = '*.yaml';          Label = 'ci/cd';         Priority = 3  }
)

# ---------------------------------------------------------------------------
# Helper to display a PR scenario
# ---------------------------------------------------------------------------
function Show-PRScenario {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$ScenarioName,

        [Parameter(Mandatory)]
        [string[]]$ChangedFiles,

        [Parameter(Mandatory)]
        [hashtable[]]$Rules
    )

    Write-Host "`n--- $ScenarioName ---" -ForegroundColor Cyan
    Write-Host 'Changed files:' -ForegroundColor Gray
    foreach ([string]$f in $ChangedFiles) {
        Write-Host "  $f" -ForegroundColor DarkGray
    }

    [string[]]$labels = Get-PRLabels -FilePaths $ChangedFiles -Rules $Rules

    if ($labels.Count -eq 0) {
        Write-Host 'Labels: (none)' -ForegroundColor Yellow
    }
    else {
        [string]$labelList = $labels -join ', '
        Write-Host "Labels: $labelList" -ForegroundColor Green
    }
}

# ---------------------------------------------------------------------------
# Scenario 1: Documentation-only PR
# ---------------------------------------------------------------------------
Show-PRScenario -ScenarioName 'Scenario 1: Documentation PR' -Rules $LabelRules -ChangedFiles @(
    'docs/getting-started.md'
    'docs/api/endpoints.md'
    'docs/contributing.md'
)

# ---------------------------------------------------------------------------
# Scenario 2: New API feature with tests
# ---------------------------------------------------------------------------
Show-PRScenario -ScenarioName 'Scenario 2: API Feature + Tests' -Rules $LabelRules -ChangedFiles @(
    'src/api/users.ts'
    'src/api/users.test.ts'
    'src/api/auth.ts'
    'src/api/auth.test.ts'
    'src/models/user.ts'
)

# ---------------------------------------------------------------------------
# Scenario 3: Full-stack feature (API + frontend + docs + CI)
# ---------------------------------------------------------------------------
Show-PRScenario -ScenarioName 'Scenario 3: Full-Stack Feature' -Rules $LabelRules -ChangedFiles @(
    'src/api/products.ts'
    'src/api/products.test.ts'
    'src/ui/ProductList.tsx'
    'src/ui/ProductList.spec.tsx'
    'docs/api/products.md'
    '.github/workflows/ci.yml'
)

# ---------------------------------------------------------------------------
# Scenario 4: Pure refactor (no tests, no docs)
# ---------------------------------------------------------------------------
Show-PRScenario -ScenarioName 'Scenario 4: Source Refactor' -Rules $LabelRules -ChangedFiles @(
    'src/utils/formatters.ts'
    'src/utils/validators.ts'
    'src/services/authService.ts'
)

# ---------------------------------------------------------------------------
# Scenario 5: CI configuration only
# ---------------------------------------------------------------------------
Show-PRScenario -ScenarioName 'Scenario 5: CI Config Update' -Rules $LabelRules -ChangedFiles @(
    '.github/workflows/ci.yml'
    '.github/workflows/release.yml'
    '.github/dependabot.yml'
)

# ---------------------------------------------------------------------------
# Scenario 6: No files match any rule
# ---------------------------------------------------------------------------
Show-PRScenario -ScenarioName 'Scenario 6: Binary/Build Files (no labels)' -Rules $LabelRules -ChangedFiles @(
    'dist/bundle.js'
    'build/output.bin'
)

Write-Host "`nDemo complete.`n" -ForegroundColor Cyan
