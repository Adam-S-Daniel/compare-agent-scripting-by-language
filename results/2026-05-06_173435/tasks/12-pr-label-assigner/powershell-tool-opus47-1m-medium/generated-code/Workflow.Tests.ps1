# Workflow structure tests — parses the YAML, asserts on triggers/jobs/steps,
# verifies referenced scripts exist, and asserts actionlint passes.

BeforeAll {
    $script:WorkflowPath = Join-Path $PSScriptRoot '.github/workflows/pr-label-assigner.yml'
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
        Install-Module -Name powershell-yaml -Force -Scope CurrentUser -AcceptLicense -SkipPublisherCheck
    }
    Import-Module powershell-yaml -Force
    $script:Workflow = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $script:WorkflowPath -Raw)
}

Describe 'Workflow structure' {
    It 'has expected triggers' {
        # YAML "on:" parses as boolean True under powershell-yaml; access via key 'on' or True
        $on = $script:Workflow['on']
        if (-not $on) { $on = $script:Workflow[$true] }
        $on | Should -Not -BeNullOrEmpty
        $on.Keys | Should -Contain 'push'
        $on.Keys | Should -Contain 'pull_request'
        $on.Keys | Should -Contain 'workflow_dispatch'
    }

    It 'declares the test and assign jobs' {
        $script:Workflow.jobs.Keys | Should -Contain 'test'
        $script:Workflow.jobs.Keys | Should -Contain 'assign'
    }

    It 'assign job depends on test job' {
        $script:Workflow.jobs.assign.needs | Should -Be 'test'
    }

    It 'uses pinned actions/checkout@v4' {
        $allSteps = @()
        foreach ($jobName in $script:Workflow.jobs.Keys) {
            $allSteps += $script:Workflow.jobs[$jobName].steps
        }
        $checkouts = $allSteps | Where-Object { $_.uses -and $_.uses -like 'actions/checkout*' }
        $checkouts | Should -Not -BeNullOrEmpty
        foreach ($c in $checkouts) { $c.uses | Should -Be 'actions/checkout@v4' }
    }

    It 'uses pwsh shell on run steps' {
        $runSteps = @()
        foreach ($jobName in $script:Workflow.jobs.Keys) {
            foreach ($step in $script:Workflow.jobs[$jobName].steps) {
                if ($step.run) { $runSteps += $step }
            }
        }
        $runSteps | Should -Not -BeNullOrEmpty
        foreach ($s in $runSteps) { $s.shell | Should -Be 'pwsh' }
    }
}

Describe 'Workflow references existing files' {
    It 'references PrLabelAssigner.Tests.ps1 (and the file exists)' {
        $raw = Get-Content -LiteralPath $script:WorkflowPath -Raw
        $raw | Should -Match 'PrLabelAssigner\.Tests\.ps1'
        Test-Path -LiteralPath (Join-Path $PSScriptRoot 'PrLabelAssigner.Tests.ps1') | Should -BeTrue
    }
    It 'references Invoke-LabelAssigner.ps1 (and the file exists)' {
        $raw = Get-Content -LiteralPath $script:WorkflowPath -Raw
        $raw | Should -Match 'Invoke-LabelAssigner\.ps1'
        Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Invoke-LabelAssigner.ps1') | Should -BeTrue
    }
    It 'has the module file present' {
        Test-Path -LiteralPath (Join-Path $PSScriptRoot 'PrLabelAssigner.psm1') | Should -BeTrue
    }
    It 'has all referenced fixtures on disk' {
        foreach ($f in 'default','docs-only','empty') {
            Test-Path -LiteralPath (Join-Path $PSScriptRoot "fixtures/$f/rules.json") | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $PSScriptRoot "fixtures/$f/files.json") | Should -BeTrue
        }
    }
}

Describe 'actionlint' {
    It 'passes with exit code 0' {
        $null = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}
