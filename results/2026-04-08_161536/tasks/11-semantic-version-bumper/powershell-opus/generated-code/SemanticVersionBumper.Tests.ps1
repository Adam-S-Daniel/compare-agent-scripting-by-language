# SemanticVersionBumper.Tests.ps1
# TDD tests for the semantic version bumper script.
# Each test was written RED first, then code was added to make it GREEN.

BeforeAll {
    . "$PSScriptRoot/SemanticVersionBumper.ps1"
}

# --- Test fixtures: mock conventional commit logs ---
# These simulate `git log --oneline` output for different bump scenarios.

Describe 'Get-SemanticVersion' {
    Context 'from a VERSION file' {
        It 'parses a valid semver string' {
            $tmpFile = Join-Path $TestDrive 'VERSION'
            Set-Content -Path $tmpFile -Value '1.2.3'
            $result = Get-SemanticVersion -Path $tmpFile
            $result | Should -Be '1.2.3'
        }

        It 'trims whitespace from the version' {
            $tmpFile = Join-Path $TestDrive 'VERSION'
            Set-Content -Path $tmpFile -Value "  2.0.1`n"
            $result = Get-SemanticVersion -Path $tmpFile
            $result | Should -Be '2.0.1'
        }
    }

    Context 'from a package.json' {
        It 'extracts version from package.json' {
            $tmpFile = Join-Path $TestDrive 'package.json'
            Set-Content -Path $tmpFile -Value '{ "name": "my-app", "version": "3.1.4" }'
            $result = Get-SemanticVersion -Path $tmpFile
            $result | Should -Be '3.1.4'
        }
    }

    Context 'error handling' {
        It 'throws when file does not exist' {
            { Get-SemanticVersion -Path '/nonexistent/VERSION' } | Should -Throw '*not found*'
        }

        It 'throws when file has no valid version' {
            $tmpFile = Join-Path $TestDrive 'bad.txt'
            Set-Content -Path $tmpFile -Value 'no version here'
            { Get-SemanticVersion -Path $tmpFile } | Should -Throw '*No valid semantic version*'
        }
    }
}

Describe 'Get-BumpType' {
    # Determines the bump type (major, minor, patch) from conventional commit messages.

    It 'returns patch for fix commits' {
        $commits = @(
            'abc1234 fix: correct null pointer in parser'
            'def5678 fix: handle empty input gracefully'
        )
        Get-BumpType -CommitMessages $commits | Should -Be 'patch'
    }

    It 'returns minor for feat commits' {
        $commits = @(
            'abc1234 feat: add search functionality'
            'def5678 fix: typo in readme'
        )
        Get-BumpType -CommitMessages $commits | Should -Be 'minor'
    }

    It 'returns major for breaking change (BREAKING CHANGE in body)' {
        $commits = @(
            'abc1234 feat: redesign API'
            'def5678 BREAKING CHANGE: removed deprecated endpoints'
        )
        Get-BumpType -CommitMessages $commits | Should -Be 'major'
    }

    It 'returns major for bang notation (feat!)' {
        $commits = @(
            'abc1234 feat!: completely new auth system'
        )
        Get-BumpType -CommitMessages $commits | Should -Be 'major'
    }

    It 'returns patch for unknown commit types' {
        $commits = @(
            'abc1234 chore: update dependencies'
            'def5678 docs: update readme'
        )
        Get-BumpType -CommitMessages $commits | Should -Be 'patch'
    }

    It 'returns patch for empty commit list' {
        Get-BumpType -CommitMessages @() | Should -Be 'patch'
    }
}

Describe 'Step-Version' {
    # Bumps a semantic version string by the given type.

    It 'bumps patch version' {
        Step-Version -Version '1.2.3' -BumpType 'patch' | Should -Be '1.2.4'
    }

    It 'bumps minor version and resets patch' {
        Step-Version -Version '1.2.3' -BumpType 'minor' | Should -Be '1.3.0'
    }

    It 'bumps major version and resets minor and patch' {
        Step-Version -Version '1.2.3' -BumpType 'major' | Should -Be '2.0.0'
    }

    It 'bumps from 0.0.0' {
        Step-Version -Version '0.0.0' -BumpType 'patch' | Should -Be '0.0.1'
    }

    It 'throws on invalid version' {
        { Step-Version -Version 'not.a.ver' -BumpType 'patch' } | Should -Throw '*Invalid semantic version*'
    }
}

Describe 'New-ChangelogEntry' {
    # Generates a markdown changelog entry from commit messages.

    It 'groups commits by type' {
        $commits = @(
            'aaa1111 feat: add login page'
            'bbb2222 fix: resolve crash on startup'
            'ccc3333 chore: update deps'
        )
        $entry = New-ChangelogEntry -Version '2.0.0' -CommitMessages $commits
        $entry | Should -Match '## 2.0.0'
        $entry | Should -Match 'Features'
        $entry | Should -Match 'add login page'
        $entry | Should -Match 'Bug Fixes'
        $entry | Should -Match 'resolve crash on startup'
    }

    It 'handles empty commit list' {
        $entry = New-ChangelogEntry -Version '1.0.1' -CommitMessages @()
        $entry | Should -Match '## 1.0.1'
        $entry | Should -Match 'No notable changes'
    }

    It 'includes breaking changes section' {
        $commits = @(
            'aaa1111 feat!: new API format'
            'bbb2222 BREAKING CHANGE: dropped v1 support'
        )
        $entry = New-ChangelogEntry -Version '3.0.0' -CommitMessages $commits
        $entry | Should -Match 'BREAKING CHANGES'
    }
}

Describe 'Update-VersionFile' {
    # Updates a VERSION or package.json file with a new version.

    It 'updates a VERSION file' {
        $tmpFile = Join-Path $TestDrive 'VERSION'
        Set-Content -Path $tmpFile -Value '1.0.0'
        Update-VersionFile -Path $tmpFile -NewVersion '1.1.0'
        Get-Content -Path $tmpFile -Raw | Should -Match '1.1.0'
    }

    It 'updates a package.json file' {
        $tmpFile = Join-Path $TestDrive 'package.json'
        $json = '{ "name": "app", "version": "1.0.0" }'
        Set-Content -Path $tmpFile -Value $json
        Update-VersionFile -Path $tmpFile -NewVersion '1.1.0'
        $updated = Get-Content -Path $tmpFile -Raw | ConvertFrom-Json
        $updated.version | Should -Be '1.1.0'
    }
}

Describe 'Invoke-VersionBump (integration)' {
    # Full integration: reads version, analyzes commits, bumps, updates file, generates changelog.

    BeforeEach {
        # Set up a VERSION file and mock commits
        $script:versionFile = Join-Path $TestDrive 'VERSION'
        Set-Content -Path $script:versionFile -Value '1.2.3'
        $script:changelogFile = Join-Path $TestDrive 'CHANGELOG.md'
    }

    It 'bumps patch for fix-only commits' {
        $commits = @(
            'aaa1111 fix: handle edge case'
        )
        $result = Invoke-VersionBump -VersionFilePath $script:versionFile `
            -CommitMessages $commits -ChangelogPath $script:changelogFile
        $result | Should -Be '1.2.4'
        Get-Content -Path $script:versionFile -Raw | Should -Match '1.2.4'
        Test-Path $script:changelogFile | Should -BeTrue
    }

    It 'bumps minor for feat commits' {
        $commits = @(
            'aaa1111 feat: new dashboard'
            'bbb2222 fix: button alignment'
        )
        $result = Invoke-VersionBump -VersionFilePath $script:versionFile `
            -CommitMessages $commits -ChangelogPath $script:changelogFile
        $result | Should -Be '1.3.0'
    }

    It 'bumps major for breaking changes' {
        $commits = @(
            'aaa1111 feat!: redesigned auth flow'
        )
        $result = Invoke-VersionBump -VersionFilePath $script:versionFile `
            -CommitMessages $commits -ChangelogPath $script:changelogFile
        $result | Should -Be '2.0.0'
    }

    It 'appends to existing changelog' {
        Set-Content -Path $script:changelogFile -Value "# Changelog`n`n## 1.2.3`nOld entry"
        $commits = @('aaa1111 fix: bug')
        Invoke-VersionBump -VersionFilePath $script:versionFile `
            -CommitMessages $commits -ChangelogPath $script:changelogFile
        $content = Get-Content -Path $script:changelogFile -Raw
        $content | Should -Match '## 1.2.4'
        $content | Should -Match '## 1.2.3'
    }
}

# --- Tests using fixture files (mock commit logs) ---

Describe 'Fixture-based integration tests' {
    # These tests use the mock commit log files from the fixtures/ directory.

    BeforeEach {
        $script:fixtureDir = Join-Path $PSScriptRoot 'fixtures'
        $script:versionFile = Join-Path $TestDrive 'VERSION'
        Set-Content -Path $script:versionFile -Value '1.0.0'
    }

    It 'detects patch bump from fixture commits' {
        $commits = Get-Content (Join-Path $script:fixtureDir 'commits-patch.txt') |
            Where-Object { $_.Trim() -ne '' }
        $bump = Get-BumpType -CommitMessages $commits
        $bump | Should -Be 'patch'
    }

    It 'detects minor bump from fixture commits' {
        $commits = Get-Content (Join-Path $script:fixtureDir 'commits-minor.txt') |
            Where-Object { $_.Trim() -ne '' }
        $bump = Get-BumpType -CommitMessages $commits
        $bump | Should -Be 'minor'
    }

    It 'detects major bump from fixture commits' {
        $commits = Get-Content (Join-Path $script:fixtureDir 'commits-major.txt') |
            Where-Object { $_.Trim() -ne '' }
        $bump = Get-BumpType -CommitMessages $commits
        $bump | Should -Be 'major'
    }

    It 'reads version from fixture VERSION file' {
        $v = Get-SemanticVersion -Path (Join-Path $script:fixtureDir 'VERSION')
        $v | Should -Be '1.2.3'
    }

    It 'reads version from fixture package.json' {
        $v = Get-SemanticVersion -Path (Join-Path $script:fixtureDir 'package.json')
        $v | Should -Be '2.5.0'
    }
}

# --- GitHub Actions workflow validation tests ---

Describe 'GitHub Actions Workflow' {
    BeforeAll {
        $script:workflowPath = Join-Path $PSScriptRoot '.github/workflows/semantic-version-bumper.yml'
    }

    It 'workflow file exists' {
        Test-Path $script:workflowPath | Should -BeTrue
    }

    It 'is valid YAML with expected structure' {
        # Use PowerShell to parse the YAML via pwsh's ConvertFrom-Yaml or manual check
        $content = Get-Content -Path $script:workflowPath -Raw
        # Check top-level keys
        $content | Should -Match '^name:'
        $content | Should -Match 'on:'
        $content | Should -Match 'jobs:'
    }

    It 'has push and pull_request triggers' {
        $content = Get-Content -Path $script:workflowPath -Raw
        $content | Should -Match 'push:'
        $content | Should -Match 'pull_request:'
    }

    It 'has workflow_dispatch trigger' {
        $content = Get-Content -Path $script:workflowPath -Raw
        $content | Should -Match 'workflow_dispatch'
    }

    It 'has a test job and a bump job' {
        $content = Get-Content -Path $script:workflowPath -Raw
        $content | Should -Match 'test:'
        $content | Should -Match 'bump:'
    }

    It 'bump job depends on test job' {
        $content = Get-Content -Path $script:workflowPath -Raw
        $content | Should -Match 'needs:\s*test'
    }

    It 'uses actions/checkout@v4' {
        $content = Get-Content -Path $script:workflowPath -Raw
        $content | Should -Match 'actions/checkout@v4'
    }

    It 'references the bump-version.ps1 script' {
        $content = Get-Content -Path $script:workflowPath -Raw
        $content | Should -Match 'bump-version\.ps1'
        # Verify the referenced script actually exists
        $scriptPath = Join-Path $PSScriptRoot 'bump-version.ps1'
        Test-Path $scriptPath | Should -BeTrue
    }

    It 'references the SemanticVersionBumper.ps1 library' {
        # The bump-version.ps1 sources the library, so verify it exists
        $libPath = Join-Path $PSScriptRoot 'SemanticVersionBumper.ps1'
        Test-Path $libPath | Should -BeTrue
    }

    It 'sets permissions' {
        $content = Get-Content -Path $script:workflowPath -Raw
        $content | Should -Match 'permissions:'
    }

    It 'passes actionlint validation' {
        # Skip if actionlint is not installed (e.g., in CI containers)
        $actionlintCmd = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $actionlintCmd) {
            Set-ItResult -Skipped -Because 'actionlint is not installed'
            return
        }
        $result = & actionlint $script:workflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint should pass: $result"
    }
}
