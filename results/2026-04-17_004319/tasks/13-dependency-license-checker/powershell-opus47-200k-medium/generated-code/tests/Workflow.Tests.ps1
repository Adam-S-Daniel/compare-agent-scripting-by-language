# Workflow tests: drive the workflow through `act` for each test case, capture
# output into act-result.txt, and assert on exact expected values.
#
# Strategy: a single Describe owns a BeforeAll that runs act for every case
# (so the expensive work happens once), stores the output in a hashtable, then
# `Context -ForEach` groups the per-case assertions.

BeforeDiscovery {
    $script:Cases = @(
        @{
            Name     = 'mixed'
            Expected = @{
                total    = 4
                approved = 2
                denied   = 1
                unknown  = 1
                deps     = @{
                    'lodash'   = 'approved'
                    'some-gpl' = 'denied'
                    'mystery'  = 'unknown'
                    'jest'     = 'approved'
                }
            }
        },
        @{
            Name     = 'all-approved'
            Expected = @{
                total    = 2
                approved = 2
                denied   = 0
                unknown  = 0
                deps     = @{
                    'lodash'  = 'approved'
                    'express' = 'approved'
                }
            }
        }
    )
}

Describe 'Workflow structure' {
    BeforeAll {
        $script:RepoRoot     = Split-Path -Parent $PSScriptRoot
        $script:WorkflowPath = Join-Path $script:RepoRoot '.github/workflows/dependency-license-checker.yml'
        & actionlint $script:WorkflowPath
        $script:ActionlintExit = $LASTEXITCODE
    }

    It 'has a workflow file that actionlint accepts' {
        $script:ActionlintExit | Should -Be 0
    }

    It 'declares push, pull_request, workflow_dispatch and schedule triggers' {
        $text = Get-Content $script:WorkflowPath -Raw
        $text | Should -Match '(?m)^\s*push:\s*$'
        $text | Should -Match '(?m)^\s*pull_request:\s*$'
        $text | Should -Match '(?m)^\s*workflow_dispatch:\s*$'
        $text | Should -Match 'schedule:'
    }

    It 'references the check-licenses.ps1 script that exists on disk' {
        (Get-Content $script:WorkflowPath -Raw) | Should -Match 'check-licenses\.ps1'
        Test-Path (Join-Path $script:RepoRoot 'check-licenses.ps1') | Should -BeTrue
    }

    It 'uses actions/checkout@v4' {
        (Get-Content $script:WorkflowPath -Raw) | Should -Match 'actions/checkout@v4'
    }
}

Describe 'act pipeline runs' {
    BeforeAll {
        $script:RepoRoot  = Split-Path -Parent $PSScriptRoot
        $script:CaseDir   = Join-Path $PSScriptRoot 'workflow-cases'
        $script:ResultLog = Join-Path $script:RepoRoot 'act-result.txt'

        if (Test-Path $script:ResultLog) { Remove-Item $script:ResultLog -Force }
        New-Item -ItemType File -Path $script:ResultLog | Out-Null

        $allCases = @(
            @{ Name = 'mixed' },
            @{ Name = 'all-approved' }
        )

        $script:CaseOutput = @{}
        foreach ($case in $allCases) {
            $caseName = $case.Name
            $caseFix  = Join-Path $script:CaseDir $caseName
            $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("lic-" + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $tempRoot | Out-Null

            # Copy project into temp dir, excluding volatile items.
            Get-ChildItem -Path $script:RepoRoot -Force |
                Where-Object { $_.Name -notin @('.git', 'act-result.txt') } |
                ForEach-Object {
                    Copy-Item -Path $_.FullName -Destination $tempRoot -Recurse -Force
                }

            # Overlay per-case fixtures as the files the workflow reads.
            Copy-Item (Join-Path $caseFix 'manifest.json')       (Join-Path $tempRoot 'manifest.json')    -Force
            Copy-Item (Join-Path $caseFix 'license-map.json')    (Join-Path $tempRoot 'license-map.json') -Force
            Copy-Item (Join-Path $script:CaseDir 'config.json')  (Join-Path $tempRoot 'config.json')      -Force

            Push-Location $tempRoot
            try {
                & git init -q 2>&1 | Out-Null
                & git config user.email 't@t' | Out-Null
                & git config user.name  'T'   | Out-Null
                & git add -A                  | Out-Null
                & git commit -q -m 'case' 2>&1 | Out-Null

                $actOut = & act push --rm --workflows '.github/workflows/dependency-license-checker.yml' 2>&1
                $actExit = $LASTEXITCODE
                $actText = ($actOut | Out-String)
            } finally {
                Pop-Location
                Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
            }

            Add-Content -Path $script:ResultLog -Value "===== CASE: $caseName (exit=$actExit) ====="
            Add-Content -Path $script:ResultLog -Value $actText
            Add-Content -Path $script:ResultLog -Value "===== END CASE: $caseName ====="

            $script:CaseOutput[$caseName] = @{
                ExitCode = $actExit
                Output   = $actText
            }
        }
    }

    Context 'case <Name>' -ForEach $script:Cases {
        It 'act exited with code 0' {
            $script:CaseOutput[$Name].ExitCode | Should -Be 0
        }

        It 'reports "Job succeeded"' {
            $script:CaseOutput[$Name].Output | Should -Match 'Job succeeded'
        }

        It 'emits the expected summary totals' {
            $e = $Expected
            $expectedLine = "SUMMARY total=$($e.total) approved=$($e.approved) denied=$($e.denied) unknown=$($e.unknown)"
            $script:CaseOutput[$Name].Output | Should -Match ([regex]::Escape($expectedLine))
        }

        It 'emits the expected per-dependency status lines' {
            foreach ($kvp in $Expected.deps.GetEnumerator()) {
                $dep    = $kvp.Key
                $status = $kvp.Value
                $pattern = "DEP name=" + [regex]::Escape($dep) + ".*status=" + [regex]::Escape($status)
                $script:CaseOutput[$Name].Output | Should -Match $pattern
            }
        }
    }
}
