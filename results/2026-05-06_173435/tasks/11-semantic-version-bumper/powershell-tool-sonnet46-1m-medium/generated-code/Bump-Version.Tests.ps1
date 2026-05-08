# Pester tests for Bump-Version.ps1
# Red/Green TDD: tests were written before implementation

BeforeAll {
    . "$PSScriptRoot/Bump-Version.ps1"
}

Describe "Get-CurrentVersion" {
    Context "from version.txt" {
        It "parses a simple semver from version.txt" {
            $tmpDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path "$($_.FullName)" }
            Set-Content -Path "$tmpDir/version.txt" -Value "1.2.3"
            $result = Get-CurrentVersion -Path $tmpDir
            $result | Should -Be "1.2.3"
            Remove-Item -Recurse -Force $tmpDir
        }

        It "parses a version with leading/trailing whitespace" {
            $tmpDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path "$($_.FullName)" }
            Set-Content -Path "$tmpDir/version.txt" -Value "  2.0.0  "
            $result = Get-CurrentVersion -Path $tmpDir
            $result | Should -Be "2.0.0"
            Remove-Item -Recurse -Force $tmpDir
        }
    }

    Context "from package.json" {
        It "parses version from package.json when no version.txt exists" {
            $tmpDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path "$($_.FullName)" }
            $pkg = @{ name = "my-app"; version = "3.1.4" } | ConvertTo-Json
            Set-Content -Path "$tmpDir/package.json" -Value $pkg
            $result = Get-CurrentVersion -Path $tmpDir
            $result | Should -Be "3.1.4"
            Remove-Item -Recurse -Force $tmpDir
        }
    }

    Context "error handling" {
        It "throws a meaningful error when no version file is found" {
            $tmpDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path "$($_.FullName)" }
            { Get-CurrentVersion -Path $tmpDir } | Should -Throw "*No version file found*"
            Remove-Item -Recurse -Force $tmpDir
        }
    }
}

Describe "Get-BumpType" {
    It "returns 'patch' for a fix commit" {
        $commits = @("fix: correct null pointer exception")
        Get-BumpType -Commits $commits | Should -Be "patch"
    }

    It "returns 'minor' for a feat commit" {
        $commits = @("feat: add user profile page")
        Get-BumpType -Commits $commits | Should -Be "minor"
    }

    It "returns 'major' for a breaking change commit" {
        $commits = @("feat!: redesign public API")
        Get-BumpType -Commits $commits | Should -Be "major"
    }

    It "returns 'major' for a BREAKING CHANGE footer" {
        $commits = @("feat: new auth system`n`nBREAKING CHANGE: old tokens no longer valid")
        Get-BumpType -Commits $commits | Should -Be "major"
    }

    It "returns 'minor' when both feat and fix commits exist" {
        $commits = @("feat: add search", "fix: correct typo")
        Get-BumpType -Commits $commits | Should -Be "minor"
    }

    It "returns 'major' when breaking commit exists alongside feat and fix" {
        $commits = @("feat: new search", "fix: typo", "feat!: drop legacy API")
        Get-BumpType -Commits $commits | Should -Be "major"
    }

    It "returns 'patch' when only chore commits exist (default to patch)" {
        $commits = @("chore: update dependencies")
        Get-BumpType -Commits $commits | Should -Be "patch"
    }
}

Describe "Invoke-VersionBump" {
    It "bumps patch version correctly" {
        Invoke-VersionBump -Version "1.2.3" -BumpType "patch" | Should -Be "1.2.4"
    }

    It "bumps minor version and resets patch" {
        Invoke-VersionBump -Version "1.2.3" -BumpType "minor" | Should -Be "1.3.0"
    }

    It "bumps major version and resets minor and patch" {
        Invoke-VersionBump -Version "1.2.3" -BumpType "major" | Should -Be "2.0.0"
    }

    It "handles 0.x.x correctly for patch" {
        Invoke-VersionBump -Version "0.1.0" -BumpType "patch" | Should -Be "0.1.1"
    }

    It "throws for invalid semver input" {
        { Invoke-VersionBump -Version "not-a-version" -BumpType "patch" } | Should -Throw "*Invalid semver*"
    }
}

Describe "New-ChangelogEntry" {
    It "generates a changelog entry with date and version" {
        $commits = @("feat: add search", "fix: correct typo")
        $result = New-ChangelogEntry -Version "1.3.0" -Commits $commits -Date "2024-01-15"
        $result | Should -Match "## \[1\.3\.0\] - 2024-01-15"
    }

    It "groups feat commits under Features section" {
        $commits = @("feat: add search")
        $result = New-ChangelogEntry -Version "1.3.0" -Commits $commits -Date "2024-01-15"
        $result | Should -Match "### Features"
        $result | Should -Match "add search"
    }

    It "groups fix commits under Bug Fixes section" {
        $commits = @("fix: correct typo")
        $result = New-ChangelogEntry -Version "1.3.0" -Commits $commits -Date "2024-01-15"
        $result | Should -Match "### Bug Fixes"
        $result | Should -Match "correct typo"
    }

    It "groups breaking changes under Breaking Changes section" {
        $commits = @("feat!: redesign API")
        $result = New-ChangelogEntry -Version "2.0.0" -Commits $commits -Date "2024-01-15"
        $result | Should -Match "### Breaking Changes"
        $result | Should -Match "redesign API"
    }

    It "includes other commit types under Other Changes" {
        $commits = @("chore: update deps", "docs: update readme")
        $result = New-ChangelogEntry -Version "1.2.4" -Commits $commits -Date "2024-01-15"
        $result | Should -Match "### Other Changes"
    }
}

Describe "Set-VersionFile" {
    Context "version.txt" {
        It "updates version.txt with the new version" {
            $tmpDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path "$($_.FullName)" }
            Set-Content -Path "$tmpDir/version.txt" -Value "1.0.0"
            Set-VersionFile -Path $tmpDir -NewVersion "1.1.0"
            Get-Content "$tmpDir/version.txt" | Should -Be "1.1.0"
            Remove-Item -Recurse -Force $tmpDir
        }
    }

    Context "package.json" {
        It "updates version in package.json" {
            $tmpDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path "$($_.FullName)" }
            $pkg = @{ name = "my-app"; version = "1.0.0"; description = "test" } | ConvertTo-Json
            Set-Content -Path "$tmpDir/package.json" -Value $pkg
            Set-VersionFile -Path $tmpDir -NewVersion "2.0.0"
            $updated = Get-Content "$tmpDir/package.json" | ConvertFrom-Json
            $updated.version | Should -Be "2.0.0"
            Remove-Item -Recurse -Force $tmpDir
        }
    }
}

Describe "Invoke-SemanticVersionBump (integration)" {
    It "bumps version, updates file, and outputs new version" {
        $tmpDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path "$($_.FullName)" }
        Set-Content -Path "$tmpDir/version.txt" -Value "1.0.0"
        $commits = @("feat: add new feature", "fix: fix a bug")
        $result = Invoke-SemanticVersionBump -Path $tmpDir -Commits $commits
        $result.NewVersion | Should -Be "1.1.0"
        Get-Content "$tmpDir/version.txt" | Should -Be "1.1.0"
        $result.Changelog | Should -Match "## \[1\.1\.0\]"
        Remove-Item -Recurse -Force $tmpDir
    }

    It "performs major bump for breaking change" {
        $tmpDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path "$($_.FullName)" }
        Set-Content -Path "$tmpDir/version.txt" -Value "1.5.2"
        $commits = @("feat!: redesign everything")
        $result = Invoke-SemanticVersionBump -Path $tmpDir -Commits $commits
        $result.NewVersion | Should -Be "2.0.0"
        Remove-Item -Recurse -Force $tmpDir
    }
}
