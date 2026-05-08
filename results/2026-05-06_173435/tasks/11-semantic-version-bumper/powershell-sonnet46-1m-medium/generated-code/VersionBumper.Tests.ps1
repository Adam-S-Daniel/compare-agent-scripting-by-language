#Requires -Modules Pester
# TDD test suite for the Semantic Version Bumper
# Tests are written first (RED), then the implementation makes them GREEN.

BeforeAll {
    # Dot-source the script with -NoExecute to load functions without running main code
    . (Join-Path $PSScriptRoot "VersionBumper.ps1") -NoExecute
}

Describe "Get-CurrentVersion" {
    Context "when reading from version.json" {
        BeforeAll {
            $script:versionFile = Join-Path $TestDrive "version.json"
            '{"version": "1.2.3"}' | Set-Content $script:versionFile
        }

        It "returns the version string" {
            Get-CurrentVersion -FilePath $script:versionFile | Should -Be "1.2.3"
        }

        It "works with additional fields in the JSON" {
            $f = Join-Path $TestDrive "package.json"
            '{"name": "my-app", "version": "2.0.0", "description": "test"}' | Set-Content $f
            Get-CurrentVersion -FilePath $f | Should -Be "2.0.0"
        }
    }

    Context "error handling" {
        It "throws when file does not exist" {
            { Get-CurrentVersion -FilePath (Join-Path $TestDrive "missing.json") } |
                Should -Throw "*not found*"
        }

        It "throws when version field is missing" {
            $f = Join-Path $TestDrive "no-version.json"
            '{"name": "my-app"}' | Set-Content $f
            { Get-CurrentVersion -FilePath $f } | Should -Throw "*No 'version' field*"
        }
    }
}

Describe "Get-BumpType" {
    It "returns 'patch' for a fix commit" {
        Get-BumpType -Commits @("fix: correct calculation error") | Should -Be "patch"
    }

    It "returns 'patch' for a fix commit with scope" {
        Get-BumpType -Commits @("fix(auth): resolve token expiry") | Should -Be "patch"
    }

    It "returns 'minor' for a feat commit" {
        Get-BumpType -Commits @("feat: add export feature") | Should -Be "minor"
    }

    It "returns 'minor' for a feat commit with scope" {
        Get-BumpType -Commits @("feat(api): add new endpoint") | Should -Be "minor"
    }

    It "returns 'major' for a feat! (breaking) commit" {
        Get-BumpType -Commits @("feat!: redesign API interface") | Should -Be "major"
    }

    It "returns 'major' for a fix! (breaking) commit" {
        Get-BumpType -Commits @("fix!: change return type") | Should -Be "major"
    }

    It "returns 'major' for BREAKING CHANGE footer" {
        Get-BumpType -Commits @("feat: new thing", "BREAKING CHANGE: removes old endpoint") |
            Should -Be "major"
    }

    It "returns 'major' for any type with ! before colon" {
        Get-BumpType -Commits @("refactor!: overhaul core module") | Should -Be "major"
    }

    It "prioritizes major over minor" {
        Get-BumpType -Commits @("feat: new feature", "feat!: breaking change") |
            Should -Be "major"
    }

    It "prioritizes minor over patch" {
        Get-BumpType -Commits @("fix: bug fix", "feat: new feature") | Should -Be "minor"
    }

    It "returns 'none' for non-conventional commits" {
        Get-BumpType -Commits @("update README", "typo fix") | Should -Be "none"
    }

    It "handles empty commits array" {
        Get-BumpType -Commits @() | Should -Be "none"
    }
}

Describe "Invoke-BumpVersion" {
    It "bumps patch: 1.0.0 -> 1.0.1" {
        Invoke-BumpVersion -Version "1.0.0" -BumpType "patch" | Should -Be "1.0.1"
    }

    It "bumps patch: 1.2.5 -> 1.2.6" {
        Invoke-BumpVersion -Version "1.2.5" -BumpType "patch" | Should -Be "1.2.6"
    }

    It "bumps minor: 1.0.0 -> 1.1.0 and resets patch" {
        Invoke-BumpVersion -Version "1.0.9" -BumpType "minor" | Should -Be "1.1.0"
    }

    It "bumps minor: 1.1.0 -> 1.2.0" {
        Invoke-BumpVersion -Version "1.1.0" -BumpType "minor" | Should -Be "1.2.0"
    }

    It "bumps major: 1.2.3 -> 2.0.0 and resets minor and patch" {
        Invoke-BumpVersion -Version "1.2.3" -BumpType "major" | Should -Be "2.0.0"
    }

    It "bumps major: 1.1.0 -> 2.0.0" {
        Invoke-BumpVersion -Version "1.1.0" -BumpType "major" | Should -Be "2.0.0"
    }

    It "does not change version for bump type 'none'" {
        Invoke-BumpVersion -Version "1.2.3" -BumpType "none" | Should -Be "1.2.3"
    }

    It "handles large version numbers" {
        Invoke-BumpVersion -Version "10.20.30" -BumpType "patch" | Should -Be "10.20.31"
    }

    It "throws on invalid semver format" {
        { Invoke-BumpVersion -Version "1.2" -BumpType "patch" } | Should -Throw "*Invalid semver*"
    }
}

Describe "New-ChangelogEntry" {
    It "includes version and date in header" {
        $entry = New-ChangelogEntry -Version "1.1.0" -Commits @("feat: test") -Date "2024-01-15"
        $entry | Should -Match "\[1\.1\.0\].*2024-01-15"
    }

    It "groups feat commits under Features" {
        $entry = New-ChangelogEntry -Version "1.1.0" -Commits @("feat: add export") -Date "2024-01-01"
        $entry | Should -Match "### Features"
        $entry | Should -Match "feat: add export"
    }

    It "groups fix commits under Bug Fixes" {
        $entry = New-ChangelogEntry -Version "1.0.1" -Commits @("fix: correct typo") -Date "2024-01-01"
        $entry | Should -Match "### Bug Fixes"
        $entry | Should -Match "fix: correct typo"
    }

    It "groups breaking changes under BREAKING CHANGES" {
        $entry = New-ChangelogEntry -Version "2.0.0" -Commits @("feat!: redesign API") -Date "2024-01-01"
        $entry | Should -Match "### BREAKING CHANGES"
        $entry | Should -Match "feat!: redesign API"
    }

    It "handles multiple commits of different types" {
        $commits = @("feat: new feature", "fix: bug fix", "feat!: breaking")
        $entry = New-ChangelogEntry -Version "2.0.0" -Commits $commits -Date "2024-01-01"
        $entry | Should -Match "### BREAKING CHANGES"
        $entry | Should -Match "### Features"
        $entry | Should -Match "### Bug Fixes"
    }

    It "uses today's date when no date specified" {
        $entry = New-ChangelogEntry -Version "1.0.0" -Commits @("fix: test")
        $today = Get-Date -Format "yyyy-MM-dd"
        $entry | Should -Match $today
    }
}

Describe "Invoke-VersionBumper (end-to-end)" {
    BeforeEach {
        # Set up a fresh temp directory for each test
        $script:testDir = Join-Path $TestDrive "e2e-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:testDir | Out-Null
    }

    It "bumps patch version and updates version.json" {
        '{"version": "1.0.0"}' | Set-Content (Join-Path $script:testDir "version.json")
        "fix: correct error`nfix: another fix" | Set-Content (Join-Path $script:testDir "commits.txt")

        $result = Invoke-VersionBumper `
            -VersionFile (Join-Path $script:testDir "version.json") `
            -CommitsFile (Join-Path $script:testDir "commits.txt") `
            -ChangelogFile (Join-Path $script:testDir "CHANGELOG.md")

        $result.NewVersion | Should -Be "1.0.1"
        $result.BumpType | Should -Be "patch"

        $updatedJson = Get-Content (Join-Path $script:testDir "version.json") -Raw | ConvertFrom-Json
        $updatedJson.version | Should -Be "1.0.1"
    }

    It "bumps minor version from feat commit" {
        '{"version": "1.1.0"}' | Set-Content (Join-Path $script:testDir "version.json")
        "feat: add new feature`nfix: bug fix" | Set-Content (Join-Path $script:testDir "commits.txt")

        $result = Invoke-VersionBumper `
            -VersionFile (Join-Path $script:testDir "version.json") `
            -CommitsFile (Join-Path $script:testDir "commits.txt") `
            -ChangelogFile (Join-Path $script:testDir "CHANGELOG.md")

        $result.NewVersion | Should -Be "1.2.0"
        $result.BumpType | Should -Be "minor"
    }

    It "bumps major version from breaking change" {
        '{"version": "1.1.0"}' | Set-Content (Join-Path $script:testDir "version.json")
        "feat!: redesign API interface" | Set-Content (Join-Path $script:testDir "commits.txt")

        $result = Invoke-VersionBumper `
            -VersionFile (Join-Path $script:testDir "version.json") `
            -CommitsFile (Join-Path $script:testDir "commits.txt") `
            -ChangelogFile (Join-Path $script:testDir "CHANGELOG.md")

        $result.NewVersion | Should -Be "2.0.0"
        $result.BumpType | Should -Be "major"
    }

    It "creates CHANGELOG.md with new entry" {
        '{"version": "1.0.0"}' | Set-Content (Join-Path $script:testDir "version.json")
        "feat: new feature" | Set-Content (Join-Path $script:testDir "commits.txt")
        $changelogPath = Join-Path $script:testDir "CHANGELOG.md"

        Invoke-VersionBumper `
            -VersionFile (Join-Path $script:testDir "version.json") `
            -CommitsFile (Join-Path $script:testDir "commits.txt") `
            -ChangelogFile $changelogPath

        $changelogPath | Should -Exist
        $content = Get-Content $changelogPath -Raw
        $content | Should -Match "\[1\.1\.0\]"
    }

    It "prepends to existing CHANGELOG.md" {
        '{"version": "1.0.0"}' | Set-Content (Join-Path $script:testDir "version.json")
        "fix: bug fix" | Set-Content (Join-Path $script:testDir "commits.txt")
        $changelogPath = Join-Path $script:testDir "CHANGELOG.md"
        "## [1.0.0] - 2023-01-01`n`n- Initial release" | Set-Content $changelogPath

        Invoke-VersionBumper `
            -VersionFile (Join-Path $script:testDir "version.json") `
            -CommitsFile (Join-Path $script:testDir "commits.txt") `
            -ChangelogFile $changelogPath

        $content = Get-Content $changelogPath -Raw
        $content | Should -Match "\[1\.0\.1\]"
        $content | Should -Match "\[1\.0\.0\]"
        # New entry should come first
        $content.IndexOf("[1.0.1]") | Should -BeLessThan ($content.IndexOf("[1.0.0]"))
    }

    It "does nothing when no conventional commits found" {
        '{"version": "1.0.0"}' | Set-Content (Join-Path $script:testDir "version.json")
        "update readme`ntypo fix" | Set-Content (Join-Path $script:testDir "commits.txt")

        $result = Invoke-VersionBumper `
            -VersionFile (Join-Path $script:testDir "version.json") `
            -CommitsFile (Join-Path $script:testDir "commits.txt") `
            -ChangelogFile (Join-Path $script:testDir "CHANGELOG.md")

        $result.NewVersion | Should -Be "1.0.0"
        $result.BumpType | Should -Be "none"
        (Join-Path $script:testDir "CHANGELOG.md") | Should -Not -Exist
    }
}

Describe "Workflow Structure Tests" {
    BeforeAll {
        $script:WorkflowPath = Join-Path $PSScriptRoot ".github/workflows/semantic-version-bumper.yml"
        $script:ScriptPath = Join-Path $PSScriptRoot "VersionBumper.ps1"
    }

    It "workflow YAML file exists" {
        $script:WorkflowPath | Should -Exist
    }

    It "VersionBumper.ps1 script exists" {
        $script:ScriptPath | Should -Exist
    }

    It "workflow has push trigger" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "push:"
    }

    It "workflow has pull_request trigger" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "pull_request:"
    }

    It "workflow has workflow_dispatch trigger" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "workflow_dispatch:"
    }

    It "workflow references VersionBumper.ps1" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "VersionBumper\.ps1"
    }

    It "workflow uses shell: pwsh for run steps" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "shell: pwsh"
    }

    It "actionlint passes on workflow file" {
        # actionlint is a host-side tool; skip if not available (e.g., inside act container)
        if (-not (Get-Command actionlint -ErrorAction SilentlyContinue)) {
            Set-ItResult -Skipped -Because "actionlint not available in this environment"
            return
        }
        $output = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint reported: $output"
    }

    It "fixture directories exist" {
        (Join-Path $PSScriptRoot "fixtures/patch-bump/version.json") | Should -Exist
        (Join-Path $PSScriptRoot "fixtures/minor-bump/version.json") | Should -Exist
        (Join-Path $PSScriptRoot "fixtures/major-bump/version.json") | Should -Exist
        (Join-Path $PSScriptRoot "fixtures/patch-bump/commits.txt") | Should -Exist
        (Join-Path $PSScriptRoot "fixtures/minor-bump/commits.txt") | Should -Exist
        (Join-Path $PSScriptRoot "fixtures/major-bump/commits.txt") | Should -Exist
    }
}

Describe "Act Integration Tests" {
    BeforeAll {
        $script:ActResultFile = Join-Path $PSScriptRoot "act-result.txt"
    }

    # -Skip: is evaluated at discovery time, so check env var directly here (not via BeforeAll)
    It "workflow runs all scenarios successfully via act" -Skip:($env:ACT -eq "true") {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "svb-act-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        try {
            # Copy all project files to temp dir for a clean git repo
            foreach ($item in @("VersionBumper.ps1", "VersionBumper.Tests.ps1", ".github", "fixtures")) {
                $src = Join-Path $PSScriptRoot $item
                if (Test-Path $src -PathType Container) {
                    Copy-Item $src (Join-Path $tempDir $item) -Recurse -Force
                } elseif (Test-Path $src) {
                    Copy-Item $src $tempDir -Force
                }
            }

            # Copy .actrc for container image selection
            $actrcSrc = Join-Path $PSScriptRoot ".actrc"
            if (Test-Path $actrcSrc) {
                Copy-Item $actrcSrc $tempDir -Force
            }

            # Initialize git repo
            $null = & git -C $tempDir init --quiet
            $null = & git -C $tempDir config user.email "test@example.com"
            $null = & git -C $tempDir config user.name "Test User"
            $null = & git -C $tempDir add -A
            $null = & git -C $tempDir commit -m "chore: test setup" --quiet

            # Run act from the temp dir
            Push-Location $tempDir
            $actOutput = & act push --rm 2>&1
            $actExitCode = $LASTEXITCODE
            Pop-Location

            # Save output to act-result.txt (append with delimiter)
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Add-Content -Path $script:ActResultFile -Value "=== ACT TEST: All Scenarios ($timestamp) ==="
            $actOutput | Add-Content -Path $script:ActResultFile
            Add-Content -Path $script:ActResultFile -Value "Exit Code: $actExitCode"
            Add-Content -Path $script:ActResultFile -Value "=== END ACT TEST ==="
            Add-Content -Path $script:ActResultFile -Value ""

            # Assert exit code
            $actExitCode | Should -Be 0 -Because "act should exit successfully. Output:`n$($actOutput -join "`n")"

            $outputText = $actOutput -join "`n"

            # Assert patch bump scenario: 1.1.0 -> 1.1.1
            $outputText | Should -Match "NEW_VERSION: 1\.1\.1" `
                -Because "patch bump (fix commits on 1.1.0) should produce 1.1.1"

            # Assert minor bump scenario: 1.1.0 -> 1.2.0
            $outputText | Should -Match "NEW_VERSION: 1\.2\.0" `
                -Because "minor bump (feat commit on 1.1.0) should produce 1.2.0"

            # Assert major bump scenario: 1.1.0 -> 2.0.0
            $outputText | Should -Match "NEW_VERSION: 2\.0\.0" `
                -Because "major bump (breaking change on 1.1.0) should produce 2.0.0"

            # Assert jobs succeeded
            $outputText | Should -Match "Job succeeded" `
                -Because "all workflow jobs should complete successfully"
        } finally {
            if ((Get-Location).Path -eq $tempDir) { Pop-Location }
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
