# SemanticVersionBumper.Tests.ps1
# Pester tests for the semantic version bumper module.
# Tests are organized by function, following TDD red/green/refactor.

BeforeAll {
    # Import the module under test
    $ModulePath = Join-Path $PSScriptRoot 'SemanticVersionBumper.psm1'
    Import-Module $ModulePath -Force
    $FixturesPath = Join-Path $PSScriptRoot 'fixtures'
}

# =============================================================================
# TDD Round 1: Read-Version - Parse version from files
# =============================================================================
Describe 'Read-Version' {
    Context 'when reading from a plain text version file' {
        It 'should parse major.minor.patch from version.txt' {
            $version = Read-Version -Path (Join-Path $FixturesPath 'version.txt')
            $version | Should -Not -BeNullOrEmpty
            $version.Major | Should -Be 1
            $version.Minor | Should -Be 2
            $version.Patch | Should -Be 3
        }
    }

    Context 'when reading from package.json' {
        It 'should parse version from the JSON version field' {
            $version = Read-Version -Path (Join-Path $FixturesPath 'package.json')
            $version.Major | Should -Be 2
            $version.Minor | Should -Be 0
            $version.Patch | Should -Be 1
        }
    }

    Context 'when the file does not exist' {
        It 'should throw a meaningful error' {
            { Read-Version -Path '/nonexistent/file.txt' } | Should -Throw '*does not exist*'
        }
    }

    Context 'when the file has no valid version' {
        It 'should throw a meaningful error for invalid content' {
            $tmp = Join-Path $TestDrive 'bad-version.txt'
            Set-Content -Path $tmp -Value 'not-a-version'
            { Read-Version -Path $tmp } | Should -Throw '*Could not parse*'
        }
    }
}

# =============================================================================
# TDD Round 2: Get-BumpType - Determine bump type from conventional commits
# =============================================================================
Describe 'Get-BumpType' {
    Context 'with only fix commits' {
        It 'should return patch' {
            $commits = Get-Content (Join-Path $FixturesPath 'commits-patch.log')
            $result = Get-BumpType -CommitMessages $commits
            $result | Should -Be 'patch'
        }
    }

    Context 'with feat commits (and fixes)' {
        It 'should return minor' {
            $commits = Get-Content (Join-Path $FixturesPath 'commits-minor.log')
            $result = Get-BumpType -CommitMessages $commits
            $result | Should -Be 'minor'
        }
    }

    Context 'with breaking change (! suffix)' {
        It 'should return major' {
            $commits = Get-Content (Join-Path $FixturesPath 'commits-major.log')
            $result = Get-BumpType -CommitMessages $commits
            $result | Should -Be 'major'
        }
    }

    Context 'with BREAKING CHANGE in commit message body' {
        It 'should return major' {
            $commits = Get-Content (Join-Path $FixturesPath 'commits-breaking-footer.log')
            $result = Get-BumpType -CommitMessages $commits
            $result | Should -Be 'major'
        }
    }

    Context 'with no conventional commits (chore, docs, style only)' {
        It 'should return none' {
            $commits = Get-Content (Join-Path $FixturesPath 'commits-mixed.log')
            $result = Get-BumpType -CommitMessages $commits
            $result | Should -Be 'none'
        }
    }

    Context 'with empty commit list' {
        It 'should return none' {
            $result = Get-BumpType -CommitMessages @()
            $result | Should -Be 'none'
        }
    }
}

# =============================================================================
# TDD Round 3: Get-NextVersion - Compute the bumped version
# =============================================================================
Describe 'Get-NextVersion' {
    It 'should bump patch version for patch type' {
        $current = [PSCustomObject]@{ Major = 1; Minor = 2; Patch = 3 }
        $next = Get-NextVersion -Version $current -BumpType 'patch'
        $next | Should -Be '1.2.4'
    }

    It 'should bump minor version and reset patch for minor type' {
        $current = [PSCustomObject]@{ Major = 1; Minor = 2; Patch = 3 }
        $next = Get-NextVersion -Version $current -BumpType 'minor'
        $next | Should -Be '1.3.0'
    }

    It 'should bump major version and reset minor+patch for major type' {
        $current = [PSCustomObject]@{ Major = 1; Minor = 2; Patch = 3 }
        $next = Get-NextVersion -Version $current -BumpType 'major'
        $next | Should -Be '2.0.0'
    }

    It 'should return current version string for none type' {
        $current = [PSCustomObject]@{ Major = 1; Minor = 2; Patch = 3 }
        $next = Get-NextVersion -Version $current -BumpType 'none'
        $next | Should -Be '1.2.3'
    }

    It 'should throw on invalid bump type' {
        $current = [PSCustomObject]@{ Major = 1; Minor = 0; Patch = 0 }
        { Get-NextVersion -Version $current -BumpType 'invalid' } | Should -Throw '*Invalid bump type*'
    }
}

# =============================================================================
# TDD Round 4: New-ChangelogEntry - Generate changelog from commits
# =============================================================================
Describe 'New-ChangelogEntry' {
    It 'should group features and fixes into sections' {
        $commits = Get-Content (Join-Path $FixturesPath 'commits-minor.log')
        $entry = New-ChangelogEntry -CommitMessages $commits -Version '1.3.0'
        # Should contain version header
        $entry | Should -Match '1\.3\.0'
        # Should list features
        $entry | Should -Match 'add user authentication module'
        $entry | Should -Match 'add password reset flow'
        # Should list fixes
        $entry | Should -Match 'correct validation logic'
    }

    It 'should include breaking changes section' {
        $commits = Get-Content (Join-Path $FixturesPath 'commits-major.log')
        $entry = New-ChangelogEntry -CommitMessages $commits -Version '2.0.0'
        $entry | Should -Match 'BREAKING'
        $entry | Should -Match 'redesign API endpoints'
    }

    It 'should handle empty commit list gracefully' {
        $entry = New-ChangelogEntry -CommitMessages @() -Version '1.0.0'
        $entry | Should -Match '1\.0\.0'
        $entry | Should -Match 'No notable changes'
    }
}

# =============================================================================
# TDD Round 5: Write-Version - Update the version file on disk
# =============================================================================
Describe 'Write-Version' {
    It 'should update a plain text version file' {
        $tmp = Join-Path $TestDrive 'version.txt'
        Set-Content -Path $tmp -Value '1.0.0'
        Write-Version -Path $tmp -NewVersion '1.1.0'
        $content = (Get-Content -Path $tmp -Raw).Trim()
        $content | Should -Be '1.1.0'
    }

    It 'should update the version field in package.json without losing other fields' {
        $tmp = Join-Path $TestDrive 'package.json'
        $json = @{ name = 'my-app'; version = '1.0.0'; description = 'test' } | ConvertTo-Json
        Set-Content -Path $tmp -Value $json
        Write-Version -Path $tmp -NewVersion '2.0.0'
        $updated = Get-Content -Path $tmp -Raw | ConvertFrom-Json
        $updated.version | Should -Be '2.0.0'
        $updated.name | Should -Be 'my-app'
        $updated.description | Should -Be 'test'
    }

    It 'should throw if the file does not exist' {
        { Write-Version -Path '/nonexistent/version.txt' -NewVersion '1.0.0' } | Should -Throw '*does not exist*'
    }
}

# =============================================================================
# TDD Round 6: Workflow structure tests
# =============================================================================
Describe 'GitHub Actions Workflow Structure' {
    BeforeAll {
        $workflowPath = Join-Path $PSScriptRoot '.github/workflows/semantic-version-bumper.yml'
        # Use pwsh-native YAML parsing via ConvertFrom-Yaml or manual parsing
        # Since PowerShell doesn't have built-in YAML, we parse key structure manually
        $workflowContent = Get-Content -LiteralPath $workflowPath -Raw
        $workflowLines = Get-Content -LiteralPath $workflowPath
    }

    It 'should have the workflow YAML file' {
        $workflowPath | Should -Exist
    }

    It 'should have a name field' {
        $workflowContent | Should -Match '^name:'
    }

    It 'should have push trigger on main or master' {
        $workflowContent | Should -Match 'push:'
        $workflowContent | Should -Match 'branches:.*\[.*ma(in|ster)'
    }

    It 'should have pull_request trigger' {
        $workflowContent | Should -Match 'pull_request:'
    }

    It 'should have workflow_dispatch trigger' {
        $workflowContent | Should -Match 'workflow_dispatch:'
    }

    It 'should have a version-bump job' {
        $workflowContent | Should -Match 'version-bump:'
    }

    It 'should have a test job' {
        $workflowContent | Should -Match 'test:'
    }

    It 'should use actions/checkout@v4' {
        $workflowContent | Should -Match 'actions/checkout@v4'
    }

    It 'should reference our script files that exist' {
        # The workflow should reference Invoke-VersionBump.ps1
        $workflowContent | Should -Match 'Invoke-VersionBump\.ps1'
        # The script file must exist
        Join-Path $PSScriptRoot 'Invoke-VersionBump.ps1' | Should -Exist
        # The module must exist
        Join-Path $PSScriptRoot 'SemanticVersionBumper.psm1' | Should -Exist
    }

    It 'should reference the fixtures directory' {
        $workflowContent | Should -Match 'fixtures/'
        Join-Path $PSScriptRoot 'fixtures' | Should -Exist
    }

    It 'should pass actionlint validation' -Skip:(-not (Get-Command 'actionlint' -ErrorAction SilentlyContinue)) {
        $lintResult = & actionlint $workflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint should pass: $lintResult"
    }
}

# =============================================================================
# TDD Round 7: Act execution test (runs workflow in Docker)
# Skipped when 'act' is not available (e.g. inside CI containers)
# =============================================================================
Describe 'Act Workflow Execution' -Skip:(-not (Get-Command 'act' -ErrorAction SilentlyContinue)) {
    BeforeAll {
        $ProjectRoot = $PSScriptRoot
        $actResultFile = Join-Path $ProjectRoot 'act-result.txt'

        # Create a temp directory, init a git repo, copy project files, run act
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        # Copy all project files into the temp repo
        Copy-Item -Path (Join-Path $ProjectRoot '*') -Destination $tempDir -Recurse -Force
        Copy-Item -Path (Join-Path $ProjectRoot '.github') -Destination $tempDir -Recurse -Force

        # Init git repo and run act
        Push-Location $tempDir
        git init 2>&1 | Out-Null
        git add -A 2>&1 | Out-Null
        git commit -m "test" 2>&1 | Out-Null

        # Run act and capture output + exit code
        $actOutput = & act push --rm 2>&1 | Out-String
        $script:actExitCode = $LASTEXITCODE
        Pop-Location

        # Save output to act-result.txt in the project root
        Set-Content -Path $actResultFile -Value $actOutput

        # Clean up temp directory
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'should produce act-result.txt in the project directory' {
        $actResultFile = Join-Path $PSScriptRoot 'act-result.txt'
        $actResultFile | Should -Exist
    }

    It 'should exit with code 0' {
        $script:actExitCode | Should -Be 0
    }

    It 'should show version-bump job succeeded' {
        $content = Get-Content (Join-Path $PSScriptRoot 'act-result.txt') -Raw
        $content | Should -Match 'version-bump.*Job succeeded'
    }

    It 'should show test job succeeded' {
        $content = Get-Content (Join-Path $PSScriptRoot 'act-result.txt') -Raw
        $content | Should -Match 'test.*Job succeeded'
    }

    It 'should output the correct bumped version 0.2.0' {
        $content = Get-Content (Join-Path $PSScriptRoot 'act-result.txt') -Raw
        # The version bumper uses commits-minor.log on a 0.1.0 base -> expect 0.2.0
        $content | Should -Match 'New version: 0\.2\.0'
        $content | Should -Match 'NEW_VERSION=0\.2\.0'
    }

    It 'should show version verification passed' {
        $content = Get-Content (Join-Path $PSScriptRoot 'act-result.txt') -Raw
        $content | Should -Match 'Version bump verified: 0\.2\.0'
    }

    It 'should show correct bump type as minor' {
        $content = Get-Content (Join-Path $PSScriptRoot 'act-result.txt') -Raw
        $content | Should -Match 'Bump type: minor'
    }

    It 'should show Pester tests passed in the test job' {
        $content = Get-Content (Join-Path $PSScriptRoot 'act-result.txt') -Raw
        # Inside CI, actionlint/act are not available so those tests are skipped.
        # The unit tests (21) + workflow structure tests without actionlint (10) should pass.
        # We assert that no tests failed.
        $content | Should -Match 'Failed: 0'
    }

    It 'should show changelog with features section' {
        $content = Get-Content (Join-Path $PSScriptRoot 'act-result.txt') -Raw
        $content | Should -Match 'add user authentication module'
        $content | Should -Match 'add password reset flow'
    }
}
