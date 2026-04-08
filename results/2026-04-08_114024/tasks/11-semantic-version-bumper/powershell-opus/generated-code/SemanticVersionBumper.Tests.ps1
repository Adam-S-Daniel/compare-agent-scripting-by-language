# SemanticVersionBumper.Tests.ps1
# Pester tests for the Semantic Version Bumper module.
# TDD approach: each section was written as a failing test first,
# then the corresponding function was implemented to make it pass.

BeforeAll {
    . "$PSScriptRoot/SemanticVersionBumper.ps1"
}

# ---------------------------------------------------------------------------
# TDD Round 1: Parse a semantic version string into its components
# ---------------------------------------------------------------------------
Describe 'ConvertFrom-SemanticVersion' {
    It 'parses a simple version like 1.2.3' {
        $v = ConvertFrom-SemanticVersion '1.2.3'
        $v.Major | Should -Be 1
        $v.Minor | Should -Be 2
        $v.Patch | Should -Be 3
    }

    It 'parses version 0.0.0' {
        $v = ConvertFrom-SemanticVersion '0.0.0'
        $v.Major | Should -Be 0
        $v.Minor | Should -Be 0
        $v.Patch | Should -Be 0
    }

    It 'parses a version with a v prefix' {
        $v = ConvertFrom-SemanticVersion 'v2.10.5'
        $v.Major | Should -Be 2
        $v.Minor | Should -Be 10
        $v.Patch | Should -Be 5
    }

    It 'throws on an invalid version string' {
        { ConvertFrom-SemanticVersion 'not-a-version' } | Should -Throw
    }

    It 'throws on an empty string' {
        { ConvertFrom-SemanticVersion '' } | Should -Throw
    }
}

# ---------------------------------------------------------------------------
# TDD Round 2: Classify conventional commits and determine bump type
# ---------------------------------------------------------------------------
Describe 'Get-ConventionalCommitType' {
    It 'classifies a fix commit as patch' {
        Get-ConventionalCommitType 'fix: correct null pointer' | Should -Be 'patch'
    }

    It 'classifies a scoped fix as patch' {
        Get-ConventionalCommitType 'fix(auth): handle expired tokens' | Should -Be 'patch'
    }

    It 'classifies a feat commit as minor' {
        Get-ConventionalCommitType 'feat: add user profile endpoint' | Should -Be 'minor'
    }

    It 'classifies a breaking feat (!) as major' {
        Get-ConventionalCommitType 'feat!: redesign auth API' | Should -Be 'major'
    }

    It 'classifies a BREAKING CHANGE line as major' {
        Get-ConventionalCommitType 'BREAKING CHANGE: remove /v1 endpoints' | Should -Be 'major'
    }

    It 'classifies a fix with breaking marker as major' {
        Get-ConventionalCommitType 'fix!: remove legacy error codes' | Should -Be 'major'
    }

    It 'classifies docs as none' {
        Get-ConventionalCommitType 'docs: update readme' | Should -Be 'none'
    }

    It 'classifies chore as none' {
        Get-ConventionalCommitType 'chore: bump deps' | Should -Be 'none'
    }

    It 'classifies unknown format as none' {
        Get-ConventionalCommitType 'random commit message' | Should -Be 'none'
    }
}

Describe 'Get-BumpTypeFromCommits' {
    It 'returns patch for fix-only commits' {
        $commits = Get-Content "$PSScriptRoot/fixtures/commits-patch.txt"
        Get-BumpTypeFromCommits $commits | Should -Be 'patch'
    }

    It 'returns minor when feat commits are present' {
        $commits = Get-Content "$PSScriptRoot/fixtures/commits-minor.txt"
        Get-BumpTypeFromCommits $commits | Should -Be 'minor'
    }

    It 'returns major when breaking changes are present' {
        $commits = Get-Content "$PSScriptRoot/fixtures/commits-major.txt"
        Get-BumpTypeFromCommits $commits | Should -Be 'major'
    }

    It 'returns none when no version-relevant commits exist' {
        $commits = Get-Content "$PSScriptRoot/fixtures/commits-none.txt"
        Get-BumpTypeFromCommits $commits | Should -Be 'none'
    }

    It 'returns minor for mixed feat/fix commits' {
        $commits = Get-Content "$PSScriptRoot/fixtures/commits-mixed.txt"
        Get-BumpTypeFromCommits $commits | Should -Be 'minor'
    }

    It 'returns none for empty commit list' {
        Get-BumpTypeFromCommits @() | Should -Be 'none'
    }
}

# ---------------------------------------------------------------------------
# TDD Round 3: Bump a version based on bump type
# ---------------------------------------------------------------------------
Describe 'Step-SemanticVersion' {
    It 'bumps patch: 1.2.3 -> 1.2.4' {
        $result = Step-SemanticVersion '1.2.3' 'patch'
        $result | Should -Be '1.2.4'
    }

    It 'bumps minor: 1.2.3 -> 1.3.0 (resets patch)' {
        $result = Step-SemanticVersion '1.2.3' 'minor'
        $result | Should -Be '1.3.0'
    }

    It 'bumps major: 1.2.3 -> 2.0.0 (resets minor and patch)' {
        $result = Step-SemanticVersion '1.2.3' 'major'
        $result | Should -Be '2.0.0'
    }

    It 'returns the same version for bump type none' {
        $result = Step-SemanticVersion '1.2.3' 'none'
        $result | Should -Be '1.2.3'
    }

    It 'handles v-prefix and returns without prefix' {
        $result = Step-SemanticVersion 'v1.0.0' 'patch'
        $result | Should -Be '1.0.1'
    }

    It 'throws on invalid bump type' {
        { Step-SemanticVersion '1.0.0' 'invalid' } | Should -Throw
    }
}

# ---------------------------------------------------------------------------
# TDD Round 4: Read version from VERSION file or package.json
# ---------------------------------------------------------------------------
Describe 'Read-VersionFile' {
    BeforeEach {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "svb-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:tempDir | Out-Null
    }
    AfterEach {
        Remove-Item -Recurse -Force $script:tempDir -ErrorAction SilentlyContinue
    }

    It 'reads version from a plain VERSION file' {
        Set-Content -Path "$script:tempDir/VERSION" -Value '3.1.4'
        $result = Read-VersionFile "$script:tempDir/VERSION"
        $result | Should -Be '3.1.4'
    }

    It 'reads version from package.json' {
        $json = '{"name":"app","version":"2.5.1","description":"test"}'
        Set-Content -Path "$script:tempDir/package.json" -Value $json
        $result = Read-VersionFile "$script:tempDir/package.json"
        $result | Should -Be '2.5.1'
    }

    It 'trims whitespace from VERSION file' {
        Set-Content -Path "$script:tempDir/VERSION" -Value "  1.0.0  `n"
        $result = Read-VersionFile "$script:tempDir/VERSION"
        $result | Should -Be '1.0.0'
    }

    It 'throws when file does not exist' {
        { Read-VersionFile "$script:tempDir/nonexistent" } | Should -Throw
    }

    It 'throws when package.json has no version field' {
        Set-Content -Path "$script:tempDir/package.json" -Value '{"name":"app"}'
        { Read-VersionFile "$script:tempDir/package.json" } | Should -Throw
    }
}

# ---------------------------------------------------------------------------
# TDD Round 5: Write updated version back to file
# ---------------------------------------------------------------------------
Describe 'Write-VersionFile' {
    BeforeEach {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "svb-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:tempDir | Out-Null
    }
    AfterEach {
        Remove-Item -Recurse -Force $script:tempDir -ErrorAction SilentlyContinue
    }

    It 'writes version to a plain VERSION file' {
        $path = "$script:tempDir/VERSION"
        Set-Content -Path $path -Value '1.0.0'
        Write-VersionFile -Path $path -NewVersion '1.1.0'
        (Get-Content $path -Raw).Trim() | Should -Be '1.1.0'
    }

    It 'updates version in package.json while preserving other fields' {
        $path = "$script:tempDir/package.json"
        $json = '{"name":"app","version":"1.0.0","description":"test"}'
        Set-Content -Path $path -Value $json
        Write-VersionFile -Path $path -NewVersion '1.1.0'
        $updated = Get-Content $path -Raw | ConvertFrom-Json
        $updated.version | Should -Be '1.1.0'
        $updated.name | Should -Be 'app'
        $updated.description | Should -Be 'test'
    }

    It 'throws when file does not exist' {
        { Write-VersionFile -Path "$script:tempDir/missing" -NewVersion '1.0.0' } | Should -Throw
    }
}

# ---------------------------------------------------------------------------
# TDD Round 6: Generate a changelog entry from commit messages
# ---------------------------------------------------------------------------
Describe 'New-ChangelogEntry' {
    It 'groups commits by type with a version header' {
        $commits = @(
            'feat: add search',
            'fix: handle empty query',
            'docs: update readme'
        )
        $entry = New-ChangelogEntry -Version '1.3.0' -Commits $commits
        $entry | Should -Match '## 1.3.0'
        $entry | Should -Match 'Features'
        $entry | Should -Match 'add search'
        $entry | Should -Match 'Bug Fixes'
        $entry | Should -Match 'handle empty query'
    }

    It 'includes a date in the header' {
        $entry = New-ChangelogEntry -Version '1.0.1' -Commits @('fix: a bug')
        $entry | Should -Match '\d{4}-\d{2}-\d{2}'
    }

    It 'handles breaking changes section' {
        $commits = @(
            'feat!: redesign auth API',
            'BREAKING CHANGE: remove /v1 endpoints'
        )
        $entry = New-ChangelogEntry -Version '2.0.0' -Commits $commits
        $entry | Should -Match 'BREAKING CHANGES'
    }

    It 'omits empty sections' {
        $commits = @('fix: a small bug')
        $entry = New-ChangelogEntry -Version '1.0.1' -Commits $commits
        $entry | Should -Not -Match 'Features'
        $entry | Should -Match 'Bug Fixes'
    }

    It 'returns a minimal entry for no relevant commits' {
        $entry = New-ChangelogEntry -Version '1.0.0' -Commits @('chore: update deps')
        $entry | Should -Match '## 1.0.0'
        $entry | Should -Match 'Other'
    }

    It 'strips scope from commit messages in the changelog' {
        $commits = @('feat(ui): add dark mode')
        $entry = New-ChangelogEntry -Version '1.1.0' -Commits $commits
        $entry | Should -Match 'add dark mode'
    }
}

# ---------------------------------------------------------------------------
# TDD Round 7: Integration — Invoke-SemanticVersionBump orchestrates everything
# ---------------------------------------------------------------------------
Describe 'Invoke-SemanticVersionBump' {
    BeforeEach {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "svb-integ-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:tempDir | Out-Null
    }
    AfterEach {
        Remove-Item -Recurse -Force $script:tempDir -ErrorAction SilentlyContinue
    }

    It 'bumps a VERSION file with patch commits' {
        $versionFile = "$script:tempDir/VERSION"
        Set-Content -Path $versionFile -Value '1.0.0'
        $commitFile = "$PSScriptRoot/fixtures/commits-patch.txt"

        $result = Invoke-SemanticVersionBump -VersionFile $versionFile -CommitLogFile $commitFile
        $result.OldVersion | Should -Be '1.0.0'
        $result.NewVersion | Should -Be '1.0.1'
        $result.BumpType   | Should -Be 'patch'
        (Get-Content $versionFile -Raw).Trim() | Should -Be '1.0.1'
    }

    It 'bumps a VERSION file with minor commits' {
        $versionFile = "$script:tempDir/VERSION"
        Set-Content -Path $versionFile -Value '1.0.0'
        $commitFile = "$PSScriptRoot/fixtures/commits-minor.txt"

        $result = Invoke-SemanticVersionBump -VersionFile $versionFile -CommitLogFile $commitFile
        $result.NewVersion | Should -Be '1.1.0'
        $result.BumpType   | Should -Be 'minor'
    }

    It 'bumps a VERSION file with major (breaking) commits' {
        $versionFile = "$script:tempDir/VERSION"
        Set-Content -Path $versionFile -Value '1.2.3'
        $commitFile = "$PSScriptRoot/fixtures/commits-major.txt"

        $result = Invoke-SemanticVersionBump -VersionFile $versionFile -CommitLogFile $commitFile
        $result.NewVersion | Should -Be '2.0.0'
        $result.BumpType   | Should -Be 'major'
    }

    It 'does not bump when no relevant commits exist' {
        $versionFile = "$script:tempDir/VERSION"
        Set-Content -Path $versionFile -Value '1.0.0'
        $commitFile = "$PSScriptRoot/fixtures/commits-none.txt"

        $result = Invoke-SemanticVersionBump -VersionFile $versionFile -CommitLogFile $commitFile
        $result.NewVersion | Should -Be '1.0.0'
        $result.BumpType   | Should -Be 'none'
        (Get-Content $versionFile -Raw).Trim() | Should -Be '1.0.0'
    }

    It 'bumps a package.json file' {
        $pkgFile = "$script:tempDir/package.json"
        Set-Content -Path $pkgFile -Value '{"name":"app","version":"2.5.1","description":"test"}'
        $commitFile = "$PSScriptRoot/fixtures/commits-minor.txt"

        $result = Invoke-SemanticVersionBump -VersionFile $pkgFile -CommitLogFile $commitFile
        $result.NewVersion | Should -Be '2.6.0'
        $pkg = Get-Content $pkgFile -Raw | ConvertFrom-Json
        $pkg.version | Should -Be '2.6.0'
        $pkg.name | Should -Be 'app'
    }

    It 'generates a changelog entry' {
        $versionFile = "$script:tempDir/VERSION"
        Set-Content -Path $versionFile -Value '1.0.0'
        $commitFile = "$PSScriptRoot/fixtures/commits-mixed.txt"

        $result = Invoke-SemanticVersionBump -VersionFile $versionFile -CommitLogFile $commitFile
        $result.Changelog | Should -Match '## 1.1.0'
        $result.Changelog | Should -Match 'Features'
        $result.Changelog | Should -Match 'Bug Fixes'
    }

    It 'throws when version file does not exist' {
        { Invoke-SemanticVersionBump -VersionFile "$script:tempDir/nope" -CommitLogFile "$PSScriptRoot/fixtures/commits-patch.txt" } |
            Should -Throw
    }

    It 'throws when commit log file does not exist' {
        $versionFile = "$script:tempDir/VERSION"
        Set-Content -Path $versionFile -Value '1.0.0'
        { Invoke-SemanticVersionBump -VersionFile $versionFile -CommitLogFile "$script:tempDir/nope.txt" } |
            Should -Throw
    }
}
