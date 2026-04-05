# VersionBumper.Tests.ps1
# TDD tests for Semantic Version Bumper
# Tests are written first (red), then implementation code (green), then refactor.

# Ensure Pester is available
#Requires -Modules Pester

BeforeAll {
    # Import the module under test
    . "$PSScriptRoot/VersionBumper.ps1"
}

# ─────────────────────────────────────────────────────────────
# Test fixtures: mock commit log data
# ─────────────────────────────────────────────────────────────
$patchCommits = @(
    "fix: correct null pointer in login handler",
    "fix: handle empty response from API",
    "docs: update README"
)

$minorCommits = @(
    "feat: add user profile page",
    "fix: correct null pointer in login handler",
    "chore: update dependencies"
)

$majorCommits = @(
    "feat!: redesign authentication API",
    "fix: correct null pointer in login handler"
)

$majorCommitsBody = @(
    "feat: add new endpoint`n`nBREAKING CHANGE: old /v1/users endpoint removed",
    "fix: correct null pointer in login handler"
)

$noReleaseCommits = @(
    "docs: update README",
    "chore: update CI config",
    "style: fix linting"
)

# ─────────────────────────────────────────────────────────────
# 1. Parse semantic version from a version file
# ─────────────────────────────────────────────────────────────
Describe "Get-CurrentVersion" {
    Context "from a plain version file" {
        It "reads version from a plain text version file" {
            $tmpFile = New-TemporaryFile
            Set-Content -Path $tmpFile.FullName -Value "1.2.3"
            $result = Get-CurrentVersion -Path $tmpFile.FullName
            $result | Should -Be "1.2.3"
            Remove-Item $tmpFile.FullName
        }

        It "trims whitespace/newlines from plain version file" {
            $tmpFile = New-TemporaryFile
            Set-Content -Path $tmpFile.FullName -Value "  2.0.0  "
            $result = Get-CurrentVersion -Path $tmpFile.FullName
            $result | Should -Be "2.0.0"
            Remove-Item $tmpFile.FullName
        }
    }

    Context "from a package.json" {
        It "reads version from package.json" {
            $tmpFile = New-TemporaryFile
            $json = @{ name = "my-app"; version = "3.1.4"; description = "test" }
            Set-Content -Path $tmpFile.FullName -Value ($json | ConvertTo-Json)
            $result = Get-CurrentVersion -Path $tmpFile.FullName
            $result | Should -Be "3.1.4"
            Remove-Item $tmpFile.FullName
        }
    }

    Context "error handling" {
        It "throws when file does not exist" {
            { Get-CurrentVersion -Path "nonexistent_file.txt" } | Should -Throw
        }

        It "throws when version is not found in file" {
            $tmpFile = New-TemporaryFile
            Set-Content -Path $tmpFile.FullName -Value "no version here"
            { Get-CurrentVersion -Path $tmpFile.FullName } | Should -Throw
            Remove-Item $tmpFile.FullName
        }
    }
}

# ─────────────────────────────────────────────────────────────
# 2. Determine bump type from conventional commits
# ─────────────────────────────────────────────────────────────
Describe "Get-BumpType" {
    It "returns 'patch' for fix commits" {
        Get-BumpType -Commits $patchCommits | Should -Be "patch"
    }

    It "returns 'minor' when feat commit is present" {
        Get-BumpType -Commits $minorCommits | Should -Be "minor"
    }

    It "returns 'major' for breaking change via ! suffix" {
        Get-BumpType -Commits $majorCommits | Should -Be "major"
    }

    It "returns 'major' for breaking change via BREAKING CHANGE in body" {
        Get-BumpType -Commits $majorCommitsBody | Should -Be "major"
    }

    It "returns 'none' when no releasable commits" {
        Get-BumpType -Commits $noReleaseCommits | Should -Be "none"
    }

    It "prioritizes major over minor and patch" {
        $mixed = @(
            "feat: add feature",
            "fix: fix bug",
            "feat!: breaking change"
        )
        Get-BumpType -Commits $mixed | Should -Be "major"
    }
}

# ─────────────────────────────────────────────────────────────
# 3. Compute the next semantic version
# ─────────────────────────────────────────────────────────────
Describe "Get-NextVersion" {
    It "increments patch version" {
        Get-NextVersion -CurrentVersion "1.2.3" -BumpType "patch" | Should -Be "1.2.4"
    }

    It "increments minor version and resets patch" {
        Get-NextVersion -CurrentVersion "1.2.3" -BumpType "minor" | Should -Be "1.3.0"
    }

    It "increments major version and resets minor and patch" {
        Get-NextVersion -CurrentVersion "1.2.3" -BumpType "major" | Should -Be "2.0.0"
    }

    It "returns same version when bump type is 'none'" {
        Get-NextVersion -CurrentVersion "1.2.3" -BumpType "none" | Should -Be "1.2.3"
    }

    It "handles 0.x.y versions correctly" {
        Get-NextVersion -CurrentVersion "0.1.0" -BumpType "minor" | Should -Be "0.2.0"
    }

    It "throws on invalid version format" {
        { Get-NextVersion -CurrentVersion "not-a-version" -BumpType "patch" } | Should -Throw
    }

    It "throws on unknown bump type" {
        { Get-NextVersion -CurrentVersion "1.0.0" -BumpType "invalid" } | Should -Throw
    }
}

# ─────────────────────────────────────────────────────────────
# 4. Update the version in a file
# ─────────────────────────────────────────────────────────────
Describe "Set-Version" {
    Context "plain version file" {
        It "updates the version in a plain text file" {
            $tmpFile = New-TemporaryFile
            Set-Content -Path $tmpFile.FullName -Value "1.0.0"
            Set-Version -Path $tmpFile.FullName -NewVersion "2.0.0"
            Get-Content -Path $tmpFile.FullName | Should -Be "2.0.0"
            Remove-Item $tmpFile.FullName
        }
    }

    Context "package.json" {
        It "updates the version field in package.json" {
            $tmpFile = New-TemporaryFile
            $json = @{ name = "my-app"; version = "1.0.0" }
            Set-Content -Path $tmpFile.FullName -Value ($json | ConvertTo-Json)
            Set-Version -Path $tmpFile.FullName -NewVersion "1.1.0"
            $updated = Get-Content -Path $tmpFile.FullName -Raw | ConvertFrom-Json
            $updated.version | Should -Be "1.1.0"
            Remove-Item $tmpFile.FullName
        }

        It "preserves other fields in package.json" {
            $tmpFile = New-TemporaryFile
            $json = @{ name = "my-app"; version = "1.0.0"; description = "keep me" }
            Set-Content -Path $tmpFile.FullName -Value ($json | ConvertTo-Json)
            Set-Version -Path $tmpFile.FullName -NewVersion "1.1.0"
            $updated = Get-Content -Path $tmpFile.FullName -Raw | ConvertFrom-Json
            $updated.name | Should -Be "my-app"
            $updated.description | Should -Be "keep me"
            Remove-Item $tmpFile.FullName
        }
    }

    Context "error handling" {
        It "throws when file does not exist" {
            { Set-Version -Path "nonexistent.txt" -NewVersion "1.0.0" } | Should -Throw
        }
    }
}

# ─────────────────────────────────────────────────────────────
# 5. Generate changelog entry
# ─────────────────────────────────────────────────────────────
Describe "New-ChangelogEntry" {
    It "generates a changelog entry with the new version" {
        $entry = New-ChangelogEntry -Version "1.3.0" -Commits $minorCommits -Date "2024-01-15"
        $entry | Should -Match "1\.3\.0"
        $entry | Should -Match "2024-01-15"
    }

    It "groups commits by type (feat, fix)" {
        $entry = New-ChangelogEntry -Version "1.3.0" -Commits $minorCommits -Date "2024-01-15"
        $entry | Should -Match "Features"
        $entry | Should -Match "Bug Fixes"
    }

    It "includes commit message descriptions" {
        $entry = New-ChangelogEntry -Version "1.3.0" -Commits $minorCommits -Date "2024-01-15"
        $entry | Should -Match "add user profile page"
        $entry | Should -Match "correct null pointer"
    }

    It "omits non-releasable commit types from changelog" {
        $entry = New-ChangelogEntry -Version "1.3.0" -Commits $minorCommits -Date "2024-01-15"
        $entry | Should -Not -Match "chore:"
    }

    It "handles empty commit list" {
        $entry = New-ChangelogEntry -Version "1.0.1" -Commits @() -Date "2024-01-15"
        $entry | Should -Match "1\.0\.1"
    }
}

# ─────────────────────────────────────────────────────────────
# 6. Prepend changelog entry to a CHANGELOG.md file
# ─────────────────────────────────────────────────────────────
Describe "Update-Changelog" {
    It "creates CHANGELOG.md if it does not exist and writes entry" {
        $tmpDir = New-Item -ItemType Directory -Path ([System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName())
        $changelogPath = Join-Path $tmpDir.FullName "CHANGELOG.md"
        Update-Changelog -Path $changelogPath -Entry "## v1.1.0`n- feat: new stuff"
        Test-Path $changelogPath | Should -BeTrue
        Get-Content $changelogPath -Raw | Should -Match "1\.1\.0"
        Remove-Item $tmpDir.FullName -Recurse
    }

    It "prepends new entry to existing CHANGELOG.md" {
        $tmpDir = New-Item -ItemType Directory -Path ([System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName())
        $changelogPath = Join-Path $tmpDir.FullName "CHANGELOG.md"
        Set-Content -Path $changelogPath -Value "## v1.0.0`n- initial release"
        Update-Changelog -Path $changelogPath -Entry "## v1.1.0`n- feat: new stuff"
        $content = Get-Content $changelogPath -Raw
        $content | Should -Match "(?s)1\.1\.0.*1\.0\.0"
        Remove-Item $tmpDir.FullName -Recurse
    }
}

# ─────────────────────────────────────────────────────────────
# 7. End-to-end: Invoke-VersionBump (integration)
# ─────────────────────────────────────────────────────────────
Describe "Invoke-VersionBump" {
    It "bumps minor version from package.json based on feat commit" {
        $tmpDir = New-Item -ItemType Directory -Path ([System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName())
        $versionFile = Join-Path $tmpDir.FullName "package.json"
        $changelogFile = Join-Path $tmpDir.FullName "CHANGELOG.md"
        $json = @{ name = "my-app"; version = "1.2.3" }
        Set-Content -Path $versionFile -Value ($json | ConvertTo-Json)

        $result = Invoke-VersionBump -VersionFile $versionFile -Commits $minorCommits -ChangelogFile $changelogFile -Date "2024-01-15"

        $result.OldVersion | Should -Be "1.2.3"
        $result.NewVersion | Should -Be "1.3.0"
        $result.BumpType  | Should -Be "minor"

        # Version file was updated
        $updated = Get-Content $versionFile -Raw | ConvertFrom-Json
        $updated.version | Should -Be "1.3.0"

        # Changelog was written
        Test-Path $changelogFile | Should -BeTrue

        Remove-Item $tmpDir.FullName -Recurse
    }

    It "bumps patch version from plain version file based on fix commit" {
        $tmpDir = New-Item -ItemType Directory -Path ([System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName())
        $versionFile = Join-Path $tmpDir.FullName "VERSION"
        $changelogFile = Join-Path $tmpDir.FullName "CHANGELOG.md"
        Set-Content -Path $versionFile -Value "2.5.1"

        $result = Invoke-VersionBump -VersionFile $versionFile -Commits $patchCommits -ChangelogFile $changelogFile -Date "2024-01-15"

        $result.NewVersion | Should -Be "2.5.2"
        $result.BumpType  | Should -Be "patch"

        Remove-Item $tmpDir.FullName -Recurse
    }

    It "bumps major version when BREAKING CHANGE is present" {
        $tmpDir = New-Item -ItemType Directory -Path ([System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName())
        $versionFile = Join-Path $tmpDir.FullName "VERSION"
        $changelogFile = Join-Path $tmpDir.FullName "CHANGELOG.md"
        Set-Content -Path $versionFile -Value "1.0.0"

        $result = Invoke-VersionBump -VersionFile $versionFile -Commits $majorCommits -ChangelogFile $changelogFile -Date "2024-01-15"

        $result.NewVersion | Should -Be "2.0.0"
        $result.BumpType  | Should -Be "major"

        Remove-Item $tmpDir.FullName -Recurse
    }

    It "makes no changes when no releasable commits" {
        $tmpDir = New-Item -ItemType Directory -Path ([System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName())
        $versionFile = Join-Path $tmpDir.FullName "VERSION"
        $changelogFile = Join-Path $tmpDir.FullName "CHANGELOG.md"
        Set-Content -Path $versionFile -Value "1.0.0"

        $result = Invoke-VersionBump -VersionFile $versionFile -Commits $noReleaseCommits -ChangelogFile $changelogFile -Date "2024-01-15"

        $result.NewVersion | Should -Be "1.0.0"
        $result.BumpType  | Should -Be "none"
        # Changelog not created when no bump
        Test-Path $changelogFile | Should -BeFalse

        Remove-Item $tmpDir.FullName -Recurse
    }
}
