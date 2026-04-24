# Structural tests for the GitHub Actions workflow file.
#
# These are complementary to the act-based integration suite: they parse the
# YAML statically and check that declared triggers, jobs, steps, and file
# references are correct. Running these is cheap (no Docker) so any break in
# the workflow shape surfaces immediately. Where possible they overlap with
# actionlint; the structural checks add semantic assertions actionlint can't.

BeforeAll {
    $script:WorkflowPath = Join-Path $PSScriptRoot '.github/workflows/artifact-cleanup-script.yml'
    $script:ProjectRoot  = $PSScriptRoot

    # Pester on the act container images has `powershell-yaml` available; if it
    # is missing we install it into the user scope at test time.
    if (-not (Get-Module -ListAvailable powershell-yaml)) {
        Install-Module powershell-yaml -Scope CurrentUser -Force -ErrorAction Stop
    }
    Import-Module powershell-yaml -Force
    $script:Workflow = ConvertFrom-Yaml (Get-Content -LiteralPath $script:WorkflowPath -Raw)
}

Describe 'Workflow file exists and is well-formed' {
    It 'exists at the expected path' {
        Test-Path -LiteralPath $script:WorkflowPath | Should -BeTrue
    }

    It 'parses as YAML into a hashtable' {
        $script:Workflow | Should -Not -BeNullOrEmpty
        $script:Workflow.Keys | Should -Contain 'name'
        $script:Workflow.Keys | Should -Contain 'jobs'
    }
}

Describe 'Triggers' {
    It 'fires on push, pull_request, schedule, and workflow_dispatch' {
        $on = $script:Workflow['on']
        $on | Should -Not -BeNullOrEmpty
        $on.Keys | Should -Contain 'push'
        $on.Keys | Should -Contain 'pull_request'
        $on.Keys | Should -Contain 'schedule'
        $on.Keys | Should -Contain 'workflow_dispatch'
    }
}

Describe 'Jobs and steps' {
    It 'declares the expected jobs' {
        $script:Workflow.jobs.Keys | Should -Contain 'unit-tests'
        $script:Workflow.jobs.Keys | Should -Contain 'cleanup-plan'
    }

    It 'orders cleanup-plan after unit-tests via needs' {
        $script:Workflow.jobs['cleanup-plan'].needs | Should -Be 'unit-tests'
    }

    It 'checks out the repository in every job' {
        foreach ($jobName in $script:Workflow.jobs.Keys) {
            $steps = $script:Workflow.jobs[$jobName].steps
            $usesCheckout = $steps | Where-Object { $_.uses -and $_.uses -like 'actions/checkout@*' }
            $usesCheckout | Should -Not -BeNullOrEmpty -Because "job '$jobName' must check out the repo"
        }
    }

    It 'pins actions/checkout to v4' {
        foreach ($jobName in $script:Workflow.jobs.Keys) {
            $checkout = $script:Workflow.jobs[$jobName].steps |
                Where-Object { $_.uses -and $_.uses -like 'actions/checkout@*' } |
                Select-Object -First 1
            $checkout.uses | Should -Be 'actions/checkout@v4'
        }
    }
}

Describe 'Script references resolve on disk' {
    It 'references ArtifactCleanup.Tests.ps1 which exists' {
        $rendered = Get-Content -LiteralPath $script:WorkflowPath -Raw
        $rendered | Should -Match 'ArtifactCleanup\.Tests\.ps1'
        Test-Path (Join-Path $script:ProjectRoot 'ArtifactCleanup.Tests.ps1') | Should -BeTrue
    }

    It 'references Invoke-Cleanup.ps1 which exists' {
        $rendered = Get-Content -LiteralPath $script:WorkflowPath -Raw
        $rendered | Should -Match 'Invoke-Cleanup\.ps1'
        Test-Path (Join-Path $script:ProjectRoot 'Invoke-Cleanup.ps1') | Should -BeTrue
    }

    It 'references a fixture under fixtures/ that exists' {
        $rendered = Get-Content -LiteralPath $script:WorkflowPath -Raw
        $rendered | Should -Match 'fixtures/default\.json'
        Test-Path (Join-Path $script:ProjectRoot 'fixtures/default.json') | Should -BeTrue
    }
}

Describe 'actionlint' {
    It 'reports no issues against the workflow' {
        $al = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $al) {
            Set-ItResult -Skipped -Because 'actionlint is not available on PATH in this context'
            return
        }
        $out  = & actionlint $script:WorkflowPath 2>&1
        $code = $LASTEXITCODE
        if ($code -ne 0) { Write-Host $out }
        $code | Should -Be 0
    }
}
