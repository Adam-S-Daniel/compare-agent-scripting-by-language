# Workflow structure tests — parse the YAML and verify expected shape.
# Also asserts actionlint exits 0 and the script paths referenced exist.

BeforeAll {
    $script:Root = $PSScriptRoot
    $script:WorkflowPath = Join-Path $Root '.github/workflows/dependency-license-checker.yml'
}

Describe 'Workflow file structure' {

    It 'exists' {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It 'declares the expected triggers' {
        $text = Get-Content $script:WorkflowPath -Raw
        $text | Should -Match '(?ms)^on:\s*\n.*push:'
        $text | Should -Match 'pull_request:'
        $text | Should -Match 'schedule:'
        $text | Should -Match 'workflow_dispatch:'
    }

    It 'uses actions/checkout@v4' {
        Get-Content $script:WorkflowPath -Raw | Should -Match 'actions/checkout@v4'
    }

    It 'declares both unit-tests and license-check jobs' {
        $text = Get-Content $script:WorkflowPath -Raw
        $text | Should -Match 'unit-tests:'
        $text | Should -Match 'license-check:'
    }

    It 'declares contents:read permission' {
        Get-Content $script:WorkflowPath -Raw | Should -Match 'permissions:\s*\n\s*contents:\s*read'
    }

    It 'license-check depends on unit-tests' {
        Get-Content $script:WorkflowPath -Raw | Should -Match 'needs:\s*unit-tests'
    }

    It 'references files that exist on disk' {
        $text = Get-Content $script:WorkflowPath -Raw
        $referenced = @('LicenseChecker.Tests.ps1', 'Invoke-LicenseChecker.ps1', 'licenses.config.json', 'fixtures/licenses-db.json')
        foreach ($r in $referenced) {
            $text | Should -Match ([regex]::Escape($r))
            (Test-Path (Join-Path $script:Root $r)) | Should -BeTrue
        }
    }
}

Describe 'actionlint' {
    It 'reports no errors' {
        $output = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ("actionlint output: " + ($output -join "`n"))
    }
}
