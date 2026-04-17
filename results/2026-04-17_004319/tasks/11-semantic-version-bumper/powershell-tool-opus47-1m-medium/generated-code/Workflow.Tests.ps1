# Workflow.Tests.ps1
# Pester tests that drive the GitHub Actions workflow via `act`, plus structural checks.
# Per the benchmark rules, every pipeline test runs in a real act container.

BeforeAll {
    $script:Root       = Split-Path -Parent $PSCommandPath
    $script:Workflow   = Join-Path $script:Root '.github/workflows/semantic-version-bumper.yml'
    $script:ActLog     = Join-Path $script:Root 'act-result.txt'
    # Reset the log at the start of a run.
    Set-Content -Path $script:ActLog -Value "act-result.txt - generated $(Get-Date -Format o)`n" -NoNewline
}

Describe 'Workflow structure' {
    It 'workflow file exists' {
        Test-Path $script:Workflow | Should -BeTrue
    }

    It 'passes actionlint' {
        $out = & actionlint $script:Workflow 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ("actionlint output: " + ($out -join "`n"))
    }

    It 'references existing script files' {
        $yaml = Get-Content -Path $script:Workflow -Raw
        $yaml | Should -Match 'bump-version\.ps1'
        Test-Path (Join-Path $script:Root 'bump-version.ps1') | Should -BeTrue
        Test-Path (Join-Path $script:Root 'SemanticVersionBumper.psm1') | Should -BeTrue
        Test-Path (Join-Path $script:Root 'SemanticVersionBumper.Tests.ps1') | Should -BeTrue
    }

    It 'declares expected triggers and jobs' {
        $yaml = Get-Content -Path $script:Workflow -Raw
        $yaml | Should -Match '(?m)^on:'
        $yaml | Should -Match 'push:'
        $yaml | Should -Match 'pull_request'
        $yaml | Should -Match 'workflow_dispatch'
        $yaml | Should -Match 'jobs:'
        $yaml | Should -Match '(?m)^\s{2}test:'
        $yaml | Should -Match '(?m)^\s{2}bump:'
        $yaml | Should -Match 'actions/checkout@v4'
    }
}

$script:ActCases = @(
    @{ Name='feat';     Fixture='fixtures/commits-feat.txt';     Start='1.1.0'; Expected='1.2.0'; Bump='minor' }
    @{ Name='fix';      Fixture='fixtures/commits-fix.txt';      Start='1.1.0'; Expected='1.1.1'; Bump='patch' }
    @{ Name='breaking'; Fixture='fixtures/commits-breaking.txt'; Start='1.1.0'; Expected='2.0.0'; Bump='major' }
)

Describe 'Workflow execution via act' -Tag 'act' {
    It 'bumps correctly for <Name> (<Start> -> <Expected>)' -ForEach $script:ActCases {
        $case = @{ Name=$Name; Fixture=$Fixture; Start=$Start; Expected=$Expected; Bump=$Bump }
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("svb-act-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            # Copy project files into the temp dir so act has an isolated repo.
            Copy-Item -Recurse -Path (Join-Path $script:Root '.github')    -Destination $tmp
            Copy-Item -Recurse -Path (Join-Path $script:Root 'fixtures')   -Destination $tmp
            Copy-Item -Path (Join-Path $script:Root 'SemanticVersionBumper.psm1')       -Destination $tmp
            Copy-Item -Path (Join-Path $script:Root 'SemanticVersionBumper.Tests.ps1')  -Destination $tmp
            Copy-Item -Path (Join-Path $script:Root 'bump-version.ps1')                 -Destination $tmp
            Copy-Item -Path (Join-Path $script:Root '.actrc')                           -Destination $tmp
            Set-Content -Path (Join-Path $tmp 'VERSION') -Value $case.Start -NoNewline

            # Per-case workflow env override: write .env used by act
            $actEnv = "COMMITS_FILE=$($case.Fixture)`nVERSION_FILE=VERSION`n"
            Set-Content -Path (Join-Path $tmp '.env') -Value $actEnv -NoNewline

            # Init a temp git repo so checkout inside act container works with local mount.
            Push-Location $tmp
            try {
                & git init -q
                & git -c user.email=t@t -c user.name=test add -A
                & git -c user.email=t@t -c user.name=test commit -q -m "case $($case.Name)" | Out-Null

                $actOut = & act push --rm --env-file .env 2>&1 | Out-String
            } finally {
                Pop-Location
            }

            # Append case output to act-result.txt with clear delimiters.
            $delim = "`n===== CASE: $($case.Name) (start=$($case.Start) expected=$($case.Expected)) =====`n"
            Add-Content -Path $script:ActLog -Value $delim
            Add-Content -Path $script:ActLog -Value $actOut
            Add-Content -Path $script:ActLog -Value "===== END CASE: $($case.Name) exit=$LASTEXITCODE =====`n"

            $LASTEXITCODE | Should -Be 0 -Because "act push failed for $($case.Name):`n$actOut"
            $actOut | Should -Match "RESULT_NEW_VERSION=$([regex]::Escape($case.Expected))"
            $actOut | Should -Match "RESULT_BUMP_TYPE=$($case.Bump)"
            $actOut | Should -Match 'Job succeeded'
            # Both jobs (test, bump) should have succeeded — count matches.
            ([regex]::Matches($actOut, 'Job succeeded')).Count | Should -BeGreaterOrEqual 2
        } finally {
            Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
        }
    }
}
