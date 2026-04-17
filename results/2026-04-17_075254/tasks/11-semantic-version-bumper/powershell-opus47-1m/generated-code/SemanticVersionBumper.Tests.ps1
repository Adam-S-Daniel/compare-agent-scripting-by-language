#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
# Unit tests for SemanticVersionBumper. Written TDD-first: each Describe block
# corresponds to one piece of functionality that was added red-green-refactor.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'SemanticVersionBumper.psm1'
    Import-Module $script:ModulePath -Force
}

Describe 'Get-BumpType' {
    It 'returns none for empty commits' {
        Get-BumpType -Commits @() | Should -Be 'none'
    }
    It 'returns patch for fix commits' {
        Get-BumpType -Commits @('fix: repair thing') | Should -Be 'patch'
    }
    It 'returns minor for feat commits' {
        Get-BumpType -Commits @('feat: new thing','chore: tweak') | Should -Be 'minor'
    }
    It 'returns major for breaking change marker' {
        Get-BumpType -Commits @('feat!: breaking api') | Should -Be 'major'
    }
    It 'returns major when BREAKING CHANGE appears in body' {
        Get-BumpType -Commits @('feat: x','BREAKING CHANGE: drop v1') | Should -Be 'major'
    }
    It 'ignores non-conventional commits' {
        Get-BumpType -Commits @('random text','docs: readme') | Should -Be 'none'
    }
    It 'respects precedence major > minor > patch' {
        Get-BumpType -Commits @('fix: a','feat: b','feat!: c') | Should -Be 'major'
    }
    It 'handles scoped commits' {
        Get-BumpType -Commits @('feat(api): route') | Should -Be 'minor'
        Get-BumpType -Commits @('fix(ui): btn') | Should -Be 'patch'
    }
}

Describe 'Step-SemVer' {
    It 'bumps patch' { Step-SemVer -Version '1.2.3' -Bump 'patch' | Should -Be '1.2.4' }
    It 'bumps minor and resets patch' { Step-SemVer -Version '1.2.3' -Bump 'minor' | Should -Be '1.3.0' }
    It 'bumps major and resets minor+patch' { Step-SemVer -Version '1.2.3' -Bump 'major' | Should -Be '2.0.0' }
    It 'leaves version unchanged on none' { Step-SemVer -Version '1.2.3' -Bump 'none' | Should -Be '1.2.3' }
    It 'throws on invalid version' {
        { Step-SemVer -Version 'not-a-version' -Bump 'patch' } | Should -Throw
    }
}

Describe 'Read-VersionFile / Update-VersionFile' {
    BeforeEach {
        $script:tmp = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ("svb-" + [guid]::NewGuid()))
    }
    AfterEach {
        Remove-Item -LiteralPath $script:tmp.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
    It 'reads plain VERSION file' {
        $p = Join-Path $script:tmp.FullName 'VERSION'
        Set-Content -LiteralPath $p -Value '0.1.0'
        Read-VersionFile -Path $p | Should -Be '0.1.0'
    }
    It 'reads package.json version' {
        $p = Join-Path $script:tmp.FullName 'package.json'
        Set-Content -LiteralPath $p -Value '{ "name": "x", "version": "2.3.4" }'
        Read-VersionFile -Path $p | Should -Be '2.3.4'
    }
    It 'updates plain VERSION file' {
        $p = Join-Path $script:tmp.FullName 'VERSION'
        Set-Content -LiteralPath $p -Value '0.1.0'
        Update-VersionFile -Path $p -NewVersion '0.2.0'
        Read-VersionFile -Path $p | Should -Be '0.2.0'
    }
    It 'updates package.json while preserving other fields' {
        $p = Join-Path $script:tmp.FullName 'package.json'
        Set-Content -LiteralPath $p -Value '{ "name": "x", "version": "1.0.0", "author": "z" }'
        Update-VersionFile -Path $p -NewVersion '1.1.0'
        $j = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
        $j.version | Should -Be '1.1.0'
        $j.author  | Should -Be 'z'
    }
    It 'throws on missing file' {
        { Read-VersionFile -Path (Join-Path $script:tmp.FullName 'missing') } | Should -Throw
    }
}

Describe 'New-ChangelogEntry' {
    It 'groups features and fixes under version header' {
        $entry = New-ChangelogEntry -Version '1.1.0' -Commits @('feat: a','fix: b') -Date '2026-04-17'
        $entry | Should -Match '^## 1\.1\.0 - 2026-04-17'
        $entry | Should -Match '### Features'
        $entry | Should -Match '- a'
        $entry | Should -Match '### Fixes'
        $entry | Should -Match '- b'
    }
    It 'includes BREAKING CHANGES section' {
        $entry = New-ChangelogEntry -Version '2.0.0' -Commits @('feat!: drop x') -Date '2026-04-17'
        $entry | Should -Match '### BREAKING CHANGES'
        $entry | Should -Match '- drop x'
    }
}

Describe 'Workflow structure' {
    BeforeAll {
        $script:wfPath = Join-Path $PSScriptRoot '.github/workflows/semantic-version-bumper.yml'
        $script:wfText = Get-Content -LiteralPath $script:wfPath -Raw
    }
    It 'workflow file exists' {
        Test-Path $script:wfPath | Should -BeTrue
    }
    It 'declares push, pull_request, and workflow_dispatch triggers' {
        $script:wfText | Should -Match '(?m)^\s*push:'
        $script:wfText | Should -Match '(?m)^\s*pull_request:'
        $script:wfText | Should -Match '(?m)^\s*workflow_dispatch:'
    }
    It 'declares test and bump jobs' {
        $script:wfText | Should -Match '(?m)^\s{2}test:'
        $script:wfText | Should -Match '(?m)^\s{2}bump:'
    }
    It 'uses actions/checkout@v4' {
        $script:wfText | Should -Match 'actions/checkout@v4'
    }
    It 'references Invoke-Bumper.ps1 which exists' {
        $script:wfText | Should -Match 'Invoke-Bumper\.ps1'
        Test-Path (Join-Path $PSScriptRoot 'Invoke-Bumper.ps1') | Should -BeTrue
    }
    It 'references fixtures that exist on disk' {
        foreach ($f in @('commits-minor.txt','commits-patch.txt','commits-major.txt','commits-none.txt')) {
            Test-Path (Join-Path $PSScriptRoot "fixtures/$f") | Should -BeTrue
        }
    }
    It 'passes actionlint' {
        $al = (Get-Command actionlint -ErrorAction SilentlyContinue)
        if (-not $al) { Set-ItResult -Skipped -Because 'actionlint not installed' ; return }
        & actionlint $script:wfPath 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
}

Describe 'Invoke-VersionBump' {
    BeforeEach {
        $script:tmp = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ("svb-" + [guid]::NewGuid()))
        $script:vf = Join-Path $script:tmp.FullName 'VERSION'
        $script:cf = Join-Path $script:tmp.FullName 'commits.txt'
        $script:cl = Join-Path $script:tmp.FullName 'CHANGELOG.md'
    }
    AfterEach {
        Remove-Item -LiteralPath $script:tmp.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'performs end-to-end minor bump' {
        Set-Content -LiteralPath $script:vf -Value '1.1.0'
        Set-Content -LiteralPath $script:cf -Value "feat: add thing`nfix: repair thing"
        $r = Invoke-VersionBump -VersionFile $script:vf -CommitsFile $script:cf -ChangelogFile $script:cl
        $r.OldVersion | Should -Be '1.1.0'
        $r.NewVersion | Should -Be '1.2.0'
        $r.BumpType   | Should -Be 'minor'
        (Get-Content -LiteralPath $script:vf -Raw).Trim() | Should -Be '1.2.0'
        (Get-Content -LiteralPath $script:cl -Raw) | Should -Match '## 1\.2\.0'
    }

    It 'performs major bump on breaking' {
        Set-Content -LiteralPath $script:vf -Value '1.1.0'
        Set-Content -LiteralPath $script:cf -Value "feat!: rewrite api"
        $r = Invoke-VersionBump -VersionFile $script:vf -CommitsFile $script:cf -ChangelogFile $script:cl
        $r.NewVersion | Should -Be '2.0.0'
    }

    It 'does not bump or touch changelog when no conventional commits' {
        Set-Content -LiteralPath $script:vf -Value '1.1.0'
        Set-Content -LiteralPath $script:cf -Value "docs: readme"
        $r = Invoke-VersionBump -VersionFile $script:vf -CommitsFile $script:cf -ChangelogFile $script:cl
        $r.NewVersion | Should -Be '1.1.0'
        $r.BumpType   | Should -Be 'none'
        Test-Path $script:cl | Should -BeFalse
    }
}
