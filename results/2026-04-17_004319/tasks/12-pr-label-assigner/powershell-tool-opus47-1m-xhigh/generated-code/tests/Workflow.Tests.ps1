# Workflow-level tests.
#
# Split into two Describe blocks:
#   1) Structure tests: parse YAML, verify references and actionlint — fast, always run.
#   2) Act-driven tests: run each case through `act push --rm`, append every run's
#      output to act-result.txt, and assert on exact expected labels / exit 0.
#
# Act runs are gated by $env:RUN_ACT='1' so unit-test runs aren't slow by default.

BeforeAll {
    $script:repoRoot     = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:workflowFile = Join-Path $repoRoot '.github' 'workflows' 'pr-label-assigner.yml'
    $script:actResult    = Join-Path $repoRoot 'act-result.txt'
    $script:cases = @(
        @{ Name = 'docs-only';    Fixture = 'fixtures/case-docs-only.json' }
        @{ Name = 'api-backend';  Fixture = 'fixtures/case-api-backend.json' }
        @{ Name = 'mixed';        Fixture = 'fixtures/case-mixed.json' }
    )
}

Describe 'Workflow structure' {
    BeforeAll {
        # powershell-yaml ships with pwsh core? Not always. Fall back to a hand parser.
        $script:workflowText = Get-Content -LiteralPath $workflowFile -Raw
    }

    It 'workflow file exists' {
        Test-Path -LiteralPath $workflowFile | Should -BeTrue
    }

    It 'declares expected triggers' {
        $workflowText | Should -Match '(?m)^on:\s*$'
        $workflowText | Should -Match '(?m)^\s{2}push:'
        $workflowText | Should -Match '(?m)^\s{2}pull_request:'
        $workflowText | Should -Match '(?m)^\s{2}workflow_dispatch:'
    }

    It 'references actions/checkout@v4' {
        $workflowText | Should -Match 'actions/checkout@v4'
    }

    It 'uses shell: pwsh for run steps' {
        $workflowText | Should -Match 'shell:\s*pwsh'
    }

    It 'references the Invoke-PRLabeler script that exists on disk' {
        $workflowText | Should -Match 'Invoke-PRLabeler\.ps1'
        Test-Path -LiteralPath (Join-Path $repoRoot 'Invoke-PRLabeler.ps1') | Should -BeTrue
    }

    It 'references the PRLabeler module file that exists on disk' {
        Test-Path -LiteralPath (Join-Path $repoRoot 'src' 'PRLabeler.psm1') | Should -BeTrue
    }

    It 'declares both unit-tests and label-assigner jobs' {
        $workflowText | Should -Match '(?m)^\s{2}unit-tests:'
        $workflowText | Should -Match '(?m)^\s{2}label-assigner:'
        # label-assigner must depend on unit-tests.
        $workflowText | Should -Match 'needs:\s*unit-tests'
    }

    It 'passes actionlint validation' {
        $al = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $al) { Set-ItResult -Skipped -Because "actionlint not installed" ; return }
        $output = & actionlint $workflowFile 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $output"
    }

    It 'config and fixture files referenced by cases exist' {
        foreach ($case in $script:cases) {
            $fixturePath = Join-Path $repoRoot $case.Fixture
            Test-Path -LiteralPath $fixturePath | Should -BeTrue -Because "fixture $($case.Fixture) must exist"
        }
        Test-Path -LiteralPath (Join-Path $repoRoot 'fixtures' 'config.json') | Should -BeTrue
    }
}

Describe 'Workflow end-to-end (act)' -Tag 'act' {
    BeforeAll {
        if ($env:RUN_ACT -ne '1') {
            # Pester 5 doesn't expose Set-ItResult in BeforeAll, but -Skip on the block is enough.
            return
        }
    }

    It 'act is available' -Skip:($env:RUN_ACT -ne '1') {
        Get-Command act -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'runs case <Name> through act and produces expected labels' `
      -Skip:($env:RUN_ACT -ne '1') `
      -ForEach @(
        @{ Name = 'docs-only';   Fixture = 'fixtures/case-docs-only.json';   Expected = @('documentation') }
        @{ Name = 'api-backend'; Fixture = 'fixtures/case-api-backend.json'; Expected = @('api','backend') }
        @{ Name = 'mixed';       Fixture = 'fixtures/case-mixed.json';       Expected = @('api','backend','frontend','tests','ci','documentation') }
    ) {
        # Staging occurs in the harness before Pester runs; here we just assert on captured output.
        $caseLog = Join-Path $script:repoRoot "act-output-$Name.txt"
        Test-Path -LiteralPath $caseLog | Should -BeTrue -Because "harness must have staged $caseLog"
        $content = Get-Content -LiteralPath $caseLog -Raw

        # 1) act exited 0 (recorded by harness as a sentinel line)
        $content | Should -Match "ACT_EXIT_CODE=0"

        # 2) every job reported success
        ($content | Select-String -Pattern 'Job succeeded' -AllMatches).Matches.Count |
            Should -BeGreaterOrEqual 2

        # 3) each expected label appears (exact token match, preceded by 'LABEL: ')
        foreach ($label in $Expected) {
            $content | Should -Match ("LABEL:\s+" + [regex]::Escape($label) + "\b")
        }

        # 4) no unexpected labels appeared
        $seenMatches = ([regex]'(?m)^\s*\|\s*LABEL:\s+(\S+)\s*$').Matches($content) +
                       ([regex]'(?m)^\s*LABEL:\s+(\S+)\s*$').Matches($content)
        $seen = @($seenMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        foreach ($label in $seen) {
            $Expected | Should -Contain $label
        }
    }
}
