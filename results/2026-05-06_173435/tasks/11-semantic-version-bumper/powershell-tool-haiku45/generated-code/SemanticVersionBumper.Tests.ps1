BeforeAll {
    # Import the module under test
    . $PSScriptRoot/SemanticVersionBumper.ps1
}

Describe "Parse-SemanticVersion" {
    It "should parse a valid semantic version string" {
        $result = Parse-SemanticVersion "1.2.3"
        $result.Major | Should -Be 1
        $result.Minor | Should -Be 2
        $result.Patch | Should -Be 3
    }

    It "should handle version with prerelease" {
        $result = Parse-SemanticVersion "1.2.3-alpha"
        $result.Major | Should -Be 1
        $result.Minor | Should -Be 2
        $result.Patch | Should -Be 3
        $result.Prerelease | Should -Be "alpha"
    }

    It "should throw on invalid version" {
        { Parse-SemanticVersion "invalid" } | Should -Throw
    }
}

Describe "Get-NextVersion" {
    It "should bump patch version for fix commits" {
        $current = @{ Major = 1; Minor = 2; Patch = 3 }
        $commits = @(
            @{ type = "fix"; subject = "fix bug" }
        )
        $result = Get-NextVersion -CurrentVersion $current -Commits $commits
        $result.Major | Should -Be 1
        $result.Minor | Should -Be 2
        $result.Patch | Should -Be 4
    }

    It "should bump minor version for feature commits" {
        $current = @{ Major = 1; Minor = 2; Patch = 3 }
        $commits = @(
            @{ type = "feat"; subject = "add new feature" }
        )
        $result = Get-NextVersion -CurrentVersion $current -Commits $commits
        $result.Major | Should -Be 1
        $result.Minor | Should -Be 3
        $result.Patch | Should -Be 0
    }

    It "should bump major version for breaking changes" {
        $current = @{ Major = 1; Minor = 2; Patch = 3 }
        $commits = @(
            @{ type = "feat"; subject = "add feature"; breaking = $true }
        )
        $result = Get-NextVersion -CurrentVersion $current -Commits $commits
        $result.Major | Should -Be 2
        $result.Minor | Should -Be 0
        $result.Patch | Should -Be 0
    }

    It "should prioritize breaking changes over other types" {
        $current = @{ Major = 1; Minor = 0; Patch = 0 }
        $commits = @(
            @{ type = "fix"; subject = "fix" },
            @{ type = "feat"; subject = "add feature"; breaking = $true },
            @{ type = "fix"; subject = "another fix" }
        )
        $result = Get-NextVersion -CurrentVersion $current -Commits $commits
        $result.Major | Should -Be 2
        $result.Minor | Should -Be 0
        $result.Patch | Should -Be 0
    }
}

Describe "Parse-ConventionalCommit" {
    It "should parse a conventional commit with type and subject" {
        $message = "feat: add new feature"
        $result = Parse-ConventionalCommit $message
        $result.type | Should -Be "feat"
        $result.subject | Should -Be "add new feature"
        $result.breaking | Should -Be $false
    }

    It "should detect breaking change with exclamation mark" {
        $message = "feat!: breaking change"
        $result = Parse-ConventionalCommit $message
        $result.type | Should -Be "feat"
        $result.subject | Should -Be "breaking change"
        $result.breaking | Should -Be $true
    }

    It "should detect breaking change in footer" {
        $message = @(
            "feat: add feature",
            "",
            "BREAKING CHANGE: this breaks things"
        ) -join "`n"
        $result = Parse-ConventionalCommit $message
        $result.breaking | Should -Be $true
    }

    It "should handle fix type" {
        $message = "fix: resolve issue"
        $result = Parse-ConventionalCommit $message
        $result.type | Should -Be "fix"
        $result.subject | Should -Be "resolve issue"
    }

    It "should return chore type as-is" {
        $message = "chore: update dependencies"
        $result = Parse-ConventionalCommit $message
        $result.type | Should -Be "chore"
    }
}

Describe "Update-VersionFile" {
    BeforeEach {
        $script:testDir = New-Item -ItemType Directory -Path "$([System.IO.Path]::GetTempPath())/svb-test-$(Get-Random)" -Force
    }

    AfterEach {
        Remove-Item -Path $script:testDir -Recurse -Force
    }

    It "should update package.json with new version" {
        $packagePath = Join-Path $script:testDir "package.json"
        @{
            name = "test-package"
            version = "1.0.0"
        } | ConvertTo-Json | Set-Content $packagePath

        Update-VersionFile -FilePath $packagePath -NewVersion "1.1.0"

        $content = Get-Content $packagePath -Raw | ConvertFrom-Json
        $content.version | Should -Be "1.1.0"
    }

    It "should update VERSION file" {
        $versionPath = Join-Path $script:testDir "VERSION"
        "1.0.0" | Set-Content $versionPath

        Update-VersionFile -FilePath $versionPath -NewVersion "1.1.0"

        Get-Content $versionPath -Raw | Should -Match "^1\.1\.0"
    }
}

Describe "Generate-ChangelogEntry" {
    It "should generate changelog entry from commits" {
        $commits = @(
            @{ type = "feat"; subject = "add authentication" },
            @{ type = "fix"; subject = "resolve memory leak" }
        )
        $newVersion = "1.1.0"

        $entry = Generate-ChangelogEntry -Version $newVersion -Commits $commits

        $entry | Should -Match "1\.1\.0"
        $entry | Should -Match "add authentication"
        $entry | Should -Match "resolve memory leak"
        $entry | Should -Match "Features"
        $entry | Should -Match "Bug Fixes"
    }

    It "should include date in changelog" {
        $commits = @(
            @{ type = "fix"; subject = "fix bug" }
        )
        $entry = Generate-ChangelogEntry -Version "1.0.1" -Commits $commits

        $entry | Should -Match "\d{4}-\d{2}-\d{2}"
    }
}

Describe "Invoke-SemanticVersionBump" {
    BeforeEach {
        $script:testDir = New-Item -ItemType Directory -Path "$([System.IO.Path]::GetTempPath())/svb-e2e-$(Get-Random)" -Force
        $script:packagePath = Join-Path $script:testDir "package.json"
        @{ name = "test"; version = "1.0.0" } | ConvertTo-Json | Set-Content $script:packagePath
    }

    AfterEach {
        Remove-Item -Path $script:testDir -Recurse -Force
    }

    It "should bump version from fix commit" {
        $commits = @(
            @{ type = "fix"; subject = "fix bug"; breaking = $false }
        )

        $result = Invoke-SemanticVersionBump -VersionFilePath $script:packagePath -Commits $commits

        $result.NewVersion | Should -Be "1.0.1"
        (Get-Content $script:packagePath | ConvertFrom-Json).version | Should -Be "1.0.1"
    }

    It "should bump version from feature commit" {
        $commits = @(
            @{ type = "feat"; subject = "add new endpoint"; breaking = $false }
        )

        $result = Invoke-SemanticVersionBump -VersionFilePath $script:packagePath -Commits $commits

        $result.NewVersion | Should -Be "1.1.0"
    }

    It "should bump version for breaking change" {
        $commits = @(
            @{ type = "feat"; subject = "redesign API"; breaking = $true }
        )

        $result = Invoke-SemanticVersionBump -VersionFilePath $script:packagePath -Commits $commits

        $result.NewVersion | Should -Be "2.0.0"
    }

    It "should return changelog in result" {
        $commits = @(
            @{ type = "fix"; subject = "bug fix"; breaking = $false }
        )

        $result = Invoke-SemanticVersionBump -VersionFilePath $script:packagePath -Commits $commits

        $result.Changelog | Should -Not -BeNullOrEmpty
        $result.Changelog | Should -Match "1\.0\.1"
    }
}
