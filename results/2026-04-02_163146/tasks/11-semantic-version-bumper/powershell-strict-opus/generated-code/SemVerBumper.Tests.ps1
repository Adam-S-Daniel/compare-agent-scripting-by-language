Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Import the module under test
BeforeAll {
    $modulePath = Join-Path $PSScriptRoot 'SemVerBumper.psm1'
    Import-Module $modulePath -Force
}

# TDD Step 1: Tests for parsing version from files
Describe 'Get-SemanticVersion' {
    Context 'When reading a plain version.txt file' {
        It 'Should parse major, minor, and patch from version.txt' {
            $fixtureFile = Join-Path $PSScriptRoot 'fixtures' 'version.txt'
            $result = Get-SemanticVersion -Path $fixtureFile
            $result.Major | Should -Be 1
            $result.Minor | Should -Be 2
            $result.Patch | Should -Be 3
        }

        It 'Should return the raw version string' {
            $fixtureFile = Join-Path $PSScriptRoot 'fixtures' 'version.txt'
            $result = Get-SemanticVersion -Path $fixtureFile
            $result.Raw | Should -Be '1.2.3'
        }
    }

    Context 'When reading a package.json file' {
        It 'Should extract version from package.json' {
            $fixtureFile = Join-Path $PSScriptRoot 'fixtures' 'package.json'
            $result = Get-SemanticVersion -Path $fixtureFile
            $result.Major | Should -Be 2
            $result.Minor | Should -Be 5
            $result.Patch | Should -Be 0
        }

        It 'Should return the raw version string from package.json' {
            $fixtureFile = Join-Path $PSScriptRoot 'fixtures' 'package.json'
            $result = Get-SemanticVersion -Path $fixtureFile
            $result.Raw | Should -Be '2.5.0'
        }
    }

    Context 'When the file does not exist' {
        It 'Should throw a meaningful error' {
            { Get-SemanticVersion -Path 'nonexistent.txt' } | Should -Throw '*does not exist*'
        }
    }

    Context 'When the file contains an invalid version' {
        It 'Should throw on malformed version string' {
            $tempFile = Join-Path $TestDrive 'bad-version.txt'
            Set-Content -Path $tempFile -Value 'not-a-version'
            { Get-SemanticVersion -Path $tempFile } | Should -Throw '*valid semantic version*'
        }
    }
}

# TDD Step 2: Tests for determining bump type from conventional commits
Describe 'Get-BumpType' {
    Context 'When commits contain only fixes' {
        It 'Should return Patch' {
            $commits = @(
                'fix: resolve null reference in user lookup',
                'fix: correct off-by-one error in pagination',
                'fix: handle empty input gracefully'
            )
            $result = Get-BumpType -CommitMessages $commits
            $result | Should -Be 'Patch'
        }
    }

    Context 'When commits contain a feat' {
        It 'Should return Minor' {
            $commits = @(
                'feat: add user search endpoint',
                'fix: correct date formatting in reports',
                'feat: support bulk import of records'
            )
            $result = Get-BumpType -CommitMessages $commits
            $result | Should -Be 'Minor'
        }
    }

    Context 'When commits contain a breaking change with bang syntax' {
        It 'Should return Major for feat! prefix' {
            $commits = @(
                'feat!: redesign authentication API',
                'fix: patch security vulnerability'
            )
            $result = Get-BumpType -CommitMessages $commits
            $result | Should -Be 'Major'
        }
    }

    Context 'When commits contain BREAKING CHANGE footer' {
        It 'Should return Major for BREAKING CHANGE text' {
            $commits = @(
                'feat: add role-based access control',
                'BREAKING CHANGE: remove deprecated v1 endpoints'
            )
            $result = Get-BumpType -CommitMessages $commits
            $result | Should -Be 'Major'
        }
    }

    Context 'When commits contain no feat or fix' {
        It 'Should return None' {
            $commits = @(
                'docs: fix typos in API documentation',
                'chore: update dependencies',
                'style: reformat code to match linting rules'
            )
            $result = Get-BumpType -CommitMessages $commits
            $result | Should -Be 'None'
        }
    }

    Context 'When commit list is empty' {
        It 'Should return None' {
            [string[]]$commits = @()
            $result = Get-BumpType -CommitMessages $commits
            $result | Should -Be 'None'
        }
    }

    Context 'When reading commits from a fixture file' {
        It 'Should detect Minor from mixed commits file' {
            $filePath = Join-Path $PSScriptRoot 'fixtures' 'commits-mixed.txt'
            $commits = Get-CommitMessages -Path $filePath
            $result = Get-BumpType -CommitMessages $commits
            $result | Should -Be 'Minor'
        }

        It 'Should detect Major from major commits file' {
            $filePath = Join-Path $PSScriptRoot 'fixtures' 'commits-major.txt'
            $commits = Get-CommitMessages -Path $filePath
            $result = Get-BumpType -CommitMessages $commits
            $result | Should -Be 'Major'
        }
    }
}

# TDD Step 3: Tests for version bumping
Describe 'Step-SemanticVersion' {
    Context 'When bumping patch version' {
        It 'Should increment patch and keep major.minor' {
            $version = [PSCustomObject]@{ Major = [int]1; Minor = [int]2; Patch = [int]3; Raw = '1.2.3' }
            $result = Step-SemanticVersion -Version $version -BumpType 'Patch'
            $result.Major | Should -Be 1
            $result.Minor | Should -Be 2
            $result.Patch | Should -Be 4
            $result.Raw | Should -Be '1.2.4'
        }
    }

    Context 'When bumping minor version' {
        It 'Should increment minor and reset patch' {
            $version = [PSCustomObject]@{ Major = [int]1; Minor = [int]2; Patch = [int]3; Raw = '1.2.3' }
            $result = Step-SemanticVersion -Version $version -BumpType 'Minor'
            $result.Major | Should -Be 1
            $result.Minor | Should -Be 3
            $result.Patch | Should -Be 0
            $result.Raw | Should -Be '1.3.0'
        }
    }

    Context 'When bumping major version' {
        It 'Should increment major and reset minor and patch' {
            $version = [PSCustomObject]@{ Major = [int]1; Minor = [int]2; Patch = [int]3; Raw = '1.2.3' }
            $result = Step-SemanticVersion -Version $version -BumpType 'Major'
            $result.Major | Should -Be 2
            $result.Minor | Should -Be 0
            $result.Patch | Should -Be 0
            $result.Raw | Should -Be '2.0.0'
        }
    }

    Context 'When bump type is None' {
        It 'Should return the same version unchanged' {
            $version = [PSCustomObject]@{ Major = [int]1; Minor = [int]2; Patch = [int]3; Raw = '1.2.3' }
            $result = Step-SemanticVersion -Version $version -BumpType 'None'
            $result.Raw | Should -Be '1.2.3'
        }
    }

    Context 'When given an invalid bump type' {
        It 'Should throw an error' {
            $version = [PSCustomObject]@{ Major = [int]1; Minor = [int]2; Patch = [int]3; Raw = '1.2.3' }
            # ValidateSet will reject values not in the set
            { Step-SemanticVersion -Version $version -BumpType 'Invalid' } | Should -Throw
        }
    }
}

# TDD Step 4: Tests for changelog generation
Describe 'New-ChangelogEntry' {
    Context 'When generating a changelog from mixed commits' {
        It 'Should include the version header' {
            $commits = @(
                'feat: add user search endpoint',
                'fix: correct date formatting in reports'
            )
            $result = New-ChangelogEntry -Version '1.3.0' -CommitMessages $commits
            $result | Should -Match '## 1\.3\.0'
        }

        It 'Should categorize features under Features heading' {
            $commits = @(
                'feat: add user search endpoint',
                'fix: correct date formatting in reports'
            )
            $result = New-ChangelogEntry -Version '1.3.0' -CommitMessages $commits
            $result | Should -Match '### Features'
            $result | Should -Match 'add user search endpoint'
        }

        It 'Should categorize fixes under Bug Fixes heading' {
            $commits = @(
                'feat: add user search endpoint',
                'fix: correct date formatting in reports'
            )
            $result = New-ChangelogEntry -Version '1.3.0' -CommitMessages $commits
            $result | Should -Match '### Bug Fixes'
            $result | Should -Match 'correct date formatting in reports'
        }
    }

    Context 'When generating a changelog with breaking changes' {
        It 'Should include Breaking Changes section' {
            $commits = @(
                'feat!: redesign authentication API',
                'BREAKING CHANGE: remove deprecated v1 endpoints'
            )
            $result = New-ChangelogEntry -Version '2.0.0' -CommitMessages $commits
            $result | Should -Match '### Breaking Changes'
        }
    }

    Context 'When there are no relevant commits' {
        It 'Should still produce a valid entry with the version header' {
            $commits = @(
                'docs: update README',
                'chore: update deps'
            )
            $result = New-ChangelogEntry -Version '1.2.3' -CommitMessages $commits
            $result | Should -Match '## 1\.2\.3'
        }
    }
}

# TDD Step 5: Tests for updating version files
Describe 'Update-VersionFile' {
    Context 'When updating a version.txt file' {
        It 'Should write the new version to the file' {
            $tempFile = Join-Path $TestDrive 'version.txt'
            Set-Content -Path $tempFile -Value '1.2.3'
            Update-VersionFile -Path $tempFile -NewVersion '1.3.0'
            $content = (Get-Content -Path $tempFile -Raw).Trim()
            $content | Should -Be '1.3.0'
        }
    }

    Context 'When updating a package.json file' {
        It 'Should update the version field in package.json' {
            $tempFile = Join-Path $TestDrive 'package.json'
            $json = @'
{
  "name": "test-project",
  "version": "2.5.0",
  "description": "A test project"
}
'@
            Set-Content -Path $tempFile -Value $json
            Update-VersionFile -Path $tempFile -NewVersion '2.6.0'
            $parsed = Get-Content -Path $tempFile -Raw | ConvertFrom-Json
            $parsed.version | Should -Be '2.6.0'
        }
    }

    Context 'When the file does not exist' {
        It 'Should throw a meaningful error' {
            { Update-VersionFile -Path 'nonexistent.txt' -NewVersion '1.0.0' } | Should -Throw '*does not exist*'
        }
    }
}

# TDD Step 6: Tests for the full workflow
Describe 'Invoke-VersionBump' {
    Context 'Full workflow with patch bump' {
        It 'Should bump patch for fix-only commits' {
            # Set up temp version file
            $tempVersionFile = Join-Path $TestDrive 'version.txt'
            Set-Content -Path $tempVersionFile -Value '1.2.3'

            $commitFile = Join-Path $PSScriptRoot 'fixtures' 'commits-patch.txt'
            $result = Invoke-VersionBump -VersionFilePath $tempVersionFile -CommitLogPath $commitFile

            $result.OldVersion | Should -Be '1.2.3'
            $result.NewVersion | Should -Be '1.2.4'
            $result.BumpType | Should -Be 'Patch'
            $result.Changelog | Should -Not -BeNullOrEmpty

            # Verify file was updated
            $updatedContent = (Get-Content -Path $tempVersionFile -Raw).Trim()
            $updatedContent | Should -Be '1.2.4'
        }
    }

    Context 'Full workflow with minor bump' {
        It 'Should bump minor for feat commits' {
            $tempVersionFile = Join-Path $TestDrive 'version.txt'
            Set-Content -Path $tempVersionFile -Value '1.2.3'

            $commitFile = Join-Path $PSScriptRoot 'fixtures' 'commits-minor.txt'
            $result = Invoke-VersionBump -VersionFilePath $tempVersionFile -CommitLogPath $commitFile

            $result.OldVersion | Should -Be '1.2.3'
            $result.NewVersion | Should -Be '1.3.0'
            $result.BumpType | Should -Be 'Minor'
        }
    }

    Context 'Full workflow with major bump' {
        It 'Should bump major for breaking change commits' {
            $tempVersionFile = Join-Path $TestDrive 'version.txt'
            Set-Content -Path $tempVersionFile -Value '1.2.3'

            $commitFile = Join-Path $PSScriptRoot 'fixtures' 'commits-major.txt'
            $result = Invoke-VersionBump -VersionFilePath $tempVersionFile -CommitLogPath $commitFile

            $result.OldVersion | Should -Be '1.2.3'
            $result.NewVersion | Should -Be '2.0.0'
            $result.BumpType | Should -Be 'Major'
        }
    }

    Context 'Full workflow with no version-relevant commits' {
        It 'Should not bump version when no feat/fix/breaking commits exist' {
            $tempVersionFile = Join-Path $TestDrive 'version.txt'
            Set-Content -Path $tempVersionFile -Value '1.2.3'

            $commitFile = Join-Path $PSScriptRoot 'fixtures' 'commits-none.txt'
            $result = Invoke-VersionBump -VersionFilePath $tempVersionFile -CommitLogPath $commitFile

            $result.OldVersion | Should -Be '1.2.3'
            $result.NewVersion | Should -Be '1.2.3'
            $result.BumpType | Should -Be 'None'
        }
    }

    Context 'Full workflow with package.json' {
        It 'Should bump version in package.json' {
            $tempFile = Join-Path $TestDrive 'package.json'
            $json = @'
{
  "name": "test-project",
  "version": "2.5.0",
  "description": "A test project"
}
'@
            Set-Content -Path $tempFile -Value $json

            $commitFile = Join-Path $PSScriptRoot 'fixtures' 'commits-minor.txt'
            $result = Invoke-VersionBump -VersionFilePath $tempFile -CommitLogPath $commitFile

            $result.OldVersion | Should -Be '2.5.0'
            $result.NewVersion | Should -Be '2.6.0'

            # Verify file was updated
            $parsed = Get-Content -Path $tempFile -Raw | ConvertFrom-Json
            $parsed.version | Should -Be '2.6.0'
        }
    }
}

# TDD Step 7: Tests for reading commit messages from file
Describe 'Get-CommitMessages' {
    Context 'When reading a valid commit log file' {
        It 'Should return an array of non-empty commit messages' {
            $filePath = Join-Path $PSScriptRoot 'fixtures' 'commits-patch.txt'
            $result = Get-CommitMessages -Path $filePath
            $result.Count | Should -Be 3
            $result[0] | Should -Be 'fix: resolve null reference in user lookup'
        }
    }

    Context 'When the file does not exist' {
        It 'Should throw a meaningful error' {
            { Get-CommitMessages -Path 'nonexistent-commits.txt' } | Should -Throw '*does not exist*'
        }
    }
}
