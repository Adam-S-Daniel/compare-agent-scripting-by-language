# TDD Red Phase: These tests are written BEFORE the implementation.
# Run with: Invoke-Pester -Path ./SemanticVersionBumper.Tests.ps1 -Output Detailed

BeforeAll {
    . "$PSScriptRoot/SemanticVersionBumper.ps1"
}

Describe "Get-CurrentVersion" {
    Context "reading from a plain version file" {
        It "reads a valid semver from version.txt" {
            $tmpFile = New-TemporaryFile
            Set-Content $tmpFile "1.2.3"
            $result = Get-CurrentVersion -FilePath $tmpFile.FullName
            $result | Should -Be "1.2.3"
            Remove-Item $tmpFile
        }

        It "trims whitespace from version.txt" {
            $tmpFile = New-TemporaryFile
            Set-Content $tmpFile "  2.0.1  "
            $result = Get-CurrentVersion -FilePath $tmpFile.FullName
            $result | Should -Be "2.0.1"
            Remove-Item $tmpFile
        }

        It "throws when version file does not exist" {
            { Get-CurrentVersion -FilePath "/nonexistent/version.txt" } | Should -Throw
        }

        It "throws when version file has invalid format" {
            $tmpFile = New-TemporaryFile
            Set-Content $tmpFile "not-a-version"
            { Get-CurrentVersion -FilePath $tmpFile.FullName } | Should -Throw
            Remove-Item $tmpFile
        }
    }

    Context "reading from package.json" {
        It "reads version from package.json" {
            $tmpFile = New-TemporaryFile
            Rename-Item $tmpFile ($tmpFile.FullName + ".json")
            $jsonPath = $tmpFile.FullName + ".json"
            Set-Content $jsonPath '{"name":"my-app","version":"3.4.5","description":"test"}'
            $result = Get-CurrentVersion -FilePath $jsonPath
            $result | Should -Be "3.4.5"
            Remove-Item $jsonPath
        }

        It "throws when package.json has no version field" {
            $tmpFile = New-TemporaryFile
            Rename-Item $tmpFile ($tmpFile.FullName + ".json")
            $jsonPath = $tmpFile.FullName + ".json"
            Set-Content $jsonPath '{"name":"my-app"}'
            { Get-CurrentVersion -FilePath $jsonPath } | Should -Throw
            Remove-Item $jsonPath
        }
    }
}

Describe "Get-BumpType" {
    Context "patch bumps for fix commits" {
        It "returns patch for a single fix commit" {
            $result = Get-BumpType -Commits @("fix: correct null pointer exception")
            $result | Should -Be "patch"
        }

        It "returns patch when all commits are fixes" {
            $result = Get-BumpType -Commits @("fix: bug one", "fix: bug two", "chore: update deps")
            $result | Should -Be "patch"
        }
    }

    Context "minor bumps for feat commits" {
        It "returns minor for a feat commit" {
            $result = Get-BumpType -Commits @("feat: add user auth", "fix: minor fix")
            $result | Should -Be "minor"
        }

        It "returns minor for feat with scope" {
            $result = Get-BumpType -Commits @("feat(auth): add OAuth support")
            $result | Should -Be "minor"
        }
    }

    Context "major bumps for breaking changes" {
        It "returns major for feat with ! suffix" {
            $result = Get-BumpType -Commits @("feat!: redesign public API")
            $result | Should -Be "major"
        }

        It "returns major for fix with ! suffix" {
            $result = Get-BumpType -Commits @("fix!: change return type")
            $result | Should -Be "major"
        }

        It "returns major for BREAKING CHANGE footer" {
            $result = Get-BumpType -Commits @("feat: add feature`nBREAKING CHANGE: removes old endpoint")
            $result | Should -Be "major"
        }

        It "major takes precedence over minor" {
            $result = Get-BumpType -Commits @("feat: new thing", "feat!: breaking api change")
            $result | Should -Be "major"
        }
    }

    Context "edge cases" {
        It "returns patch for empty commit list" {
            $result = Get-BumpType -Commits @()
            $result | Should -Be "patch"
        }

        It "returns patch for non-conventional commits" {
            $result = Get-BumpType -Commits @("update readme", "WIP: something")
            $result | Should -Be "patch"
        }
    }
}

Describe "Get-NextVersion" {
    It "bumps patch version: 1.1.0 -> 1.1.1" {
        $result = Get-NextVersion -CurrentVersion "1.1.0" -BumpType "patch"
        $result | Should -Be "1.1.1"
    }

    It "bumps minor version and resets patch: 1.1.5 -> 1.2.0" {
        $result = Get-NextVersion -CurrentVersion "1.1.5" -BumpType "minor"
        $result | Should -Be "1.2.0"
    }

    It "bumps major version and resets minor+patch: 1.2.3 -> 2.0.0" {
        $result = Get-NextVersion -CurrentVersion "1.2.3" -BumpType "major"
        $result | Should -Be "2.0.0"
    }

    It "handles 0.x.x versions" {
        $result = Get-NextVersion -CurrentVersion "0.9.0" -BumpType "minor"
        $result | Should -Be "0.10.0"
    }

    It "throws for invalid current version" {
        { Get-NextVersion -CurrentVersion "invalid" -BumpType "patch" } | Should -Throw
    }

    It "throws for invalid bump type" {
        { Get-NextVersion -CurrentVersion "1.0.0" -BumpType "invalid" } | Should -Throw
    }
}

Describe "New-ChangelogEntry" {
    It "generates a changelog entry with version header" {
        $result = New-ChangelogEntry -Version "1.2.0" -Commits @("feat: add new feature") -Date "2026-04-19"
        $result | Should -Match "## \[1\.2\.0\] - 2026-04-19"
    }

    It "groups features under Features section" {
        $result = New-ChangelogEntry -Version "1.2.0" -Commits @("feat: add auth", "feat(api): add endpoint") -Date "2026-04-19"
        $result | Should -Match "### Features"
        $result | Should -Match "feat: add auth"
    }

    It "groups fixes under Bug Fixes section" {
        $result = New-ChangelogEntry -Version "1.1.1" -Commits @("fix: null check", "fix: typo") -Date "2026-04-19"
        $result | Should -Match "### Bug Fixes"
        $result | Should -Match "fix: null check"
    }

    It "groups breaking changes under Breaking Changes section" {
        $result = New-ChangelogEntry -Version "2.0.0" -Commits @("feat!: new API") -Date "2026-04-19"
        $result | Should -Match "### Breaking Changes"
    }

    It "uses today's date when no date given" {
        $today = Get-Date -Format "yyyy-MM-dd"
        $result = New-ChangelogEntry -Version "1.0.0" -Commits @("fix: a fix")
        $result | Should -Match $today
    }
}

Describe "Update-VersionFile" {
    Context "updating a plain version file" {
        It "writes the new version to version.txt" {
            $tmpFile = New-TemporaryFile
            Set-Content $tmpFile "1.0.0"
            Update-VersionFile -FilePath $tmpFile.FullName -Version "1.1.0"
            $result = (Get-Content $tmpFile.FullName).Trim()
            $result | Should -Be "1.1.0"
            Remove-Item $tmpFile
        }
    }

    Context "updating package.json" {
        It "updates only the version field in package.json" {
            $tmpFile = New-TemporaryFile
            Rename-Item $tmpFile ($tmpFile.FullName + ".json")
            $jsonPath = $tmpFile.FullName + ".json"
            Set-Content $jsonPath '{"name":"my-app","version":"1.0.0","description":"test"}'
            Update-VersionFile -FilePath $jsonPath -Version "2.0.0"
            $json = Get-Content $jsonPath | ConvertFrom-Json
            $json.version | Should -Be "2.0.0"
            $json.name | Should -Be "my-app"
            Remove-Item $jsonPath
        }
    }
}

Describe "Invoke-SemanticVersionBump (integration)" {
    It "patch bump from 1.1.0 using fix commits from fixture file" {
        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "svb-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $tmpDir | Out-Null
        Set-Content "$tmpDir/version.txt" "1.1.0"
        $commits = Get-Content "$PSScriptRoot/fixtures/commits-patch.txt"
        $newVersion = Invoke-SemanticVersionBump -VersionFile "$tmpDir/version.txt" -Commits $commits
        $newVersion | Should -Be "1.1.1"
        (Get-Content "$tmpDir/version.txt").Trim() | Should -Be "1.1.1"
        Remove-Item $tmpDir -Recurse
    }

    It "minor bump from 1.1.0 using feat commits from fixture file" {
        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "svb-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $tmpDir | Out-Null
        Set-Content "$tmpDir/version.txt" "1.1.0"
        $commits = Get-Content "$PSScriptRoot/fixtures/commits-minor.txt"
        $newVersion = Invoke-SemanticVersionBump -VersionFile "$tmpDir/version.txt" -Commits $commits
        $newVersion | Should -Be "1.2.0"
        (Get-Content "$tmpDir/version.txt").Trim() | Should -Be "1.2.0"
        Remove-Item $tmpDir -Recurse
    }

    It "major bump from 1.1.0 using breaking commits from fixture file" {
        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "svb-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $tmpDir | Out-Null
        Set-Content "$tmpDir/version.txt" "1.1.0"
        $commits = Get-Content "$PSScriptRoot/fixtures/commits-major.txt"
        $newVersion = Invoke-SemanticVersionBump -VersionFile "$tmpDir/version.txt" -Commits $commits
        $newVersion | Should -Be "2.0.0"
        Remove-Item $tmpDir -Recurse
    }

    It "bumps version in package.json" {
        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "svb-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $tmpDir | Out-Null
        Set-Content "$tmpDir/package.json" '{"name":"my-app","version":"2.3.1"}'
        $commits = Get-Content "$PSScriptRoot/fixtures/commits-minor.txt"
        $newVersion = Invoke-SemanticVersionBump -VersionFile "$tmpDir/package.json" -Commits $commits
        $newVersion | Should -Be "2.4.0"
        Remove-Item $tmpDir -Recurse
    }

    It "generates CHANGELOG.md alongside version file" {
        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "svb-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $tmpDir | Out-Null
        Set-Content "$tmpDir/version.txt" "1.0.0"
        $commits = Get-Content "$PSScriptRoot/fixtures/commits-minor.txt"
        Invoke-SemanticVersionBump -VersionFile "$tmpDir/version.txt" -Commits $commits | Out-Null
        Test-Path "$tmpDir/CHANGELOG.md" | Should -Be $true
        Get-Content "$tmpDir/CHANGELOG.md" -Raw | Should -Match "## \[1\.1\.0\]"
        Remove-Item $tmpDir -Recurse
    }
}
