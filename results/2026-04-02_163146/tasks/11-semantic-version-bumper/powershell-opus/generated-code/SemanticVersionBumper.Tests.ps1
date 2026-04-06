# SemanticVersionBumper.Tests.ps1
# Pester tests for the Semantic Version Bumper module.
# Following red/green TDD: each test was written before its implementation.

BeforeAll {
    # Import the module under test
    $ModulePath = Join-Path $PSScriptRoot 'SemanticVersionBumper.psm1'
    Import-Module $ModulePath -Force

    # Path to test fixtures
    $script:FixturesPath = Join-Path $PSScriptRoot 'fixtures'
}

# ============================================================================
# TDD Round 1: Parse version from a plain VERSION file
# RED:  Wrote these tests first; Get-VersionFromFile did not exist yet.
# GREEN: Implemented Get-VersionFromFile to make them pass.
# ============================================================================
Describe 'Get-VersionFromFile' {
    It 'parses a semver string from a plain text VERSION file' {
        $versionFile = Join-Path $script:FixturesPath 'sample-version.txt'
        $result = Get-VersionFromFile -Path $versionFile
        $result | Should -Be '1.2.3'
    }

    It 'trims whitespace and newlines from the version string' {
        $tempFile = Join-Path $TestDrive 'version-whitespace.txt'
        Set-Content -Path $tempFile -Value "  3.0.1  `n"
        $result = Get-VersionFromFile -Path $tempFile
        $result | Should -Be '3.0.1'
    }

    It 'throws an error if the file does not exist' {
        { Get-VersionFromFile -Path '/nonexistent/VERSION' } | Should -Throw '*does not exist*'
    }

    It 'throws an error if the file does not contain a valid semver' {
        $tempFile = Join-Path $TestDrive 'bad-version.txt'
        Set-Content -Path $tempFile -Value 'not-a-version'
        { Get-VersionFromFile -Path $tempFile } | Should -Throw '*valid semantic version*'
    }
}

# ============================================================================
# TDD Round 2: Parse version from package.json
# RED:  Wrote these tests; Get-VersionFromPackageJson did not exist yet.
# GREEN: Implemented Get-VersionFromPackageJson.
# ============================================================================
Describe 'Get-VersionFromPackageJson' {
    It 'extracts the version field from a package.json file' {
        $pkgFile = Join-Path $script:FixturesPath 'sample-package.json'
        $result = Get-VersionFromPackageJson -Path $pkgFile
        $result | Should -Be '2.5.1'
    }

    It 'throws if the file does not exist' {
        { Get-VersionFromPackageJson -Path '/nonexistent/package.json' } | Should -Throw '*does not exist*'
    }

    It 'throws if package.json has no version field' {
        $tempFile = Join-Path $TestDrive 'no-version.json'
        Set-Content -Path $tempFile -Value '{ "name": "test" }'
        { Get-VersionFromPackageJson -Path $tempFile } | Should -Throw '*version*'
    }

    It 'throws if version in package.json is not valid semver' {
        $tempFile = Join-Path $TestDrive 'bad-pkg.json'
        Set-Content -Path $tempFile -Value '{ "name": "test", "version": "banana" }'
        { Get-VersionFromPackageJson -Path $tempFile } | Should -Throw '*valid semantic version*'
    }
}

# ============================================================================
# TDD Round 3: Classify a single conventional commit message
# RED:  Wrote these tests; Get-CommitType did not exist yet.
# GREEN: Implemented Get-CommitType.
# ============================================================================
Describe 'Get-CommitType' {
    It 'classifies a fix commit as patch' {
        $result = Get-CommitType -Message 'fix: resolve null reference'
        $result | Should -Be 'patch'
    }

    It 'classifies a feat commit as minor' {
        $result = Get-CommitType -Message 'feat: add user profile endpoint'
        $result | Should -Be 'minor'
    }

    It 'classifies a feat! commit as major (breaking via bang)' {
        $result = Get-CommitType -Message 'feat!: redesign authentication API'
        $result | Should -Be 'major'
    }

    It 'classifies a fix! commit as major (breaking via bang)' {
        $result = Get-CommitType -Message 'fix!: change error response format'
        $result | Should -Be 'major'
    }

    It 'classifies a commit with BREAKING CHANGE footer as major' {
        $result = Get-CommitType -Message 'feat: migrate to new schema BREAKING CHANGE: old migrations dropped'
        $result | Should -Be 'major'
    }

    It 'classifies a scoped feat commit as minor' {
        $result = Get-CommitType -Message 'feat(api): add pagination support'
        $result | Should -Be 'minor'
    }

    It 'classifies a scoped fix commit as patch' {
        $result = Get-CommitType -Message 'fix(auth): correct token expiry check'
        $result | Should -Be 'patch'
    }

    It 'classifies docs commits as none' {
        $result = Get-CommitType -Message 'docs: update README'
        $result | Should -Be 'none'
    }

    It 'classifies chore commits as none' {
        $result = Get-CommitType -Message 'chore: update dependencies'
        $result | Should -Be 'none'
    }

    It 'classifies unrecognized commits as none' {
        $result = Get-CommitType -Message 'random commit message'
        $result | Should -Be 'none'
    }
}

# ============================================================================
# TDD Round 4: Parse commit log lines into structured objects
# RED:  Wrote these tests; ConvertFrom-CommitLog did not exist yet.
# GREEN: Implemented ConvertFrom-CommitLog.
# ============================================================================
Describe 'ConvertFrom-CommitLog' {
    It 'parses a commit log file into commit objects with hash and message' {
        $logFile = Join-Path $script:FixturesPath 'patch-commits.txt'
        $logContent = Get-Content -Path $logFile -Raw
        $commits = ConvertFrom-CommitLog -LogContent $logContent
        $commits.Count | Should -Be 3
        $commits[0].Hash | Should -Be 'abc1234'
        $commits[0].Message | Should -Be 'fix: resolve null reference in user lookup'
    }

    It 'handles empty input gracefully' {
        $commits = ConvertFrom-CommitLog -LogContent ''
        $commits.Count | Should -Be 0
    }

    It 'skips blank lines in the log' {
        $logContent = "abc1234 feat: add search`n`ndef5678 fix: typo"
        $commits = ConvertFrom-CommitLog -LogContent $logContent
        $commits.Count | Should -Be 2
    }
}

# ============================================================================
# TDD Round 5: Determine the highest-priority bump type from a list of commits
# RED:  Wrote these tests; Get-BumpType did not exist yet.
# GREEN: Implemented Get-BumpType.
# ============================================================================
Describe 'Get-BumpType' {
    It 'returns patch when all commits are fixes' {
        $logFile = Join-Path $script:FixturesPath 'patch-commits.txt'
        $logContent = Get-Content -Path $logFile -Raw
        $result = Get-BumpType -LogContent $logContent
        $result | Should -Be 'patch'
    }

    It 'returns minor when commits include a feat' {
        $logFile = Join-Path $script:FixturesPath 'minor-commits.txt'
        $logContent = Get-Content -Path $logFile -Raw
        $result = Get-BumpType -LogContent $logContent
        $result | Should -Be 'minor'
    }

    It 'returns major when commits include a breaking change (bang syntax)' {
        $logFile = Join-Path $script:FixturesPath 'major-commits.txt'
        $logContent = Get-Content -Path $logFile -Raw
        $result = Get-BumpType -LogContent $logContent
        $result | Should -Be 'major'
    }

    It 'returns major when commits include BREAKING CHANGE footer' {
        $logFile = Join-Path $script:FixturesPath 'breaking-footer-commits.txt'
        $logContent = Get-Content -Path $logFile -Raw
        $result = Get-BumpType -LogContent $logContent
        $result | Should -Be 'major'
    }

    It 'returns none when there are no version-relevant commits' {
        $logContent = "abc1234 docs: update readme`ndef5678 chore: lint"
        $result = Get-BumpType -LogContent $logContent
        $result | Should -Be 'none'
    }

    It 'throws when given null or empty log content' {
        { Get-BumpType -LogContent '' } | Should -Throw '*No commits*'
    }
}

# ============================================================================
# TDD Round 6: Bump a semantic version string
# RED:  Wrote these tests; Step-SemanticVersion did not exist yet.
# GREEN: Implemented Step-SemanticVersion.
# ============================================================================
Describe 'Step-SemanticVersion' {
    It 'bumps patch version (1.2.3 -> 1.2.4)' {
        $result = Step-SemanticVersion -Version '1.2.3' -BumpType 'patch'
        $result | Should -Be '1.2.4'
    }

    It 'bumps minor version and resets patch (1.2.3 -> 1.3.0)' {
        $result = Step-SemanticVersion -Version '1.2.3' -BumpType 'minor'
        $result | Should -Be '1.3.0'
    }

    It 'bumps major version and resets minor and patch (1.2.3 -> 2.0.0)' {
        $result = Step-SemanticVersion -Version '1.2.3' -BumpType 'major'
        $result | Should -Be '2.0.0'
    }

    It 'handles version 0.0.0 correctly for patch bump' {
        $result = Step-SemanticVersion -Version '0.0.0' -BumpType 'patch'
        $result | Should -Be '0.0.1'
    }

    It 'handles version 0.0.0 correctly for major bump' {
        $result = Step-SemanticVersion -Version '0.0.0' -BumpType 'major'
        $result | Should -Be '1.0.0'
    }

    It 'throws on invalid version string' {
        { Step-SemanticVersion -Version 'abc' -BumpType 'patch' } | Should -Throw '*valid semantic version*'
    }

    It 'throws on invalid bump type' {
        { Step-SemanticVersion -Version '1.0.0' -BumpType 'invalid' } | Should -Throw '*Invalid bump type*'
    }

    It 'returns the same version when bump type is none' {
        $result = Step-SemanticVersion -Version '1.2.3' -BumpType 'none'
        $result | Should -Be '1.2.3'
    }
}

# ============================================================================
# TDD Round 7: Update version in files
# RED:  Wrote these tests; Update-VersionFile / Update-PackageJsonVersion didn't exist.
# GREEN: Implemented both functions.
# ============================================================================
Describe 'Update-VersionFile' {
    It 'writes the new version to a plain text file' {
        $tempFile = Join-Path $TestDrive 'VERSION'
        Set-Content -Path $tempFile -Value '1.0.0'
        Update-VersionFile -Path $tempFile -NewVersion '1.1.0'
        $content = (Get-Content -Path $tempFile -Raw).Trim()
        $content | Should -Be '1.1.0'
    }

    It 'throws if the file does not exist' {
        { Update-VersionFile -Path '/nonexistent/VERSION' -NewVersion '1.0.0' } | Should -Throw '*does not exist*'
    }
}

Describe 'Update-PackageJsonVersion' {
    It 'updates the version field in a package.json file' {
        $tempFile = Join-Path $TestDrive 'package.json'
        $content = '{ "name": "test-app", "version": "1.0.0", "description": "test" }'
        Set-Content -Path $tempFile -Value $content
        Update-PackageJsonVersion -Path $tempFile -NewVersion '1.1.0'
        $pkg = Get-Content -Path $tempFile -Raw | ConvertFrom-Json
        $pkg.version | Should -Be '1.1.0'
    }

    It 'preserves other fields in package.json' {
        $tempFile = Join-Path $TestDrive 'package2.json'
        $content = '{ "name": "my-app", "version": "2.0.0", "description": "sample" }'
        Set-Content -Path $tempFile -Value $content
        Update-PackageJsonVersion -Path $tempFile -NewVersion '3.0.0'
        $pkg = Get-Content -Path $tempFile -Raw | ConvertFrom-Json
        $pkg.name | Should -Be 'my-app'
        $pkg.description | Should -Be 'sample'
    }

    It 'throws if the file does not exist' {
        { Update-PackageJsonVersion -Path '/nonexistent/package.json' -NewVersion '1.0.0' } | Should -Throw '*does not exist*'
    }
}

# ============================================================================
# TDD Round 8: Generate changelog entry from commits
# RED:  Wrote these tests; New-ChangelogEntry did not exist yet.
# GREEN: Implemented New-ChangelogEntry.
# ============================================================================
Describe 'New-ChangelogEntry' {
    It 'generates a changelog with the new version as a heading' {
        $logFile = Join-Path $script:FixturesPath 'mixed-commits.txt'
        $logContent = Get-Content -Path $logFile -Raw
        $entry = New-ChangelogEntry -Version '1.3.0' -LogContent $logContent
        $entry | Should -Match '## 1.3.0'
    }

    It 'groups features under a Features section' {
        $logFile = Join-Path $script:FixturesPath 'mixed-commits.txt'
        $logContent = Get-Content -Path $logFile -Raw
        $entry = New-ChangelogEntry -Version '1.3.0' -LogContent $logContent
        $entry | Should -Match 'Features'
        $entry | Should -Match 'add search functionality'
    }

    It 'groups fixes under a Bug Fixes section' {
        $logFile = Join-Path $script:FixturesPath 'mixed-commits.txt'
        $logContent = Get-Content -Path $logFile -Raw
        $entry = New-ChangelogEntry -Version '1.3.0' -LogContent $logContent
        $entry | Should -Match 'Bug Fixes'
        $entry | Should -Match 'resolve memory leak in cache'
    }

    It 'includes a date in the heading' {
        $logContent = "abc1234 feat: add thing"
        $entry = New-ChangelogEntry -Version '1.0.0' -LogContent $logContent
        # Should contain a date pattern like YYYY-MM-DD
        $entry | Should -Match '\d{4}-\d{2}-\d{2}'
    }

    It 'handles commits with no features or fixes gracefully' {
        $logContent = "abc1234 docs: update readme`ndef5678 chore: lint"
        $entry = New-ChangelogEntry -Version '1.0.0' -LogContent $logContent
        $entry | Should -Match '## 1.0.0'
        # Should still produce a valid entry even with no feat/fix sections
        $entry | Should -Match 'Other'
    }

    It 'includes breaking changes in a dedicated section' {
        $logFile = Join-Path $script:FixturesPath 'major-commits.txt'
        $logContent = Get-Content -Path $logFile -Raw
        $entry = New-ChangelogEntry -Version '2.0.0' -LogContent $logContent
        $entry | Should -Match 'BREAKING CHANGES'
    }
}

# ============================================================================
# TDD Round 9: Main orchestration - Invoke-SemanticVersionBump
# RED:  Wrote these tests; Invoke-SemanticVersionBump did not exist yet.
# GREEN: Implemented Invoke-SemanticVersionBump.
# ============================================================================
Describe 'Invoke-SemanticVersionBump' {
    It 'bumps a VERSION file based on patch commits and returns new version' {
        # Setup: create a temp VERSION file and use patch commit fixtures
        $tempVersion = Join-Path $TestDrive 'VERSION'
        Set-Content -Path $tempVersion -Value '1.2.3'
        $logFile = Join-Path $script:FixturesPath 'patch-commits.txt'
        $logContent = Get-Content -Path $logFile -Raw

        $result = Invoke-SemanticVersionBump -VersionFilePath $tempVersion -CommitLog $logContent
        $result.OldVersion | Should -Be '1.2.3'
        $result.NewVersion | Should -Be '1.2.4'
        $result.BumpType | Should -Be 'patch'
        # Verify the file was actually updated
        (Get-Content -Path $tempVersion -Raw).Trim() | Should -Be '1.2.4'
    }

    It 'bumps a VERSION file based on minor commits' {
        $tempVersion = Join-Path $TestDrive 'VERSION-minor'
        Set-Content -Path $tempVersion -Value '1.2.3'
        $logFile = Join-Path $script:FixturesPath 'minor-commits.txt'
        $logContent = Get-Content -Path $logFile -Raw

        $result = Invoke-SemanticVersionBump -VersionFilePath $tempVersion -CommitLog $logContent
        $result.NewVersion | Should -Be '1.3.0'
        $result.BumpType | Should -Be 'minor'
    }

    It 'bumps a VERSION file based on major commits' {
        $tempVersion = Join-Path $TestDrive 'VERSION-major'
        Set-Content -Path $tempVersion -Value '1.2.3'
        $logFile = Join-Path $script:FixturesPath 'major-commits.txt'
        $logContent = Get-Content -Path $logFile -Raw

        $result = Invoke-SemanticVersionBump -VersionFilePath $tempVersion -CommitLog $logContent
        $result.NewVersion | Should -Be '2.0.0'
        $result.BumpType | Should -Be 'major'
    }

    It 'bumps a package.json based on feat commits' {
        $tempPkg = Join-Path $TestDrive 'package.json'
        $content = '{ "name": "test-app", "version": "0.9.5", "description": "test" }'
        Set-Content -Path $tempPkg -Value $content
        $logFile = Join-Path $script:FixturesPath 'minor-commits.txt'
        $logContent = Get-Content -Path $logFile -Raw

        $result = Invoke-SemanticVersionBump -PackageJsonPath $tempPkg -CommitLog $logContent
        $result.NewVersion | Should -Be '0.10.0'
        $result.BumpType | Should -Be 'minor'
        # Verify the file was updated
        $pkg = Get-Content -Path $tempPkg -Raw | ConvertFrom-Json
        $pkg.version | Should -Be '0.10.0'
    }

    It 'returns a changelog entry in the result' {
        $tempVersion = Join-Path $TestDrive 'VERSION-cl'
        Set-Content -Path $tempVersion -Value '1.0.0'
        $logFile = Join-Path $script:FixturesPath 'mixed-commits.txt'
        $logContent = Get-Content -Path $logFile -Raw

        $result = Invoke-SemanticVersionBump -VersionFilePath $tempVersion -CommitLog $logContent
        $result.Changelog | Should -Not -BeNullOrEmpty
        $result.Changelog | Should -Match '## 1.1.0'
    }

    It 'does not bump when there are no relevant commits' {
        $tempVersion = Join-Path $TestDrive 'VERSION-none'
        Set-Content -Path $tempVersion -Value '1.0.0'
        $logContent = "abc1234 docs: update readme`ndef5678 chore: lint"

        $result = Invoke-SemanticVersionBump -VersionFilePath $tempVersion -CommitLog $logContent
        $result.NewVersion | Should -Be '1.0.0'
        $result.BumpType | Should -Be 'none'
    }

    It 'throws when neither VersionFilePath nor PackageJsonPath is provided' {
        { Invoke-SemanticVersionBump -CommitLog 'abc1234 fix: something' } | Should -Throw '*version file*'
    }

    It 'throws when CommitLog is empty' {
        $tempVersion = Join-Path $TestDrive 'VERSION-empty'
        Set-Content -Path $tempVersion -Value '1.0.0'
        { Invoke-SemanticVersionBump -VersionFilePath $tempVersion -CommitLog '' } | Should -Throw '*No commits*'
    }
}
