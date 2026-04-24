# Integration tests: run the workflow inside `act` for each fixture
# and assert on exact expected values. Also validates workflow structure
# and actionlint compliance.

# Defined at discovery time so -ForEach can see these cases.
$script:Cases = @(
    @{ Name = 'simple';               Fixture = 'fixtures/simple.json';               Expect = 'Matrix' },
    @{ Name = 'with-include-exclude'; Fixture = 'fixtures/with-include-exclude.json'; Expect = 'Matrix' },
    @{ Name = 'too-large';            Fixture = 'fixtures/too-large.json';            Expect = 'Error'  }
)

BeforeAll {
    $script:ProjectRoot = $PSScriptRoot
    $script:WorkflowPath = Join-Path $ProjectRoot '.github/workflows/environment-matrix-generator.yml'
    $script:ActResultFile = Join-Path $ProjectRoot 'act-result.txt'

    # Ensure we start with a clean act-result.txt that we will append to.
    if (Test-Path $script:ActResultFile) { Remove-Item $script:ActResultFile }
    New-Item -ItemType File -Path $script:ActResultFile | Out-Null

    function Invoke-ActForFixture {
        param([string]$FixturePath, [string]$CaseName)

        # Build a scratch git repo with our project, swap in the fixture, run act.
        $tmp = Join-Path ([IO.Path]::GetTempPath()) "emg-$CaseName-$([Guid]::NewGuid())"
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            # Copy project files (excluding act-result.txt and .git).
            Get-ChildItem -Path $script:ProjectRoot -Force | Where-Object {
                $_.Name -notin @('.git', 'act-result.txt')
            } | ForEach-Object {
                Copy-Item -Path $_.FullName -Destination $tmp -Recurse -Force
            }

            # Stage the active fixture for this case.
            Copy-Item -Path (Join-Path $script:ProjectRoot $FixturePath) `
                      -Destination (Join-Path $tmp 'active-fixture.json') -Force

            Push-Location $tmp
            try {
                git init -q
                git config user.email 'test@example.com'
                git config user.name 'Tester'
                git add -A
                git commit -q -m 'test' 2>&1 | Out-Null

                # --rm: remove container after run. --pull=false: use local image
                # from .actrc (act-ubuntu-pwsh is not in any public registry).
                $out = act push --rm --pull=false 2>&1 | Out-String
                $exit = $LASTEXITCODE
                return [pscustomobject]@{ Output = $out; ExitCode = $exit }
            } finally { Pop-Location }
        } finally {
            Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
        }
    }

    # Execute every case up-front and stash results. We also append to act-result.txt.
    $script:Results = @{}
    foreach ($case in $script:Cases) {
        $r = Invoke-ActForFixture -FixturePath $case.Fixture -CaseName $case.Name
        $script:Results[$case.Name] = $r
        Add-Content -Path $script:ActResultFile -Value "===== CASE: $($case.Name) (exit=$($r.ExitCode)) ====="
        Add-Content -Path $script:ActResultFile -Value $r.Output
        Add-Content -Path $script:ActResultFile -Value "===== END CASE: $($case.Name) ====="
    }
}

Describe 'Workflow structure' {
    It 'workflow file exists' {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It 'passes actionlint' {
        $null = & actionlint $script:WorkflowPath
        $LASTEXITCODE | Should -Be 0
    }

    It 'references MatrixGenerator.ps1 in the workflow' {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match 'MatrixGenerator\.ps1'
        Test-Path (Join-Path $script:ProjectRoot 'MatrixGenerator.ps1') | Should -BeTrue
    }

    It 'uses actions/checkout@v4' {
        (Get-Content $script:WorkflowPath -Raw) | Should -Match 'actions/checkout@v4'
    }

    It 'declares test and generate jobs with dependency' {
        $yaml = Get-Content $script:WorkflowPath -Raw
        $yaml | Should -Match 'jobs:'
        $yaml | Should -Match '\btest:'
        $yaml | Should -Match '\bgenerate:'
        $yaml | Should -Match 'needs:\s*test'
    }

    It 'declares at least one trigger' {
        $yaml = Get-Content $script:WorkflowPath -Raw
        $yaml | Should -Match '(?m)^on:'
        $yaml | Should -Match 'push:'
    }
}

Describe 'Act run: case <_.Name>' -ForEach $script:Cases {
    BeforeAll {
        # Re-resolve from script scope inside the Describe.
        $script:Case = $_
        $script:Result = $script:Results[$_.Name]
    }

    It 'act exited with code 0' {
        $script:Result.ExitCode | Should -Be 0
    }

    It 'runs Pester tests and reports all passing' {
        $script:Result.Output | Should -Match '===PESTER_PASSED===16==='
    }

    It 'every job reports success' {
        # act prints "Job succeeded" for each job; with needs: test,
        # we should see exactly 2 success lines (test + generate).
        $jobMatches = [regex]::Matches($script:Result.Output, 'Job succeeded')
        $jobMatches.Count | Should -BeGreaterOrEqual 2
    }
}

Describe 'Exact matrix output for simple fixture' {
    BeforeAll {
        $script:Text = $script:Results['simple'].Output
    }
    It 'contains matrix delimiters' {
        $script:Text | Should -Match '===MATRIX_START==='
        $script:Text | Should -Match '===MATRIX_END==='
    }
    It 'emits fail-fast: true' {
        $script:Text | Should -Match '"fail-fast":\s*true'
    }
    It 'emits max-parallel: 4' {
        $script:Text | Should -Match '"max-parallel":\s*4'
    }
    It 'includes both OS values' {
        $script:Text | Should -Match 'ubuntu-latest'
        $script:Text | Should -Match 'windows-latest'
    }
    It 'includes both language versions' {
        $script:Text | Should -Match '"3\.11"'
        $script:Text | Should -Match '"3\.12"'
    }
}

Describe 'Exact matrix output for include/exclude fixture' {
    BeforeAll {
        $script:Text = $script:Results['with-include-exclude'].Output
    }
    It 'emits fail-fast: false' {
        $script:Text | Should -Match '"fail-fast":\s*false'
    }
    It 'emits max-parallel: 2' {
        $script:Text | Should -Match '"max-parallel":\s*2'
    }
    It 'keeps macos-latest via include' {
        $script:Text | Should -Match 'macos-latest'
    }
    It 'records the exclude rule' {
        # Exclude stanza must name windows-latest + 3.10
        $script:Text | Should -Match '"windows-latest"'
        $script:Text | Should -Match '"3\.10"'
    }
}

Describe 'Exact matrix output for too-large fixture' {
    BeforeAll {
        $script:Text = $script:Results['too-large'].Output
    }
    It 'reports a validation error' {
        $script:Text | Should -Match '===ERROR_START==='
    }
    It 'mentions the max_size breach with exact numbers (16 > 5)' {
        # 4 x 4 = 16, max_size = 5
        $script:Text | Should -Match 'Matrix size \(16\) exceeds max_size \(5\)'
    }
}
