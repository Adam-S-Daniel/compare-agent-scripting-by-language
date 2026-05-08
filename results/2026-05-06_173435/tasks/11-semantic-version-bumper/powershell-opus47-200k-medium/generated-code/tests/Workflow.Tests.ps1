# Workflow.Tests.ps1
#
# - Static structure checks on the YAML (triggers, jobs, steps, script paths)
# - actionlint (exit 0 required)
# - For each fixture: spin up an isolated git repo containing project files +
#   that case's package.json + commits.txt, run `act push --rm`, capture output
#   into act-result.txt (appended), and assert the EXACT expected version.

BeforeAll {
    $script:RepoRoot     = Split-Path -Parent $PSScriptRoot
    $script:WorkflowFile = Join-Path $script:RepoRoot '.github/workflows/semantic-version-bumper.yml'
    $script:ActResultFile = Join-Path $script:RepoRoot 'act-result.txt'
    if (Test-Path $script:ActResultFile) { Remove-Item $script:ActResultFile -Force }
    '' | Set-Content $script:ActResultFile  # ensure file exists from the start
}

Describe 'Workflow YAML structure' {
    BeforeAll {
        $script:wf = Get-Content $script:WorkflowFile -Raw
    }
    It 'exists' { Test-Path $script:WorkflowFile | Should -BeTrue }
    It 'declares push, pull_request, and workflow_dispatch triggers' {
        $script:wf | Should -Match '(?m)^\s*push:'
        $script:wf | Should -Match '(?m)^\s*pull_request:'
        $script:wf | Should -Match '(?m)^\s*workflow_dispatch:'
    }
    It 'uses actions/checkout@v4' {
        $script:wf | Should -Match 'actions/checkout@v4'
    }
    It 'invokes Invoke-Bump.ps1 (script file exists)' {
        $script:wf | Should -Match 'Invoke-Bump\.ps1'
        Test-Path (Join-Path $script:RepoRoot 'Invoke-Bump.ps1') | Should -BeTrue
    }
    It 'references Pester test path that exists' {
        $script:wf | Should -Match 'tests/SemanticVersionBumper\.Tests\.ps1'
        Test-Path (Join-Path $script:RepoRoot 'tests/SemanticVersionBumper.Tests.ps1') | Should -BeTrue
    }
    It 'declares permissions and uses pwsh shell' {
        $script:wf | Should -Match '(?m)^permissions:'
        $script:wf | Should -Match 'shell:\s*pwsh'
    }
}

Describe 'actionlint' {
    It 'passes with exit code 0' {
        $out = & actionlint $script:WorkflowFile 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($out -join "`n")
    }
}

Describe 'act end-to-end' {
    BeforeDiscovery {
        $cases = @(
            @{ Name='minor'; PkgVersion='1.1.0'; CommitsFixture='commits-minor.txt';
               ExpectedNew='1.2.0'; ExpectedBump='minor'; ExpectedOld='1.1.0' }
            @{ Name='major'; PkgVersion='0.9.4'; CommitsFixture='commits-major.txt';
               ExpectedNew='1.0.0'; ExpectedBump='major'; ExpectedOld='0.9.4' }
            @{ Name='patch'; PkgVersion='1.0.0'; CommitsFixture='commits-patch.txt';
               ExpectedNew='1.0.1'; ExpectedBump='patch'; ExpectedOld='1.0.0' }
        )
    }
    BeforeAll {
        $script:FixturesDir = Join-Path $PSScriptRoot 'fixtures'
    }

    It 'runs case <Name> through act and produces version <ExpectedNew>' -ForEach $cases {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("svb-act-" + [guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        try {
            # Mirror project files into the temp repo.
            Copy-Item (Join-Path $script:RepoRoot 'SemanticVersionBumper.psm1') $tmp
            Copy-Item (Join-Path $script:RepoRoot 'Invoke-Bump.ps1') $tmp
            Copy-Item (Join-Path $script:RepoRoot '.github') $tmp -Recurse
            Copy-Item (Join-Path $script:RepoRoot '.actrc') $tmp
            Copy-Item (Join-Path $script:RepoRoot 'tests') $tmp -Recurse

            # Case-specific input files.
            "{`"name`":`"demo`",`"version`":`"$PkgVersion`"}" |
                Set-Content (Join-Path $tmp 'package.json')
            Copy-Item (Join-Path $script:FixturesDir $CommitsFixture) (Join-Path $tmp 'commits.txt')

            # act needs a git repo to discover events.
            Push-Location $tmp
            git init -q
            git -c user.email=t@e -c user.name=t add -A
            git -c user.email=t@e -c user.name=t commit -q -m 'init' | Out-Null

            $out = & act push --rm 2>&1
            $exit = $LASTEXITCODE
            Pop-Location

            # Append delimited output to the required artifact.
            $delim = "`n===== CASE: $Name (exit=$exit) =====`n"
            Add-Content $script:ActResultFile $delim
            Add-Content $script:ActResultFile ($out -join "`n")

            $exit | Should -Be 0 -Because "act should succeed for case $Name"
            $joined = $out -join "`n"
            $joined | Should -Match "RESULT::${ExpectedOld}::${ExpectedBump}::${ExpectedNew}"
            $joined | Should -Match 'Job succeeded'
        } finally {
            if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
        }
    }
}
