# VersionBumper.Tests.ps1 - Pester tests for semantic version bumper
# TDD: These tests were written FIRST, before the implementation.
# Each Describe block covers a distinct function in VersionBumper.ps1.

BeforeAll {
    . "$PSScriptRoot/VersionBumper.ps1"
}

Describe 'Get-CurrentVersion' {
    Context 'VERSION file parsing' {
        It 'parses a simple semver string' {
            $f = Join-Path $TestDrive 'VERSION'
            Set-Content $f '1.2.3'
            $v = Get-CurrentVersion -FilePath $f
            $v.Major | Should -Be 1
            $v.Minor | Should -Be 2
            $v.Patch | Should -Be 3
        }

        It 'handles v-prefix' {
            $f = Join-Path $TestDrive 'VERSION'
            Set-Content $f 'v2.0.1'
            $v = Get-CurrentVersion -FilePath $f
            $v.Major | Should -Be 2
            $v.Minor | Should -Be 0
            $v.Patch | Should -Be 1
        }

        It 'trims surrounding whitespace' {
            $f = Join-Path $TestDrive 'VERSION'
            Set-Content $f "  3.1.4  `n"
            $v = Get-CurrentVersion -FilePath $f
            $v.Major | Should -Be 3
            $v.Minor | Should -Be 1
            $v.Patch | Should -Be 4
        }

        It 'throws on missing file' {
            { Get-CurrentVersion -FilePath '/nonexistent/VERSION' } |
                Should -Throw '*not found*'
        }

        It 'throws on invalid version format' {
            $f = Join-Path $TestDrive 'VERSION'
            Set-Content $f 'not-a-version'
            { Get-CurrentVersion -FilePath $f } |
                Should -Throw '*Invalid semantic version*'
        }
    }

    Context 'package.json parsing' {
        It 'parses version from package.json' {
            $f = Join-Path $TestDrive 'package.json'
            @{ name = 'test-pkg'; version = '4.5.6' } |
                ConvertTo-Json | Set-Content $f
            $v = Get-CurrentVersion -FilePath $f
            $v.Major | Should -Be 4
            $v.Minor | Should -Be 5
            $v.Patch | Should -Be 6
        }

        It 'throws when version field is missing' {
            $f = Join-Path $TestDrive 'package.json'
            @{ name = 'no-version' } | ConvertTo-Json | Set-Content $f
            { Get-CurrentVersion -FilePath $f } |
                Should -Throw "*No 'version' field*"
        }
    }
}

Describe 'Get-BumpType' {
    It 'returns patch for fix-only commits' {
        Get-BumpType -CommitMessages @(
            'fix: correct null reference in user validation',
            'fix: handle edge case in date parsing'
        ) | Should -Be 'patch'
    }

    It 'returns minor when feat commits are present' {
        Get-BumpType -CommitMessages @(
            'feat: add user profile avatar support',
            'fix: resolve login timeout issue'
        ) | Should -Be 'minor'
    }

    It 'returns major for bang-syntax breaking changes' {
        Get-BumpType -CommitMessages @(
            'feat!: redesign authentication API',
            'fix: patch security vulnerability'
        ) | Should -Be 'major'
    }

    It 'returns major for BREAKING CHANGE keyword' {
        Get-BumpType -CommitMessages @(
            'refactor: overhaul config BREAKING CHANGE: new format',
            'fix: minor typo'
        ) | Should -Be 'major'
    }

    It 'returns patch for non-conventional commits' {
        Get-BumpType -CommitMessages @(
            'update readme',
            'docs: add API documentation'
        ) | Should -Be 'patch'
    }

    It 'handles scoped conventional commits' {
        Get-BumpType -CommitMessages @(
            'feat(auth): add OAuth2 support',
            'fix(db): resolve connection pooling'
        ) | Should -Be 'minor'
    }
}

Describe 'Invoke-VersionBump' {
    It 'bumps patch version' {
        $v = @{ Major = 1; Minor = 2; Patch = 3 }
        Invoke-VersionBump -CurrentVersion $v -BumpType 'patch' |
            Should -Be '1.2.4'
    }

    It 'bumps minor and resets patch' {
        $v = @{ Major = 1; Minor = 2; Patch = 3 }
        Invoke-VersionBump -CurrentVersion $v -BumpType 'minor' |
            Should -Be '1.3.0'
    }

    It 'bumps major and resets minor+patch' {
        $v = @{ Major = 1; Minor = 2; Patch = 3 }
        Invoke-VersionBump -CurrentVersion $v -BumpType 'major' |
            Should -Be '2.0.0'
    }

    It 'handles 0.0.0' {
        $v = @{ Major = 0; Minor = 0; Patch = 0 }
        Invoke-VersionBump -CurrentVersion $v -BumpType 'patch' |
            Should -Be '0.0.1'
    }

    It 'handles large version numbers' {
        $v = @{ Major = 99; Minor = 99; Patch = 99 }
        Invoke-VersionBump -CurrentVersion $v -BumpType 'major' |
            Should -Be '100.0.0'
    }
}

Describe 'New-ChangelogEntry' {
    It 'generates entry with features and fixes sections' {
        $entry = New-ChangelogEntry -NewVersion '2.1.0' -CommitMessages @(
            'feat: add dark mode',
            'fix: resolve crash on startup'
        )
        $entry | Should -Match '## \[2\.1\.0\]'
        $entry | Should -Match '### Features'
        $entry | Should -Match '### Bug Fixes'
        $entry | Should -Match 'add dark mode'
        $entry | Should -Match 'resolve crash on startup'
    }

    It 'includes breaking changes section' {
        $entry = New-ChangelogEntry -NewVersion '3.0.0' -CommitMessages @(
            'feat!: new API format',
            'feat: add endpoint'
        )
        $entry | Should -Match '### Breaking Changes'
        $entry | Should -Match 'new API format'
    }

    It 'includes today''s date' {
        $today = Get-Date -Format 'yyyy-MM-dd'
        $entry = New-ChangelogEntry -NewVersion '1.0.1' -CommitMessages @('fix: bug')
        $entry | Should -Match $today
    }
}

Describe 'Update-VersionFile' {
    It 'writes new version to VERSION file' {
        $f = Join-Path $TestDrive 'VERSION'
        Set-Content $f '1.0.0'
        Update-VersionFile -FilePath $f -NewVersion '1.1.0'
        (Get-Content $f -Raw) | Should -Be '1.1.0'
    }

    It 'updates version in package.json' {
        $f = Join-Path $TestDrive 'package.json'
        @{ name = 'test'; version = '1.0.0' } |
            ConvertTo-Json | Set-Content $f
        Update-VersionFile -FilePath $f -NewVersion '2.0.0'
        $json = Get-Content $f -Raw | ConvertFrom-Json
        $json.version | Should -Be '2.0.0'
    }
}

Describe 'Get-CommitMessages' {
    It 'reads from fixture file and skips blank lines' {
        $f = Join-Path $TestDrive 'commits.txt'
        @('feat: add feature', 'fix: bug fix', '') | Set-Content $f
        $msgs = Get-CommitMessages -CommitLogFile $f
        $msgs.Count | Should -Be 2
        $msgs[0] | Should -Be 'feat: add feature'
    }
}

Describe 'End-to-End: fixture-based version bumping' {
    BeforeAll {
        $fixtureDir = "$PSScriptRoot/fixtures"
    }

    It 'patch bump: fix commits bump 1.2.3 -> 1.2.4' {
        $f = Join-Path $TestDrive 'VERSION'
        Set-Content $f '1.2.3'
        $ver  = Get-CurrentVersion -FilePath $f
        $msgs = Get-CommitMessages -CommitLogFile "$fixtureDir/patch-commits.txt"
        $bump = Get-BumpType -CommitMessages $msgs
        $new  = Invoke-VersionBump -CurrentVersion $ver -BumpType $bump
        $bump | Should -Be 'patch'
        $new  | Should -Be '1.2.4'
    }

    It 'minor bump: feat commits bump 1.0.0 -> 1.1.0' {
        $f = Join-Path $TestDrive 'VERSION'
        Set-Content $f '1.0.0'
        $ver  = Get-CurrentVersion -FilePath $f
        $msgs = Get-CommitMessages -CommitLogFile "$fixtureDir/minor-commits.txt"
        $bump = Get-BumpType -CommitMessages $msgs
        $new  = Invoke-VersionBump -CurrentVersion $ver -BumpType $bump
        $bump | Should -Be 'minor'
        $new  | Should -Be '1.1.0'
    }

    It 'major bump: breaking changes bump 2.1.0 -> 3.0.0' {
        $f = Join-Path $TestDrive 'VERSION'
        Set-Content $f '2.1.0'
        $ver  = Get-CurrentVersion -FilePath $f
        $msgs = Get-CommitMessages -CommitLogFile "$fixtureDir/major-commits.txt"
        $bump = Get-BumpType -CommitMessages $msgs
        $new  = Invoke-VersionBump -CurrentVersion $ver -BumpType $bump
        $bump | Should -Be 'major'
        $new  | Should -Be '3.0.0'
    }
}
