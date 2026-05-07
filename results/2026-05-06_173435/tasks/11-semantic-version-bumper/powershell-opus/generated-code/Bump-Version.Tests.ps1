BeforeAll {
    . $PSScriptRoot/Bump-Version.ps1
}

Describe "Parse-SemanticVersion" {
    It "parses a valid version string" {
        $result = Parse-SemanticVersion -VersionString "1.2.3"
        $result.Major | Should -Be 1
        $result.Minor | Should -Be 2
        $result.Patch | Should -Be 3
    }

    It "parses version with leading/trailing whitespace" {
        $result = Parse-SemanticVersion -VersionString "  2.0.1  "
        $result.Major | Should -Be 2
        $result.Minor | Should -Be 0
        $result.Patch | Should -Be 1
    }

    It "parses version from package.json format" {
        $json = '{ "name": "app", "version": "3.1.4" }'
        $result = Parse-SemanticVersion -VersionString $json
        $result.Major | Should -Be 3
        $result.Minor | Should -Be 1
        $result.Patch | Should -Be 4
    }

    It "throws on invalid version string" {
        { Parse-SemanticVersion -VersionString "not-a-version" } | Should -Throw
    }

    It "throws on partial version" {
        { Parse-SemanticVersion -VersionString "1.2" } | Should -Throw
    }
}

Describe "Get-BumpType" {
    It "returns patch for fix commits" {
        $commits = @("fix: resolve null reference", "docs: update readme")
        Get-BumpType -CommitMessages $commits | Should -Be "patch"
    }

    It "returns minor for feat commits" {
        $commits = @("feat: add new feature", "fix: small bugfix")
        Get-BumpType -CommitMessages $commits | Should -Be "minor"
    }

    It "returns major for breaking change with !" {
        $commits = @("feat!: redesign API", "fix: minor fix")
        Get-BumpType -CommitMessages $commits | Should -Be "major"
    }

    It "returns major for BREAKING CHANGE footer" {
        $commits = @("feat: new thing", "BREAKING CHANGE: old API removed")
        Get-BumpType -CommitMessages $commits | Should -Be "major"
    }

    It "returns none when no conventional commits present" {
        $commits = @("docs: update readme", "chore: bump deps")
        Get-BumpType -CommitMessages $commits | Should -Be "none"
    }

    It "handles empty commit list" {
        Get-BumpType -CommitMessages @() | Should -Be "none"
    }

    It "handles scoped commit types" {
        $commits = @("feat(auth): add OAuth support")
        Get-BumpType -CommitMessages $commits | Should -Be "minor"
    }
}

Describe "Bump-SemanticVersion" {
    It "increments patch version" {
        $v = @{ Major = 1; Minor = 2; Patch = 3 }
        $result = Bump-SemanticVersion -Version $v -BumpType "patch"
        $result.Major | Should -Be 1
        $result.Minor | Should -Be 2
        $result.Patch | Should -Be 4
    }

    It "increments minor and resets patch" {
        $v = @{ Major = 1; Minor = 2; Patch = 3 }
        $result = Bump-SemanticVersion -Version $v -BumpType "minor"
        $result.Major | Should -Be 1
        $result.Minor | Should -Be 3
        $result.Patch | Should -Be 0
    }

    It "increments major and resets minor and patch" {
        $v = @{ Major = 1; Minor = 2; Patch = 3 }
        $result = Bump-SemanticVersion -Version $v -BumpType "major"
        $result.Major | Should -Be 2
        $result.Minor | Should -Be 0
        $result.Patch | Should -Be 0
    }

    It "returns same version for none bump type" {
        $v = @{ Major = 1; Minor = 2; Patch = 3 }
        $result = Bump-SemanticVersion -Version $v -BumpType "none"
        $result.Major | Should -Be 1
        $result.Minor | Should -Be 2
        $result.Patch | Should -Be 3
    }
}

Describe "Format-Version" {
    It "formats version hashtable as string" {
        $v = @{ Major = 2; Minor = 5; Patch = 0 }
        Format-Version -Version $v | Should -Be "2.5.0"
    }
}

Describe "Generate-Changelog" {
    It "generates changelog with features and fixes" {
        $commits = @("feat: add login", "fix: resolve crash")
        $result = Generate-Changelog -NewVersion "1.1.0" -CommitMessages $commits
        $result | Should -Match "## \[1.1.0\]"
        $result | Should -Match "### Features"
        $result | Should -Match "### Bug Fixes"
        $result | Should -Match "feat: add login"
        $result | Should -Match "fix: resolve crash"
    }

    It "generates changelog with breaking changes section" {
        $commits = @("feat!: redesign auth")
        $result = Generate-Changelog -NewVersion "2.0.0" -CommitMessages $commits
        $result | Should -Match "### Breaking Changes"
    }

    It "skips empty messages" {
        $commits = @("feat: something", "", "  ")
        $result = Generate-Changelog -NewVersion "1.1.0" -CommitMessages $commits
        $result | Should -Match "feat: something"
        $result | Should -Not -Match "^- $"
    }
}

Describe "End-to-end: Bump-Version.ps1 script" {
    BeforeEach {
        $testDir = Join-Path ([System.IO.Path]::GetTempPath()) "semver-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $testDir | Out-Null
    }

    AfterEach {
        Remove-Item -Recurse -Force $testDir -ErrorAction SilentlyContinue
    }

    It "bumps patch version with fix commits" {
        Set-Content -Path "$testDir/VERSION" -Value "1.0.0" -NoNewline
        $commitFile = "$PSScriptRoot/fixtures/patch-commits.txt"
        $output = & $PSScriptRoot/Bump-Version.ps1 -VersionFile "$testDir/VERSION" -CommitLogFile $commitFile -ChangelogFile "$testDir/CHANGELOG.md"
        $output | Should -Contain "NEW_VERSION=1.0.1"
        Get-Content "$testDir/VERSION" -Raw | Should -Be "1.0.1"
    }

    It "bumps minor version with feat commits" {
        Set-Content -Path "$testDir/VERSION" -Value "1.1.0" -NoNewline
        $commitFile = "$PSScriptRoot/fixtures/minor-commits.txt"
        $output = & $PSScriptRoot/Bump-Version.ps1 -VersionFile "$testDir/VERSION" -CommitLogFile $commitFile -ChangelogFile "$testDir/CHANGELOG.md"
        $output | Should -Contain "NEW_VERSION=1.2.0"
        Get-Content "$testDir/VERSION" -Raw | Should -Be "1.2.0"
    }

    It "bumps major version with breaking commits" {
        Set-Content -Path "$testDir/VERSION" -Value "1.5.3" -NoNewline
        $commitFile = "$PSScriptRoot/fixtures/major-commits.txt"
        $output = & $PSScriptRoot/Bump-Version.ps1 -VersionFile "$testDir/VERSION" -CommitLogFile $commitFile -ChangelogFile "$testDir/CHANGELOG.md"
        $output | Should -Contain "NEW_VERSION=2.0.0"
        Get-Content "$testDir/VERSION" -Raw | Should -Be "2.0.0"
    }

    It "bumps major version with BREAKING CHANGE footer" {
        Set-Content -Path "$testDir/VERSION" -Value "2.1.0" -NoNewline
        $commitFile = "$PSScriptRoot/fixtures/breaking-footer-commits.txt"
        $output = & $PSScriptRoot/Bump-Version.ps1 -VersionFile "$testDir/VERSION" -CommitLogFile $commitFile -ChangelogFile "$testDir/CHANGELOG.md"
        $output | Should -Contain "NEW_VERSION=3.0.0"
        Get-Content "$testDir/VERSION" -Raw | Should -Be "3.0.0"
    }

    It "reports no bump when no conventional commits" {
        Set-Content -Path "$testDir/VERSION" -Value "1.0.0" -NoNewline
        $commitFile = "$PSScriptRoot/fixtures/no-bump-commits.txt"
        $output = & $PSScriptRoot/Bump-Version.ps1 -VersionFile "$testDir/VERSION" -CommitLogFile $commitFile -ChangelogFile "$testDir/CHANGELOG.md"
        $output | Should -Contain "NO_BUMP"
        Get-Content "$testDir/VERSION" -Raw | Should -Be "1.0.0"
    }

    It "creates CHANGELOG.md if it does not exist" {
        Set-Content -Path "$testDir/VERSION" -Value "1.0.0" -NoNewline
        $commitFile = "$PSScriptRoot/fixtures/patch-commits.txt"
        & $PSScriptRoot/Bump-Version.ps1 -VersionFile "$testDir/VERSION" -CommitLogFile $commitFile -ChangelogFile "$testDir/CHANGELOG.md"
        Test-Path "$testDir/CHANGELOG.md" | Should -Be $true
        Get-Content "$testDir/CHANGELOG.md" -Raw | Should -Match "# Changelog"
    }
}
