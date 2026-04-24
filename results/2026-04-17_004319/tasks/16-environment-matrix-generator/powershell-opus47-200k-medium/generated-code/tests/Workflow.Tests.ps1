# Workflow structure tests + end-to-end act harness.
#
# Structure tests parse the YAML and verify the triggers, jobs, steps, and
# script references. The act harness spins up a temp git repo for each
# fixture, runs `act push --rm`, and asserts exact expected values parsed
# out of the captured output.

BeforeAll {
    $script:Root           = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:WorkflowPath   = Join-Path $script:Root '.github/workflows/environment-matrix-generator.yml'
    $script:ActResultFile  = Join-Path $script:Root 'act-result.txt'

    # Start fresh so the artifact only contains this run's output.
    if (Test-Path $script:ActResultFile) { Remove-Item $script:ActResultFile -Force }
    Set-Content -LiteralPath $script:ActResultFile -Value ''

    function Get-WorkflowYaml {
        # Minimal YAML parse — we only need top-level keys and specific strings.
        Get-Content -LiteralPath $script:WorkflowPath -Raw
    }

    function Invoke-ActCase {
        param(
            [Parameter(Mandatory)] [string]$CaseName,
            [Parameter(Mandatory)] [string]$FixturePath,
            [switch]$ExpectFailure
        )
        # Build an isolated temp git repo containing the project files plus the
        # case's config.json, then run `act push --rm`.
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ("matrix-act-{0}-{1}" -f $CaseName, ([guid]::NewGuid().ToString('N').Substring(0,8)))
        New-Item -ItemType Directory -Path $tmp | Out-Null

        # Copy project files
        Copy-Item -Path (Join-Path $script:Root 'src')        -Destination (Join-Path $tmp 'src')        -Recurse
        Copy-Item -Path (Join-Path $script:Root 'tests')      -Destination (Join-Path $tmp 'tests')      -Recurse
        Copy-Item -Path (Join-Path $script:Root 'fixtures')   -Destination (Join-Path $tmp 'fixtures')   -Recurse
        New-Item -ItemType Directory -Path (Join-Path $tmp '.github/workflows') -Force | Out-Null
        Copy-Item -Path $script:WorkflowPath -Destination (Join-Path $tmp '.github/workflows/environment-matrix-generator.yml')
        Copy-Item -Path (Join-Path $script:Root '.actrc') -Destination (Join-Path $tmp '.actrc')

        # Do NOT copy the workflow-test harness — it would run Pester-recursively inside act.
        Remove-Item (Join-Path $tmp 'tests/Workflow.Tests.ps1') -Force -ErrorAction Ignore

        # Case-specific: config.json + optional expect-failure.marker
        Copy-Item -Path $FixturePath -Destination (Join-Path $tmp 'config.json')
        if ($ExpectFailure) {
            Set-Content -LiteralPath (Join-Path $tmp 'expect-failure.marker') -Value 'yes'
        }

        Push-Location $tmp
        try {
            git init -q 2>&1 | Out-Null
            git -c user.email=t@t -c user.name=t add -A 2>&1 | Out-Null
            git -c user.email=t@t -c user.name=t commit -q -m "case $CaseName" 2>&1 | Out-Null

            $out = act push --rm --pull=false 2>&1 | Out-String
            $exit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        # Append to shared act-result.txt
        $delim = "`n===== CASE: $CaseName (exit=$exit) =====`n"
        Add-Content -LiteralPath $script:ActResultFile -Value $delim
        Add-Content -LiteralPath $script:ActResultFile -Value $out

        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue

        return [pscustomobject]@{ Output = $out; ExitCode = $exit }
    }
}

Describe 'Workflow structure' {
    It 'exists at the required path' {
        Test-Path $script:WorkflowPath | Should -Be $true
    }

    It 'declares push, pull_request, and workflow_dispatch triggers' {
        $y = Get-WorkflowYaml
        $y | Should -Match 'on:'
        $y | Should -Match 'push:'
        $y | Should -Match 'pull_request:'
        $y | Should -Match 'workflow_dispatch:'
    }

    It 'defines pester-tests and generate-matrix jobs' {
        $y = Get-WorkflowYaml
        $y | Should -Match 'pester-tests:'
        $y | Should -Match 'generate-matrix:'
        $y | Should -Match 'needs: pester-tests'
    }

    It 'uses actions/checkout@v4 and shell: pwsh' {
        $y = Get-WorkflowYaml
        $y | Should -Match 'actions/checkout@v4'
        $y | Should -Match 'shell: pwsh'
    }

    It 'references src/Generate-Matrix.ps1 and the file exists' {
        $y = Get-WorkflowYaml
        $y | Should -Match 'src/Generate-Matrix.ps1'
        Test-Path (Join-Path $script:Root 'src/Generate-Matrix.ps1') | Should -Be $true
    }

    It 'passes actionlint cleanly' {
        $out = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($out -join "`n")
    }
}

Describe 'act end-to-end: basic fixture (2x2 matrix)' {
    It 'runs the workflow successfully and emits 4-entry matrix' {
        $r = Invoke-ActCase -CaseName 'basic' -FixturePath (Join-Path $script:Root 'fixtures/basic.json')
        $r.ExitCode | Should -Be 0 -Because $r.Output

        # Every job must have succeeded
        ($r.Output -split "`n" | Where-Object { $_ -match 'Job succeeded' }).Count | Should -BeGreaterOrEqual 2

        # Exact-value assertions
        $r.Output | Should -Match 'MATRIX_ENTRIES:4'
        $r.Output | Should -Match 'MATRIX_FAILFAST:True'
        $r.Output | Should -Match 'MATRIX_MAXPARALLEL:4'

        # Verify JSON body contains expected os/node pairs
        $r.Output | Should -Match 'ubuntu-latest'
        $r.Output | Should -Match 'windows-latest'
    }
}

Describe 'act end-to-end: with-rules fixture (include + exclude)' {
    It 'applies exclude and include rules and emits 6-entry matrix' {
        # axes: 3 os * 2 node = 6; exclude macos+18 -> 5; include (u,20)=merge, (u,21)=new -> 6
        $r = Invoke-ActCase -CaseName 'with-rules' -FixturePath (Join-Path $script:Root 'fixtures/with-rules.json')
        $r.ExitCode | Should -Be 0 -Because $r.Output

        ($r.Output -split "`n" | Where-Object { $_ -match 'Job succeeded' }).Count | Should -BeGreaterOrEqual 2

        $r.Output | Should -Match 'MATRIX_ENTRIES:6'
        $r.Output | Should -Match 'MATRIX_FAILFAST:False'
        $r.Output | Should -Match 'MATRIX_MAXPARALLEL:3'

        # Excluded combo must not appear in a way that would survive; quick check:
        # there should be a "coverage" key from the include merge
        $r.Output | Should -Match 'coverage'
        $r.Output | Should -Match 'experimental'
    }
}

Describe 'act end-to-end: oversize fixture (expected failure)' {
    It 'fails inside the generator and surfaces the MATRIX_FAILED_AS_EXPECTED marker' {
        # 3 * 3 * 2 = 18 > max-size 5
        $r = Invoke-ActCase -CaseName 'oversize' -FixturePath (Join-Path $script:Root 'fixtures/oversize.json') -ExpectFailure
        $r.ExitCode | Should -Be 0 -Because $r.Output

        ($r.Output -split "`n" | Where-Object { $_ -match 'Job succeeded' }).Count | Should -BeGreaterOrEqual 2

        $r.Output | Should -Match 'MATRIX_FAILED_AS_EXPECTED'
        $r.Output | Should -Match 'exceeds max-size'
    }
}
