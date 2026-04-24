#Requires -Modules Pester
# TDD test suite for SemanticVersionBumper.ps1
# Red/Green cycle: tests written first, then implementation added to make them pass.

BeforeAll {
    $script:ScriptUnderTest = Join-Path $PSScriptRoot "SemanticVersionBumper.ps1"
    # Dot-source to bring Get-BumpType, Get-NewVersion, Get-ChangelogEntry into scope.
    # The main execution body is guarded by $MyInvocation.InvocationName -ne '.'
    . $script:ScriptUnderTest
}

# ===========================================================================
# Unit tests — Get-BumpType
# ===========================================================================
Describe "Get-BumpType" {
    It "returns major for feat! (exclamation breaking change)" {
        Get-BumpType -Commits @("feat!: redesign public API") | Should -Be "major"
    }

    It "returns major for fix! (exclamation breaking change)" {
        Get-BumpType -Commits @("fix!: remove deprecated parameter") | Should -Be "major"
    }

    It "returns major for BREAKING CHANGE in commit body" {
        Get-BumpType -Commits @("feat: new thing`n`nBREAKING CHANGE: removes old API") | Should -Be "major"
    }

    It "returns major even when feat also present" {
        Get-BumpType -Commits @("feat: add feature", "feat!: break everything") | Should -Be "major"
    }

    It "returns minor for feat: commits" {
        Get-BumpType -Commits @("feat: add OAuth2 login", "fix: typo in readme") | Should -Be "minor"
    }

    It "returns minor for feat with scope" {
        Get-BumpType -Commits @("feat(auth): add JWT support") | Should -Be "minor"
    }

    It "returns patch for fix: commits only" {
        Get-BumpType -Commits @("fix: correct null pointer", "fix: handle empty response") | Should -Be "patch"
    }

    It "returns patch for fix with scope" {
        Get-BumpType -Commits @("fix(api): handle timeout correctly") | Should -Be "patch"
    }

    It "returns none for chore/docs/style commits" {
        Get-BumpType -Commits @("chore: update deps", "docs: improve readme", "style: reformat") | Should -Be "none"
    }

    It "returns none for empty commit list" {
        Get-BumpType -Commits @() | Should -Be "none"
    }

    It "minor wins over patch when both present" {
        Get-BumpType -Commits @("fix: bugfix", "feat: new feature") | Should -Be "minor"
    }

    It "major wins over minor when both present" {
        Get-BumpType -Commits @("feat: new feature", "feat!: breaking redesign") | Should -Be "major"
    }
}

# ===========================================================================
# Unit tests — Get-NewVersion
# ===========================================================================
Describe "Get-NewVersion" {
    It "bumps major: 1.0.0 -> 2.0.0" {
        Get-NewVersion -CurrentVersion "1.0.0" -BumpType "major" | Should -Be "2.0.0"
    }

    It "bumps major: 2.5.3 -> 3.0.0" {
        Get-NewVersion -CurrentVersion "2.5.3" -BumpType "major" | Should -Be "3.0.0"
    }

    It "bumps minor: 1.0.0 -> 1.1.0" {
        Get-NewVersion -CurrentVersion "1.0.0" -BumpType "minor" | Should -Be "1.1.0"
    }

    It "bumps minor: 2.5.3 -> 2.6.0" {
        Get-NewVersion -CurrentVersion "2.5.3" -BumpType "minor" | Should -Be "2.6.0"
    }

    It "bumps patch: 1.0.0 -> 1.0.1" {
        Get-NewVersion -CurrentVersion "1.0.0" -BumpType "patch" | Should -Be "1.0.1"
    }

    It "bumps patch: 2.5.3 -> 2.5.4" {
        Get-NewVersion -CurrentVersion "2.5.3" -BumpType "patch" | Should -Be "2.5.4"
    }

    It "no bump: 1.2.3 stays at 1.2.3" {
        Get-NewVersion -CurrentVersion "1.2.3" -BumpType "none" | Should -Be "1.2.3"
    }

    It "major bump resets minor and patch to zero" {
        Get-NewVersion -CurrentVersion "3.7.12" -BumpType "major" | Should -Be "4.0.0"
    }

    It "minor bump resets patch to zero" {
        Get-NewVersion -CurrentVersion "3.7.12" -BumpType "minor" | Should -Be "3.8.0"
    }

    It "throws for invalid version string" {
        { Get-NewVersion -CurrentVersion "not-a-version" -BumpType "patch" } | Should -Throw
    }
}

# ===========================================================================
# Unit tests — Get-ChangelogEntry
# ===========================================================================
Describe "Get-ChangelogEntry" {
    It "includes version header" {
        $r = Get-ChangelogEntry -NewVersion "1.0.1" -Commits @("fix: a bug") -Date ([DateTime]"2026-01-15")
        $r | Should -Match "\[1\.0\.1\]"
    }

    It "includes date in header" {
        $r = Get-ChangelogEntry -NewVersion "1.0.1" -Commits @("fix: a bug") -Date ([DateTime]"2026-01-15")
        $r | Should -Match "2026-01-15"
    }

    It "lists fix commits under Bug Fixes section" {
        $r = Get-ChangelogEntry -NewVersion "1.0.1" -Commits @("fix: correct null pointer") -Date ([DateTime]"2026-01-15")
        $r | Should -Match "Bug Fixes"
        $r | Should -Match "fix: correct null pointer"
    }

    It "lists feat commits under Features section" {
        $r = Get-ChangelogEntry -NewVersion "1.1.0" -Commits @("feat: add OAuth2") -Date ([DateTime]"2026-01-15")
        $r | Should -Match "Features"
        $r | Should -Match "feat: add OAuth2"
    }

    It "lists breaking changes under Breaking Changes section" {
        $r = Get-ChangelogEntry -NewVersion "2.0.0" -Commits @("feat!: redesign API") -Date ([DateTime]"2026-01-15")
        $r | Should -Match "Breaking Changes"
        $r | Should -Match "feat!: redesign API"
    }

    It "does not include empty sections" {
        $r = Get-ChangelogEntry -NewVersion "1.0.1" -Commits @("fix: a bug") -Date ([DateTime]"2026-01-15")
        $r | Should -Not -Match "Features"
        $r | Should -Not -Match "Breaking Changes"
    }
}

# ===========================================================================
# Integration tests — full script invocation (no act)
# ===========================================================================
Describe "Invoke-SemanticVersionBump (integration)" {
    BeforeEach {
        $script:tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tmpDir | Out-Null
    }

    AfterEach {
        if (Test-Path $script:tmpDir) { Remove-Item -Recurse -Force $script:tmpDir }
    }

    It "reads version.json and outputs NEW_VERSION line" {
        $vf = Join-Path $script:tmpDir "version.json"
        $cf = Join-Path $script:tmpDir "commits.txt"
        '{"version":"1.0.0"}' | Set-Content $vf
        "fix: a bug" | Set-Content $cf

        $out = (& $script:ScriptUnderTest -VersionFile $vf -CommitsFile $cf) -join "`n"
        $out | Should -Match "NEW_VERSION=1\.0\.1"
    }

    It "reads package.json version field" {
        $vf = Join-Path $script:tmpDir "package.json"
        $cf = Join-Path $script:tmpDir "commits.txt"
        '{"name":"my-app","version":"2.3.0"}' | Set-Content $vf
        "feat: add feature" | Set-Content $cf

        $out = (& $script:ScriptUnderTest -VersionFile $vf -CommitsFile $cf) -join "`n"
        $out | Should -Match "NEW_VERSION=2\.4\.0"
    }

    It "updates version file with new version" {
        $vf = Join-Path $script:tmpDir "version.json"
        $cf = Join-Path $script:tmpDir "commits.txt"
        '{"version":"1.0.0"}' | Set-Content $vf
        "feat!: breaking change" | Set-Content $cf

        & $script:ScriptUnderTest -VersionFile $vf -CommitsFile $cf | Out-Null
        (Get-Content $vf | ConvertFrom-Json).version | Should -Be "2.0.0"
    }

    It "does not update version file when -DryRun" {
        $vf = Join-Path $script:tmpDir "version.json"
        $cf = Join-Path $script:tmpDir "commits.txt"
        '{"version":"1.0.0"}' | Set-Content $vf
        "feat: new thing" | Set-Content $cf

        & $script:ScriptUnderTest -VersionFile $vf -CommitsFile $cf -DryRun | Out-Null
        (Get-Content $vf | ConvertFrom-Json).version | Should -Be "1.0.0"
    }

    It "writes changelog entry to CHANGELOG.md" {
        $vf  = Join-Path $script:tmpDir "version.json"
        $cf  = Join-Path $script:tmpDir "commits.txt"
        $clf = Join-Path $script:tmpDir "CHANGELOG.md"
        '{"version":"1.0.0"}' | Set-Content $vf
        "fix: resolve memory leak" | Set-Content $cf

        & $script:ScriptUnderTest -VersionFile $vf -CommitsFile $cf -ChangelogFile $clf | Out-Null
        $cl = Get-Content $clf -Raw
        $cl | Should -Match "\[1\.0\.1\]"
        $cl | Should -Match "fix: resolve memory leak"
    }

    It "prepends to existing CHANGELOG.md" {
        $vf  = Join-Path $script:tmpDir "version.json"
        $cf  = Join-Path $script:tmpDir "commits.txt"
        $clf = Join-Path $script:tmpDir "CHANGELOG.md"
        '{"version":"1.0.0"}' | Set-Content $vf
        "fix: bug" | Set-Content $cf
        "# Changelog`n`n## [0.9.0] - 2025-01-01`n`n- old entry" | Set-Content $clf

        & $script:ScriptUnderTest -VersionFile $vf -CommitsFile $cf -ChangelogFile $clf | Out-Null
        $cl = Get-Content $clf -Raw
        $cl | Should -Match "\[1\.0\.1\]"
        $cl | Should -Match "\[0\.9\.0\]"
    }

    It "exits with error for missing version file" {
        $cf = Join-Path $script:tmpDir "commits.txt"
        "fix: bug" | Set-Content $cf

        { & $script:ScriptUnderTest -VersionFile "$script:tmpDir/nonexistent.json" -CommitsFile $cf } | Should -Throw
    }

    It "outputs current version unchanged when no relevant commits" {
        $vf = Join-Path $script:tmpDir "version.json"
        $cf = Join-Path $script:tmpDir "commits.txt"
        '{"version":"1.2.3"}' | Set-Content $vf
        "chore: update deps" | Set-Content $cf

        $out = (& $script:ScriptUnderTest -VersionFile $vf -CommitsFile $cf) -join "`n"
        $out | Should -Match "NEW_VERSION=1\.2\.3"
    }
}

# ===========================================================================
# Workflow structure tests
# ===========================================================================
Describe "Workflow Structure" {
    BeforeAll {
        $script:WorkflowPath = Join-Path $PSScriptRoot ".github/workflows/semantic-version-bumper.yml"
        $script:WorkflowText = Get-Content $script:WorkflowPath -Raw -ErrorAction SilentlyContinue
    }

    It "workflow file exists" {
        Test-Path $script:WorkflowPath | Should -Be $true
    }

    It "workflow has push trigger" {
        $script:WorkflowText | Should -Match "push:"
    }

    It "workflow has workflow_dispatch trigger" {
        $script:WorkflowText | Should -Match "workflow_dispatch"
    }

    It "workflow references SemanticVersionBumper.ps1" {
        $script:WorkflowText | Should -Match "SemanticVersionBumper\.ps1"
    }

    It "workflow uses shell: pwsh" {
        $script:WorkflowText | Should -Match "shell:\s*pwsh"
    }

    It "workflow uses actions/checkout@v4" {
        $script:WorkflowText | Should -Match "actions/checkout@v4"
    }

    It "script file exists" {
        Test-Path (Join-Path $PSScriptRoot "SemanticVersionBumper.ps1") | Should -Be $true
    }

    It "actionlint passes on workflow file" {
        & actionlint $script:WorkflowPath 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
}

# ===========================================================================
# Act integration tests
# Each test case sets up a temp git repo with the workflow and specific
# fixture data, runs `act push --rm`, and asserts on the exact output.
# All output is appended to act-result.txt.
# ===========================================================================
Describe "Act Integration Tests" {
    BeforeAll {
        $script:actResultFile = Join-Path $PSScriptRoot "act-result.txt"
        Set-Content $script:actResultFile "# Act Integration Test Results`n" -Encoding UTF8
        $script:fixturesDir  = Join-Path $PSScriptRoot "fixtures"
        $script:scriptSrc    = Join-Path $PSScriptRoot "SemanticVersionBumper.ps1"
        $script:workflowSrc  = Join-Path $PSScriptRoot ".github/workflows/semantic-version-bumper.yml"
        $script:actrcSrc     = Join-Path $PSScriptRoot ".actrc"
    }

    # Test cases parameterized via -TestCases (Pester 5).
    # All act invocation logic is inlined in the single It body.
    $testCases = @(
        @{ Name = "patch-bump"; VersionJson = '{"version":"1.0.0"}'; FixtureFile = "patch-commits.txt"; Expected = "1.0.1" }
        @{ Name = "minor-bump"; VersionJson = '{"version":"1.0.0"}'; FixtureFile = "minor-commits.txt"; Expected = "1.1.0" }
        @{ Name = "major-bump"; VersionJson = '{"version":"1.0.0"}'; FixtureFile = "major-commits.txt"; Expected = "2.0.0" }
        @{ Name = "noop-bump";  VersionJson = '{"version":"2.5.3"}'; FixtureFile = "noop-commits.txt";  Expected = "2.5.3" }
    )

    It "act run: <Name> produces NEW_VERSION=<Expected>" -TestCases $testCases {
        $commits = Get-Content (Join-Path $script:fixturesDir $FixtureFile) -Raw

        # Create a temp git repo containing the project files and test fixture data
        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tmpDir ".github/workflows") -Force | Out-Null

        Copy-Item $script:scriptSrc  (Join-Path $tmpDir "SemanticVersionBumper.ps1")
        Copy-Item $script:workflowSrc (Join-Path $tmpDir ".github/workflows/semantic-version-bumper.yml")
        if (Test-Path $script:actrcSrc) {
            Copy-Item $script:actrcSrc (Join-Path $tmpDir ".actrc")
        }

        Set-Content (Join-Path $tmpDir "version.json") $VersionJson -Encoding UTF8
        Set-Content (Join-Path $tmpDir "commits.txt")  $commits     -Encoding UTF8

        Push-Location $tmpDir
        & git init --quiet
        & git config user.email "test@example.com"
        & git config user.name "Test Runner"
        & git add -A
        & git commit -m "test: $Name" --quiet

        $actOutput = & act push --rm 2>&1
        $actExit   = $LASTEXITCODE
        Pop-Location
        Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue

        # Save output to act-result.txt
        $sep = "=" * 60
        @("", $sep, "TEST CASE: $Name", "EXIT CODE: $actExit", $sep) |
            Add-Content $script:actResultFile
        $actOutput | ForEach-Object { Add-Content $script:actResultFile $_ }
        Add-Content $script:actResultFile "$sep`n"

        # Assertions: exit code, exact version, job success
        $outStr = $actOutput -join "`n"
        $actExit | Should -Be 0
        $outStr  | Should -Match "NEW_VERSION=$([regex]::Escape($Expected))"
        $outStr  | Should -Match "Job succeeded"
    }

    It "act-result.txt exists after all tests" {
        Test-Path $script:actResultFile | Should -Be $true
    }
}
