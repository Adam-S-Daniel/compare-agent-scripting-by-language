# SemanticVersionBumper.Tests.ps1
# TDD tests for Semantic Version Bumper
# Approach: Red/Green/Refactor cycle for each feature

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Import the module under test (will fail until module exists)
$modulePath = Join-Path $PSScriptRoot 'SemanticVersionBumper.psm1'
Import-Module $modulePath -Force

Describe 'Get-VersionFromFile' {

    BeforeAll {
        # Create temp directory for test fixtures
        $script:TempDir = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'versiontest')
    }

    Context 'Reading version from package.json' {
        It 'parses version from a standard package.json' {
            $pkgJson = @{ version = '1.2.3'; name = 'my-app' } | ConvertTo-Json
            $filePath = Join-Path $script:TempDir 'package.json'
            Set-Content -Path $filePath -Value $pkgJson

            $result = Get-VersionFromFile -FilePath $filePath
            $result | Should -Be '1.2.3'
        }

        It 'throws when version key is missing from package.json' {
            $pkgJson = @{ name = 'my-app' } | ConvertTo-Json
            $filePath = Join-Path $script:TempDir 'no-version.json'
            Set-Content -Path $filePath -Value $pkgJson

            { Get-VersionFromFile -FilePath $filePath } | Should -Throw '*version*'
        }
    }

    Context 'Reading version from version.json' {
        It 'parses version from a version.json file' {
            $versionJson = @{ version = '0.5.0' } | ConvertTo-Json
            $filePath = Join-Path $script:TempDir 'version.json'
            Set-Content -Path $filePath -Value $versionJson

            $result = Get-VersionFromFile -FilePath $filePath
            $result | Should -Be '0.5.0'
        }
    }

    Context 'Reading version from plain text VERSION file' {
        It 'parses version from a plain text file' {
            $filePath = Join-Path $script:TempDir 'VERSION'
            Set-Content -Path $filePath -Value '2.0.1'

            $result = Get-VersionFromFile -FilePath $filePath
            $result | Should -Be '2.0.1'
        }

        It 'handles trailing whitespace in VERSION file' {
            $filePath = Join-Path $script:TempDir 'VERSION_ws'
            Set-Content -Path $filePath -Value '  3.1.4  '

            $result = Get-VersionFromFile -FilePath $filePath
            $result | Should -Be '3.1.4'
        }
    }

    Context 'Error handling' {
        It 'throws when file does not exist' {
            { Get-VersionFromFile -FilePath '/nonexistent/path/version.json' } | Should -Throw
        }

        It 'throws for invalid semver format' {
            $filePath = Join-Path $script:TempDir 'bad-version.json'
            Set-Content -Path $filePath -Value (@{ version = 'not-a-version' } | ConvertTo-Json)

            { Get-VersionFromFile -FilePath $filePath } | Should -Throw '*invalid*'
        }
    }
}

Describe 'Get-VersionBumpType' {

    Context 'Determining bump type from conventional commits' {
        It 'returns Major for breaking change (BREAKING CHANGE in body)' {
            [string[]]$commits = @(
                'fix: correct typo in README',
                'feat: add new login flow',
                'fix: patch SQL bug

BREAKING CHANGE: auth API signature changed'
            )
            $result = Get-VersionBumpType -CommitMessages $commits
            $result | Should -Be 'Major'
        }

        It 'returns Major for breaking change (! in type)' {
            [string[]]$commits = @(
                'feat!: redesign public API',
                'fix: minor patch'
            )
            $result = Get-VersionBumpType -CommitMessages $commits
            $result | Should -Be 'Major'
        }

        It 'returns Minor for feat commit without breaking change' {
            [string[]]$commits = @(
                'fix: correct input validation',
                'feat: add dark mode support',
                'docs: update README'
            )
            $result = Get-VersionBumpType -CommitMessages $commits
            $result | Should -Be 'Minor'
        }

        It 'returns Patch for only fix commits' {
            [string[]]$commits = @(
                'fix: resolve null pointer exception',
                'fix: handle empty input gracefully',
                'chore: update dependencies'
            )
            $result = Get-VersionBumpType -CommitMessages $commits
            $result | Should -Be 'Patch'
        }

        It 'returns Patch for only chore/docs/style commits' {
            [string[]]$commits = @(
                'chore: update CI config',
                'docs: improve API docs',
                'style: fix linting issues'
            )
            $result = Get-VersionBumpType -CommitMessages $commits
            $result | Should -Be 'Patch'
        }

        It 'throws for empty commit list' {
            { Get-VersionBumpType -CommitMessages @() } | Should -Throw '*empty*'
        }

        It 'Major takes precedence over feat' {
            [string[]]$commits = @(
                'feat: add new endpoint',
                'feat!: remove deprecated API'
            )
            $result = Get-VersionBumpType -CommitMessages $commits
            $result | Should -Be 'Major'
        }
    }
}

Describe 'Invoke-VersionBump' {

    Context 'Bumping semantic version numbers' {
        It 'bumps major version and resets minor and patch' {
            $result = Invoke-VersionBump -Version '1.2.3' -BumpType 'Major'
            $result | Should -Be '2.0.0'
        }

        It 'bumps minor version and resets patch' {
            $result = Invoke-VersionBump -Version '1.2.3' -BumpType 'Minor'
            $result | Should -Be '1.3.0'
        }

        It 'bumps patch version only' {
            $result = Invoke-VersionBump -Version '1.2.3' -BumpType 'Patch'
            $result | Should -Be '1.2.4'
        }

        It 'handles 0.x.y versions correctly' {
            $result = Invoke-VersionBump -Version '0.0.1' -BumpType 'Minor'
            $result | Should -Be '0.1.0'
        }

        It 'throws for invalid bump type' {
            { Invoke-VersionBump -Version '1.0.0' -BumpType 'Invalid' } | Should -Throw '*BumpType*'
        }

        It 'throws for invalid version string' {
            { Invoke-VersionBump -Version 'bad.version' -BumpType 'Patch' } | Should -Throw
        }
    }
}

Describe 'New-ChangelogEntry' {

    Context 'Generating changelog entries from commits' {
        It 'generates a changelog section with the new version and date' {
            [string[]]$commits = @(
                'feat: add dark mode',
                'fix: resolve crash on startup'
            )
            $result = New-ChangelogEntry -NewVersion '1.3.0' -CommitMessages $commits -Date '2026-04-08'

            $result | Should -Match '## \[1\.3\.0\]'
            $result | Should -Match '2026-04-08'
        }

        It 'groups feat commits under Features section' {
            [string[]]$commits = @('feat: add export button', 'feat: support CSV output')
            $result = New-ChangelogEntry -NewVersion '1.1.0' -CommitMessages $commits -Date '2026-04-08'

            $result | Should -Match 'Features'
            $result | Should -Match 'add export button'
        }

        It 'groups fix commits under Bug Fixes section' {
            [string[]]$commits = @('fix: handle null values', 'fix: correct date formatting')
            $result = New-ChangelogEntry -NewVersion '1.0.1' -CommitMessages $commits -Date '2026-04-08'

            $result | Should -Match 'Bug Fixes'
            $result | Should -Match 'handle null values'
        }

        It 'includes breaking changes prominently' {
            [string[]]$commits = @('feat!: overhaul authentication API')
            $result = New-ChangelogEntry -NewVersion '2.0.0' -CommitMessages $commits -Date '2026-04-08'

            $result | Should -Match 'BREAKING'
        }

        It 'uses today date when Date not specified' {
            [string[]]$commits = @('fix: minor fix')
            $result = New-ChangelogEntry -NewVersion '1.0.1' -CommitMessages $commits
            $todayStr = [DateTime]::Today.ToString('yyyy-MM-dd')

            $result | Should -Match $todayStr
        }
    }
}

Describe 'Update-VersionFile' {

    BeforeAll {
        $script:TempDir2 = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'updatetest')
    }

    Context 'Updating version in files' {
        It 'updates version in package.json' {
            $pkgJson = @{ version = '1.0.0'; name = 'my-app' } | ConvertTo-Json
            $filePath = Join-Path $script:TempDir2 'package.json'
            Set-Content -Path $filePath -Value $pkgJson

            Update-VersionFile -FilePath $filePath -NewVersion '1.1.0'

            $updated = Get-Content $filePath | ConvertFrom-Json
            $updated.version | Should -Be '1.1.0'
        }

        It 'updates version in version.json' {
            $versionJson = @{ version = '2.3.4' } | ConvertTo-Json
            $filePath = Join-Path $script:TempDir2 'version.json'
            Set-Content -Path $filePath -Value $versionJson

            Update-VersionFile -FilePath $filePath -NewVersion '2.4.0'

            $updated = Get-Content $filePath | ConvertFrom-Json
            $updated.version | Should -Be '2.4.0'
        }

        It 'updates VERSION plain text file' {
            $filePath = Join-Path $script:TempDir2 'VERSION'
            Set-Content -Path $filePath -Value '1.5.2'

            Update-VersionFile -FilePath $filePath -NewVersion '1.6.0'

            $content = (Get-Content $filePath).Trim()
            $content | Should -Be '1.6.0'
        }

        It 'throws for invalid new version format' {
            $filePath = Join-Path $script:TempDir2 'VERSION2'
            Set-Content -Path $filePath -Value '1.0.0'

            { Update-VersionFile -FilePath $filePath -NewVersion 'bad-version' } | Should -Throw '*invalid*'
        }
    }
}

Describe 'Invoke-SemanticVersionBump (Integration)' {

    BeforeAll {
        $script:TempDir3 = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'integrationtest')
    }

    Context 'Full end-to-end version bump' {
        It 'bumps minor version for feat commit and writes changelog' {
            # Arrange
            $pkgJson = @{ version = '1.0.0'; name = 'test-app' } | ConvertTo-Json
            $versionFile = Join-Path $script:TempDir3 'package.json'
            $changelogFile = Join-Path $script:TempDir3 'CHANGELOG.md'
            Set-Content -Path $versionFile -Value $pkgJson
            Set-Content -Path $changelogFile -Value "# Changelog`n"

            [string[]]$commits = @(
                'feat: add user authentication',
                'fix: resolve token expiry bug'
            )

            # Act
            $result = Invoke-SemanticVersionBump -VersionFilePath $versionFile `
                -CommitMessages $commits `
                -ChangelogPath $changelogFile `
                -Date '2026-04-08'

            # Assert
            $result | Should -Be '1.1.0'

            $updatedPkg = Get-Content $versionFile | ConvertFrom-Json
            $updatedPkg.version | Should -Be '1.1.0'

            $changelog = Get-Content $changelogFile -Raw
            $changelog | Should -Match '1\.1\.0'
            $changelog | Should -Match 'add user authentication'
        }

        It 'bumps major version for breaking change' {
            $pkgJson = @{ version = '1.5.3'; name = 'test-app' } | ConvertTo-Json
            $versionFile = Join-Path $script:TempDir3 'package_major.json'
            $changelogFile = Join-Path $script:TempDir3 'CHANGELOG_major.md'
            Set-Content -Path $versionFile -Value $pkgJson
            Set-Content -Path $changelogFile -Value "# Changelog`n"

            [string[]]$commits = @('feat!: redesign entire API')

            $result = Invoke-SemanticVersionBump -VersionFilePath $versionFile `
                -CommitMessages $commits `
                -ChangelogPath $changelogFile `
                -Date '2026-04-08'

            $result | Should -Be '2.0.0'
        }

        It 'prepends new changelog entry before existing content' {
            $pkgJson = @{ version = '1.0.0'; name = 'test-app' } | ConvertTo-Json
            $versionFile = Join-Path $script:TempDir3 'package_cl.json'
            $changelogFile = Join-Path $script:TempDir3 'CHANGELOG_existing.md'
            Set-Content -Path $versionFile -Value $pkgJson
            Set-Content -Path $changelogFile -Value "# Changelog`n`n## [1.0.0] - 2026-01-01`n- Initial release`n"

            [string[]]$commits = @('fix: patch edge case')

            Invoke-SemanticVersionBump -VersionFilePath $versionFile `
                -CommitMessages $commits `
                -ChangelogPath $changelogFile `
                -Date '2026-04-08' | Out-Null

            $changelog = Get-Content $changelogFile -Raw
            # New entry should appear before old entry
            $newIdx = $changelog.IndexOf('1.0.1')
            $oldIdx = $changelog.IndexOf('1.0.0')
            $newIdx | Should -BeLessThan $oldIdx
        }
    }
}
