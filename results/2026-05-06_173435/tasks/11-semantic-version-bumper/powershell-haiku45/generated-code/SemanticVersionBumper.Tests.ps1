# SemanticVersionBumper.Tests.ps1
# TDD: Failing tests written first

BeforeAll {
    # Import the module under test
    $scriptPath = if ($PSScriptRoot) { "$PSScriptRoot/SemanticVersionBumper.ps1" } else { "./SemanticVersionBumper.ps1" }
    . $scriptPath

    # Create a temp directory for test fixtures
    $tempRoot = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
    $tempPath = Join-Path $tempRoot "SemanticVersionBumper_$(Get-Random)"
    $script:TestTempDir = New-Item -ItemType Directory -Path $tempPath -Force
}

AfterAll {
    # Cleanup
    if ($null -ne $script:TestTempDir -and (Test-Path $script:TestTempDir)) {
        Remove-Item $script:TestTempDir -Recurse -Force
    }
}

Describe "Get-CurrentVersion" {
    It "should parse version from package.json" {
        $packageJson = @{
            version = "1.2.3"
            name = "test-project"
        } | ConvertTo-Json

        $pkgPath = Join-Path $script:TestTempDir "package.json"
        Set-Content -Path $pkgPath -Value $packageJson

        $version = Get-CurrentVersion -Path $pkgPath
        $version | Should -Be "1.2.3"
    }

    It "should parse version from version.txt" {
        $versionFile = Join-Path $script:TestTempDir "version.txt"
        Set-Content -Path $versionFile -Value "2.0.1"

        $version = Get-CurrentVersion -Path $versionFile
        $version | Should -Be "2.0.1"
    }
}

Describe "Compare-Versions" {
    It "should return 1 when first version is greater" {
        $result = Compare-Versions -Version1 "2.0.0" -Version2 "1.9.9"
        $result | Should -Be 1
    }

    It "should return 0 when versions are equal" {
        $result = Compare-Versions -Version1 "1.5.0" -Version2 "1.5.0"
        $result | Should -Be 0
    }

    It "should return -1 when first version is less" {
        $result = Compare-Versions -Version1 "1.0.0" -Version2 "1.0.1"
        $result | Should -Be -1
    }
}

Describe "Get-BumpType" {
    It "should return 'major' for breaking change commits" {
        $commits = @(
            @{ message = "feat!: breaking change" }
        )
        $bumpType = Get-BumpType -Commits $commits
        $bumpType | Should -Be "major"
    }

    It "should return 'minor' for feature commits" {
        $commits = @(
            @{ message = "feat: new feature" }
        )
        $bumpType = Get-BumpType -Commits $commits
        $bumpType | Should -Be "minor"
    }

    It "should return 'patch' for fix commits" {
        $commits = @(
            @{ message = "fix: bug fix" }
        )
        $bumpType = Get-BumpType -Commits $commits
        $bumpType | Should -Be "patch"
    }

    It "should return 'major' when breaking change exists among commits" {
        $commits = @(
            @{ message = "fix: bug fix" },
            @{ message = "feat: new feature" },
            @{ message = "feat!: breaking change" }
        )
        $bumpType = Get-BumpType -Commits $commits
        $bumpType | Should -Be "major"
    }

    It "should return 'minor' when feature exists but no breaking change" {
        $commits = @(
            @{ message = "fix: bug fix" },
            @{ message = "feat: new feature" }
        )
        $bumpType = Get-BumpType -Commits $commits
        $bumpType | Should -Be "minor"
    }
}

Describe "Bump-Version" {
    It "should bump major version" {
        $newVersion = Bump-Version -Version "1.2.3" -BumpType "major"
        $newVersion | Should -Be "2.0.0"
    }

    It "should bump minor version" {
        $newVersion = Bump-Version -Version "1.2.3" -BumpType "minor"
        $newVersion | Should -Be "1.3.0"
    }

    It "should bump patch version" {
        $newVersion = Bump-Version -Version "1.2.3" -BumpType "patch"
        $newVersion | Should -Be "1.2.4"
    }

    It "should handle version 0.0.0" {
        $newVersion = Bump-Version -Version "0.0.0" -BumpType "major"
        $newVersion | Should -Be "1.0.0"
    }
}

Describe "Update-VersionFile" {
    It "should update version in package.json" {
        $packageJson = @{
            version = "1.0.0"
            name = "test-project"
        } | ConvertTo-Json

        $pkgPath = Join-Path $script:TestTempDir "update-pkg.json"
        Set-Content -Path $pkgPath -Value $packageJson

        Update-VersionFile -Path $pkgPath -NewVersion "1.1.0"

        $updated = Get-Content -Path $pkgPath | ConvertFrom-Json
        $updated.version | Should -Be "1.1.0"
    }

    It "should update version in version.txt" {
        $versionFile = Join-Path $script:TestTempDir "update-version.txt"
        Set-Content -Path $versionFile -Value "1.0.0"

        Update-VersionFile -Path $versionFile -NewVersion "1.1.0"

        $updated = Get-Content -Path $versionFile
        $updated.Trim() | Should -Be "1.1.0"
    }
}

Describe "Generate-ChangelogEntry" {
    It "should generate changelog entry from commits" {
        $commits = @(
            @{ message = "feat: add new feature"; hash = "abc123" },
            @{ message = "fix: resolve bug"; hash = "def456" }
        )

        $changelog = Generate-ChangelogEntry -Version "1.1.0" -Commits $commits

        $changelog | Should -Match "1\.1\.0"
        $changelog | Should -Match "Features"
        $changelog | Should -Match "Bug Fixes"
    }
}

Describe "Invoke-SemanticVersionBumper" {
    It "should bump version and generate changelog from git commits" {
        # This is an integration test
        $projectDir = Join-Path $script:TestTempDir "project"
        New-Item -ItemType Directory -Path $projectDir -Force > $null

        # Create initial package.json
        $packageJson = @{
            version = "1.0.0"
            name = "test-project"
        } | ConvertTo-Json
        Set-Content -Path (Join-Path $projectDir "package.json") -Value $packageJson

        # Create mock commit log file
        $commitsFile = Join-Path $projectDir "commits.json"
        $commits = @(
            @{ message = "feat: new feature"; hash = "abc123"; author = "Test User" }
        ) | ConvertTo-Json
        Set-Content -Path $commitsFile -Value $commits

        $result = Invoke-SemanticVersionBumper -ProjectPath $projectDir -CommitsFile $commitsFile

        $result.NewVersion | Should -Be "1.1.0"
        $result.BumpType | Should -Be "minor"
        $result.Changelog | Should -Match "1\.1\.0"
    }
}
