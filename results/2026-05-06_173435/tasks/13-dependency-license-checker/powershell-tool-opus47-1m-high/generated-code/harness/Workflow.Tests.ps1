# Structural tests for the GitHub Actions workflow.
# Run from the project root with:
#     Invoke-Pester -Path harness/Workflow.Tests.ps1
#
# These run on the host (not inside act). They verify the workflow:
#   * is valid YAML with the expected triggers/jobs/steps,
#   * references files that actually exist in the project,
#   * passes actionlint cleanly.

BeforeAll {
    $script:Root         = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:WorkflowPath = Join-Path $script:Root '.github/workflows/dependency-license-checker.yml'

    if (-not (Get-Module -ListAvailable powershell-yaml)) {
        # powershell-yaml is not strictly required - we'll fall back to
        # raw text checks if it isn't installed in the host environment.
        $script:YamlAvailable = $false
    } else {
        Import-Module powershell-yaml -ErrorAction SilentlyContinue
        $script:YamlAvailable = $true
    }
    $script:RawYaml = Get-Content $script:WorkflowPath -Raw
}

Describe 'Workflow file existence and parseability' {
    It 'exists at .github/workflows/dependency-license-checker.yml' {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It 'is parseable as YAML' -Skip:(-not $script:YamlAvailable) {
        { ConvertFrom-Yaml -Yaml $script:RawYaml } | Should -Not -Throw
    }
}

Describe 'Workflow structure (text-level assertions)' {

    It 'has a name field' {
        $script:RawYaml | Should -Match '(?m)^name:\s*Dependency License Checker'
    }

    It 'is wired to push, pull_request, schedule, workflow_dispatch' {
        $script:RawYaml | Should -Match '(?m)^\s+push:'
        $script:RawYaml | Should -Match '(?m)^\s+pull_request:'
        $script:RawYaml | Should -Match '(?m)^\s+workflow_dispatch:'
        $script:RawYaml | Should -Match '(?m)^\s+schedule:'
    }

    It 'declares contents: read permissions' {
        $script:RawYaml | Should -Match 'contents:\s*read'
    }

    It 'pins actions/checkout to v4' {
        $script:RawYaml | Should -Match 'actions/checkout@v4'
    }

    It 'invokes the Pester test suite' {
        $script:RawYaml | Should -Match 'Invoke-Pester'
    }

    It 'invokes the CLI script via shell: pwsh' {
        $script:RawYaml | Should -Match 'shell:\s*pwsh'
        $script:RawYaml | Should -Match 'scripts/Invoke-LicenseCheck\.ps1'
    }
}

Describe 'Referenced files actually exist' {
    It 'tests/ directory exists' {
        Test-Path (Join-Path $script:Root 'tests') | Should -BeTrue
    }
    It 'CLI script exists' {
        Test-Path (Join-Path $script:Root 'scripts/Invoke-LicenseCheck.ps1') | Should -BeTrue
    }
    It 'Module exists' {
        Test-Path (Join-Path $script:Root 'src/DependencyLicenseChecker.psm1') | Should -BeTrue
    }
    It 'Default fixtures exist' {
        Test-Path (Join-Path $script:Root 'fixtures/manifest.package.json') | Should -BeTrue
        Test-Path (Join-Path $script:Root 'fixtures/license-config.json')   | Should -BeTrue
        Test-Path (Join-Path $script:Root 'fixtures/mock-licenses.json')    | Should -BeTrue
    }
}

Describe 'actionlint validation' {
    It 'reports no errors on the workflow' {
        $alOut  = & actionlint $script:WorkflowPath 2>&1
        $alExit = $LASTEXITCODE
        if ($alExit -ne 0) {
            Write-Host ($alOut -join "`n")
        }
        $alExit | Should -Be 0
    }
}
