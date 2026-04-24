# Workflow + act harness tests.
#
# These tests run the CI workflow under `act` against multiple fixture
# variants. Each case sets up an isolated git repo containing the project
# files plus the case-specific fixture, runs `act push --rm`, and asserts
# on exact expected values in the output. All output is appended to
# `act-result.txt` in the project root (the required artifact).

BeforeAll {
    $script:ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:WorkflowPath = Join-Path $script:ProjectRoot '.github/workflows/dependency-license-checker.yml'
    $script:ResultFile = Join-Path $script:ProjectRoot 'act-result.txt'

    function New-TempProjectRepo {
        <#
        Copies the entire project (minus .git and heavyweight ignored files)
        into a fresh temp directory and initialises a git repo there. Required
        because `act push` needs a real git repo with a HEAD.
        #>
        param(
            [Parameter(Mandatory)] [string] $ManifestJson,
            [Parameter(Mandatory)] [string] $DatabaseJson
        )

        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("act-case-{0}" -f ([guid]::NewGuid()))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null

        # Copy project files. rsync gives us sensible exclusion semantics.
        & rsync -a `
            --exclude '.git' `
            --exclude 'act-result.txt' `
            --exclude '.actrc' `
            "$script:ProjectRoot/" `
            "$tmp/" | Out-Null

        # Point the copy's .actrc at the pre-built custom image used in this
        # env. --pull=false stops act from trying to pull the local-only image
        # from dockerhub (which fails with "pull access denied").
        Set-Content -Path (Join-Path $tmp '.actrc') -Value @(
            '-P ubuntu-latest=act-ubuntu-pwsh:latest'
            '--pull=false'
        )

        # Workflow input lives at repo-root manifest.json; harness overwrites
        # it per case. fixtures/* remain untouched so unit tests still see
        # their control data when the workflow runs them inside act.
        Set-Content -Path (Join-Path $tmp 'manifest.json') -Value $ManifestJson
        # License DB is static across cases, but we overwrite to prove the
        # harness owns the data the workflow reads.
        Set-Content -Path (Join-Path $tmp 'fixtures/license-database.json') -Value $DatabaseJson

        & git -C $tmp init -q
        & git -C $tmp -c user.email=t@t -c user.name=t add . | Out-Null
        & git -C $tmp -c user.email=t@t -c user.name=t commit -q -m init | Out-Null

        return $tmp
    }

    function Invoke-ActPush {
        <#
        Runs `act push --rm` in the given repo directory and appends the
        output (with a labelled delimiter) to the shared act-result.txt.
        Returns a hashtable with ExitCode and Output.

        Flags are passed explicitly rather than relying on .actrc (which act
        does not pick up reliably when -C is used). --pull=false stops act
        from trying to pull the local-only custom image from dockerhub.
        #>
        param(
            [Parameter(Mandatory)] [string] $RepoDir,
            [Parameter(Mandatory)] [string] $Label
        )

        $prevCwd = Get-Location
        Set-Location $RepoDir
        try {
            $output = & act push --rm `
                -P ubuntu-latest=act-ubuntu-pwsh:latest `
                --pull=false 2>&1 | Out-String
            $code = $LASTEXITCODE
        } finally {
            Set-Location $prevCwd
        }

        $delim = "`n========== TEST CASE: $Label ==========`n"
        $summary = "EXIT CODE: $code`n"
        Add-Content -Path $script:ResultFile -Value ($delim + $summary + $output)

        return @{ ExitCode = $code; Output = $output }
    }

    # Make sure the result file starts empty for each test run.
    if (Test-Path $script:ResultFile) { Remove-Item $script:ResultFile -Force }
    New-Item -ItemType File -Path $script:ResultFile -Force | Out-Null

    # Run act once per case up front and cache results, so Pester's per-It
    # invocations don't re-run the (slow) act command. Three cases total,
    # which is the at-most-3 act-push budget the task allows.

    $fixturesDir = Join-Path $script:ProjectRoot 'fixtures'
    $standardDb = Get-Content (Join-Path $fixturesDir 'license-database.json') -Raw

    # Case 1: the canonical package.json with gpl-lib (denied) +
    # mystery-pkg (unknown). Expect Denied=1, Unknown=1, Approved=3.
    $case1Manifest = Get-Content (Join-Path $fixturesDir 'package.json') -Raw
    $repo1 = New-TempProjectRepo -ManifestJson $case1Manifest -DatabaseJson $standardDb
    $script:Case1 = Invoke-ActPush -RepoDir $repo1 -Label 'denied-and-unknown'

    # Case 2: fully compliant — express + lodash + jest (all MIT).
    # Expect Denied=0, Unknown=0, Approved=3, HasViolations=false.
    $case2Manifest = @{
        name = 'clean-app'; version = '1.0.0'
        dependencies    = @{ express = '4.0.0'; lodash = '4.17.21' }
        devDependencies = @{ jest    = '29.7.0' }
    } | ConvertTo-Json -Depth 5
    $repo2 = New-TempProjectRepo -ManifestJson $case2Manifest -DatabaseJson $standardDb
    $script:Case2 = Invoke-ActPush -RepoDir $repo2 -Label 'fully-compliant'

    # Case 3: all unknown — none of the packages are in the license DB.
    # Expect Denied=0, Unknown=2, Approved=0, HasViolations=false.
    $case3Manifest = @{
        name = 'unknown-app'; version = '1.0.0'
        dependencies = @{ 'some-obscure-lib' = '1.2.3'; 'yet-another' = '0.0.1' }
    } | ConvertTo-Json -Depth 5
    $repo3 = New-TempProjectRepo -ManifestJson $case3Manifest -DatabaseJson $standardDb
    $script:Case3 = Invoke-ActPush -RepoDir $repo3 -Label 'all-unknown'
}

Describe 'Workflow structure' {
    It 'workflow file exists at the required path' {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It 'actionlint validates the workflow cleanly' {
        $null = & actionlint $script:WorkflowPath
        $LASTEXITCODE | Should -Be 0
    }

    It 'declares the required trigger events' {
        $yaml = Get-Content $script:WorkflowPath -Raw
        $yaml | Should -Match '(?m)^on:'
        $yaml | Should -Match '(?m)^\s{2}push:'
        $yaml | Should -Match '(?m)^\s{2}pull_request:'
        $yaml | Should -Match 'workflow_dispatch:'
        $yaml | Should -Match 'schedule:'
    }

    It 'references the script and fixture paths that exist on disk' {
        $yaml = Get-Content $script:WorkflowPath -Raw
        # Paths referenced in the workflow must resolve in the checked-out repo.
        $yaml | Should -Match 'src/DependencyLicenseChecker\.psm1'
        $yaml | Should -Match 'tests/DependencyLicenseChecker\.Tests\.ps1'

        Test-Path (Join-Path $script:ProjectRoot 'src/DependencyLicenseChecker.psm1') | Should -BeTrue
        Test-Path (Join-Path $script:ProjectRoot 'tests/DependencyLicenseChecker.Tests.ps1') | Should -BeTrue
        Test-Path (Join-Path $script:ProjectRoot 'fixtures/package.json') | Should -BeTrue
        Test-Path (Join-Path $script:ProjectRoot 'fixtures/license-policy.json') | Should -BeTrue
        Test-Path (Join-Path $script:ProjectRoot 'fixtures/license-database.json') | Should -BeTrue
    }

    It 'uses actions/checkout@v4 and shell: pwsh' {
        $yaml = Get-Content $script:WorkflowPath -Raw
        $yaml | Should -Match 'actions/checkout@v4'
        $yaml | Should -Match 'shell:\s*pwsh'
    }

    It 'declares permissions' {
        $yaml = Get-Content $script:WorkflowPath -Raw
        $yaml | Should -Match '(?m)^permissions:'
    }

    It 'has the compliance job depend on the test job' {
        $yaml = Get-Content $script:WorkflowPath -Raw
        # The `needs: test` keyword wires in the job dependency.
        $yaml | Should -Match 'needs:\s*test'
    }
}

Describe 'act execution - case 1 (denied + unknown)' {
    It 'act exited with code 0' {
        $script:Case1.ExitCode | Should -Be 0
    }
    It 'reports both jobs succeeded' {
        # act prints "Job succeeded" per job on success.
        ($script:Case1.Output | Select-String -Pattern 'Job succeeded' -AllMatches).Matches.Count |
            Should -BeGreaterOrEqual 2
    }
    It 'reports Approved = 3' {
        $script:Case1.Output | Should -Match '=== COMPLIANCE_APPROVED: 3 ==='
    }
    It 'reports Denied = 1' {
        $script:Case1.Output | Should -Match '=== COMPLIANCE_DENIED: 1 ==='
    }
    It 'reports Unknown = 1' {
        $script:Case1.Output | Should -Match '=== COMPLIANCE_UNKNOWN: 1 ==='
    }
    It 'reports Total = 5' {
        $script:Case1.Output | Should -Match '=== COMPLIANCE_TOTAL: 5 ==='
    }
    It 'reports HasViolations = true' {
        $script:Case1.Output | Should -Match '=== COMPLIANCE_HAS_VIOLATIONS: true ==='
    }
}

Describe 'act execution - case 2 (fully compliant)' {
    It 'act exited with code 0' {
        $script:Case2.ExitCode | Should -Be 0
    }
    It 'reports Approved = 3' {
        $script:Case2.Output | Should -Match '=== COMPLIANCE_APPROVED: 3 ==='
    }
    It 'reports Denied = 0' {
        $script:Case2.Output | Should -Match '=== COMPLIANCE_DENIED: 0 ==='
    }
    It 'reports Unknown = 0' {
        $script:Case2.Output | Should -Match '=== COMPLIANCE_UNKNOWN: 0 ==='
    }
    It 'reports HasViolations = false' {
        $script:Case2.Output | Should -Match '=== COMPLIANCE_HAS_VIOLATIONS: false ==='
    }
    It 'reports both jobs succeeded' {
        ($script:Case2.Output | Select-String -Pattern 'Job succeeded' -AllMatches).Matches.Count |
            Should -BeGreaterOrEqual 2
    }
}

Describe 'act execution - case 3 (all unknown packages)' {
    It 'act exited with code 0' {
        $script:Case3.ExitCode | Should -Be 0
    }
    It 'reports Approved = 0' {
        $script:Case3.Output | Should -Match '=== COMPLIANCE_APPROVED: 0 ==='
    }
    It 'reports Denied = 0' {
        $script:Case3.Output | Should -Match '=== COMPLIANCE_DENIED: 0 ==='
    }
    It 'reports Unknown = 2' {
        $script:Case3.Output | Should -Match '=== COMPLIANCE_UNKNOWN: 2 ==='
    }
    It 'reports HasViolations = false' {
        $script:Case3.Output | Should -Match '=== COMPLIANCE_HAS_VIOLATIONS: false ==='
    }
    It 'reports both jobs succeeded' {
        ($script:Case3.Output | Select-String -Pattern 'Job succeeded' -AllMatches).Matches.Count |
            Should -BeGreaterOrEqual 2
    }
}

Describe 'act-result.txt artifact' {
    It 'exists' {
        Test-Path $script:ResultFile | Should -BeTrue
    }
    It 'contains a delimiter for each of the three cases' {
        $content = Get-Content $script:ResultFile -Raw
        $content | Should -Match 'TEST CASE: denied-and-unknown'
        $content | Should -Match 'TEST CASE: fully-compliant'
        $content | Should -Match 'TEST CASE: all-unknown'
    }
}
