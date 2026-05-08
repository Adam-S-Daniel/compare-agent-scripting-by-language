# Workflow structural tests:
#  * parse the YAML, assert triggers/jobs/steps
#  * verify referenced script paths exist
#  * verify `actionlint` passes (exit 0)
#
# We use a tiny line-based YAML parser tailored to our workflow's shape because
# pwsh ships without a YAML module by default. Tests assert on textual presence
# of required structural elements rather than full YAML semantics.

BeforeAll {
    $script:ProjectRoot   = Split-Path -Parent $PSScriptRoot
    $script:WorkflowPath  = Join-Path $script:ProjectRoot '.github/workflows/environment-matrix-generator.yml'
    $script:WorkflowText  = Get-Content -LiteralPath $script:WorkflowPath -Raw
}

Describe 'Workflow file' {
    It 'exists at the expected path' {
        Test-Path -LiteralPath $script:WorkflowPath | Should -BeTrue
    }

    It 'declares the required trigger events' {
        $script:WorkflowText | Should -Match '(?ms)^on:'
        $script:WorkflowText | Should -Match 'push:'
        $script:WorkflowText | Should -Match 'pull_request:'
        $script:WorkflowText | Should -Match 'workflow_dispatch:'
        $script:WorkflowText | Should -Match 'schedule:'
    }

    It 'declares contents:read permissions' {
        $script:WorkflowText | Should -Match 'permissions:\s*(\r?\n)\s+contents:\s*read'
    }

    It 'defines the three required jobs' {
        $script:WorkflowText | Should -Match '(?m)^\s{2}unit-tests:'
        $script:WorkflowText | Should -Match '(?m)^\s{2}generate-matrix:'
        $script:WorkflowText | Should -Match '(?m)^\s{2}summary:'
    }

    It 'wires generate-matrix as a dependency of summary' {
        $script:WorkflowText | Should -Match 'needs:\s*generate-matrix'
    }

    It 'uses pinned actions/checkout' {
        $script:WorkflowText | Should -Match 'uses:\s*actions/checkout@v4'
    }

    It 'references the CLI script with a path that exists' {
        $script:WorkflowText | Should -Match 'src/Invoke-MatrixGenerator\.ps1'
        Test-Path -LiteralPath (Join-Path $script:ProjectRoot 'src/Invoke-MatrixGenerator.ps1') | Should -BeTrue
    }

    It 'references the unit test directory which exists' {
        $script:WorkflowText | Should -Match './tests'
        Test-Path -LiteralPath (Join-Path $script:ProjectRoot 'tests') | Should -BeTrue
    }

    It 'uses pwsh shell on every run step' {
        # Every "run:" step in this workflow should opt into pwsh.
        $runCount   = ([regex]::Matches($script:WorkflowText, '(?m)^\s{6}run:\s*\|')).Count
        $shellCount = ([regex]::Matches($script:WorkflowText, '(?m)^\s{6}shell:\s*pwsh')).Count
        $shellCount | Should -Be $runCount
    }
}

Describe 'actionlint' {
    It 'reports no errors for the workflow' {
        $actionlint = (Get-Command actionlint -ErrorAction SilentlyContinue)?.Source
        if (-not $actionlint) {
            Set-ItResult -Skipped -Because 'actionlint is not available on PATH'
            return
        }
        $proc = Start-Process -FilePath $actionlint -ArgumentList @($script:WorkflowPath) -PassThru -Wait -NoNewWindow `
                  -RedirectStandardOutput /tmp/actionlint.out -RedirectStandardError /tmp/actionlint.err
        $stdout = if (Test-Path /tmp/actionlint.out) { Get-Content /tmp/actionlint.out -Raw } else { '' }
        $stderr = if (Test-Path /tmp/actionlint.err) { Get-Content /tmp/actionlint.err -Raw } else { '' }
        if ($proc.ExitCode -ne 0) {
            Write-Host "actionlint stdout: $stdout"
            Write-Host "actionlint stderr: $stderr"
        }
        $proc.ExitCode | Should -Be 0
    }
}
