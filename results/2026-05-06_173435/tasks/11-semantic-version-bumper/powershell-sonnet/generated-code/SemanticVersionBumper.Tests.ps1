# SemanticVersionBumper.Tests.ps1
# TDD test suite for SemanticVersionBumper module.
# Tests were written first to drive the design of SemanticVersionBumper.psm1.

BeforeAll {
    Import-Module "$PSScriptRoot/SemanticVersionBumper.psm1" -Force
}

Describe "SemanticVersionBumper" {

    # -------------------------------------------------------------------------
    # RED phase: These tests defined the expected API before any code existed.
    # GREEN phase: SemanticVersionBumper.psm1 was written to satisfy them.
    # -------------------------------------------------------------------------

    Context "Get-VersionFromFile - version.txt" {
        BeforeEach {
            Set-Content -Path TestDrive:/version.txt -Value "1.0.0"
            Set-Content -Path TestDrive:/version-2.3.1.txt -Value "2.3.1"
            Set-Content -Path TestDrive:/bad.txt -Value "not-a-version"
        }

        It "parses plain version.txt and returns 1.0.0" {
            Get-VersionFromFile "TestDrive:/version.txt" | Should -Be "1.0.0"
        }

        It "parses version-2.3.1.txt and returns 2.3.1" {
            Get-VersionFromFile "TestDrive:/version-2.3.1.txt" | Should -Be "2.3.1"
        }

        It "throws for a missing file" {
            { Get-VersionFromFile "TestDrive:/nonexistent.txt" } | Should -Throw
        }

        It "throws for invalid semver content" {
            { Get-VersionFromFile "TestDrive:/bad.txt" } | Should -Throw
        }
    }

    Context "Get-VersionFromFile - package.json" {
        BeforeEach {
            @{ name = "my-pkg"; version = "3.2.1" } | ConvertTo-Json | Set-Content -Path TestDrive:/package.json
            @{ name = "no-ver" } | ConvertTo-Json | Set-Content -Path TestDrive:/no-version.json
        }

        It "parses package.json and returns 3.2.1" {
            Get-VersionFromFile "TestDrive:/package.json" | Should -Be "3.2.1"
        }

        It "throws when JSON has no version field" {
            { Get-VersionFromFile "TestDrive:/no-version.json" } | Should -Throw
        }
    }

    Context "Get-BumpType - commit type detection" {
        It "returns patch for a fix commit" {
            $commits = @([PSCustomObject]@{ type="fix"; message="fix null ptr"; breaking=$false })
            Get-BumpType -Commits $commits | Should -Be "patch"
        }

        It "returns minor for a feat commit" {
            $commits = @([PSCustomObject]@{ type="feat"; message="add auth"; breaking=$false })
            Get-BumpType -Commits $commits | Should -Be "minor"
        }

        It "returns major for a commit with breaking=true" {
            $commits = @([PSCustomObject]@{ type="feat"; message="redesign API"; breaking=$true })
            Get-BumpType -Commits $commits | Should -Be "major"
        }

        It "returns major for a commit with BREAKING CHANGE in message" {
            $commits = @([PSCustomObject]@{ type="feat"; message="BREAKING CHANGE: drop legacy endpoint"; breaking=$false })
            Get-BumpType -Commits $commits | Should -Be "major"
        }

        It "returns major even when mixed with fix commits" {
            $commits = @(
                [PSCustomObject]@{ type="fix";  message="fix bug";        breaking=$false },
                [PSCustomObject]@{ type="feat"; message="redesign API";   breaking=$true  }
            )
            Get-BumpType -Commits $commits | Should -Be "major"
        }

        It "returns minor when feat and fix are both present (feat wins)" {
            $commits = @(
                [PSCustomObject]@{ type="feat"; message="add dashboard"; breaking=$false },
                [PSCustomObject]@{ type="fix";  message="fix sidebar";   breaking=$false }
            )
            Get-BumpType -Commits $commits | Should -Be "minor"
        }

        It "defaults to patch for non-feat/fix types" {
            $commits = @([PSCustomObject]@{ type="chore"; message="update deps"; breaking=$false })
            Get-BumpType -Commits $commits | Should -Be "patch"
        }
    }

    Context "Get-NextVersion - version arithmetic" {
        It "bumps 1.0.0 with patch to 1.0.1" {
            Get-NextVersion -CurrentVersion "1.0.0" -BumpType "patch" | Should -Be "1.0.1"
            Write-Host "VERSION-CHECK patch 1.0.0->1.0.1"
        }

        It "bumps 1.0.0 with minor to 1.1.0" {
            Get-NextVersion -CurrentVersion "1.0.0" -BumpType "minor" | Should -Be "1.1.0"
            Write-Host "VERSION-CHECK minor 1.0.0->1.1.0"
        }

        It "bumps 1.0.0 with major to 2.0.0" {
            Get-NextVersion -CurrentVersion "1.0.0" -BumpType "major" | Should -Be "2.0.0"
            Write-Host "VERSION-CHECK major 1.0.0->2.0.0"
        }

        It "resets minor and patch on major bump: 2.3.1 -> 3.0.0" {
            Get-NextVersion -CurrentVersion "2.3.1" -BumpType "major" | Should -Be "3.0.0"
        }

        It "resets patch on minor bump: 2.3.1 -> 2.4.0" {
            Get-NextVersion -CurrentVersion "2.3.1" -BumpType "minor" | Should -Be "2.4.0"
        }
    }

    Context "Update-VersionFile" {
        BeforeEach {
            Set-Content -Path TestDrive:/version.txt -Value "1.0.0"
            @{ name = "pkg"; version = "1.0.0" } | ConvertTo-Json | Set-Content -Path TestDrive:/package.json
        }

        It "writes the new version to a plain text file" {
            Update-VersionFile -FilePath "TestDrive:/version.txt" -NewVersion "1.1.0"
            (Get-Content "TestDrive:/version.txt").Trim() | Should -Be "1.1.0"
        }

        It "updates the version field in package.json" {
            Update-VersionFile -FilePath "TestDrive:/package.json" -NewVersion "2.0.0"
            $json = Get-Content "TestDrive:/package.json" -Raw | ConvertFrom-Json
            $json.version | Should -Be "2.0.0"
        }

        It "does not modify the file in dry-run mode" {
            Update-VersionFile -FilePath "TestDrive:/version.txt" -NewVersion "9.9.9" -DryRun
            (Get-Content "TestDrive:/version.txt").Trim() | Should -Be "1.0.0"
        }
    }

    Context "New-ChangelogEntry" {
        It "includes the version and date header" {
            $commits = @([PSCustomObject]@{ type="fix"; message="fix bug"; breaking=$false })
            $entry = New-ChangelogEntry -NewVersion "1.0.1" -Commits $commits -Date "2026-01-01"
            $entry | Should -Match '\[1\.0\.1\]'
            $entry | Should -Match '2026-01-01'
        }

        It "lists feat commits under Features section" {
            $commits = @([PSCustomObject]@{ type="feat"; message="add auth"; breaking=$false })
            $entry = New-ChangelogEntry -NewVersion "1.1.0" -Commits $commits -Date "2026-01-01"
            $entry | Should -Match '### Features'
            $entry | Should -Match 'add auth'
        }

        It "lists fix commits under Bug Fixes section" {
            $commits = @([PSCustomObject]@{ type="fix"; message="fix crash"; breaking=$false })
            $entry = New-ChangelogEntry -NewVersion "1.0.1" -Commits $commits -Date "2026-01-01"
            $entry | Should -Match '### Bug Fixes'
            $entry | Should -Match 'fix crash'
        }

        It "lists breaking changes under Breaking Changes section" {
            $commits = @([PSCustomObject]@{ type="feat"; message="redesign API"; breaking=$true })
            $entry = New-ChangelogEntry -NewVersion "2.0.0" -Commits $commits -Date "2026-01-01"
            $entry | Should -Match '### Breaking Changes'
            $entry | Should -Match 'redesign API'
        }
    }

    Context "Read-CommitsFile" {
        BeforeEach {
            $fixture = @(
                @{ type="feat"; message="add feature"; breaking=$false; hash="abc1" }
                @{ type="fix";  message="fix bug";     breaking=$false; hash="def2" }
            ) | ConvertTo-Json
            Set-Content -Path TestDrive:/commits.json -Value $fixture
        }

        It "reads and parses a commits JSON fixture file" {
            $commits = Read-CommitsFile "TestDrive:/commits.json"
            $commits.Count | Should -Be 2
            $commits[0].type | Should -Be "feat"
            $commits[1].type | Should -Be "fix"
        }

        It "throws for a missing file" {
            { Read-CommitsFile "TestDrive:/missing.json" } | Should -Throw
        }
    }

    Context "Integration - full pipeline using fixture files" {

        It "pipeline: 1.0.0 + fix commit -> 1.0.1" {
            $commits = Read-CommitsFile "$PSScriptRoot/fixtures/commits-fix.json"
            $ver     = Get-VersionFromFile "$PSScriptRoot/fixtures/version-1.0.0.txt"
            $bump    = Get-BumpType -Commits $commits
            $new     = Get-NextVersion -CurrentVersion $ver -BumpType $bump
            Write-Host "SCENARIO fix: NEW_VERSION=$new"
            $new | Should -Be "1.0.1"
        }

        It "pipeline: 1.0.0 + feat commit -> 1.1.0" {
            $commits = Read-CommitsFile "$PSScriptRoot/fixtures/commits-feat.json"
            $ver     = Get-VersionFromFile "$PSScriptRoot/fixtures/version-1.0.0.txt"
            $bump    = Get-BumpType -Commits $commits
            $new     = Get-NextVersion -CurrentVersion $ver -BumpType $bump
            Write-Host "SCENARIO feat: NEW_VERSION=$new"
            $new | Should -Be "1.1.0"
        }

        It "pipeline: 1.0.0 + breaking commit -> 2.0.0" {
            $commits = Read-CommitsFile "$PSScriptRoot/fixtures/commits-breaking.json"
            $ver     = Get-VersionFromFile "$PSScriptRoot/fixtures/version-1.0.0.txt"
            $bump    = Get-BumpType -Commits $commits
            $new     = Get-NextVersion -CurrentVersion $ver -BumpType $bump
            Write-Host "SCENARIO breaking: NEW_VERSION=$new"
            $new | Should -Be "2.0.0"
        }

        It "pipeline: 2.3.1 + mixed commits (feat+fix) -> 2.4.0" {
            $commits = Read-CommitsFile "$PSScriptRoot/fixtures/commits-mixed.json"
            $ver     = Get-VersionFromFile "$PSScriptRoot/fixtures/version-2.3.1.txt"
            $bump    = Get-BumpType -Commits $commits
            $new     = Get-NextVersion -CurrentVersion $ver -BumpType $bump
            Write-Host "SCENARIO mixed: NEW_VERSION=$new"
            $new | Should -Be "2.4.0"
        }

        It "pipeline: package.json 3.2.1 + fix commit -> 3.2.2" {
            $commits = Read-CommitsFile "$PSScriptRoot/fixtures/commits-fix.json"
            $ver     = Get-VersionFromFile "$PSScriptRoot/fixtures/package-3.2.1.json"
            $bump    = Get-BumpType -Commits $commits
            $new     = Get-NextVersion -CurrentVersion $ver -BumpType $bump
            Write-Host "SCENARIO package-json: NEW_VERSION=$new"
            $new | Should -Be "3.2.2"
        }

        It "changelog entry includes correct version and commit details" {
            $commits = Read-CommitsFile "$PSScriptRoot/fixtures/commits-feat.json"
            $entry   = New-ChangelogEntry -NewVersion "1.1.0" -Commits $commits -Date "2026-01-15"
            $entry | Should -Match '\[1\.1\.0\]'
            $entry | Should -Match 'add user authentication'
        }
    }
}
