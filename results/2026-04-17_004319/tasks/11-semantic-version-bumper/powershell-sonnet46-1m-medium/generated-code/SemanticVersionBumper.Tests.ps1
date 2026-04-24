# Semantic Version Bumper — Pester Test Suite
# TDD approach: tests written before implementation.
# Unit tests + workflow structure tests + act integration tests (skipped inside act).

BeforeAll {
    # Dot-source the implementation to load all functions without running main logic.
    # $MyInvocation.InvocationName is '.' when dot-sourced, which suppresses main execution.
    $ScriptPath = Join-Path $PSScriptRoot "Invoke-SemanticVersionBump.ps1"
    . $ScriptPath
}

# ---------------------------------------------------------------------------
# UNIT TESTS: written first (red), then implementation written (green).
# ---------------------------------------------------------------------------

Describe "Read-VersionFile" {
    It "reads version from a JSON file with 'version' key" {
        $tmp = Join-Path $TestDrive "version.json"
        @{ version = "1.2.3" } | ConvertTo-Json | Set-Content $tmp
        Read-VersionFile -Path $tmp | Should -Be "1.2.3"
    }

    It "reads version from package.json format" {
        $tmp = Join-Path $TestDrive "package.json"
        @{ name = "my-app"; version = "0.5.0"; description = "test" } | ConvertTo-Json | Set-Content $tmp
        Read-VersionFile -Path $tmp | Should -Be "0.5.0"
    }

    It "throws a meaningful error when file does not exist" {
        { Read-VersionFile -Path "nonexistent.json" } | Should -Throw "*not find*"
    }

    It "throws when file has no version field" {
        $tmp = Join-Path $TestDrive "bad.json"
        @{ name = "no-version" } | ConvertTo-Json | Set-Content $tmp
        { Read-VersionFile -Path $tmp } | Should -Throw "*version*"
    }
}

Describe "Get-BumpType" {
    It "returns 'patch' for only fix commits" {
        $commits = @(
            @{ hash = "aaa"; subject = "fix: resolve bug"; body = "" }
            @{ hash = "bbb"; subject = "docs: update readme"; body = "" }
        )
        Get-BumpType -Commits $commits | Should -Be "patch"
    }

    It "returns 'minor' for feat commits (no breaking)" {
        $commits = @(
            @{ hash = "aaa"; subject = "feat: add new endpoint"; body = "" }
            @{ hash = "bbb"; subject = "fix: correct typo"; body = "" }
        )
        Get-BumpType -Commits $commits | Should -Be "minor"
    }

    It "returns 'major' for feat! (breaking) commits" {
        $commits = @(
            @{ hash = "aaa"; subject = "feat!: redesign auth API"; body = "" }
        )
        Get-BumpType -Commits $commits | Should -Be "major"
    }

    It "returns 'major' when body contains BREAKING CHANGE" {
        $commits = @(
            @{ hash = "aaa"; subject = "feat: new API"; body = "BREAKING CHANGE: removed v1 endpoint" }
        )
        Get-BumpType -Commits $commits | Should -Be "major"
    }

    It "major takes priority over minor" {
        $commits = @(
            @{ hash = "aaa"; subject = "feat!: breaking feature"; body = "" }
            @{ hash = "bbb"; subject = "feat: regular feature"; body = "" }
        )
        Get-BumpType -Commits $commits | Should -Be "major"
    }

    It "minor takes priority over patch" {
        $commits = @(
            @{ hash = "aaa"; subject = "feat: new feature"; body = "" }
            @{ hash = "bbb"; subject = "fix: bug fix"; body = "" }
        )
        Get-BumpType -Commits $commits | Should -Be "minor"
    }

    It "returns 'patch' when no conventional commits are present" {
        $commits = @(
            @{ hash = "aaa"; subject = "chore: update deps"; body = "" }
        )
        Get-BumpType -Commits $commits | Should -Be "patch"
    }
}

Describe "Get-NextVersion" {
    It "bumps patch: 1.1.0 -> 1.1.1" {
        Get-NextVersion -CurrentVersion "1.1.0" -BumpType "patch" | Should -Be "1.1.1"
    }

    It "bumps minor: 1.1.0 -> 1.2.0 and resets patch" {
        Get-NextVersion -CurrentVersion "1.1.0" -BumpType "minor" | Should -Be "1.2.0"
    }

    It "bumps major: 1.1.0 -> 2.0.0 and resets minor and patch" {
        Get-NextVersion -CurrentVersion "1.1.0" -BumpType "major" | Should -Be "2.0.0"
    }

    It "bumps patch: 2.3.9 -> 2.3.10 (no overflow)" {
        Get-NextVersion -CurrentVersion "2.3.9" -BumpType "patch" | Should -Be "2.3.10"
    }

    It "bumps major: 0.9.9 -> 1.0.0" {
        Get-NextVersion -CurrentVersion "0.9.9" -BumpType "major" | Should -Be "1.0.0"
    }
}

Describe "Update-VersionFile" {
    It "writes new version to JSON file" {
        $tmp = Join-Path $TestDrive "version.json"
        @{ version = "1.0.0" } | ConvertTo-Json | Set-Content $tmp
        Update-VersionFile -Path $tmp -NewVersion "1.1.0"
        (Get-Content $tmp | ConvertFrom-Json).version | Should -Be "1.1.0"
    }

    It "preserves other fields in JSON" {
        $tmp = Join-Path $TestDrive "package.json"
        @{ name = "my-app"; version = "1.0.0"; description = "test app" } | ConvertTo-Json | Set-Content $tmp
        Update-VersionFile -Path $tmp -NewVersion "2.0.0"
        $content = Get-Content $tmp | ConvertFrom-Json
        $content.version | Should -Be "2.0.0"
        $content.name | Should -Be "my-app"
        $content.description | Should -Be "test app"
    }
}

Describe "New-ChangelogEntry" {
    It "includes the new version in the header" {
        $commits = @(@{ hash = "aaa"; subject = "fix: bug"; body = "" })
        $entry = New-ChangelogEntry -Version "1.1.1" -Commits $commits
        $entry | Should -Match "\[1\.1\.1\]"
    }

    It "groups fix commits under Bug Fixes" {
        $commits = @(@{ hash = "aaa"; subject = "fix: resolve crash"; body = "" })
        $entry = New-ChangelogEntry -Version "1.1.1" -Commits $commits
        $entry | Should -Match "Bug Fixes"
        $entry | Should -Match "fix: resolve crash"
    }

    It "groups feat commits under Features" {
        $commits = @(@{ hash = "aaa"; subject = "feat: add search"; body = "" })
        $entry = New-ChangelogEntry -Version "1.2.0" -Commits $commits
        $entry | Should -Match "Features"
        $entry | Should -Match "feat: add search"
    }

    It "groups breaking commits under Breaking Changes" {
        $commits = @(@{ hash = "aaa"; subject = "feat!: new auth"; body = "" })
        $entry = New-ChangelogEntry -Version "2.0.0" -Commits $commits
        $entry | Should -Match "Breaking Changes"
    }

    It "includes a date in the header" {
        $commits = @(@{ hash = "aaa"; subject = "fix: bug"; body = "" })
        $entry = New-ChangelogEntry -Version "1.1.1" -Commits $commits
        $entry | Should -Match "\d{4}-\d{2}-\d{2}"
    }
}

# ---------------------------------------------------------------------------
# WORKFLOW STRUCTURE TESTS
# ---------------------------------------------------------------------------

Describe "Workflow Structure" {
    BeforeAll {
        $WorkflowPath = Join-Path $PSScriptRoot ".github/workflows/semantic-version-bumper.yml"
        $script:WorkflowContent = Get-Content $WorkflowPath -Raw -ErrorAction Stop
        $script:WorkflowPath = $WorkflowPath
    }

    It "workflow file exists" {
        Test-Path $script:WorkflowPath | Should -Be $true
    }

    It "workflow has push trigger" {
        $script:WorkflowContent | Should -Match "push"
    }

    It "workflow has workflow_dispatch trigger" {
        $script:WorkflowContent | Should -Match "workflow_dispatch"
    }

    It "workflow references Invoke-SemanticVersionBump.ps1" {
        $script:WorkflowContent | Should -Match "Invoke-SemanticVersionBump\.ps1"
        Test-Path (Join-Path $PSScriptRoot "Invoke-SemanticVersionBump.ps1") | Should -Be $true
    }

    It "workflow references fixture files" {
        $script:WorkflowContent | Should -Match "commits-patch\.json"
        Test-Path (Join-Path $PSScriptRoot "fixtures/commits-patch.json") | Should -Be $true
        Test-Path (Join-Path $PSScriptRoot "fixtures/commits-minor.json") | Should -Be $true
        Test-Path (Join-Path $PSScriptRoot "fixtures/commits-major.json") | Should -Be $true
    }

    It "workflow uses shell: pwsh for run steps" {
        $script:WorkflowContent | Should -Match "shell: pwsh"
    }

    It "workflow passes actionlint validation" -Skip:($null -ne $env:ACT) {
        $result = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint reported: $result"
    }
}

# ---------------------------------------------------------------------------
# ACT INTEGRATION TESTS
# Skipped when running inside act (ACT env var is set) to prevent recursion.
# Run locally by the benchmark harness — creates act-result.txt.
# ---------------------------------------------------------------------------

Describe "Act Integration Tests" -Skip:($null -ne $env:ACT) {
    BeforeAll {
        # Set up a temp git repo with all project files, then run act push --rm.
        # A single act run exercises all 3 jobs (patch, minor, major) in the workflow.
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "semver-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:TempDir | Out-Null

        # Copy the entire workspace into the temp dir
        $Source = $PSScriptRoot
        Copy-Item -Path "$Source/*" -Destination $script:TempDir -Recurse -Force
        # Copy .actrc so act uses the right Docker image
        $actrc = Join-Path $Source ".actrc"
        if (Test-Path $actrc) {
            Copy-Item $actrc (Join-Path $script:TempDir ".actrc")
        }

        # Initialize git repo (act requires a real git repo)
        Push-Location $script:TempDir
        & git init -q
        & git config user.email "test@test.com"
        & git config user.name "Test"
        & git add -A
        & git commit -q -m "test: initial commit"

        # Run act with --pull=false to use the locally-built act-ubuntu-pwsh image.
        # (act defaults --pull=true which fails for local-only images)
        Write-Host "Running act push --rm --pull=false in $script:TempDir ..."
        $script:ActOutput = & act push --rm --pull=false 2>&1 | ForEach-Object { "$_" }
        $script:ActExitCode = $LASTEXITCODE
        Pop-Location

        # Save output to act-result.txt in the workspace directory (required artifact)
        $ResultPath = Join-Path $PSScriptRoot "act-result.txt"
        $delimiter = "=" * 60
        @(
            $delimiter
            "ACT RUN: semantic-version-bumper — all scenarios"
            "Temp dir: $script:TempDir"
            "Exit code: $script:ActExitCode"
            $delimiter
        ) | Add-Content $ResultPath
        $script:ActOutput | Add-Content $ResultPath
        @("", $delimiter, "") | Add-Content $ResultPath

        Write-Host "act exit code: $script:ActExitCode"
        $script:ActOutput | Select-Object -Last 20 | Write-Host
    }

    AfterAll {
        if (Test-Path $script:TempDir) {
            Remove-Item -Recurse -Force $script:TempDir -ErrorAction SilentlyContinue
        }
    }

    It "act exits with code 0" {
        $script:ActExitCode | Should -Be 0 -Because ($script:ActOutput -join "`n")
    }

    It "patch bump produces exactly version 1.1.1" {
        $combined = $script:ActOutput -join "`n"
        $combined | Should -Match "PATCH_RESULT: 1\.1\.1"
    }

    It "minor bump produces exactly version 1.2.0" {
        $combined = $script:ActOutput -join "`n"
        $combined | Should -Match "MINOR_RESULT: 1\.2\.0"
    }

    It "major bump produces exactly version 2.0.0" {
        $combined = $script:ActOutput -join "`n"
        $combined | Should -Match "MAJOR_RESULT: 2\.0\.0"
    }

    It "bump-patch job succeeded" {
        $combined = $script:ActOutput -join "`n"
        $combined | Should -Match "bump-patch"
        $combined | Should -Match "Job succeeded|✅"
    }

    It "bump-minor job succeeded" {
        $combined = $script:ActOutput -join "`n"
        $combined | Should -Match "bump-minor"
    }

    It "bump-major job succeeded" {
        $combined = $script:ActOutput -join "`n"
        $combined | Should -Match "bump-major"
    }
}
