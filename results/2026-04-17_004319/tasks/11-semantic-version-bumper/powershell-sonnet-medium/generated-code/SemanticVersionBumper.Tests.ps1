# SemanticVersionBumper.Tests.ps1
# Pester test suite for the semantic version bumper.
# TDD: these tests were written BEFORE the implementation.
# Run with: Invoke-Pester -Output Detailed

BeforeAll {
    # Dot-source functions only (no main execution)
    . "$PSScriptRoot/Invoke-SemanticVersionBump.ps1" -LoadOnly
}

Describe "Get-BumpType" {
    It "returns 'patch' for fix commits" {
        $commits = @("fix: correct typo", "chore: update deps")
        Get-BumpType -Commits $commits | Should -Be "patch"
    }

    It "returns 'minor' for feat commits" {
        $commits = @("feat: add new feature", "fix: small fix")
        Get-BumpType -Commits $commits | Should -Be "minor"
    }

    It "returns 'major' for BREAKING CHANGE commits" {
        $commits = @("feat: new api", "BREAKING CHANGE: removed old endpoint")
        Get-BumpType -Commits $commits | Should -Be "major"
    }

    It "returns 'major' for ! (breaking) commits" {
        $commits = @("feat!: breaking feature change")
        Get-BumpType -Commits $commits | Should -Be "major"
    }

    It "returns 'major' for fix! commits" {
        $commits = @("fix!: incompatible fix")
        Get-BumpType -Commits $commits | Should -Be "major"
    }

    It "returns 'patch' when no conventional commits found" {
        $commits = @("update readme", "misc changes")
        Get-BumpType -Commits $commits | Should -Be "patch"
    }

    It "prefers major over minor" {
        $commits = @("feat: new feature", "feat!: breaking change")
        Get-BumpType -Commits $commits | Should -Be "major"
    }

    It "prefers minor over patch" {
        $commits = @("fix: small fix", "feat: new feature")
        Get-BumpType -Commits $commits | Should -Be "minor"
    }
}

Describe "Invoke-BumpVersion" {
    It "bumps patch version" {
        Invoke-BumpVersion -Version "1.2.3" -BumpType "patch" | Should -Be "1.2.4"
    }

    It "bumps minor version and resets patch" {
        Invoke-BumpVersion -Version "1.2.3" -BumpType "minor" | Should -Be "1.3.0"
    }

    It "bumps major version and resets minor and patch" {
        Invoke-BumpVersion -Version "1.2.3" -BumpType "major" | Should -Be "2.0.0"
    }

    It "handles patch on 1.0.0" {
        Invoke-BumpVersion -Version "1.0.0" -BumpType "patch" | Should -Be "1.0.1"
    }

    It "handles minor on 1.0.0" {
        Invoke-BumpVersion -Version "1.0.0" -BumpType "minor" | Should -Be "1.1.0"
    }

    It "handles major on 1.0.0" {
        Invoke-BumpVersion -Version "1.0.0" -BumpType "major" | Should -Be "2.0.0"
    }

    It "handles large version numbers" {
        Invoke-BumpVersion -Version "10.20.30" -BumpType "patch" | Should -Be "10.20.31"
    }
}

Describe "New-ChangelogEntry" {
    It "generates changelog with version header" {
        $entry = New-ChangelogEntry -Version "1.2.0" -Commits @("feat: add feature")
        $entry | Should -Match "## \[1\.2\.0\]"
    }

    It "includes feat commits under Features section" {
        $entry = New-ChangelogEntry -Version "1.2.0" -Commits @("feat: add new feature")
        $entry | Should -Match "### Features"
        $entry | Should -Match "add new feature"
    }

    It "includes fix commits under Bug Fixes section" {
        $entry = New-ChangelogEntry -Version "1.1.1" -Commits @("fix: correct bug")
        $entry | Should -Match "### Bug Fixes"
        $entry | Should -Match "correct bug"
    }

    It "includes breaking changes section" {
        $entry = New-ChangelogEntry -Version "2.0.0" -Commits @("feat!: breaking API change")
        $entry | Should -Match "### Breaking Changes"
    }

    It "includes date in changelog entry" {
        $entry = New-ChangelogEntry -Version "1.0.1" -Commits @("fix: a fix")
        $entry | Should -Match "\d{4}-\d{2}-\d{2}"
    }

    It "handles multiple commit types" {
        $commits = @("feat: new feature", "fix: bug fix", "chore: cleanup")
        $entry = New-ChangelogEntry -Version "1.1.0" -Commits $commits
        $entry | Should -Match "### Features"
        $entry | Should -Match "### Bug Fixes"
    }
}

Describe "Get-VersionFromFile" {
    It "reads version from version.json" {
        $tempFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempFile -Value '{"version": "1.2.3"}'
        $version = Get-VersionFromFile -FilePath $tempFile
        $version | Should -Be "1.2.3"
        Remove-Item $tempFile
    }

    It "reads version from package.json format" {
        $tempFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempFile -Value '{"name": "myapp", "version": "2.0.1", "description": "test"}'
        $version = Get-VersionFromFile -FilePath $tempFile
        $version | Should -Be "2.0.1"
        Remove-Item $tempFile
    }

    It "throws error for missing file" {
        { Get-VersionFromFile -FilePath "nonexistent-file-xyz.json" } | Should -Throw
    }

    It "throws error when no version field" {
        $tempFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempFile -Value '{"name": "myapp"}'
        { Get-VersionFromFile -FilePath $tempFile } | Should -Throw
        Remove-Item $tempFile
    }
}

Describe "Set-VersionInFile" {
    It "updates version in version.json" {
        $tempFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempFile -Value '{"version": "1.0.0"}'
        Set-VersionInFile -FilePath $tempFile -NewVersion "1.1.0"
        $content = Get-Content -Path $tempFile -Raw | ConvertFrom-Json
        $content.version | Should -Be "1.1.0"
        Remove-Item $tempFile
    }

    It "preserves other fields when updating" {
        $tempFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempFile -Value '{"name": "myapp", "version": "1.0.0", "author": "test"}'
        Set-VersionInFile -FilePath $tempFile -NewVersion "2.0.0"
        $content = Get-Content -Path $tempFile -Raw | ConvertFrom-Json
        $content.version | Should -Be "2.0.0"
        $content.name | Should -Be "myapp"
        $content.author | Should -Be "test"
        Remove-Item $tempFile
    }
}

Describe "Invoke-SemanticVersionBump (integration)" {
    It "bumps minor for feat commit and updates file" {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempDir | Out-Null
        $versionFile = Join-Path $tempDir "version.json"
        $commitsFile = Join-Path $tempDir "commits.txt"
        Set-Content -Path $versionFile -Value '{"version": "1.0.0"}'
        Set-Content -Path $commitsFile -Value "feat: add new feature`nfix: small fix"

        $result = Invoke-SemanticVersionBump -VersionFilePath $versionFile -CommitsFilePath $commitsFile

        $result.NewVersion | Should -Be "1.1.0"
        $result.BumpType | Should -Be "minor"
        $result.OldVersion | Should -Be "1.0.0"
        $result.Changelog | Should -Match "## \[1\.1\.0\]"

        $updated = Get-Content -Path $versionFile -Raw | ConvertFrom-Json
        $updated.version | Should -Be "1.1.0"

        Remove-Item -Recurse -Force $tempDir
    }

    It "bumps patch for fix-only commits" {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempDir | Out-Null
        $versionFile = Join-Path $tempDir "version.json"
        $commitsFile = Join-Path $tempDir "commits.txt"
        Set-Content -Path $versionFile -Value '{"version": "2.3.5"}'
        Set-Content -Path $commitsFile -Value "fix: correct null check`nfix: handle edge case"

        $result = Invoke-SemanticVersionBump -VersionFilePath $versionFile -CommitsFilePath $commitsFile

        $result.NewVersion | Should -Be "2.3.6"
        $result.BumpType | Should -Be "patch"

        Remove-Item -Recurse -Force $tempDir
    }

    It "bumps major for breaking change commits" {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempDir | Out-Null
        $versionFile = Join-Path $tempDir "version.json"
        $commitsFile = Join-Path $tempDir "commits.txt"
        Set-Content -Path $versionFile -Value '{"version": "1.5.3"}'
        Set-Content -Path $commitsFile -Value "feat!: breaking API redesign"

        $result = Invoke-SemanticVersionBump -VersionFilePath $versionFile -CommitsFilePath $commitsFile

        $result.NewVersion | Should -Be "2.0.0"
        $result.BumpType | Should -Be "major"

        Remove-Item -Recurse -Force $tempDir
    }
}

Describe "Workflow Structure" {
    It "workflow file exists" {
        "$PSScriptRoot/.github/workflows/semantic-version-bumper.yml" | Should -Exist
    }

    It "script file exists" {
        "$PSScriptRoot/Invoke-SemanticVersionBump.ps1" | Should -Exist
    }

    It "workflow has push trigger" {
        $content = Get-Content "$PSScriptRoot/.github/workflows/semantic-version-bumper.yml" -Raw
        $content | Should -Match "push:"
    }

    It "workflow references script file" {
        $content = Get-Content "$PSScriptRoot/.github/workflows/semantic-version-bumper.yml" -Raw
        $content | Should -Match "Invoke-SemanticVersionBump\.ps1"
    }

    It "workflow uses shell: pwsh for run steps" {
        $content = Get-Content "$PSScriptRoot/.github/workflows/semantic-version-bumper.yml" -Raw
        $content | Should -Match "shell: pwsh"
    }

    It "workflow includes actions/checkout@v4" {
        $content = Get-Content "$PSScriptRoot/.github/workflows/semantic-version-bumper.yml" -Raw
        $content | Should -Match "actions/checkout@v4"
    }

    It "actionlint passes on workflow file" {
        $hasActionlint = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $hasActionlint) {
            Set-ItResult -Skipped -Because "actionlint not installed in this environment"
            return
        }
        $lintOutput = & actionlint "$PSScriptRoot/.github/workflows/semantic-version-bumper.yml" 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $lintOutput"
    }

    It "fixture files exist" {
        "$PSScriptRoot/fixtures/version.json" | Should -Exist
        "$PSScriptRoot/fixtures/patch-commits.txt" | Should -Exist
        "$PSScriptRoot/fixtures/minor-commits.txt" | Should -Exist
        "$PSScriptRoot/fixtures/major-commits.txt" | Should -Exist
    }
}

Describe "Act Integration" -Tag "ActIntegration" {
    # This runs act push --rm and asserts on exact output values.
    # Saves results to act-result.txt as required.

    BeforeAll {
        $script:ActResultFile = Join-Path $PSScriptRoot "act-result.txt"
        $script:ActOutput = $null
        $script:ActExitCode = -1

        # Set up a temp git repo with all project files
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:TempDir | Out-Null

        $filesToCopy = @(
            "Invoke-SemanticVersionBump.ps1",
            "SemanticVersionBumper.Tests.ps1",
            ".github",
            "fixtures",
            ".actrc"
        )
        foreach ($item in $filesToCopy) {
            $src = Join-Path $PSScriptRoot $item
            if (Test-Path $src) {
                Copy-Item -Path $src -Destination $script:TempDir -Recurse -Force
            }
        }

        Push-Location $script:TempDir
        git init 2>&1 | Out-Null
        git config user.email "test@example.com" 2>&1 | Out-Null
        git config user.name "Test Runner" 2>&1 | Out-Null
        git add -A 2>&1 | Out-Null
        git commit -m "test: initial commit for act integration test" 2>&1 | Out-Null

        Write-Host "Running act push --rm from: $script:TempDir"
        # --pull=false uses the local image without attempting a registry pull
        $script:ActOutput = & act push --rm --pull=false 2>&1
        $script:ActExitCode = $LASTEXITCODE
        Pop-Location

        # Save full output to act-result.txt
        $delimiter = "=" * 60
        $content = @(
            $delimiter,
            "ACT INTEGRATION TEST - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
            $delimiter,
            ($script:ActOutput -join "`n"),
            $delimiter,
            "EXIT CODE: $($script:ActExitCode)",
            $delimiter
        ) -join "`n"
        Set-Content -Path $script:ActResultFile -Value $content -Encoding UTF8

        Remove-Item -Recurse -Force $script:TempDir -ErrorAction SilentlyContinue
    }

    It "act-result.txt was created" {
        $script:ActResultFile | Should -Exist
    }

    It "act exited with code 0" {
        $script:ActExitCode | Should -Be 0 -Because "act output:`n$($script:ActOutput -join "`n")"
    }

    It "workflow job succeeded" {
        $outputStr = $script:ActOutput -join "`n"
        $outputStr | Should -Match "Job succeeded"
    }

    It "patch bump output is exactly 1.0.1" {
        $outputStr = $script:ActOutput -join "`n"
        $outputStr | Should -Match "PATCH_RESULT: 1\.0\.1"
    }

    It "minor bump output is exactly 1.1.0" {
        $outputStr = $script:ActOutput -join "`n"
        $outputStr | Should -Match "MINOR_RESULT: 1\.1\.0"
    }

    It "major bump output is exactly 2.0.0" {
        $outputStr = $script:ActOutput -join "`n"
        $outputStr | Should -Match "MAJOR_RESULT: 2\.0\.0"
    }
}
