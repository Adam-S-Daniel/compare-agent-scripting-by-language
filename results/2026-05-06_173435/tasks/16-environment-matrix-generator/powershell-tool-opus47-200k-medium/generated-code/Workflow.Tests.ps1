# Structural tests for the GitHub Actions workflow itself: parse the YAML,
# spot-check shape, ensure referenced paths exist, run actionlint.

BeforeAll {
    $script:WorkflowPath = Join-Path $PSScriptRoot '.github/workflows/environment-matrix-generator.yml'
    $script:Yaml = Get-Content -Raw -LiteralPath $script:WorkflowPath
}

Describe 'environment-matrix-generator.yml structure' {
    It 'exists' {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It 'declares the expected triggers' {
        $script:Yaml | Should -Match '(?ms)^on:\s*\r?\n(?:.*\r?\n)*?\s*push:'
        $script:Yaml | Should -Match 'pull_request:'
        $script:Yaml | Should -Match 'workflow_dispatch:'
    }

    It 'declares both jobs (test + generate)' {
        $script:Yaml | Should -Match '(?m)^\s{2}test:\s*$'
        $script:Yaml | Should -Match '(?m)^\s{2}generate:\s*$'
    }

    It 'has the generate job depend on the test job' {
        $script:Yaml | Should -Match 'needs:\s*test'
    }

    It 'uses actions/checkout@v4' {
        $script:Yaml | Should -Match 'actions/checkout@v4'
    }

    It 'declares contents:read permission' {
        $script:Yaml | Should -Match 'contents:\s*read'
    }

    It 'references the script and tests by path' {
        $script:Yaml | Should -Match 'MatrixGenerator\.Tests\.ps1'
        $script:Yaml | Should -Match 'MatrixGenerator\.ps1'
        Test-Path (Join-Path $PSScriptRoot 'MatrixGenerator.ps1')        | Should -BeTrue
        Test-Path (Join-Path $PSScriptRoot 'MatrixGenerator.Tests.ps1')  | Should -BeTrue
    }

    It 'uses pwsh shell on run steps (not bash-invoked pwsh)' {
        $script:Yaml | Should -Match 'shell:\s*pwsh'
        $script:Yaml | Should -Not -Match 'pwsh\s+-Command'
        $script:Yaml | Should -Not -Match 'pwsh\s+-File'
    }
}

Describe 'actionlint' {
    It 'reports no errors for the workflow file' {
        $output = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}

Describe 'Fixtures referenced by the harness' {
    It 'has the three fixture files' {
        foreach ($f in 'basic.json','simple.json','flags.json') {
            Test-Path (Join-Path $PSScriptRoot 'fixtures' $f) | Should -BeTrue
        }
    }
}
