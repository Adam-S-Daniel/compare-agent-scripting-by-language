# SemanticVersionBumper.Tests.ps1
# TDD tests for semantic version bumper functionality using Pester 5

BeforeAll {
    . "$PSScriptRoot/SemanticVersionBumper.ps1"
}

Describe 'Get-SemanticVersion' {
    It 'parses a version string from a VERSION file' {
        $versionFile = Join-Path $TestDrive 'VERSION'
        Set-Content -Path $versionFile -Value '1.2.3'
        $result = Get-SemanticVersion -Path $versionFile
        $result.Major | Should -Be 1
        $result.Minor | Should -Be 2
        $result.Patch | Should -Be 3
    }

    It 'parses a version from package.json' {
        $pkgFile = Join-Path $TestDrive 'package.json'
        Set-Content -Path $pkgFile -Value '{ "name": "myapp", "version": "2.5.10" }'
        $result = Get-SemanticVersion -Path $pkgFile
        $result.Major | Should -Be 2
        $result.Minor | Should -Be 5
        $result.Patch | Should -Be 10
    }

    It 'throws when file does not exist' {
        { Get-SemanticVersion -Path (Join-Path $TestDrive 'nonexistent') } | Should -Throw '*not found*'
    }

    It 'throws when file has no valid version' {
        $badFile = Join-Path $TestDrive 'bad.txt'
        Set-Content -Path $badFile -Value 'no version here'
        { Get-SemanticVersion -Path $badFile } | Should -Throw '*No valid semantic version*'
    }
}

Describe 'Get-BumpType' {
    It 'returns major for breaking change commits' {
        $commits = @(
            'feat!: redesign API',
            'fix: patch something'
        )
        Get-BumpType -CommitMessages $commits | Should -Be 'major'
    }

    It 'returns major for BREAKING CHANGE in commit body' {
        $commits = @(
            'feat: new feature BREAKING CHANGE: removed old API'
        )
        Get-BumpType -CommitMessages $commits | Should -Be 'major'
    }

    It 'returns minor for feat commits' {
        $commits = @(
            'feat: add new button',
            'fix: correct typo'
        )
        Get-BumpType -CommitMessages $commits | Should -Be 'minor'
    }

    It 'returns patch for fix-only commits' {
        $commits = @(
            'fix: correct typo',
            'fix: resolve null ref'
        )
        Get-BumpType -CommitMessages $commits | Should -Be 'patch'
    }

    It 'returns patch for unrecognized commit types' {
        $commits = @(
            'chore: update deps',
            'docs: add readme'
        )
        Get-BumpType -CommitMessages $commits | Should -Be 'patch'
    }

    It 'throws on empty commit list' {
        { Get-BumpType -CommitMessages @() } | Should -Throw '*No commit messages*'
    }
}

Describe 'Invoke-VersionBump' {
    It 'bumps patch version' {
        $ver = [PSCustomObject]@{ Major = 1; Minor = 2; Patch = 3 }
        $result = Invoke-VersionBump -Version $ver -BumpType 'patch'
        $result | Should -Be '1.2.4'
    }

    It 'bumps minor version and resets patch' {
        $ver = [PSCustomObject]@{ Major = 1; Minor = 2; Patch = 3 }
        $result = Invoke-VersionBump -Version $ver -BumpType 'minor'
        $result | Should -Be '1.3.0'
    }

    It 'bumps major version and resets minor and patch' {
        $ver = [PSCustomObject]@{ Major = 1; Minor = 2; Patch = 3 }
        $result = Invoke-VersionBump -Version $ver -BumpType 'major'
        $result | Should -Be '2.0.0'
    }

    It 'throws on invalid bump type' {
        $ver = [PSCustomObject]@{ Major = 1; Minor = 0; Patch = 0 }
        { Invoke-VersionBump -Version $ver -BumpType 'invalid' } | Should -Throw '*Invalid bump type*'
    }
}

Describe 'Update-VersionFile' {
    It 'updates a VERSION file with new version string' {
        $vf = Join-Path $TestDrive 'VERSION'
        Set-Content -Path $vf -Value '1.0.0'
        Update-VersionFile -Path $vf -NewVersion '1.1.0'
        (Get-Content -Path $vf -Raw).Trim() | Should -Be '1.1.0'
    }

    It 'updates version in package.json preserving structure' {
        $pf = Join-Path $TestDrive 'package.json'
        $json = @'
{
  "name": "myapp",
  "version": "1.0.0",
  "description": "test"
}
'@
        Set-Content -Path $pf -Value $json
        Update-VersionFile -Path $pf -NewVersion '1.1.0'
        $content = Get-Content -Path $pf -Raw
        $content | Should -Match '"version":\s*"1\.1\.0"'
        # Ensure other fields are preserved
        $content | Should -Match '"name":\s*"myapp"'
        $content | Should -Match '"description":\s*"test"'
    }
}

Describe 'New-ChangelogEntry' {
    It 'generates a changelog from commit messages grouped by type' {
        $commits = @(
            'feat: add login page',
            'feat: add signup flow',
            'fix: correct validation bug',
            'chore: update deps'
        )
        $entry = New-ChangelogEntry -Version '2.0.0' -CommitMessages $commits
        $entry | Should -Match '## 2\.0\.0'
        $entry | Should -Match 'Features'
        $entry | Should -Match 'add login page'
        $entry | Should -Match 'add signup flow'
        $entry | Should -Match 'Bug Fixes'
        $entry | Should -Match 'correct validation bug'
        $entry | Should -Match 'Other'
        $entry | Should -Match 'update deps'
    }

    It 'omits empty sections' {
        $commits = @('fix: only fixes here')
        $entry = New-ChangelogEntry -Version '1.0.1' -CommitMessages $commits
        $entry | Should -Not -Match 'Features'
        $entry | Should -Match 'Bug Fixes'
    }
}

Describe 'Invoke-SemanticVersionBump (integration)' {
    # Full end-to-end: read version, determine bump, write new version, generate changelog
    BeforeEach {
        $script:vFile = Join-Path $TestDrive 'VERSION'
        Set-Content -Path $script:vFile -Value '1.2.3'
        # Create mock commit log fixture
        $script:commitFile = Join-Path $TestDrive 'commits.txt'
        Set-Content -Path $script:commitFile -Value @(
            'feat: add dark mode support',
            'fix: resolve crash on startup',
            'chore: update CI config'
        )
    }

    It 'bumps version, updates file, and returns result with changelog' {
        $result = Invoke-SemanticVersionBump -VersionFilePath $script:vFile -CommitLogPath $script:commitFile
        $result.OldVersion | Should -Be '1.2.3'
        $result.NewVersion | Should -Be '1.3.0'
        $result.BumpType | Should -Be 'minor'
        $result.Changelog | Should -Match 'add dark mode support'
        # Verify file was updated
        (Get-Content -Path $script:vFile -Raw).Trim() | Should -Be '1.3.0'
    }

    It 'handles major bump from breaking change' {
        Set-Content -Path $script:commitFile -Value @(
            'feat!: redesign API completely',
            'feat: add new endpoint'
        )
        $result = Invoke-SemanticVersionBump -VersionFilePath $script:vFile -CommitLogPath $script:commitFile
        $result.NewVersion | Should -Be '2.0.0'
        $result.BumpType | Should -Be 'major'
    }

    It 'handles patch bump from fix-only commits' {
        Set-Content -Path $script:commitFile -Value @(
            'fix: null reference exception',
            'fix: off-by-one error'
        )
        $result = Invoke-SemanticVersionBump -VersionFilePath $script:vFile -CommitLogPath $script:commitFile
        $result.NewVersion | Should -Be '1.2.4'
        $result.BumpType | Should -Be 'patch'
    }

    It 'works with package.json' {
        $pkgFile = Join-Path $TestDrive 'pkg.json'
        Set-Content -Path $pkgFile -Value '{ "name": "app", "version": "3.1.4" }'
        Set-Content -Path $script:commitFile -Value @('feat: new feature')
        $result = Invoke-SemanticVersionBump -VersionFilePath $pkgFile -CommitLogPath $script:commitFile
        $result.NewVersion | Should -Be '3.2.0'
        $parsed = Get-Content -Path $pkgFile -Raw | ConvertFrom-Json
        $parsed.version | Should -Be '3.2.0'
    }
}

Describe 'Test fixtures' {
    # Verify that the mock commit log fixtures exist and are well-formed
    It 'fixture files exist in fixtures directory' {
        $fixtureDir = Join-Path $PSScriptRoot 'fixtures'
        Test-Path (Join-Path $fixtureDir 'commits-feat.txt') | Should -BeTrue
        Test-Path (Join-Path $fixtureDir 'commits-fix.txt') | Should -BeTrue
        Test-Path (Join-Path $fixtureDir 'commits-breaking.txt') | Should -BeTrue
        Test-Path (Join-Path $fixtureDir 'commits-mixed.txt') | Should -BeTrue
        Test-Path (Join-Path $fixtureDir 'VERSION') | Should -BeTrue
        Test-Path (Join-Path $fixtureDir 'package.json') | Should -BeTrue
    }

    It 'fixture commit logs produce expected bump types' {
        $fixtureDir = Join-Path $PSScriptRoot 'fixtures'

        $feat = Get-Content (Join-Path $fixtureDir 'commits-feat.txt')
        Get-BumpType -CommitMessages $feat | Should -Be 'minor'

        $fix = Get-Content (Join-Path $fixtureDir 'commits-fix.txt')
        Get-BumpType -CommitMessages $fix | Should -Be 'patch'

        $breaking = Get-Content (Join-Path $fixtureDir 'commits-breaking.txt')
        Get-BumpType -CommitMessages $breaking | Should -Be 'major'
    }
}
