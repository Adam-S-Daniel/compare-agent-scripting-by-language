Describe "Semantic Version Bumper" {
    BeforeAll {
        $scriptDir = $PSScriptRoot
        if (-not $scriptDir) {
            $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        }
        . (Join-Path $scriptDir 'semantic-version-bumper.ps1')
    }

    Context "Parse Version" {
        It "should parse version from package.json" {
            # Arrange - use cross-platform temp directory
            $tempBase = if ([System.IO.Path]::PathSeparator -eq '\') { $env:TEMP } else { '/tmp' }
            $testDir = Join-Path $tempBase "svb-test-$(Get-Random)"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null

            $packageJson = @{
                version = "1.0.0"
            } | ConvertTo-Json

            Set-Content -Path (Join-Path $testDir "package.json") -Value $packageJson

            # Act
            $version = Get-CurrentVersion -Path (Join-Path $testDir "package.json")

            # Assert
            $version | Should -Be "1.0.0"

            # Cleanup
            Remove-Item -Path $testDir -Recurse -Force
        }
    }

    Context "Determine Next Version" {
        It "should bump minor version for feat commits" {
            # Act
            $nextVersion = Get-NextVersion -CurrentVersion "1.0.0" -Commits @("feat: add new feature")

            # Assert
            $nextVersion | Should -Be "1.1.0"
        }

        It "should bump patch version for fix commits" {
            # Act
            $nextVersion = Get-NextVersion -CurrentVersion "1.0.0" -Commits @("fix: resolve bug")

            # Assert
            $nextVersion | Should -Be "1.0.1"
        }

        It "should bump major version for breaking changes" {
            # Act
            $nextVersion = Get-NextVersion -CurrentVersion "1.0.0" -Commits @("feat: new api`nBREAKING CHANGE: api changed")

            # Assert
            $nextVersion | Should -Be "2.0.0"
        }

        It "should prioritize breaking change over feat/fix" {
            # Act
            $nextVersion = Get-NextVersion -CurrentVersion "1.2.3" -Commits @("fix: bugfix", "feat: feature", "feat: api change`nBREAKING CHANGE: old removed")

            # Assert
            $nextVersion | Should -Be "2.0.0"
        }

        It "should use highest priority bump when multiple commit types" {
            # Act
            $nextVersion = Get-NextVersion -CurrentVersion "1.0.0" -Commits @("fix: bug1", "feat: feature1", "fix: bug2")

            # Assert
            $nextVersion | Should -Be "1.1.0"
        }
    }

    Context "Update Version File" {
        It "should update package.json with new version" {
            # Arrange
            $tempBase = if ([System.IO.Path]::PathSeparator -eq '\') { $env:TEMP } else { '/tmp' }
            $testDir = Join-Path $tempBase "svb-upd-$(Get-Random)"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            $packagePath = Join-Path $testDir "package.json"

            $packageJson = @{
                version = "1.0.0"
                name = "test-project"
            } | ConvertTo-Json

            Set-Content -Path $packagePath -Value $packageJson

            # Act
            Update-VersionFile -Path $packagePath -NewVersion "1.1.0"
            $updated = Get-Content -Path $packagePath -Raw | ConvertFrom-Json

            # Assert
            $updated.version | Should -Be "1.1.0"
            $updated.name | Should -Be "test-project"

            # Cleanup
            Remove-Item -Path $testDir -Recurse -Force
        }
    }

    Context "Generate Changelog" {
        It "should generate changelog from commits" {
            # Act
            $changelog = Get-Changelog -Version "1.1.0" -Commits @(
                "feat: add new feature",
                "fix: resolve issue",
                "feat: another feature"
            )

            # Assert
            $changelog | Should -Match "1.1.0"
            $changelog | Should -Match "new feature"
            $changelog | Should -Match "resolve issue"
        }
    }

    Context "End-to-End" {
        It "should perform complete version bump workflow" {
            # Arrange
            $tempBase = if ([System.IO.Path]::PathSeparator -eq '\') { $env:TEMP } else { '/tmp' }
            $testDir = Join-Path $tempBase "svb-e2e-$(Get-Random)"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            $packagePath = Join-Path $testDir "package.json"
            $changelogPath = Join-Path $testDir "CHANGELOG.md"

            $packageJson = @{
                version = "1.0.0"
                name = "my-app"
            } | ConvertTo-Json

            Set-Content -Path $packagePath -Value $packageJson

            # Act
            $result = Update-SemanticVersion -PackagePath $packagePath -ChangelogPath $changelogPath -Commits @(
                "feat: add feature",
                "fix: fix bug"
            )

            # Assert
            $result.NewVersion | Should -Be "1.1.0"
            $updated = Get-Content -Path $packagePath -Raw | ConvertFrom-Json
            $updated.version | Should -Be "1.1.0"
            Test-Path $changelogPath | Should -Be $true

            # Cleanup
            Remove-Item -Path $testDir -Recurse -Force
        }
    }
}
