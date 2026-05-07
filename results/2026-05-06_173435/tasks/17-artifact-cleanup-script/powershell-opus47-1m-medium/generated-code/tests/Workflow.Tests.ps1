#Requires -Module Pester

# End-to-end pipeline tests. Each Pester test case runs the workflow inside a
# disposable temp git repo via `act push --rm`, captures the output, and asserts
# on exact expected lines emitted by Invoke-Cleanup.ps1. All output is appended
# to act-result.txt in the project root.

BeforeAll {
    $script:ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:ResultLog   = Join-Path $script:ProjectRoot 'act-result.txt'
    if (Test-Path $script:ResultLog) { Remove-Item -LiteralPath $script:ResultLog -Force }

    function script:Invoke-ActCase {
        param(
            [string]$Label,
            [string]$Fixture,
            [int]$MaxAge = 0,
            [long]$MaxSize = 0,
            [int]$Keep = 0,
            [bool]$DryRun = $false
        )

        # Build a fresh temp repo with the project files + the per-case .ci-case.txt
        # so this run is hermetic.
        $work = Join-Path ([System.IO.Path]::GetTempPath()) ("act-cleanup-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $work | Out-Null
        Copy-Item -Path (Join-Path $script:ProjectRoot '*') -Destination $work -Recurse -Force
        Copy-Item -Path (Join-Path $script:ProjectRoot '.github') -Destination $work -Recurse -Force
        if (Test-Path (Join-Path $script:ProjectRoot '.actrc')) {
            Copy-Item -Path (Join-Path $script:ProjectRoot '.actrc') -Destination $work -Force
        }
        $caseLine = "$Fixture|$MaxAge|$MaxSize|$Keep|$([string]$DryRun.ToString().ToLower())"
        Set-Content -Path (Join-Path $work '.ci-case.txt') -Value $caseLine -Encoding utf8

        Push-Location $work
        try {
            git init -q
            git config user.email t@t.t
            git config user.name t
            git add -A | Out-Null
            git commit -qm "case $Label" | Out-Null
            $output = & act push --rm 2>&1 | Out-String
            $exit   = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        $banner = "===== CASE: $Label (exit=$exit) ====="
        Add-Content -LiteralPath $script:ResultLog -Value $banner
        Add-Content -LiteralPath $script:ResultLog -Value $output
        Add-Content -LiteralPath $script:ResultLog -Value ""

        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        [pscustomobject]@{ Output = $output; ExitCode = $exit }
    }
}

Describe 'Workflow structure' {
    It 'YAML parses and declares expected triggers and jobs' {
        $yamlPath = Join-Path $script:ProjectRoot '.github/workflows/artifact-cleanup-script.yml'
        Test-Path $yamlPath | Should -BeTrue
        $text = Get-Content -LiteralPath $yamlPath -Raw
        $text | Should -Match 'on:'
        $text | Should -Match 'push:'
        $text | Should -Match 'pull_request:'
        $text | Should -Match 'workflow_dispatch:'
        $text | Should -Match 'schedule:'
        $text | Should -Match 'cleanup:'
        $text | Should -Match 'shell: pwsh'
    }

    It 'references script files that exist' {
        Test-Path (Join-Path $script:ProjectRoot 'Invoke-Cleanup.ps1') | Should -BeTrue
        Test-Path (Join-Path $script:ProjectRoot 'ArtifactCleanup.psm1') | Should -BeTrue
        Test-Path (Join-Path $script:ProjectRoot 'fixtures/case1-max-age.json') | Should -BeTrue
        Test-Path (Join-Path $script:ProjectRoot 'fixtures/case2-keep-latest.json') | Should -BeTrue
        Test-Path (Join-Path $script:ProjectRoot 'fixtures/case3-dry-run-combined.json') | Should -BeTrue
    }

    It 'passes actionlint' {
        Push-Location $script:ProjectRoot
        try {
            & actionlint '.github/workflows/artifact-cleanup-script.yml' 2>&1 | Out-Null
            $LASTEXITCODE | Should -Be 0
        } finally { Pop-Location }
    }
}

Describe 'Pipeline runs (act)' {
    It 'case1 max-age: deletes 1, retains 1, reclaims 1000' {
        $r = Invoke-ActCase -Label 'case1' -Fixture 'case1-max-age.json' -MaxAge 30 -DryRun $false
        $r.ExitCode | Should -Be 0
        $r.Output   | Should -Match 'DRY_RUN=False'
        $r.Output   | Should -Match 'DELETED_COUNT=1'
        $r.Output   | Should -Match 'RETAINED_COUNT=1'
        $r.Output   | Should -Match 'SPACE_RECLAIMED=1000'
        $r.Output   | Should -Match 'DELETE_NAMES=old\.zip'
        $r.Output   | Should -Match 'RETAIN_NAMES=fresh\.zip'
        $r.Output   | Should -Match 'ACTUALLY_DELETED=old\.zip'
        $r.Output   | Should -Match 'Job succeeded'
    }

    It 'case2 keep-latest-per-workflow: keeps newest of each workflow' {
        $r = Invoke-ActCase -Label 'case2' -Fixture 'case2-keep-latest.json' -Keep 1 -DryRun $false
        $r.ExitCode | Should -Be 0
        $r.Output   | Should -Match 'DELETED_COUNT=1'
        $r.Output   | Should -Match 'RETAINED_COUNT=2'
        $r.Output   | Should -Match 'SPACE_RECLAIMED=100'
        $r.Output   | Should -Match 'DELETE_NAMES=a\.zip'
        $r.Output   | Should -Match 'RETAIN_NAMES=b\.zip,c\.zip'
        $r.Output   | Should -Match 'ACTUALLY_DELETED=a\.zip'
        $r.Output   | Should -Match 'Job succeeded'
    }

    It 'case3 combined+dry-run: deletes nothing for real but plans 2' {
        $r = Invoke-ActCase -Label 'case3' -Fixture 'case3-dry-run-combined.json' -MaxAge 30 -Keep 1 -DryRun $true
        $r.ExitCode | Should -Be 0
        $r.Output   | Should -Match 'DRY_RUN=True'
        $r.Output   | Should -Match 'DELETED_COUNT=2'
        $r.Output   | Should -Match 'RETAINED_COUNT=1'
        $r.Output   | Should -Match 'SPACE_RECLAIMED=300'
        $r.Output   | Should -Match 'DELETE_NAMES=old\.zip,recent1\.zip'
        $r.Output   | Should -Match 'RETAIN_NAMES=recent2\.zip'
        # Dry-run: deleter should never run, so ACTUALLY_DELETED line is empty.
        $r.Output   | Should -Match 'ACTUALLY_DELETED=\s'
        $r.Output   | Should -Match 'Job succeeded'
    }
}
