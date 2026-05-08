# act-driven workflow tests. Every test case runs the entire CI pipeline
# through `act push --rm` against an isolated temp git repo containing
# this project + a curated fixtures/ directory. We then parse the act
# output and assert exact AGG_* totals.
#
# Output of every act run is appended to ./act-result.txt with a
# delimiter so the file is a complete audit trail of what ran.

BeforeAll {
    $script:RepoRoot   = $PSScriptRoot
    $script:ActResults = Join-Path $script:RepoRoot 'act-result.txt'

    # Reset act-result.txt at the start of the test run.
    Set-Content -LiteralPath $script:ActResults -Value "act-result.txt - generated $(Get-Date -Format o)`n" -Encoding UTF8

    function script:New-CaseRepo {
        param(
            [Parameter(Mandatory)] [string] $CaseName,
            [Parameter(Mandatory)] [string[]] $FixtureFiles
        )
        $work = Join-Path ([IO.Path]::GetTempPath()) ("agg-act-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $work | Out-Null

        # Copy all project files we need into the temp repo.
        Copy-Item (Join-Path $script:RepoRoot 'Aggregator.psm1')          $work
        Copy-Item (Join-Path $script:RepoRoot 'Aggregate-TestResults.ps1') $work
        Copy-Item (Join-Path $script:RepoRoot 'Aggregator.Tests.ps1')      $work
        Copy-Item (Join-Path $script:RepoRoot '.actrc')                    $work
        $wfDest = Join-Path $work '.github/workflows'
        New-Item -ItemType Directory -Path $wfDest -Force | Out-Null
        Copy-Item (Join-Path $script:RepoRoot '.github/workflows/test-results-aggregator.yml') $wfDest

        # Selective fixture copy so each case sees a different matrix.
        $fixDest = Join-Path $work 'fixtures'
        New-Item -ItemType Directory -Path $fixDest -Force | Out-Null
        foreach ($f in $FixtureFiles) {
            Copy-Item (Join-Path $script:RepoRoot "fixtures/$f") $fixDest
        }

        # Git init + commit so act has a clean push event to operate on.
        Push-Location $work
        try {
            git init -q -b main 2>$null | Out-Null
            git config user.email 'ci@example.com'
            git config user.name  'ci'
            git add -A
            git commit -q -m "case: $CaseName" | Out-Null
        } finally { Pop-Location }

        return $work
    }

    function script:Invoke-ActCase {
        param(
            [Parameter(Mandatory)] [string] $CaseName,
            [Parameter(Mandatory)] [string] $RepoDir
        )
        $log = Join-Path ([IO.Path]::GetTempPath()) ("act-$CaseName-" + [guid]::NewGuid().ToString('N') + '.log')
        Push-Location $RepoDir
        try {
            # `act push --rm` runs the workflow exactly as GitHub would on a
            # push event, then deletes the container regardless of result.
            # --pull=false because act-ubuntu-pwsh:latest is a local image
            # built from Dockerfile.act; force-pull would 404 on Docker Hub.
            & act push --rm --pull=false *> $log
            $exit = $LASTEXITCODE
        } finally { Pop-Location }

        $output = if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log -Raw } else { '' }

        # Append to the audit trail with a clear delimiter.
        $delim = ('=' * 80)
        Add-Content -LiteralPath $script:ActResults -Value @"
$delim
CASE: $CaseName
EXIT: $exit
$delim
$output

"@
        [pscustomobject]@{ Exit = $exit; Output = $output }
    }
}

Describe 'Workflow structure' {
    It 'parses as YAML and has the expected jobs/triggers' {
        $yamlPath = Join-Path $PSScriptRoot '.github/workflows/test-results-aggregator.yml'
        Test-Path $yamlPath | Should -BeTrue
        $text = Get-Content -LiteralPath $yamlPath -Raw
        $text | Should -Match '(?m)^on:'
        $text | Should -Match '(?m)^\s+push:'
        $text | Should -Match '(?m)^\s+pull_request:'
        $text | Should -Match '(?m)^\s+workflow_dispatch:'
        $text | Should -Match '(?m)^\s+schedule:'
        $text | Should -Match 'unit-tests:'
        $text | Should -Match 'aggregate:'
        $text | Should -Match 'needs:\s+unit-tests'
    }

    It 'references files that exist in the repo' {
        $yaml = Get-Content (Join-Path $PSScriptRoot '.github/workflows/test-results-aggregator.yml') -Raw
        $yaml | Should -Match 'Aggregate-TestResults\.ps1'
        $yaml | Should -Match 'Aggregator\.Tests\.ps1'
        Test-Path (Join-Path $PSScriptRoot 'Aggregate-TestResults.ps1') | Should -BeTrue
        Test-Path (Join-Path $PSScriptRoot 'Aggregator.Tests.ps1')      | Should -BeTrue
        Test-Path (Join-Path $PSScriptRoot 'Aggregator.psm1')           | Should -BeTrue
    }

    It 'passes actionlint with exit code 0' {
        $yamlPath = Join-Path $PSScriptRoot '.github/workflows/test-results-aggregator.yml'
        & actionlint $yamlPath
        $LASTEXITCODE | Should -Be 0
    }

    It 'uses pwsh shell on run steps (not bash invoking pwsh)' {
        $yaml = Get-Content (Join-Path $PSScriptRoot '.github/workflows/test-results-aggregator.yml') -Raw
        $yaml | Should -Match 'shell: pwsh'
        $yaml | Should -Not -Match 'pwsh -Command'
        $yaml | Should -Not -Match 'pwsh -File'
    }
}

Describe 'act execution' {
    # Each It block runs ONE `act push` invocation. The full project rules
    # cap us at 3 act push runs, so there are exactly 3 cases below.
    # Expected values are pre-computed from the fixture files.

    It 'Case 1: all three fixtures produce 11 passed / 4 failed / 3 skipped / 1 flaky' {
        $repo = New-CaseRepo -CaseName 'all-fixtures' -FixtureFiles @('linux.xml','macos.json','windows.xml')
        try {
            $r = Invoke-ActCase -CaseName 'all-fixtures' -RepoDir $repo
            $r.Exit | Should -Be 0
            $r.Output | Should -Match 'AGG_PASSED=11'
            $r.Output | Should -Match 'AGG_FAILED=4'
            $r.Output | Should -Match 'AGG_SKIPPED=3'
            $r.Output | Should -Match 'AGG_FLAKY=1'
            $r.Output | Should -Match 'AGG_RUNS=3'
            # One Job succeeded line per job; we have 2 jobs (unit-tests, aggregate).
            ([regex]::Matches($r.Output, 'Job succeeded')).Count | Should -BeGreaterOrEqual 2
        } finally { Remove-Item $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'Case 2: linux.xml only - no flaky tests, single run' {
        $repo = New-CaseRepo -CaseName 'linux-only' -FixtureFiles @('linux.xml')
        try {
            $r = Invoke-ActCase -CaseName 'linux-only' -RepoDir $repo
            $r.Exit | Should -Be 0
            $r.Output | Should -Match 'AGG_PASSED=4'
            $r.Output | Should -Match 'AGG_FAILED=1'
            $r.Output | Should -Match 'AGG_SKIPPED=1'
            $r.Output | Should -Match 'AGG_FLAKY=0'
            $r.Output | Should -Match 'AGG_RUNS=1'
            ([regex]::Matches($r.Output, 'Job succeeded')).Count | Should -BeGreaterOrEqual 2
        } finally { Remove-Item $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'Case 3: linux.xml + macos.json - mixed formats with one flaky test' {
        # connects_to_host passes on linux.xml, fails on macos.json -> flaky.
        $repo = New-CaseRepo -CaseName 'mixed-formats-flaky' -FixtureFiles @('linux.xml','macos.json')
        try {
            $r = Invoke-ActCase -CaseName 'mixed-formats-flaky' -RepoDir $repo
            $r.Exit | Should -Be 0
            $r.Output | Should -Match 'AGG_PASSED=7'
            $r.Output | Should -Match 'AGG_FAILED=3'
            $r.Output | Should -Match 'AGG_SKIPPED=2'
            $r.Output | Should -Match 'AGG_FLAKY=1'
            $r.Output | Should -Match 'AGG_RUNS=2'
            ([regex]::Matches($r.Output, 'Job succeeded')).Count | Should -BeGreaterOrEqual 2
        } finally { Remove-Item $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
