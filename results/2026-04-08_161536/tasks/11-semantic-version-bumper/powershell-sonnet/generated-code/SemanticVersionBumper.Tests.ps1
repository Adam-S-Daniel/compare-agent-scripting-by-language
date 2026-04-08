# Semantic Version Bumper Tests
# TDD approach: each test is written before the implementation
# Tests use Pester framework (Invoke-Pester)

BeforeAll {
    # Import the module under test
    . "$PSScriptRoot/SemanticVersionBumper.ps1"
}

Describe "Get-CurrentVersion" {
    Context "when reading from version.txt" {
        It "parses a simple semantic version string" {
            # Arrange: create a temp version file
            $tmpFile = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tmpFile -Value "1.2.3"

            # Act
            $result = Get-CurrentVersion -VersionFile $tmpFile

            # Assert
            $result | Should -Be "1.2.3"

            Remove-Item $tmpFile
        }

        It "parses a version string with leading/trailing whitespace" {
            $tmpFile = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tmpFile -Value "  2.0.0  "

            $result = Get-CurrentVersion -VersionFile $tmpFile

            $result | Should -Be "2.0.0"

            Remove-Item $tmpFile
        }

        It "throws a meaningful error when file does not exist" {
            { Get-CurrentVersion -VersionFile "/nonexistent/path/version.txt" } |
                Should -Throw "*not found*"
        }
    }

    Context "when reading from package.json" {
        It "extracts version from package.json" {
            $tmpFile = [System.IO.Path]::GetTempFileName()
            $json = @{ version = "3.1.4" } | ConvertTo-Json
            Set-Content -Path $tmpFile -Value $json

            $result = Get-CurrentVersion -VersionFile $tmpFile -Format "json"

            $result | Should -Be "3.1.4"

            Remove-Item $tmpFile
        }

        It "throws when package.json has no version field" {
            $tmpFile = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tmpFile -Value '{"name": "myapp"}'

            { Get-CurrentVersion -VersionFile $tmpFile -Format "json" } |
                Should -Throw "*version field*"

            Remove-Item $tmpFile
        }
    }
}

Describe "Get-BumpType" {
    Context "with conventional commit messages" {
        It "returns 'patch' for fix commits" {
            $commits = @(
                "fix: correct off-by-one error in parser",
                "fix(auth): handle null token"
            )
            $result = Get-BumpType -Commits $commits
            $result | Should -Be "patch"
        }

        It "returns 'minor' for feat commits" {
            $commits = @(
                "feat: add user profile page",
                "fix: minor typo"
            )
            $result = Get-BumpType -Commits $commits
            $result | Should -Be "minor"
        }

        It "returns 'major' for BREAKING CHANGE in commit body" {
            $commits = @(
                "feat: new API endpoint",
                "feat!: remove deprecated endpoints",
                "fix: patch something"
            )
            $result = Get-BumpType -Commits $commits
            $result | Should -Be "major"
        }

        It "returns 'major' for breaking change footer" {
            $commits = @(
                "feat: add feature`n`nBREAKING CHANGE: old API removed"
            )
            $result = Get-BumpType -Commits $commits
            $result | Should -Be "major"
        }

        It "returns 'patch' as default when no conventional commits found" {
            $commits = @(
                "chore: update dependencies",
                "docs: update readme"
            )
            $result = Get-BumpType -Commits $commits
            $result | Should -Be "patch"
        }

        It "returns 'patch' when commit list is empty" {
            $result = Get-BumpType -Commits @()
            $result | Should -Be "patch"
        }
    }
}

Describe "Get-NextVersion" {
    It "increments patch version for patch bump" {
        $result = Get-NextVersion -CurrentVersion "1.2.3" -BumpType "patch"
        $result | Should -Be "1.2.4"
    }

    It "increments minor version for minor bump and resets patch" {
        $result = Get-NextVersion -CurrentVersion "1.2.3" -BumpType "minor"
        $result | Should -Be "1.3.0"
    }

    It "increments major version for major bump and resets minor and patch" {
        $result = Get-NextVersion -CurrentVersion "1.2.3" -BumpType "major"
        $result | Should -Be "2.0.0"
    }

    It "handles 0.x.x versions for minor bump" {
        $result = Get-NextVersion -CurrentVersion "0.4.2" -BumpType "minor"
        $result | Should -Be "0.5.0"
    }

    It "throws on invalid version string" {
        { Get-NextVersion -CurrentVersion "not-a-version" -BumpType "patch" } |
            Should -Throw "*invalid*"
    }
}

Describe "Set-VersionFile" {
    It "updates version.txt with new version" {
        $tmpFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tmpFile -Value "1.0.0"

        Set-VersionFile -VersionFile $tmpFile -NewVersion "1.0.1"

        $content = Get-Content -Path $tmpFile -Raw
        $content.Trim() | Should -Be "1.0.1"

        Remove-Item $tmpFile
    }

    It "updates version in package.json" {
        $tmpFile = [System.IO.Path]::GetTempFileName()
        $json = @{ name = "myapp"; version = "2.0.0"; description = "test" } | ConvertTo-Json
        Set-Content -Path $tmpFile -Value $json

        Set-VersionFile -VersionFile $tmpFile -NewVersion "2.1.0" -Format "json"

        $updated = Get-Content -Path $tmpFile -Raw | ConvertFrom-Json
        $updated.version | Should -Be "2.1.0"

        Remove-Item $tmpFile
    }
}

Describe "New-ChangelogEntry" {
    It "generates a changelog entry with version header and commit list" {
        $commits = @(
            "feat: add login page",
            "fix: correct redirect URL",
            "fix(auth): handle expired tokens"
        )
        $result = New-ChangelogEntry -NewVersion "1.3.0" -Commits $commits -Date "2026-04-08"

        $result | Should -Match "## \[1\.3\.0\]"
        $result | Should -Match "2026-04-08"
        $result | Should -Match "feat: add login page"
        $result | Should -Match "fix: correct redirect URL"
    }

    It "groups commits by type in changelog" {
        $commits = @(
            "feat: new dashboard",
            "fix: button alignment",
            "feat: dark mode toggle"
        )
        $result = New-ChangelogEntry -NewVersion "2.0.0" -Commits $commits -Date "2026-04-08"

        $result | Should -Match "### Features"
        $result | Should -Match "### Bug Fixes"
    }

    It "handles empty commit list gracefully" {
        $result = New-ChangelogEntry -NewVersion "1.0.1" -Commits @() -Date "2026-04-08"
        $result | Should -Match "## \[1\.0\.1\]"
    }
}

Describe "Invoke-SemanticVersionBump" {
    It "end-to-end: reads version, determines bump, updates file, returns new version" {
        # Setup temp directory
        $tmpDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName())
        New-Item -ItemType Directory -Path $tmpDir | Out-Null

        $versionFile = Join-Path $tmpDir "version.txt"
        Set-Content -Path $versionFile -Value "1.0.0"

        $commits = @(
            "feat: add search functionality",
            "fix: resolve memory leak"
        )

        # Act
        $result = Invoke-SemanticVersionBump -VersionFile $versionFile -Commits $commits

        # Assert
        $result.NewVersion | Should -Be "1.1.0"
        $result.OldVersion | Should -Be "1.0.0"
        $result.BumpType | Should -Be "minor"
        $result.ChangelogEntry | Should -Not -BeNullOrEmpty

        $fileContent = (Get-Content -Path $versionFile -Raw).Trim()
        $fileContent | Should -Be "1.1.0"

        Remove-Item -Recurse -Force $tmpDir
    }
}

Describe "GitHub Actions Workflow" {
    BeforeAll {
        $script:WorkflowPath = "$PSScriptRoot/.github/workflows/semantic-version-bumper.yml"
        $script:WorkflowContent = if (Test-Path $script:WorkflowPath) {
            Get-Content -Path $script:WorkflowPath -Raw
        } else { "" }
    }

    It "workflow file exists" {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It "workflow has valid YAML with required top-level keys" {
        # Parse YAML by checking for required keys
        $script:WorkflowContent | Should -Match "^name:"
        $script:WorkflowContent | Should -Match "on:"
        $script:WorkflowContent | Should -Match "jobs:"
    }

    It "workflow has push trigger" {
        $script:WorkflowContent | Should -Match "push:"
    }

    It "workflow has workflow_dispatch trigger" {
        $script:WorkflowContent | Should -Match "workflow_dispatch"
    }

    It "workflow references the PowerShell script" {
        $script:WorkflowContent | Should -Match "SemanticVersionBumper\.ps1"
    }

    It "workflow uses actions/checkout@v4" {
        $script:WorkflowContent | Should -Match "actions/checkout@v4"
    }

    It "workflow installs PowerShell or uses pwsh" {
        $script:WorkflowContent | Should -Match "pwsh|powershell|PowerShell"
    }

    It "script file referenced in workflow exists" {
        $scriptPath = "$PSScriptRoot/SemanticVersionBumper.ps1"
        Test-Path $scriptPath | Should -BeTrue
    }

    It "passes actionlint validation" {
        $actionlintResult = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint should pass with no errors. Output: $actionlintResult"
    }
}
