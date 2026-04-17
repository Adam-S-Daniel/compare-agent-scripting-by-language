# Workflow-structure + end-to-end act tests.
#
# Structure tests: parse YAML, verify triggers/jobs/steps, verify actionlint.
# E2E tests: build a temp git repo per fixture, run `act push --rm`, append
# output to act-result.txt, assert exit code 0 and exact expected labels.
#
# Budget: at most 3 act runs in total (we use 2 here).

BeforeAll {
    $script:Root       = $PSScriptRoot
    $script:Workflow   = Join-Path $Root '.github/workflows/pr-label-assigner.yml'
    $script:ActResult  = Join-Path $Root 'act-result.txt'
    # Start a fresh act-result.txt at the top of the run.
    if (Test-Path $ActResult) { Remove-Item $ActResult -Force }
}

Describe 'Workflow structure' {
    It 'workflow file exists' {
        Test-Path $script:Workflow | Should -BeTrue
    }

    It 'passes actionlint cleanly' {
        $out = & actionlint $script:Workflow 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($out -join "`n")
    }

    It 'has push, pull_request, and workflow_dispatch triggers' {
        $content = Get-Content $script:Workflow -Raw
        $content | Should -Match '(?m)^on:'
        $content | Should -Match '(?m)^\s{2}push:'
        $content | Should -Match '(?m)^\s{2}pull_request:'
        $content | Should -Match '(?m)^\s{2}workflow_dispatch:'
    }

    It 'references existing script files' {
        $content = Get-Content $script:Workflow -Raw
        $content | Should -Match 'assign-labels\.ps1'
        $content | Should -Match 'PRLabelAssigner\.Tests\.ps1'
        (Test-Path (Join-Path $Root 'assign-labels.ps1'))             | Should -BeTrue
        (Test-Path (Join-Path $Root 'PRLabelAssigner.Tests.ps1'))     | Should -BeTrue
        (Test-Path (Join-Path $Root 'PRLabelAssigner.psm1'))          | Should -BeTrue
        (Test-Path (Join-Path $Root 'rules.example.json'))            | Should -BeTrue
    }

    It 'declares the test and assign-labels jobs' {
        $content = Get-Content $script:Workflow -Raw
        $content | Should -Match 'jobs:'
        $content | Should -Match '(?m)^\s{2}test:'
        $content | Should -Match '(?m)^\s{2}assign-labels:'
        $content | Should -Match 'needs:\s*test'
    }

    It 'uses actions/checkout@v4' {
        $content = Get-Content $script:Workflow -Raw
        $content | Should -Match 'actions/checkout@v4'
    }
}

Describe 'Act end-to-end' -Tag 'E2E' {
    BeforeAll {
        # Helper: copy the project into a fresh temp dir, overwrite the fixture
        # with the test case's content, initialize git, run act, capture output.
        function Invoke-ActCase {
            param(
                [Parameter(Mandatory)][string]$CaseName,
                [Parameter(Mandatory)][string[]]$FixtureLines
            )
            $tmp = Join-Path ([IO.Path]::GetTempPath()) ("pla-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -ItemType Directory -Path $tmp | Out-Null
            try {
                # Copy project contents (exclude act-result.txt and the .git
                # directory so act starts from a clean tree).
                Get-ChildItem -Path $script:Root -Force |
                    Where-Object { $_.Name -notin @('.git', 'act-result.txt') } |
                    ForEach-Object { Copy-Item -Recurse -Force $_.FullName -Destination $tmp }

                # Overwrite the fixture for this case.
                $fixturePath = Join-Path $tmp 'fixtures/changed-files.txt'
                New-Item -ItemType Directory -Path (Split-Path $fixturePath) -Force | Out-Null
                Set-Content -Path $fixturePath -Value ($FixtureLines -join "`n")

                # Copy repo-level .actrc so we pin the act-ubuntu-pwsh image.
                $actrcSrc = Join-Path $script:Root '.actrc'
                if (Test-Path $actrcSrc) { Copy-Item $actrcSrc -Destination $tmp }

                # Initialize a throwaway git repo inside the temp directory;
                # act needs a git root to know which event to fire.
                Push-Location $tmp
                try {
                    git init -q 2>&1 | Out-Null
                    git config user.email 'ci@example.com'
                    git config user.name  'CI'
                    git add -A 2>&1 | Out-Null
                    git commit -q -m 'test fixture' 2>&1 | Out-Null

                    $output = & act push --rm 2>&1
                    $exit   = $LASTEXITCODE

                    # Append to act-result.txt at the project root.
                    $header = "=== CASE: $CaseName (exit=$exit) ==="
                    Add-Content -Path $script:ActResult -Value ''
                    Add-Content -Path $script:ActResult -Value $header
                    Add-Content -Path $script:ActResult -Value ($output -join "`n")
                    Add-Content -Path $script:ActResult -Value "=== END CASE: $CaseName ==="

                    return [pscustomobject]@{
                        ExitCode = $exit
                        Output   = ($output -join "`n")
                    }
                } finally {
                    Pop-Location
                }
            } finally {
                Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
            }
        }
    }

    It 'case 1: mixed-fixture emits all six expected labels in priority order' {
        $r = Invoke-ActCase -CaseName 'mixed' -FixtureLines @(
            'docs/intro.md'
            'src/api/users.ps1'
            'src/ui/home.js'
            'README.md'
            'tests/foo.test.ps1'
            '.github/workflows/pr-label-assigner.yml'
        )
        $r.ExitCode | Should -Be 0 -Because $r.Output

        # Every job should report success.
        ($r.Output | Select-String -Pattern 'Job succeeded' -AllMatches).Matches.Count |
            Should -BeGreaterOrEqual 2

        # Parse LABEL: lines between the delimiters.
        $inBlock = $false
        $labels = foreach ($line in ($r.Output -split "`n")) {
            if ($line -match '=== ASSIGNED LABELS ===') { $inBlock = $true; continue }
            if ($line -match '=== END LABELS ===')      { $inBlock = $false; continue }
            if ($inBlock -and $line -match 'LABEL:\s*(\S+)') { $matches[1] }
        }
        $labels | Should -Be @('tests', 'ci', 'api', 'frontend', 'documentation', 'powershell')
    }

    It 'case 2: docs-only fixture emits a single documentation label' {
        $r = Invoke-ActCase -CaseName 'docs-only' -FixtureLines @(
            'docs/intro.md'
            'docs/guide/setup.md'
            'README.md'
        )
        $r.ExitCode | Should -Be 0 -Because $r.Output

        ($r.Output | Select-String -Pattern 'Job succeeded' -AllMatches).Matches.Count |
            Should -BeGreaterOrEqual 2

        $inBlock = $false
        $labels = foreach ($line in ($r.Output -split "`n")) {
            if ($line -match '=== ASSIGNED LABELS ===') { $inBlock = $true; continue }
            if ($line -match '=== END LABELS ===')      { $inBlock = $false; continue }
            if ($inBlock -and $line -match 'LABEL:\s*(\S+)') { $matches[1] }
        }
        $labels | Should -Be @('documentation')
    }
}
