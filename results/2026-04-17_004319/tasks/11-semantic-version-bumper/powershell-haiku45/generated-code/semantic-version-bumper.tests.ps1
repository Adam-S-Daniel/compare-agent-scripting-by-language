# Semantic Version Bumper Tests
# TDD approach: failing tests first, then implementation

Describe "Semantic Version Bumper" {
    BeforeAll {
        # Load the script functions before running tests
        . ./semantic-version-bumper.ps1

        $tempPath = Join-Path $PSScriptRoot ".test-temp-$(Get-Random)"
        $testTempDir = New-Item -ItemType Directory -Path $tempPath -Force
        $projectDir = $testTempDir.FullName
    }

    AfterAll {
        if (Test-Path $projectDir) {
            Remove-Item -Path $projectDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Parse Version File" {
        It "should parse version from package.json" {
            $packageJson = @{
                name = "test-package"
                version = "1.2.3"
            } | ConvertTo-Json

            $packagePath = Join-Path $projectDir "package.json"
            Set-Content -Path $packagePath -Value $packageJson

            $version = Get-VersionFromFile -Path $packagePath
            $version | Should -Be "1.2.3"
        }

        It "should parse version from version file" {
            $versionPath = Join-Path $projectDir "VERSION"
            Set-Content -Path $versionPath -Value "2.0.0"

            $version = Get-VersionFromFile -Path $versionPath
            $version | Should -Be "2.0.0"
        }
    }

    Context "Determine Next Version" {
        It "should bump major version for breaking change" {
            $currentVersion = "1.2.3"
            $commits = @(
                @{ type = "feat"; message = "add new feature" }
                @{ type = "feat"; isBreaking = $true; message = "BREAKING CHANGE: remove old API" }
            )

            $nextVersion = Get-NextVersion -CurrentVersion $currentVersion -Commits $commits
            $nextVersion | Should -Be "2.0.0"
        }

        It "should bump minor version for feature commit" {
            $currentVersion = "1.2.3"
            $commits = @(
                @{ type = "feat"; message = "add new feature" }
            )

            $nextVersion = Get-NextVersion -CurrentVersion $currentVersion -Commits $commits
            $nextVersion | Should -Be "1.3.0"
        }

        It "should bump patch version for fix commit" {
            $currentVersion = "1.2.3"
            $commits = @(
                @{ type = "fix"; message = "fix bug in parser" }
            )

            $nextVersion = Get-NextVersion -CurrentVersion $currentVersion -Commits $commits
            $nextVersion | Should -Be "1.2.4"
        }

        It "should not bump version for non-release commits" {
            $currentVersion = "1.2.3"
            $commits = @(
                @{ type = "docs"; message = "update readme" }
                @{ type = "style"; message = "fix formatting" }
            )

            $nextVersion = Get-NextVersion -CurrentVersion $currentVersion -Commits $commits
            $nextVersion | Should -Be "1.2.3"
        }

        It "should handle multiple commits - highest priority wins" {
            $currentVersion = "1.0.0"
            $commits = @(
                @{ type = "fix"; message = "fix bug" }
                @{ type = "feat"; message = "add feature" }
                @{ type = "feat"; isBreaking = $true; message = "BREAKING: remove old API" }
            )

            $nextVersion = Get-NextVersion -CurrentVersion $currentVersion -Commits $commits
            $nextVersion | Should -Be "2.0.0"
        }
    }

    Context "Parse Conventional Commits" {
        It "should parse feature commit" {
            $commitMessage = "feat: add new parser functionality"
            $commit = Parse-ConventionalCommit -Message $commitMessage

            $commit.type | Should -Be "feat"
            $commit.scope | Should -BeNullOrEmpty
            $commit.message | Should -Be "add new parser functionality"
            $commit.isBreaking | Should -Be $false
        }

        It "should parse fix commit" {
            $commitMessage = "fix(parser): handle edge case in version parsing"
            $commit = Parse-ConventionalCommit -Message $commitMessage

            $commit.type | Should -Be "fix"
            $commit.scope | Should -Be "parser"
            $commit.message | Should -Be "handle edge case in version parsing"
        }

        It "should detect breaking changes" {
            $commitMessage = "feat!: redesign API`nBREAKING CHANGE: old endpoints removed"
            $commit = Parse-ConventionalCommit -Message $commitMessage

            $commit.isBreaking | Should -Be $true
        }

        It "should handle scope in breaking change" {
            $commitMessage = "feat(api)!: new authentication method"
            $commit = Parse-ConventionalCommit -Message $commitMessage

            $commit.type | Should -Be "feat"
            $commit.scope | Should -Be "api"
            $commit.isBreaking | Should -Be $true
        }
    }

    Context "Generate Changelog" {
        It "should generate changelog entry with features and fixes" {
            $version = "1.2.0"
            $commits = @(
                @{ type = "feat"; scope = "parser"; message = "add JSON support" }
                @{ type = "feat"; scope = "cli"; message = "add verbose flag" }
                @{ type = "fix"; scope = "core"; message = "handle empty input" }
            )

            $changelog = New-ChangelogEntry -Version $version -Commits $commits
            $changelog | Should -Match "## \[1\.2\.0\]"
            $changelog | Should -Match "### Features"
            $changelog | Should -Match "### Bug Fixes"
            $changelog | Should -Match "add JSON support"
            $changelog | Should -Match "handle empty input"
        }

        It "should group changes by scope" {
            $version = "2.0.0"
            $commits = @(
                @{ type = "feat"; scope = "api"; message = "redesign endpoints"; isBreaking = $true }
                @{ type = "feat"; scope = "parser"; message = "new parser engine" }
            )

            $changelog = New-ChangelogEntry -Version $version -Commits $commits
            $changelog | Should -Match "api"
            $changelog | Should -Match "parser"
        }
    }

    Context "Update Version File" {
        It "should update version in package.json" {
            $packageJson = @{
                name = "test-package"
                version = "1.0.0"
                description = "test"
            } | ConvertTo-Json

            $packagePath = Join-Path $projectDir "package.json"
            Set-Content -Path $packagePath -Value $packageJson

            Update-VersionInFile -Path $packagePath -NewVersion "1.1.0"

            $updated = Get-Content -Path $packagePath | ConvertFrom-Json
            $updated.version | Should -Be "1.1.0"
        }

        It "should update version in VERSION file" {
            $versionPath = Join-Path $projectDir "VERSION"
            Set-Content -Path $versionPath -Value "1.0.0"

            Update-VersionInFile -Path $versionPath -NewVersion "1.1.0"

            $updated = Get-Content -Path $versionPath
            $updated | Should -Be "1.1.0"
        }
    }

    Context "Integration - Full Workflow" {
        It "should bump version and generate changelog from mock commits" {
            # Setup: create package.json with version 1.0.0
            $packageJson = @{
                name = "bumper-test"
                version = "1.0.0"
            } | ConvertTo-Json

            $packagePath = Join-Path $projectDir "package.json"
            Set-Content -Path $packagePath -Value $packageJson

            # Simulate commits
            $commits = @(
                @{ type = "feat"; scope = "core"; message = "add new parser"; isBreaking = $false }
                @{ type = "fix"; scope = "cli"; message = "fix version output"; isBreaking = $false }
            )

            # Run bumper
            $result = Invoke-SemanticVersionBumper -PackagePath $packagePath -Commits $commits

            # Assert
            $result.oldVersion | Should -Be "1.0.0"
            $result.newVersion | Should -Be "1.1.0"
            $result.changelog | Should -Match "1\.1\.0"

            # Verify file was updated
            $updated = Get-Content -Path $packagePath | ConvertFrom-Json
            $updated.version | Should -Be "1.1.0"
        }
    }
}
