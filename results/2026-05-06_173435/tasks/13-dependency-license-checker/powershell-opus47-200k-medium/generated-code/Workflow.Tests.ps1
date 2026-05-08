<#
    Workflow integration tests.

    All test scenarios run through the GitHub Actions workflow via `nektos/act`.
    For each test case we:
        1. Build a temporary git repo containing the workflow + script + the
           case-specific fixture data.
        2. Run `act push --rm`, capture combined output.
        3. Append output (delimited) to ./act-result.txt in the original cwd.
        4. Assert exit code 0 and that the output contains EXACT expected
           SUMMARY/ROW/RESULT lines emitted by the workflow.

    Cap: <=3 `act push` runs total. We satisfy this by combining all license
    test scenarios into ONE `act push` run via a single fixture set, then
    running 2 more scenarios for `unknown` and `clean` cases.
#>

BeforeDiscovery {
    $script:RepoRoot   = $PSScriptRoot
    $script:ResultFile = Join-Path $RepoRoot 'act-result.txt'

    # Reset the artifact at the start so the file always reflects this run.
    if (Test-Path $ResultFile) { Remove-Item $ResultFile -Force }

    # Read the workflow YAML once.
    $script:WorkflowPath = Join-Path $RepoRoot '.github/workflows/dependency-license-checker.yml'
    $script:WorkflowText = Get-Content -Raw $WorkflowPath
}

BeforeAll {
    $script:RepoRoot   = $PSScriptRoot
    $script:ResultFile = Join-Path $RepoRoot 'act-result.txt'
    $script:WorkflowPath = Join-Path $RepoRoot '.github/workflows/dependency-license-checker.yml'

    function New-ActWorkspace {
        param([hashtable]$Fixtures)
        $work = Join-Path ([System.IO.Path]::GetTempPath()) ("act-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $work -Force | Out-Null

        # Copy script + workflow + tests
        Copy-Item (Join-Path $RepoRoot 'LicenseChecker.ps1')        (Join-Path $work 'LicenseChecker.ps1')
        Copy-Item (Join-Path $RepoRoot 'LicenseChecker.Tests.ps1')  (Join-Path $work 'LicenseChecker.Tests.ps1')
        New-Item -ItemType Directory -Path (Join-Path $work '.github/workflows') -Force | Out-Null
        Copy-Item $WorkflowPath (Join-Path $work '.github/workflows/dependency-license-checker.yml')

        # Pin the same act image the parent .actrc selects.
        Copy-Item (Join-Path $RepoRoot '.actrc') (Join-Path $work '.actrc')

        # Write fixture files.
        $fixDir = Join-Path $work 'fixtures'
        New-Item -ItemType Directory -Path $fixDir -Force | Out-Null
        foreach ($k in $Fixtures.Keys) {
            $Fixtures[$k] | Set-Content -Path (Join-Path $fixDir $k) -NoNewline
        }

        # git init so act can detect the repo.
        Push-Location $work
        try {
            git init -q                                             | Out-Null
            git config user.email 'test@example.com'                | Out-Null
            git config user.name  'Test'                            | Out-Null
            git add -A                                              | Out-Null
            git commit -q -m 'init'                                 | Out-Null
        } finally { Pop-Location }
        return $work
    }

    function Invoke-ActPush {
        param(
            [Parameter(Mandatory)][string]$WorkspacePath,
            [Parameter(Mandatory)][string]$CaseLabel
        )
        Push-Location $WorkspacePath
        try {
            $combined = & act push --rm 2>&1
            $rc = $LASTEXITCODE
        } finally { Pop-Location }

        $delim = "=" * 70
        $header = @(
            $delim
            "ACT CASE: $CaseLabel"
            "EXIT: $rc"
            $delim
        ) -join [Environment]::NewLine
        Add-Content -Path $script:ResultFile -Value $header
        Add-Content -Path $script:ResultFile -Value ($combined -join [Environment]::NewLine)
        Add-Content -Path $script:ResultFile -Value ""

        return [pscustomobject]@{
            ExitCode = $rc
            Output   = ($combined -join [Environment]::NewLine)
        }
    }
}

Describe 'Workflow file structure' {
    It 'workflow file exists' {
        Test-Path $WorkflowPath | Should -BeTrue
    }

    It 'declares push, pull_request, schedule, and workflow_dispatch triggers' {
        $yaml = Get-Content -Raw $WorkflowPath
        $yaml | Should -Match 'on:'
        $yaml | Should -Match 'push:'
        $yaml | Should -Match 'pull_request:'
        $yaml | Should -Match 'schedule:'
        $yaml | Should -Match 'workflow_dispatch:'
    }

    It 'uses pinned actions/checkout@v4' {
        (Get-Content -Raw $WorkflowPath) | Should -Match 'actions/checkout@v4'
    }

    It 'declares minimum required permissions' {
        (Get-Content -Raw $WorkflowPath) | Should -Match 'permissions:\s*\r?\n\s*contents:\s*read'
    }

    It 'references LicenseChecker.ps1 and the test file (which exist)' {
        $yaml = Get-Content -Raw $WorkflowPath
        $yaml | Should -Match 'LicenseChecker\.ps1'
        $yaml | Should -Match 'LicenseChecker\.Tests\.ps1'
        Test-Path (Join-Path $RepoRoot 'LicenseChecker.ps1')       | Should -BeTrue
        Test-Path (Join-Path $RepoRoot 'LicenseChecker.Tests.ps1') | Should -BeTrue
    }

    It 'uses shell: pwsh on run steps' {
        (Get-Content -Raw $WorkflowPath) | Should -Match 'shell:\s*pwsh'
    }

    It 'passes actionlint with exit code 0' {
        $null = & actionlint $WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}

Describe 'Workflow execution via act' {

    Context 'Case 1: clean run with all approved licenses' {
        BeforeAll {
            $script:fixtures1 = @{
                'package.json' = @'
{
  "dependencies": { "express": "4.18.0", "lodash": "4.17.21" },
  "devDependencies": { "jest": "29.0.0" }
}
'@
                'licenses.json' = '{ "allow": ["MIT", "Apache-2.0"], "deny": ["GPL-3.0"] }'
                'lookup.json'   = '{ "express": "MIT", "lodash": "MIT", "jest": "MIT" }'
            }
            $script:work1   = New-ActWorkspace -Fixtures $fixtures1
            $script:result1 = Invoke-ActPush -WorkspacePath $work1 -CaseLabel 'clean-all-approved'
        }
        AfterAll { if ($work1 -and (Test-Path $work1)) { Remove-Item $work1 -Recurse -Force } }

        It 'act exits 0' { $result1.ExitCode | Should -Be 0 }

        It 'every job reports succeeded' {
            ($result1.Output -split "`n" | Where-Object { $_ -match 'Job succeeded' }).Count |
                Should -BeGreaterOrEqual 2
        }

        It 'summary shows 3 approved 0 denied 0 unknown' {
            $result1.Output | Should -Match 'SUMMARY total=3 approved=3 denied=0 unknown=0'
        }

        It 'reports each dependency exactly with status Approved' {
            $result1.Output | Should -Match 'ROW name=express version=4\.18\.0 license=MIT status=Approved'
            $result1.Output | Should -Match 'ROW name=lodash version=4\.17\.21 license=MIT status=Approved'
            $result1.Output | Should -Match 'ROW name=jest version=29\.0\.0 license=MIT status=Approved'
        }

        It 'emits RESULT=CLEAN' {
            $result1.Output | Should -Match 'RESULT=CLEAN'
        }
    }

    Context 'Case 2: mixed manifest with denied + unknown licenses' {
        BeforeAll {
            $script:fixtures2 = @{
                'package.json' = @'
{
  "dependencies": {
    "express":  "4.18.0",
    "evil-pkg": "1.0.0",
    "mystery":  "0.1.0"
  }
}
'@
                'licenses.json' = '{ "allow": ["MIT"], "deny": ["GPL-3.0"] }'
                'lookup.json'   = '{ "express": "MIT", "evil-pkg": "GPL-3.0" }'
            }
            $script:work2   = New-ActWorkspace -Fixtures $fixtures2
            $script:result2 = Invoke-ActPush -WorkspacePath $work2 -CaseLabel 'mixed-denied-unknown'
        }
        AfterAll { if ($work2 -and (Test-Path $work2)) { Remove-Item $work2 -Recurse -Force } }

        It 'act exits 0' { $result2.ExitCode | Should -Be 0 }

        It 'every job reports succeeded' {
            ($result2.Output -split "`n" | Where-Object { $_ -match 'Job succeeded' }).Count |
                Should -BeGreaterOrEqual 2
        }

        It 'summary is exactly 1 approved, 1 denied, 1 unknown out of 3' {
            $result2.Output | Should -Match 'SUMMARY total=3 approved=1 denied=1 unknown=1'
        }

        It 'classifies each row precisely' {
            $result2.Output | Should -Match 'ROW name=express version=4\.18\.0 license=MIT status=Approved'
            $result2.Output | Should -Match 'ROW name=evil-pkg version=1\.0\.0 license=GPL-3\.0 status=Denied'
            $result2.Output | Should -Match 'ROW name=mystery version=0\.1\.0 license=UNKNOWN status=Unknown'
        }

        It 'emits RESULT=DENIED_LICENSES' {
            $result2.Output | Should -Match 'RESULT=DENIED_LICENSES'
        }
    }
}
