#Requires -Modules Pester
# VersionBumper.Tests.ps1
# TDD tests for semantic version bumper using Pester 5

BeforeAll {
    # Import the main script (dot-source it so functions are available)
    . "$PSScriptRoot/VersionBumper.ps1"
}

Describe "Get-CurrentVersion" {
    Context "Reading from version.txt" {
        It "reads a simple version string" {
            $tmpFile = New-TemporaryFile
            Set-Content -Path $tmpFile -Value "1.2.3"
            $result = Get-CurrentVersion -Path $tmpFile
            $result | Should -Be "1.2.3"
            Remove-Item $tmpFile
        }

        It "trims whitespace from version string" {
            $tmpFile = New-TemporaryFile
            Set-Content -Path $tmpFile -Value "  2.0.0  "
            $result = Get-CurrentVersion -Path $tmpFile
            $result | Should -Be "2.0.0"
            Remove-Item $tmpFile
        }
    }

    Context "Reading from package.json" {
        It "extracts version from package.json" {
            $tmpFile = New-TemporaryFile
            $json = @{ name = "myapp"; version = "3.1.4" } | ConvertTo-Json
            Set-Content -Path $tmpFile -Value $json
            $result = Get-CurrentVersion -Path $tmpFile
            $result | Should -Be "3.1.4"
            Remove-Item $tmpFile
        }
    }

    Context "Error handling" {
        It "throws when file does not exist" {
            { Get-CurrentVersion -Path "/nonexistent/path/version.txt" } | Should -Throw
        }
    }
}

Describe "Get-CommitBumpType" {
    It "returns 'patch' for fix commits" {
        $commits = @("fix: correct typo in README", "fix(auth): resolve login bug")
        Get-CommitBumpType -Commits $commits | Should -Be "patch"
    }

    It "returns 'minor' for feat commits" {
        $commits = @("feat: add dark mode", "fix: small correction")
        Get-CommitBumpType -Commits $commits | Should -Be "minor"
    }

    It "returns 'major' for breaking change commits" {
        $commits = @("feat!: redesign API", "fix: other thing")
        Get-CommitBumpType -Commits $commits | Should -Be "major"
    }

    It "returns 'major' for BREAKING CHANGE footer" {
        $commits = @("feat: new feature`n`nBREAKING CHANGE: old API removed")
        Get-CommitBumpType -Commits $commits | Should -Be "major"
    }

    It "returns 'patch' when no conventional commits found" {
        $commits = @("random commit message", "update stuff")
        Get-CommitBumpType -Commits $commits | Should -Be "patch"
    }

    It "returns 'patch' for empty commit list" {
        $commits = @()
        Get-CommitBumpType -Commits $commits | Should -Be "patch"
    }
}

Describe "Get-NextVersion" {
    It "bumps patch version correctly" {
        Get-NextVersion -CurrentVersion "1.2.3" -BumpType "patch" | Should -Be "1.2.4"
    }

    It "bumps minor version and resets patch" {
        Get-NextVersion -CurrentVersion "1.2.3" -BumpType "minor" | Should -Be "1.3.0"
    }

    It "bumps major version and resets minor and patch" {
        Get-NextVersion -CurrentVersion "1.2.3" -BumpType "major" | Should -Be "2.0.0"
    }

    It "handles 0.x.x versions correctly" {
        Get-NextVersion -CurrentVersion "0.1.0" -BumpType "minor" | Should -Be "0.2.0"
    }

    It "throws on invalid version string" {
        { Get-NextVersion -CurrentVersion "not-a-version" -BumpType "patch" } | Should -Throw
    }
}

Describe "New-ChangelogEntry" {
    It "generates a changelog entry with date and version" {
        $commits = @("feat: add login", "fix: correct typo")
        $result = New-ChangelogEntry -Version "1.3.0" -Commits $commits -Date "2026-04-09"
        $result | Should -Match "## \[1\.3\.0\]"
        $result | Should -Match "2026-04-09"
    }

    It "groups feat commits under Features section" {
        $commits = @("feat: add dark mode", "feat: add notifications")
        $result = New-ChangelogEntry -Version "1.3.0" -Commits $commits -Date "2026-04-09"
        $result | Should -Match "### Features"
        $result | Should -Match "add dark mode"
        $result | Should -Match "add notifications"
    }

    It "groups fix commits under Bug Fixes section" {
        $commits = @("fix: resolve crash on startup", "fix(ui): button alignment")
        $result = New-ChangelogEntry -Version "1.2.4" -Commits $commits -Date "2026-04-09"
        $result | Should -Match "### Bug Fixes"
        $result | Should -Match "resolve crash on startup"
    }

    It "groups breaking changes under Breaking Changes section" {
        $commits = @("feat!: new API design")
        $result = New-ChangelogEntry -Version "2.0.0" -Commits $commits -Date "2026-04-09"
        $result | Should -Match "### Breaking Changes"
    }

    It "handles mixed commit types" {
        $commits = @("feat: new feature", "fix: bug fix", "chore: update deps")
        $result = New-ChangelogEntry -Version "1.3.0" -Commits $commits -Date "2026-04-09"
        $result | Should -Match "### Features"
        $result | Should -Match "### Bug Fixes"
    }
}

Describe "Update-VersionFile" {
    Context "Updating version.txt" {
        It "writes new version to version.txt" {
            $tmpFile = New-TemporaryFile
            Set-Content -Path $tmpFile -Value "1.0.0"
            Update-VersionFile -Path $tmpFile -NewVersion "1.1.0"
            Get-Content -Path $tmpFile | Should -Be "1.1.0"
            Remove-Item $tmpFile
        }
    }

    Context "Updating package.json" {
        It "updates version field in package.json" {
            $tmpFile = New-TemporaryFile
            $json = @{ name = "myapp"; version = "1.0.0"; description = "test" } | ConvertTo-Json
            Set-Content -Path $tmpFile -Value $json
            Update-VersionFile -Path $tmpFile -NewVersion "2.0.0"
            $updated = Get-Content -Path $tmpFile | ConvertFrom-Json
            $updated.version | Should -Be "2.0.0"
            # Preserve other fields
            $updated.name | Should -Be "myapp"
            Remove-Item $tmpFile
        }
    }
}

Describe "Update-Changelog" {
    It "prepends new entry to existing CHANGELOG.md" {
        $tmpFile = New-TemporaryFile
        Set-Content -Path $tmpFile -Value "# Changelog`n`n## [1.0.0] - 2026-01-01`n`n- Initial release"
        $entry = "## [1.1.0] - 2026-04-09`n`n### Features`n`n- add dark mode"
        Update-Changelog -Path $tmpFile -Entry $entry
        $content = Get-Content -Path $tmpFile -Raw
        $content | Should -Match "1\.1\.0"
        $content | Should -Match "1\.0\.0"
        # New entry should come before old
        $content.IndexOf("1.1.0") | Should -BeLessThan ($content.IndexOf("1.0.0"))
        Remove-Item $tmpFile
    }

    It "creates CHANGELOG.md if it does not exist" {
        $tmpPath = [System.IO.Path]::GetTempFileName() + "_changelog.md"
        $entry = "## [1.0.0] - 2026-04-09`n`n### Features`n`n- initial release"
        Update-Changelog -Path $tmpPath -Entry $entry
        Test-Path $tmpPath | Should -BeTrue
        Remove-Item $tmpPath
    }
}

Describe "Invoke-VersionBump (integration)" {
    It "performs a full version bump from patch commit" {
        $tmpDir = New-Item -ItemType Directory -Path ([System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName())
        $versionFile = Join-Path $tmpDir "version.txt"
        $changelogFile = Join-Path $tmpDir "CHANGELOG.md"
        Set-Content -Path $versionFile -Value "1.2.3"

        $commits = @("fix: correct null reference", "fix(api): handle empty response")
        $result = Invoke-VersionBump -VersionFilePath $versionFile -ChangelogPath $changelogFile -Commits $commits -Date "2026-04-09"

        $result | Should -Be "1.2.4"
        Get-Content -Path $versionFile | Should -Be "1.2.4"
        (Get-Content -Path $changelogFile -Raw) | Should -Match "1\.2\.4"

        Remove-Item -Recurse -Force $tmpDir
    }

    It "performs a full version bump from feat commit" {
        $tmpDir = New-Item -ItemType Directory -Path ([System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName())
        $versionFile = Join-Path $tmpDir "version.txt"
        $changelogFile = Join-Path $tmpDir "CHANGELOG.md"
        Set-Content -Path $versionFile -Value "1.2.3"

        $commits = @("feat: add user dashboard", "fix: typo")
        $result = Invoke-VersionBump -VersionFilePath $versionFile -ChangelogPath $changelogFile -Commits $commits -Date "2026-04-09"

        $result | Should -Be "1.3.0"
        Remove-Item -Recurse -Force $tmpDir
    }

    It "performs a full version bump for major/breaking change" {
        $tmpDir = New-Item -ItemType Directory -Path ([System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName())
        $versionFile = Join-Path $tmpDir "version.txt"
        $changelogFile = Join-Path $tmpDir "CHANGELOG.md"
        Set-Content -Path $versionFile -Value "1.2.3"

        $commits = @("feat!: breaking API redesign")
        $result = Invoke-VersionBump -VersionFilePath $versionFile -ChangelogPath $changelogFile -Commits $commits -Date "2026-04-09"

        $result | Should -Be "2.0.0"
        Remove-Item -Recurse -Force $tmpDir
    }
}

Describe "Workflow structure tests" {
    It "workflow file exists" {
        $workflowPath = "$PSScriptRoot/.github/workflows/semantic-version-bumper.yml"
        Test-Path $workflowPath | Should -BeTrue
    }

    It "workflow references existing script file" {
        $workflowPath = "$PSScriptRoot/.github/workflows/semantic-version-bumper.yml"
        $content = Get-Content $workflowPath -Raw
        # Check that the workflow references VersionBumper.ps1
        $content | Should -Match "VersionBumper\.ps1"
        Test-Path "$PSScriptRoot/VersionBumper.ps1" | Should -BeTrue
    }

    It "workflow has required trigger events" {
        $workflowPath = "$PSScriptRoot/.github/workflows/semantic-version-bumper.yml"
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match "push"
    }

    It "workflow has pwsh shell for run steps" {
        $workflowPath = "$PSScriptRoot/.github/workflows/semantic-version-bumper.yml"
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match "shell:\s*pwsh"
    }

    It "actionlint passes on workflow file" {
        $workflowPath = "$PSScriptRoot/.github/workflows/semantic-version-bumper.yml"
        # Skip if actionlint is not installed (e.g., inside the act container)
        if (-not (Get-Command actionlint -ErrorAction SilentlyContinue)) {
            Set-ItResult -Skipped -Because "actionlint not installed in this environment"
            return
        }
        $output = actionlint $workflowPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}
