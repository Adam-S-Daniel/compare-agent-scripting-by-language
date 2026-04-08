# VersionBumper.Tests.ps1
# TDD tests for the Semantic Version Bumper
# Run with: Invoke-Pester

BeforeAll {
    # Import the implementation module
    . "$PSScriptRoot/VersionBumper.ps1"
}

Describe "Get-CurrentVersion" {
    Context "When reading from package.json" {
        BeforeEach {
            # Create a temp package.json fixture
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "versionbumper-test-$([System.Guid]::NewGuid().ToString('N')[0..7] -join '')"
            New-Item -ItemType Directory -Path $script:TempDir | Out-Null
            $script:PackageJsonPath = Join-Path $script:TempDir "package.json"
        }

        AfterEach {
            Remove-Item -Recurse -Force $script:TempDir -ErrorAction SilentlyContinue
        }

        It "reads the version from a valid package.json" {
            # Arrange
            @{ version = "1.2.3" } | ConvertTo-Json | Set-Content $script:PackageJsonPath

            # Act
            $result = Get-CurrentVersion -VersionFilePath $script:PackageJsonPath

            # Assert
            $result | Should -Be "1.2.3"
        }

        It "throws a meaningful error when package.json is missing" {
            # Act & Assert
            { Get-CurrentVersion -VersionFilePath "/nonexistent/package.json" } |
                Should -Throw "*not found*"
        }

        It "throws a meaningful error when version field is absent" {
            # Arrange
            @{ name = "my-app" } | ConvertTo-Json | Set-Content $script:PackageJsonPath

            # Act & Assert
            { Get-CurrentVersion -VersionFilePath $script:PackageJsonPath } |
                Should -Throw "*version*"
        }

        It "reads the version from a plain VERSION file" {
            # Arrange
            $versionFilePath = Join-Path $script:TempDir "VERSION"
            "2.0.1" | Set-Content $versionFilePath

            # Act
            $result = Get-CurrentVersion -VersionFilePath $versionFilePath

            # Assert
            $result | Should -Be "2.0.1"
        }
    }
}

Describe "Get-BumpType" {
    It "returns 'major' for a breaking change commit" {
        $commits = @("feat!: remove deprecated API")
        Get-BumpType -Commits $commits | Should -Be "major"
    }

    It "returns 'major' for a commit with BREAKING CHANGE footer" {
        $commits = @("feat: new feature`n`nBREAKING CHANGE: old behavior removed")
        Get-BumpType -Commits $commits | Should -Be "major"
    }

    It "returns 'minor' for a feat commit" {
        $commits = @("feat: add user authentication")
        Get-BumpType -Commits $commits | Should -Be "minor"
    }

    It "returns 'patch' for a fix commit" {
        $commits = @("fix: resolve null pointer exception")
        Get-BumpType -Commits $commits | Should -Be "patch"
    }

    It "returns 'patch' for other conventional commits (docs, chore, etc.)" {
        $commits = @("chore: update dependencies", "docs: fix typo")
        Get-BumpType -Commits $commits | Should -Be "patch"
    }

    It "returns 'patch' when no conventional commits are found" {
        $commits = @("random message without type")
        Get-BumpType -Commits $commits | Should -Be "patch"
    }

    It "returns 'major' when breaking change is mixed with feat and fix" {
        $commits = @(
            "fix: minor bug fix",
            "feat!: breaking redesign",
            "feat: add widget"
        )
        Get-BumpType -Commits $commits | Should -Be "major"
    }

    It "returns 'minor' when feat and fix are mixed (no breaking)" {
        $commits = @(
            "fix: minor bug",
            "feat: add feature"
        )
        Get-BumpType -Commits $commits | Should -Be "minor"
    }
}

Describe "Invoke-VersionBump" {
    It "increments major version and resets minor and patch" {
        Invoke-VersionBump -Version "1.2.3" -BumpType "major" | Should -Be "2.0.0"
    }

    It "increments minor version and resets patch" {
        Invoke-VersionBump -Version "1.2.3" -BumpType "minor" | Should -Be "1.3.0"
    }

    It "increments patch version only" {
        Invoke-VersionBump -Version "1.2.3" -BumpType "patch" | Should -Be "1.2.4"
    }

    It "handles version 0.0.0 for patch bump" {
        Invoke-VersionBump -Version "0.0.0" -BumpType "patch" | Should -Be "0.0.1"
    }

    It "throws a meaningful error for invalid semver format" {
        { Invoke-VersionBump -Version "not.a.version" -BumpType "patch" } |
            Should -Throw "*invalid*"
    }

    It "throws a meaningful error for invalid bump type" {
        { Invoke-VersionBump -Version "1.0.0" -BumpType "invalid" } |
            Should -Throw "*bump type*"
    }
}

Describe "New-ChangelogEntry" {
    It "generates a changelog entry with date and new version" {
        $commits = @(
            "feat: add login page",
            "fix: correct redirect URL"
        )
        $result = New-ChangelogEntry -NewVersion "1.3.0" -Commits $commits -Date "2026-04-08"

        $result | Should -Match "## \[1\.3\.0\]"
        $result | Should -Match "2026-04-08"
    }

    It "includes feat commits under Features section" {
        $commits = @("feat: add dark mode")
        $result = New-ChangelogEntry -NewVersion "1.3.0" -Commits $commits -Date "2026-04-08"

        $result | Should -Match "### Features"
        $result | Should -Match "add dark mode"
    }

    It "includes fix commits under Bug Fixes section" {
        $commits = @("fix: patch memory leak")
        $result = New-ChangelogEntry -NewVersion "1.3.0" -Commits $commits -Date "2026-04-08"

        $result | Should -Match "### Bug Fixes"
        $result | Should -Match "patch memory leak"
    }

    It "includes breaking changes under Breaking Changes section" {
        $commits = @("feat!: remove v1 endpoints")
        $result = New-ChangelogEntry -NewVersion "2.0.0" -Commits $commits -Date "2026-04-08"

        $result | Should -Match "### Breaking Changes"
        $result | Should -Match "remove v1 endpoints"
    }

    It "groups commits by type correctly" {
        $commits = @(
            "feat: add dashboard",
            "fix: login bug",
            "chore: update deps"
        )
        $result = New-ChangelogEntry -NewVersion "1.3.0" -Commits $commits -Date "2026-04-08"

        $result | Should -Match "### Features"
        $result | Should -Match "add dashboard"
        $result | Should -Match "### Bug Fixes"
        $result | Should -Match "login bug"
    }
}

Describe "Set-VersionInFile" {
    BeforeEach {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "versionbumper-test-$([System.Guid]::NewGuid().ToString('N')[0..7] -join '')"
        New-Item -ItemType Directory -Path $script:TempDir | Out-Null
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:TempDir -ErrorAction SilentlyContinue
    }

    It "updates the version in package.json" {
        # Arrange
        $packageJsonPath = Join-Path $script:TempDir "package.json"
        @{ name = "my-app"; version = "1.0.0" } | ConvertTo-Json | Set-Content $packageJsonPath

        # Act
        Set-VersionInFile -VersionFilePath $packageJsonPath -NewVersion "1.1.0"

        # Assert
        $updated = Get-Content $packageJsonPath | ConvertFrom-Json
        $updated.version | Should -Be "1.1.0"
    }

    It "updates the version in a plain VERSION file" {
        # Arrange
        $versionFilePath = Join-Path $script:TempDir "VERSION"
        "1.0.0" | Set-Content $versionFilePath

        # Act
        Set-VersionInFile -VersionFilePath $versionFilePath -NewVersion "2.0.0"

        # Assert
        (Get-Content $versionFilePath).Trim() | Should -Be "2.0.0"
    }

    It "preserves other fields in package.json" {
        # Arrange
        $packageJsonPath = Join-Path $script:TempDir "package.json"
        @{ name = "my-app"; version = "1.0.0"; description = "Test app" } | ConvertTo-Json | Set-Content $packageJsonPath

        # Act
        Set-VersionInFile -VersionFilePath $packageJsonPath -NewVersion "1.1.0"

        # Assert
        $updated = Get-Content $packageJsonPath | ConvertFrom-Json
        $updated.name | Should -Be "my-app"
        $updated.description | Should -Be "Test app"
    }
}

Describe "Invoke-SemanticVersionBump (integration)" {
    BeforeEach {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "versionbumper-test-$([System.Guid]::NewGuid().ToString('N')[0..7] -join '')"
        New-Item -ItemType Directory -Path $script:TempDir | Out-Null
        $script:PackageJsonPath = Join-Path $script:TempDir "package.json"
        $script:ChangelogPath = Join-Path $script:TempDir "CHANGELOG.md"
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:TempDir -ErrorAction SilentlyContinue
    }

    It "bumps minor version for feat commits and creates changelog" {
        # Arrange
        @{ version = "1.0.0" } | ConvertTo-Json | Set-Content $script:PackageJsonPath
        $commits = @(
            "feat: add search functionality",
            "fix: correct pagination offset"
        )

        # Act
        $result = Invoke-SemanticVersionBump `
            -VersionFilePath $script:PackageJsonPath `
            -Commits $commits `
            -ChangelogPath $script:ChangelogPath `
            -Date "2026-04-08"

        # Assert
        $result | Should -Be "1.1.0"
        (Get-Content $script:PackageJsonPath | ConvertFrom-Json).version | Should -Be "1.1.0"
        (Get-Content $script:ChangelogPath -Raw) | Should -Match "1\.1\.0"
    }

    It "bumps major version for breaking changes" {
        # Arrange
        @{ version = "1.0.0" } | ConvertTo-Json | Set-Content $script:PackageJsonPath
        $commits = @("feat!: redesign API")

        # Act
        $result = Invoke-SemanticVersionBump `
            -VersionFilePath $script:PackageJsonPath `
            -Commits $commits `
            -ChangelogPath $script:ChangelogPath `
            -Date "2026-04-08"

        # Assert
        $result | Should -Be "2.0.0"
    }

    It "appends to an existing changelog" {
        # Arrange
        @{ version = "1.1.0" } | ConvertTo-Json | Set-Content $script:PackageJsonPath
        "# Changelog`n`n## [1.1.0] - 2026-04-01`n`n- old entry" | Set-Content $script:ChangelogPath
        $commits = @("fix: resolve crash on startup")

        # Act
        Invoke-SemanticVersionBump `
            -VersionFilePath $script:PackageJsonPath `
            -Commits $commits `
            -ChangelogPath $script:ChangelogPath `
            -Date "2026-04-08" | Out-Null

        # Assert
        $content = Get-Content $script:ChangelogPath -Raw
        $content | Should -Match "1\.1\.1"
        $content | Should -Match "1\.1\.0"   # old entry preserved
    }
}
