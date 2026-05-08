# Pester tests for the semantic version bumper.
# Tests follow the red/green TDD cycle: each Describe block was written
# before the corresponding function existed, then minimum code added to
# make it pass.

BeforeAll {
    # Dot-source the script so its functions are available without
    # triggering the main entry block.
    . $PSScriptRoot/Bump-Version.ps1
}

Describe 'Get-BumpType' {
    It 'returns major for "!" breaking marker' {
        Get-BumpType -Commits @('feat!: drop python 2 support') | Should -Be 'major'
    }
    It 'returns major for BREAKING CHANGE footer' {
        Get-BumpType -Commits @("feat: x`n`nBREAKING CHANGE: removed Y") | Should -Be 'major'
    }
    It 'returns minor for feat' {
        Get-BumpType -Commits @('feat: add foo') | Should -Be 'minor'
    }
    It 'returns minor for scoped feat' {
        Get-BumpType -Commits @('feat(api): add endpoint') | Should -Be 'minor'
    }
    It 'returns patch for fix' {
        Get-BumpType -Commits @('fix: bug') | Should -Be 'patch'
    }
    It 'returns none for chore-only' {
        Get-BumpType -Commits @('chore: deps', 'docs: readme') | Should -Be 'none'
    }
    It 'picks highest precedence (feat over fix)' {
        Get-BumpType -Commits @('fix: a', 'feat: b') | Should -Be 'minor'
    }
    It 'picks highest precedence (breaking over feat)' {
        Get-BumpType -Commits @('feat: a', 'fix!: b') | Should -Be 'major'
    }
}

Describe 'Get-NextVersion' {
    It 'bumps major' { Get-NextVersion -Current '1.2.3' -BumpType 'major' | Should -Be '2.0.0' }
    It 'bumps minor' { Get-NextVersion -Current '1.2.3' -BumpType 'minor' | Should -Be '1.3.0' }
    It 'bumps patch' { Get-NextVersion -Current '1.2.3' -BumpType 'patch' | Should -Be '1.2.4' }
    It 'no bump returns current' { Get-NextVersion -Current '1.2.3' -BumpType 'none' | Should -Be '1.2.3' }
    It 'rejects non-semver' { { Get-NextVersion -Current 'abc' -BumpType 'patch' } | Should -Throw -ExpectedMessage '*semver*' }
}

Describe 'Get-CurrentVersion' {
    It 'reads version from a package.json' {
        $f = Join-Path $TestDrive 'package.json'
        Set-Content $f -Value '{"name":"x","version":"1.2.3"}'
        Get-CurrentVersion -Path $f | Should -Be '1.2.3'
    }
    It 'reads from a plain VERSION file' {
        $f = Join-Path $TestDrive 'VERSION'
        Set-Content $f -Value '0.5.7'
        Get-CurrentVersion -Path $f | Should -Be '0.5.7'
    }
    It 'throws on missing file' {
        { Get-CurrentVersion -Path (Join-Path $TestDrive 'nope.txt') } | Should -Throw -ExpectedMessage '*not found*'
    }
    It 'throws on package.json missing version' {
        $f = Join-Path $TestDrive 'noversion.json'
        Set-Content $f -Value '{"name":"x"}'
        { Get-CurrentVersion -Path $f } | Should -Throw -ExpectedMessage "*version*"
    }
}

Describe 'Read-Commits' {
    It 'splits commits on --- delimiter' {
        $f = Join-Path $TestDrive 'commits.txt'
        Set-Content $f -Value "feat: a`n---`nfix: b`n---`nchore: c"
        $c = Read-Commits -Path $f
        $c.Count | Should -Be 3
        $c[0] | Should -Be 'feat: a'
        $c[1] | Should -Be 'fix: b'
    }
}

Describe 'New-ChangelogEntry' {
    It 'groups commits by type' {
        $entry = New-ChangelogEntry -Version '1.2.0' -Commits @('feat: a', 'fix: b', 'feat!: c') -Date '2026-05-08'
        $entry | Should -Match '## 1.2.0 - 2026-05-08'
        $entry | Should -Match '### BREAKING CHANGES'
        $entry | Should -Match '### Features'
        $entry | Should -Match '### Fixes'
    }
}

Describe 'Invoke-VersionBump (integration)' {
    It 'bumps package.json minor for feat commit and writes changelog' {
        $vfile = Join-Path $TestDrive 'package.json'
        Set-Content $vfile -Value '{"name":"x","version":"1.1.0"}'
        $cfile = Join-Path $TestDrive 'commits.txt'
        Set-Content $cfile -Value "feat: add login`n---`nfix: typo"
        $cl = Join-Path $TestDrive 'CHANGELOG.md'

        $r = Invoke-VersionBump -VersionFile $vfile -CommitsFile $cfile -ChangelogFile $cl

        $r.NewVersion | Should -Be '1.2.0'
        $r.BumpType   | Should -Be 'minor'
        $r.OldVersion | Should -Be '1.1.0'
        (Get-Content $vfile -Raw) | Should -Match '"version":\s*"1.2.0"'
        (Get-Content $cl -Raw) | Should -Match '## 1.2.0'
    }
    It 'major bump for breaking change' {
        $vfile = Join-Path $TestDrive 'pkg2.json'
        Set-Content $vfile -Value '{"name":"x","version":"1.0.0"}'
        $cfile = Join-Path $TestDrive 'c2.txt'
        Set-Content $cfile -Value "feat!: redesign"
        $cl = Join-Path $TestDrive 'C2.md'

        $r = Invoke-VersionBump -VersionFile $vfile -CommitsFile $cfile -ChangelogFile $cl
        $r.NewVersion | Should -Be '2.0.0'
        $r.BumpType   | Should -Be 'major'
    }
    It 'no-op when only chore commits' {
        $vfile = Join-Path $TestDrive 'pkg3.json'
        Set-Content $vfile -Value '{"name":"x","version":"3.4.5"}'
        $cfile = Join-Path $TestDrive 'c3.txt'
        Set-Content $cfile -Value "chore: deps"
        $cl = Join-Path $TestDrive 'C3.md'

        $r = Invoke-VersionBump -VersionFile $vfile -CommitsFile $cfile -ChangelogFile $cl
        $r.NewVersion | Should -Be '3.4.5'
        $r.BumpType   | Should -Be 'none'
    }
}
