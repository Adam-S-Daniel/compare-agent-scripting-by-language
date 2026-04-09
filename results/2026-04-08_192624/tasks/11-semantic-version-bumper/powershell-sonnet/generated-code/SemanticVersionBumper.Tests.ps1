# Pester tests for Semantic Version Bumper
# TDD approach: tests written first, then implementation added to make them pass

BeforeAll {
    # Import the module under test
    . "$PSScriptRoot/SemanticVersionBumper.ps1"
}

Describe "Get-BumpType" {
    Context "When commits contain breaking changes" {
        It "Returns 'major' for feat! commits" {
            $commits = @("feat!: breaking API change", "fix: small fix")
            Get-BumpType -Commits $commits | Should -Be "major"
        }

        It "Returns 'major' for BREAKING CHANGE footer" {
            $commits = @("feat: new feature`n`nBREAKING CHANGE: removes old API")
            Get-BumpType -Commits $commits | Should -Be "major"
        }
    }

    Context "When commits contain features (no breaking)" {
        It "Returns 'minor' for feat commits" {
            $commits = @("feat: add new endpoint", "fix: patch bug")
            Get-BumpType -Commits $commits | Should -Be "minor"
        }

        It "Returns 'minor' even with multiple fix commits" {
            $commits = @("feat: cool feature", "fix: bug1", "fix: bug2")
            Get-BumpType -Commits $commits | Should -Be "minor"
        }
    }

    Context "When commits contain only fixes" {
        It "Returns 'patch' for fix commits" {
            $commits = @("fix: correct null pointer", "fix: handle edge case")
            Get-BumpType -Commits $commits | Should -Be "patch"
        }
    }

    Context "When commits have no releasable changes" {
        It "Returns 'none' for chore/docs/style commits" {
            $commits = @("chore: update deps", "docs: fix typo", "style: format code")
            Get-BumpType -Commits $commits | Should -Be "none"
        }

        It "Returns 'none' for empty commit list" {
            Get-BumpType -Commits @() | Should -Be "none"
        }
    }
}

Describe "Get-NextVersion" {
    Context "Patch bump" {
        It "Increments patch from 1.2.3 to 1.2.4" {
            Get-NextVersion -CurrentVersion "1.2.3" -BumpType "patch" | Should -Be "1.2.4"
        }

        It "Increments patch from 0.0.1 to 0.0.2" {
            Get-NextVersion -CurrentVersion "0.0.1" -BumpType "patch" | Should -Be "0.0.2"
        }
    }

    Context "Minor bump" {
        It "Increments minor and resets patch from 1.2.3 to 1.3.0" {
            Get-NextVersion -CurrentVersion "1.2.3" -BumpType "minor" | Should -Be "1.3.0"
        }

        It "Increments minor from 1.1.0 to 1.2.0" {
            Get-NextVersion -CurrentVersion "1.1.0" -BumpType "minor" | Should -Be "1.2.0"
        }
    }

    Context "Major bump" {
        It "Increments major and resets minor+patch from 1.2.3 to 2.0.0" {
            Get-NextVersion -CurrentVersion "1.2.3" -BumpType "major" | Should -Be "2.0.0"
        }

        It "Increments major from 0.9.5 to 1.0.0" {
            Get-NextVersion -CurrentVersion "0.9.5" -BumpType "major" | Should -Be "1.0.0"
        }
    }

    Context "No bump" {
        It "Returns same version for 'none' bump type" {
            Get-NextVersion -CurrentVersion "1.2.3" -BumpType "none" | Should -Be "1.2.3"
        }
    }

    Context "Error handling" {
        It "Throws on invalid version format" {
            { Get-NextVersion -CurrentVersion "not-a-version" -BumpType "patch" } | Should -Throw
        }
    }
}

Describe "Read-VersionFromFile" {
    Context "Reading from version.txt" {
        It "Reads version string from a file" {
            $tmpFile = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tmpFile -Value "2.5.1"
            Read-VersionFromFile -FilePath $tmpFile | Should -Be "2.5.1"
            Remove-Item $tmpFile
        }

        It "Trims whitespace from version" {
            $tmpFile = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tmpFile -Value "  1.0.0  `n"
            Read-VersionFromFile -FilePath $tmpFile | Should -Be "1.0.0"
            Remove-Item $tmpFile
        }
    }

    Context "Reading from package.json" {
        It "Reads version field from package.json" {
            $tmpFile = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.json'
            @{ version = "3.1.4"; name = "my-package" } | ConvertTo-Json | Set-Content -Path $tmpFile
            Read-VersionFromFile -FilePath $tmpFile | Should -Be "3.1.4"
            Remove-Item $tmpFile
        }
    }

    Context "Error handling" {
        It "Throws when file does not exist" {
            { Read-VersionFromFile -FilePath "/nonexistent/path/version.txt" } | Should -Throw
        }
    }
}

Describe "Write-VersionToFile" {
    Context "Writing to version.txt" {
        It "Writes new version to a plain text file" {
            $tmpFile = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tmpFile -Value "1.0.0"
            Write-VersionToFile -FilePath $tmpFile -NewVersion "1.1.0"
            Get-Content $tmpFile | Should -Be "1.1.0"
            Remove-Item $tmpFile
        }
    }

    Context "Writing to package.json" {
        It "Updates version field in package.json" {
            $tmpFile = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.json'
            @{ version = "1.0.0"; name = "test" } | ConvertTo-Json | Set-Content -Path $tmpFile
            Write-VersionToFile -FilePath $tmpFile -NewVersion "2.0.0"
            $pkg = Get-Content $tmpFile | ConvertFrom-Json
            $pkg.version | Should -Be "2.0.0"
            Remove-Item $tmpFile
        }
    }
}

Describe "New-ChangelogEntry" {
    It "Generates a changelog entry with version and commits" {
        $commits = @("feat: add login", "fix: patch null ref")
        $entry = New-ChangelogEntry -Version "1.2.0" -Commits $commits -Date "2026-04-08"
        $entry | Should -Match "## \[1\.2\.0\]"
        $entry | Should -Match "2026-04-08"
        $entry | Should -Match "add login"
        $entry | Should -Match "patch null ref"
    }

    It "Groups commits by type" {
        $commits = @("feat: new feature", "fix: bug fix", "feat: another feature")
        $entry = New-ChangelogEntry -Version "1.3.0" -Commits $commits -Date "2026-04-08"
        $entry | Should -Match "### Features"
        $entry | Should -Match "### Bug Fixes"
    }
}

Describe "Invoke-SemanticVersionBump (integration)" {
    It "Bumps patch version from fixture file and returns new version" {
        $tmpDir = New-TemporaryDirectory
        $versionFile = Join-Path $tmpDir "version.txt"
        Set-Content -Path $versionFile -Value "1.0.0"
        $commitFile = "$PSScriptRoot/fixtures/patch-commits.txt"
        $commits = Get-Content $commitFile

        $result = Invoke-SemanticVersionBump -VersionFile $versionFile -Commits $commits
        $result.NewVersion | Should -Be "1.0.1"
        Get-Content $versionFile | Should -Be "1.0.1"
    }

    It "Bumps minor version from fixture file" {
        $tmpDir = New-TemporaryDirectory
        $versionFile = Join-Path $tmpDir "version.txt"
        Set-Content -Path $versionFile -Value "1.1.0"
        $commits = Get-Content "$PSScriptRoot/fixtures/minor-commits.txt"

        $result = Invoke-SemanticVersionBump -VersionFile $versionFile -Commits $commits
        $result.NewVersion | Should -Be "1.2.0"
    }

    It "Bumps major version from fixture file" {
        $tmpDir = New-TemporaryDirectory
        $versionFile = Join-Path $tmpDir "version.txt"
        Set-Content -Path $versionFile -Value "1.2.3"
        $commits = Get-Content "$PSScriptRoot/fixtures/major-commits.txt"

        $result = Invoke-SemanticVersionBump -VersionFile $versionFile -Commits $commits
        $result.NewVersion | Should -Be "2.0.0"
    }

    It "Does not bump version when no releasable commits" {
        $tmpDir = New-TemporaryDirectory
        $versionFile = Join-Path $tmpDir "version.txt"
        Set-Content -Path $versionFile -Value "3.0.0"
        $commits = Get-Content "$PSScriptRoot/fixtures/no-bump-commits.txt"

        $result = Invoke-SemanticVersionBump -VersionFile $versionFile -Commits $commits
        $result.NewVersion | Should -Be "3.0.0"
        $result.BumpType | Should -Be "none"
    }

    AfterEach {
        if ($tmpDir -and (Test-Path $tmpDir)) {
            Remove-Item -Recurse -Force $tmpDir
        }
    }
}

Describe "Workflow Structure Tests" {
    BeforeAll {
        # $PSScriptRoot must be captured inside BeforeAll where it is valid
        $script:scriptDir = Split-Path -Parent $PSCommandPath
        $script:workflowPath = Join-Path $script:scriptDir ".github/workflows/semantic-version-bumper.yml"
    }

    It "Workflow file exists" {
        Test-Path $script:workflowPath | Should -BeTrue
    }

    It "Workflow YAML contains push trigger" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match 'push:'
    }

    It "Workflow YAML contains pull_request trigger" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match 'pull_request:'
    }

    It "Workflow YAML contains workflow_dispatch trigger" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match 'workflow_dispatch:'
    }

    It "Workflow references SemanticVersionBumper.ps1" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match 'SemanticVersionBumper\.ps1'
    }

    It "Workflow references fixture files" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match 'fixtures/'
    }

    It "SemanticVersionBumper.ps1 exists" {
        Test-Path (Join-Path $script:scriptDir "SemanticVersionBumper.ps1") | Should -BeTrue
    }

    It "Fixture files exist" {
        Test-Path (Join-Path $script:scriptDir "fixtures/patch-commits.txt") | Should -BeTrue
        Test-Path (Join-Path $script:scriptDir "fixtures/minor-commits.txt") | Should -BeTrue
        Test-Path (Join-Path $script:scriptDir "fixtures/major-commits.txt") | Should -BeTrue
        Test-Path (Join-Path $script:scriptDir "fixtures/no-bump-commits.txt") | Should -BeTrue
    }

    It "actionlint passes on workflow file" {
        & actionlint $script:workflowPath 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
}
