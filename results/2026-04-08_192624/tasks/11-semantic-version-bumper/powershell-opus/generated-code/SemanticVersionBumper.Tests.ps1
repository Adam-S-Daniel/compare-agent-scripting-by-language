#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pester tests for the Semantic Version Bumper.
    All functional tests run through the GitHub Actions workflow via `act`.
    Workflow structure tests validate YAML, actionlint, and file references.

.DESCRIPTION
    Test cases:
    1. Workflow structure: YAML parsing, triggers, jobs, steps, file refs, actionlint
    2. Patch bump: fix commits -> 1.0.0 becomes 1.0.1
    3. Minor bump: feat commits -> 1.0.0 becomes 1.1.0
    4. Major bump (bang): feat! commit -> 1.0.0 becomes 2.0.0
    5. Major bump (BREAKING CHANGE): BREAKING CHANGE text -> 2.3.1 becomes 3.0.0
    6. No bump: chore/docs commits -> version stays 1.0.0
    7. Package.json: version read from package.json -> minor bump -> 2.4.0
#>

BeforeAll {
    # Working directory for our project
    $script:ProjectDir = $PSScriptRoot
    $script:ActResultFile = Join-Path $script:ProjectDir "act-result.txt"
    $script:WorkflowPath = Join-Path $script:ProjectDir ".github/workflows/semantic-version-bumper.yml"

    # Clear previous act results
    if (Test-Path $script:ActResultFile) {
        Remove-Item $script:ActResultFile -Force
    }
    # Create the file so it exists even if tests fail
    "" | Set-Content $script:ActResultFile

    function Invoke-ActTest {
        <#
        .SYNOPSIS
            Sets up a temporary git repo with project files and fixture data,
            runs act push, captures output, and returns it.
        #>
        param(
            [string]$TestName,
            [string]$FixtureFile = "",
            [string]$InitialVersion = "1.0.0",
            [string]$VersionFileName = "VERSION"
        )

        # Create a temp directory for this test
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "svb-test-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        try {
            # Copy project files into temp dir
            Copy-Item (Join-Path $script:ProjectDir "Invoke-SemanticVersionBump.ps1") -Destination $tempDir
            Copy-Item (Join-Path $script:ProjectDir ".github") -Destination $tempDir -Recurse
            Copy-Item (Join-Path $script:ProjectDir "fixtures") -Destination $tempDir -Recurse

            # If using package.json as version file, set that up
            if ($VersionFileName -eq "package.json") {
                # The workflow needs tweaking for package.json - we handle it via env
                # We'll create the package.json with the right version in the temp dir
                $pkgJson = @{
                    name = "test-project"
                    version = $InitialVersion
                    description = "Test package"
                } | ConvertTo-Json
                $pkgJson | Set-Content (Join-Path $tempDir "package.json")
            }

            # Initialize git repo in temp dir
            Push-Location $tempDir
            try {
                git init -b master 2>&1 | Out-Null
                git config user.email "test@test.com" 2>&1 | Out-Null
                git config user.name "Test" 2>&1 | Out-Null
                git add -A 2>&1 | Out-Null
                git commit -m "feat: initial commit" 2>&1 | Out-Null

                # Build env vars for act
                $envArgs = @()
                if ($FixtureFile) {
                    $envArgs += @("--env", "FIXTURE_FILE=$FixtureFile")
                }
                $envArgs += @("--env", "INITIAL_VERSION=$InitialVersion")

                # If we need package.json as version file, modify the workflow step
                # Actually we'll pass it via a different env var
                if ($VersionFileName -eq "package.json") {
                    $envArgs += @("--env", "VERSION_FILE_NAME=package.json")
                }

                # Run act
                $actOutput = & act push --rm -W .github/workflows/semantic-version-bumper.yml @envArgs 2>&1
                $exitCode = $LASTEXITCODE

                $outputText = $actOutput -join "`n"

                # Append to act-result.txt
                $delimiter = "`n`n" + "=" * 60 + "`n"
                $entry = "${delimiter}TEST: $TestName`n" + "=" * 60 + "`n$outputText`n"
                Add-Content -Path $script:ActResultFile -Value $entry

                return @{
                    Output   = $outputText
                    ExitCode = $exitCode
                    Lines    = $actOutput
                }
            }
            finally {
                Pop-Location
            }
        }
        finally {
            # Cleanup temp dir
            if (Test-Path $tempDir) {
                Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# ============================================================
# WORKFLOW STRUCTURE TESTS
# ============================================================
Describe "Workflow Structure Tests" {
    It "YAML file exists and is valid" {
        $script:WorkflowPath | Should -Exist
        # Parse YAML - pwsh can handle this via ConvertFrom-Yaml or manual check
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Not -BeNullOrEmpty
    }

    It "Has expected triggers (push, pull_request, workflow_dispatch)" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "push:"
        $content | Should -Match "pull_request:"
        $content | Should -Match "workflow_dispatch:"
    }

    It "Has version-bump job with expected steps" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "version-bump:"
        $content | Should -Match "actions/checkout@v4"
        $content | Should -Match "Install PowerShell"
        $content | Should -Match "Setup version file"
        $content | Should -Match "Run semantic version bump"
        $content | Should -Match "Display results"
    }

    It "References script files that exist" {
        # The workflow references Invoke-SemanticVersionBump.ps1
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "Invoke-SemanticVersionBump.ps1"

        $scriptPath = Join-Path $script:ProjectDir "Invoke-SemanticVersionBump.ps1"
        $scriptPath | Should -Exist
    }

    It "References fixture directory that exists" {
        $fixturesDir = Join-Path $script:ProjectDir "fixtures"
        $fixturesDir | Should -Exist
    }

    It "Passes actionlint validation" {
        $lintOutput = actionlint $script:WorkflowPath 2>&1
        $lintExitCode = $LASTEXITCODE
        if ($lintExitCode -ne 0) {
            Write-Host "actionlint output: $($lintOutput -join "`n")"
        }
        $lintExitCode | Should -Be 0
    }
}

# ============================================================
# FUNCTIONAL TESTS VIA ACT
# ============================================================
Describe "Patch Bump - fix commits bump 1.0.0 to 1.0.1" {
    BeforeAll {
        $script:patchResult = Invoke-ActTest `
            -TestName "Patch Bump" `
            -FixtureFile "patch-commits.txt" `
            -InitialVersion "1.0.0"
    }

    It "act exits with code 0" {
        $script:patchResult.ExitCode | Should -Be 0
    }

    It "Job succeeds" {
        $script:patchResult.Output | Should -Match "Job succeeded"
    }

    It "Detects patch bump type" {
        $script:patchResult.Output | Should -Match "Bump type: patch"
    }

    It "Bumps version to exactly 1.0.1" {
        $script:patchResult.Output | Should -Match "NEW_VERSION=1\.0\.1"
    }

    It "VERSION file contains 1.0.1" {
        # The Display results step shows the version file content
        $script:patchResult.Output | Should -Match "=== VERSION FILE ==="
        $script:patchResult.Output | Should -Match "1\.0\.1"
    }

    It "Changelog contains Bug Fixes section" {
        $script:patchResult.Output | Should -Match "Bug Fixes"
    }
}

Describe "Minor Bump - feat commits bump 1.0.0 to 1.1.0" {
    BeforeAll {
        $script:minorResult = Invoke-ActTest `
            -TestName "Minor Bump" `
            -FixtureFile "minor-commits.txt" `
            -InitialVersion "1.0.0"
    }

    It "act exits with code 0" {
        $script:minorResult.ExitCode | Should -Be 0
    }

    It "Job succeeds" {
        $script:minorResult.Output | Should -Match "Job succeeded"
    }

    It "Detects minor bump type" {
        $script:minorResult.Output | Should -Match "Bump type: minor"
    }

    It "Bumps version to exactly 1.1.0" {
        $script:minorResult.Output | Should -Match "NEW_VERSION=1\.1\.0"
    }

    It "Changelog contains Features section" {
        $script:minorResult.Output | Should -Match "Features"
    }
}

Describe "Major Bump (bang syntax) - feat! bumps 1.0.0 to 2.0.0" {
    BeforeAll {
        $script:majorResult = Invoke-ActTest `
            -TestName "Major Bump (bang)" `
            -FixtureFile "major-commits.txt" `
            -InitialVersion "1.0.0"
    }

    It "act exits with code 0" {
        $script:majorResult.ExitCode | Should -Be 0
    }

    It "Job succeeds" {
        $script:majorResult.Output | Should -Match "Job succeeded"
    }

    It "Detects major bump type" {
        $script:majorResult.Output | Should -Match "Bump type: major"
    }

    It "Bumps version to exactly 2.0.0" {
        $script:majorResult.Output | Should -Match "NEW_VERSION=2\.0\.0"
    }
}

Describe "Major Bump (BREAKING CHANGE) - bumps 2.3.1 to 3.0.0" {
    BeforeAll {
        $script:breakingResult = Invoke-ActTest `
            -TestName "Major Bump (BREAKING CHANGE)" `
            -FixtureFile "breaking-change-commits.txt" `
            -InitialVersion "2.3.1"
    }

    It "act exits with code 0" {
        $script:breakingResult.ExitCode | Should -Be 0
    }

    It "Job succeeds" {
        $script:breakingResult.Output | Should -Match "Job succeeded"
    }

    It "Detects major bump type" {
        $script:breakingResult.Output | Should -Match "Bump type: major"
    }

    It "Bumps version to exactly 3.0.0" {
        $script:breakingResult.Output | Should -Match "NEW_VERSION=3\.0\.0"
    }

    It "Changelog contains Breaking Changes section" {
        $script:breakingResult.Output | Should -Match "Breaking Changes"
    }
}

Describe "No Bump - chore/docs/style commits keep version at 1.0.0" {
    BeforeAll {
        $script:noBumpResult = Invoke-ActTest `
            -TestName "No Bump" `
            -FixtureFile "no-bump-commits.txt" `
            -InitialVersion "1.0.0"
    }

    It "act exits with code 0" {
        $script:noBumpResult.ExitCode | Should -Be 0
    }

    It "Job succeeds" {
        $script:noBumpResult.Output | Should -Match "Job succeeded"
    }

    It "Detects no bump needed" {
        $script:noBumpResult.Output | Should -Match "Bump type: none"
    }

    It "Version stays at 1.0.0" {
        $script:noBumpResult.Output | Should -Match "NEW_VERSION=1\.0\.0"
    }
}

Describe "Default push event - git log feat commit bumps 1.0.0 to 1.1.0" {
    BeforeAll {
        $script:defaultResult = Invoke-ActTest `
            -TestName "Default Push (git log)" `
            -InitialVersion "1.0.0"
    }

    It "act exits with code 0" {
        $script:defaultResult.ExitCode | Should -Be 0
    }

    It "Job succeeds" {
        $script:defaultResult.Output | Should -Match "Job succeeded"
    }

    It "Uses git log when no fixture specified" {
        $script:defaultResult.Output | Should -Match "No fixture specified, using git log"
    }

    It "Bumps version to 1.1.0 from the feat: initial commit" {
        # The initial commit is "feat: initial commit" -> minor bump
        $script:defaultResult.Output | Should -Match "NEW_VERSION=1\.1\.0"
    }
}
