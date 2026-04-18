# Pester tests for SemVerBumper. Written red-green TDD style:
# each Describe block was added before the matching function existed,
# then the implementation was filled in until the test went green.

# File-scope vars are evaluated at discovery time so Skip expressions see them.
$FixtureDir = Join-Path $PSScriptRoot 'fixtures'

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'SemVerBumper.psm1'
    Import-Module $script:ModulePath -Force
    $script:FixtureDir = Join-Path $PSScriptRoot 'fixtures'
}

Describe 'Test-SemanticVersion' {
    It 'accepts valid semvers' {
        Test-SemanticVersion '0.0.0'   | Should -BeTrue
        Test-SemanticVersion '1.2.3'   | Should -BeTrue
        Test-SemanticVersion '10.20.30'| Should -BeTrue
    }
    It 'rejects invalid strings' {
        Test-SemanticVersion ''        | Should -BeFalse
        Test-SemanticVersion '1.2'     | Should -BeFalse
        Test-SemanticVersion 'v1.2.3'  | Should -BeFalse
        Test-SemanticVersion '1.2.3.4' | Should -BeFalse
    }
}

Describe 'Get-VersionFromFile' {
    It 'reads a plain VERSION file' {
        $p = Join-Path $TestDrive 'VERSION'
        Set-Content -LiteralPath $p -Value '2.5.7'
        Get-VersionFromFile -Path $p | Should -Be '2.5.7'
    }
    It 'reads package.json' {
        $p = Join-Path $TestDrive 'package.json'
        Set-Content -LiteralPath $p -Value '{ "name":"demo","version":"1.4.0"}'
        Get-VersionFromFile -Path $p | Should -Be '1.4.0'
    }
    It 'throws when file missing' {
        { Get-VersionFromFile -Path (Join-Path $TestDrive 'nope.json') } |
            Should -Throw '*not found*'
    }
}

Describe 'Get-BumpTypeFromCommits' {
    It 'returns none on empty' {
        Get-BumpTypeFromCommits @() | Should -Be 'none'
    }
    It 'detects patch for fix commits' {
        Get-BumpTypeFromCommits @('fix: correct off-by-one') | Should -Be 'patch'
    }
    It 'detects minor for feat commits' {
        Get-BumpTypeFromCommits @('feat: add thing','chore: tidy') | Should -Be 'minor'
    }
    It 'feat beats fix' {
        Get-BumpTypeFromCommits @('fix: x','feat: y') | Should -Be 'minor'
    }
    It 'detects major with !' {
        Get-BumpTypeFromCommits @('feat!: drop api v1') | Should -Be 'major'
    }
    It 'detects major with scope!' {
        Get-BumpTypeFromCommits @('refactor(core)!: rename module') | Should -Be 'major'
    }
    It 'detects major with BREAKING CHANGE footer' {
        $msg = "feat: new shape`n`nBREAKING CHANGE: shape is different"
        Get-BumpTypeFromCommits @($msg) | Should -Be 'major'
    }
    It 'ignores non-conventional commits' {
        Get-BumpTypeFromCommits @('wip','random stuff') | Should -Be 'none'
    }
}

Describe 'Step-SemanticVersion' {
    It 'bumps patch' { Step-SemanticVersion -Version '1.2.3' -Bump patch | Should -Be '1.2.4' }
    It 'bumps minor and resets patch' { Step-SemanticVersion -Version '1.2.3' -Bump minor | Should -Be '1.3.0' }
    It 'bumps major and resets minor/patch' { Step-SemanticVersion -Version '1.2.3' -Bump major | Should -Be '2.0.0' }
    It 'none leaves version' { Step-SemanticVersion -Version '1.2.3' -Bump none | Should -Be '1.2.3' }
    It 'rejects bad version' {
        { Step-SemanticVersion -Version 'abc' -Bump patch } | Should -Throw '*valid*'
    }
}

Describe 'Set-VersionInFile' {
    It 'updates package.json in place and preserves other fields' {
        $p = Join-Path $TestDrive 'pkg.json'
        Set-Content -LiteralPath $p -Value '{ "name":"a","version":"1.0.0","scripts":{}}'
        Set-VersionInFile -Path $p -Version '2.0.0'
        $raw = Get-Content -LiteralPath $p -Raw
        $raw   | Should -Match '"version":"2.0.0"'
        $raw   | Should -Match '"name":"a"'
    }
    It 'writes plain VERSION file' {
        $p = Join-Path $TestDrive 'VERSION'
        Set-Content -LiteralPath $p -Value '0.0.1'
        Set-VersionInFile -Path $p -Version '0.0.2'
        (Get-Content -LiteralPath $p -Raw).Trim() | Should -Be '0.0.2'
    }
    It 'rejects invalid' {
        $p = Join-Path $TestDrive 'v.txt'
        Set-Content -LiteralPath $p -Value '1.0.0'
        { Set-VersionInFile -Path $p -Version 'nope' } | Should -Throw
    }
}

Describe 'New-ChangelogEntry' {
    It 'renders header, features and fixes' {
        $entry = New-ChangelogEntry -Version '1.2.0' -Date '2026-04-17' `
            -Commits @('feat: add login','fix(api): handle 500','chore: whatever')
        $entry | Should -Match '## 1.2.0 - 2026-04-17'
        $entry | Should -Match '### Features'
        $entry | Should -Match '- add login'
        $entry | Should -Match '### Fixes'
        $entry | Should -Match '- handle 500'
    }
    It 'shows BREAKING CHANGES section' {
        $entry = New-ChangelogEntry -Version '2.0.0' -Date '2026-04-17' `
            -Commits @('feat!: drop v1')
        $entry | Should -Match '### BREAKING CHANGES'
    }
}

Describe 'Read-CommitFixture' {
    It 'parses a multi-commit fixture' {
        $p = Join-Path $TestDrive 'log.txt'
        @'
feat: one
---
fix: two
---
feat!: three
'@ | Set-Content -LiteralPath $p
        $c = Read-CommitFixture -Path $p
        $c.Count | Should -Be 3
        $c[0]    | Should -Be 'feat: one'
        $c[2]    | Should -Be 'feat!: three'
    }
}

Describe 'Invoke-VersionBump (end-to-end)' {
    It 'bumps minor and writes changelog' {
        $pkg = Join-Path $TestDrive 'package.json'
        Set-Content -LiteralPath $pkg -Value '{ "name":"demo","version":"1.1.0"}'
        $cl  = Join-Path $TestDrive 'CHANGELOG.md'

        $res = Invoke-VersionBump -VersionPath $pkg -ChangelogPath $cl `
            -Commits @('feat: thing','fix: other')

        $res.OldVersion | Should -Be '1.1.0'
        $res.NewVersion | Should -Be '1.2.0'
        $res.Bump       | Should -Be 'minor'
        (Get-Content -LiteralPath $pkg -Raw) | Should -Match '"version":"1.2.0"'
        (Get-Content -LiteralPath $cl  -Raw) | Should -Match '## 1.2.0'
    }
    It 'bumps major on breaking' {
        $v = Join-Path $TestDrive 'VERSION2'
        Set-Content -LiteralPath $v -Value '1.4.2'
        $r = Invoke-VersionBump -VersionPath $v -Commits @('feat!: huge')
        $r.NewVersion | Should -Be '2.0.0'
    }
    It 'no change when no conventional commits' {
        $v = Join-Path $TestDrive 'VERSION3'
        Set-Content -LiteralPath $v -Value '0.5.0'
        $r = Invoke-VersionBump -VersionPath $v -Commits @('wip random')
        $r.NewVersion | Should -Be '0.5.0'
        $r.Bump       | Should -Be 'none'
    }
}

Describe 'Fixture-based cases' {
    It 'patch fixture bumps patch' -Skip:(-not (Test-Path $FixtureDir)) {
        $commits = Read-CommitFixture -Path (Join-Path $script:FixtureDir 'commits-patch.txt')
        Get-BumpTypeFromCommits $commits | Should -Be 'patch'
    }
    It 'minor fixture bumps minor' -Skip:(-not (Test-Path $FixtureDir)) {
        $commits = Read-CommitFixture -Path (Join-Path $script:FixtureDir 'commits-minor.txt')
        Get-BumpTypeFromCommits $commits | Should -Be 'minor'
    }
    It 'major fixture bumps major' -Skip:(-not (Test-Path $FixtureDir)) {
        $commits = Read-CommitFixture -Path (Join-Path $script:FixtureDir 'commits-major.txt')
        Get-BumpTypeFromCommits $commits | Should -Be 'major'
    }
}
