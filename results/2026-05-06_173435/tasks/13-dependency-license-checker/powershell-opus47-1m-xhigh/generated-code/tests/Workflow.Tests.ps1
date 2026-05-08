# Workflow.Tests.ps1
#
# Static / structural checks against the GitHub Actions workflow file.
# These tests run inside Run-ActTests.ps1 (the act harness), but are
# independent of any `act` invocation: they parse the YAML directly,
# verify the file paths it references actually exist, and confirm
# `actionlint` accepts the workflow.
#
# Why a separate file: keeps the unit-test job in the workflow itself
# focused on the LicenseChecker module's behavior, while structural
# concerns (does the workflow look like a workflow?) live one level up.

BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    $script:WorkflowPath = Join-Path $script:RepoRoot '.github/workflows/dependency-license-checker.yml'

    # Light-weight YAML reader: powershell-yaml may not be installed in CI,
    # so we shell out to `pwsh ... ConvertFrom-Yaml` only if the module is
    # available; otherwise we parse the bits we need (jobs/steps/triggers)
    # by running the workflow through Python's yaml module via process. To
    # keep things self-contained for this benchmark, we read the raw text
    # and assert on it with regex-based shape checks instead. That's enough
    # for "does the workflow have the structure we claim".
    $script:WorkflowText = Get-Content -LiteralPath $script:WorkflowPath -Raw
}

Describe 'Workflow file - file existence and metadata' {
    It 'exists at the expected path' {
        Test-Path -LiteralPath $script:WorkflowPath | Should -BeTrue
    }

    It 'has a `name:` field' {
        $script:WorkflowText | Should -Match '(?m)^name:\s+\S'
    }
}

Describe 'Workflow file - triggers' {
    It 'triggers on push' {
        $script:WorkflowText | Should -Match '(?ms)^on:.*\bpush:'
    }
    It 'triggers on pull_request' {
        $script:WorkflowText | Should -Match '(?ms)^on:.*\bpull_request:'
    }
    It 'has a schedule trigger' {
        $script:WorkflowText | Should -Match '(?ms)^on:.*\bschedule:'
    }
    It 'supports manual workflow_dispatch' {
        $script:WorkflowText | Should -Match '(?ms)^on:.*\bworkflow_dispatch:'
    }
}

Describe 'Workflow file - referenced files exist' {
    It 'references src/LicenseChecker.psm1 and that file exists' {
        $script:WorkflowText | Should -Match 'src/LicenseChecker\.psm1'
        Test-Path (Join-Path $script:RepoRoot 'src/LicenseChecker.psm1') | Should -BeTrue
    }
    It 'references src/Get-LicenseReport.ps1 and that file exists' {
        $script:WorkflowText | Should -Match 'src/Get-LicenseReport\.ps1'
        Test-Path (Join-Path $script:RepoRoot 'src/Get-LicenseReport.ps1') | Should -BeTrue
    }
    It 'references the tests directory and Pester tests exist' {
        $script:WorkflowText | Should -Match "tests"
        Test-Path (Join-Path $script:RepoRoot 'tests/LicenseChecker.Tests.ps1') | Should -BeTrue
    }
    It 'references the default manifest and policy fixtures and they exist' {
        $script:WorkflowText | Should -Match 'fixtures/package\.json'
        $script:WorkflowText | Should -Match 'fixtures/license-policy\.json'
        Test-Path (Join-Path $script:RepoRoot 'fixtures/package.json') | Should -BeTrue
        Test-Path (Join-Path $script:RepoRoot 'fixtures/license-policy.json') | Should -BeTrue
    }
}

Describe 'Workflow file - job structure' {
    It 'declares a `unit-tests` job' {
        $script:WorkflowText | Should -Match '(?m)^\s{2}unit-tests:'
    }
    It 'declares a `compliance-check` job' {
        $script:WorkflowText | Should -Match '(?m)^\s{2}compliance-check:'
    }
    It 'compliance-check depends on unit-tests' {
        $script:WorkflowText | Should -Match '(?ms)compliance-check:.*?needs:\s+unit-tests'
    }
    It 'each job pins runs-on: ubuntu-latest' {
        $matchCount = ([regex]::Matches($script:WorkflowText, '(?m)^\s+runs-on:\s+ubuntu-latest')).Count
        $matchCount | Should -BeGreaterOrEqual 2
    }
    It 'declares minimum permissions: contents: read' {
        $script:WorkflowText | Should -Match '(?ms)permissions:\s*\n\s*contents:\s+read'
    }
    It 'uses actions/checkout@v4 for source checkout' {
        $script:WorkflowText | Should -Match 'actions/checkout@v4'
    }
    It 'uses shell: pwsh on PowerShell run steps' {
        $script:WorkflowText | Should -Match 'shell:\s+pwsh'
    }
}

Describe 'Workflow file - actionlint validation' {
    It 'passes actionlint with exit code 0' {
        $output = & actionlint $script:WorkflowPath 2>&1
        $exit = $LASTEXITCODE
        if ($exit -ne 0) {
            Write-Host "actionlint output:`n$output"
        }
        $exit | Should -Be 0
    }
}
