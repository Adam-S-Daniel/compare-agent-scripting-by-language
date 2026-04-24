# Harness tests — every functional assertion runs through `act push` using a
# temp git repo. Also validates workflow structure and actionlint cleanliness.

BeforeAll {
    $script:Root      = $PSScriptRoot
    $script:Workflow  = Join-Path $Root '.github/workflows/artifact-cleanup-script.yml'
    $script:ActOutput = Join-Path $Root 'act-result.txt'
    if (Test-Path $script:ActOutput) { Remove-Item $script:ActOutput -Force }

    function Invoke-ActCase {
        param(
            [string]$Name,
            [string]$FixtureJson,
            [string]$DryRun = 'true'
        )
        $tmp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ("act-" + [guid]::NewGuid())) -Force
        try {
            Copy-Item -Path (Join-Path $script:Root 'Cleanup.ps1')        -Destination $tmp.FullName
            Copy-Item -Path (Join-Path $script:Root 'Cleanup.Tests.ps1')  -Destination $tmp.FullName
            Copy-Item -Path (Join-Path $script:Root 'Invoke-Cleanup.ps1') -Destination $tmp.FullName
            Copy-Item -Path (Join-Path $script:Root '.actrc')             -Destination $tmp.FullName
            Copy-Item -Path (Join-Path $script:Root '.github') -Destination $tmp.FullName -Recurse
            New-Item  -ItemType Directory -Path (Join-Path $tmp.FullName 'fixtures') -Force | Out-Null
            Set-Content -Path (Join-Path $tmp.FullName 'fixtures/default.json') -Value $FixtureJson -Encoding utf8

            Push-Location $tmp.FullName
            try {
                git init -q
                git config user.email "t@t"
                git config user.name  "t"
                git add -A
                git -c commit.gpgsign=false commit -q -m "case $Name"

                $log = Join-Path $tmp.FullName 'act.log'
                & act push --rm --pull=false --env DRY_RUN=$DryRun *> $log
                $exit = $LASTEXITCODE
                $content = Get-Content -Raw -Path $log

                $delim = "===== CASE: $Name (exit=$exit) ====="
                Add-Content -Path $script:ActOutput -Value $delim
                Add-Content -Path $script:ActOutput -Value $content
                Add-Content -Path $script:ActOutput -Value ""

                return [pscustomobject]@{ Exit = $exit; Output = $content }
            } finally { Pop-Location }
        } finally {
            Remove-Item -Recurse -Force $tmp.FullName -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Workflow structure' {
    It 'is valid YAML with expected triggers and jobs' {
        Test-Path $script:Workflow | Should -Be $true
        $text = Get-Content -Raw $script:Workflow
        $text | Should -Match 'on:'
        $text | Should -Match 'push:'
        $text | Should -Match 'workflow_dispatch:'
        $text | Should -Match 'schedule:'
        $text | Should -Match 'jobs:'
        $text | Should -Match 'test:'
        $text | Should -Match 'cleanup:'
        $text | Should -Match 'needs: test'
    }

    It 'references script files that exist' {
        (Get-Content -Raw $script:Workflow) | Should -Match 'Invoke-Cleanup\.ps1'
        (Get-Content -Raw $script:Workflow) | Should -Match 'Cleanup\.Tests\.ps1'
        Test-Path (Join-Path $script:Root 'Invoke-Cleanup.ps1')  | Should -Be $true
        Test-Path (Join-Path $script:Root 'Cleanup.Tests.ps1')   | Should -Be $true
        Test-Path (Join-Path $script:Root 'fixtures/default.json') | Should -Be $true
    }

    It 'passes actionlint with exit code 0' {
        & actionlint $script:Workflow
        $LASTEXITCODE | Should -Be 0
    }
}

Describe 'End-to-end via act' {
    It 'Case 1 — combined policy reports deleted=3 retained=2 reclaimed=600' {
        $fx = Get-Content -Raw (Join-Path $script:Root 'fixtures/default.json')
        $r = Invoke-ActCase -Name 'combined' -FixtureJson $fx -DryRun 'true'
        $r.Exit | Should -Be 0
        $r.Output | Should -Match 'SUMMARY deleted=3 retained=2 reclaimed=600 failed=0 dry_run=true'
        $r.Output | Should -Match 'Job succeeded'
        ($r.Output | Select-String -Pattern 'Job succeeded' -AllMatches).Matches.Count |
            Should -BeGreaterOrEqual 2
    }

    It 'Case 2 — size-only policy keeps newest two' {
        $fx = Get-Content -Raw (Join-Path $script:Root 'fixtures/size-only.json')
        $r = Invoke-ActCase -Name 'size-only' -FixtureJson $fx -DryRun 'true'
        $r.Exit | Should -Be 0
        $r.Output | Should -Match 'SUMMARY deleted=1 retained=2 reclaimed=500 failed=0 dry_run=true'
        $r.Output | Should -Match 'Job succeeded'
    }
}

AfterAll {
    Test-Path $script:ActOutput | Should -Be $true
}
