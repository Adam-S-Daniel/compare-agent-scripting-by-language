# Bump-SemanticVersion.Tests.ps1
#
# Pester tests for the Semantic Version Bumper.
# All functional tests run through the GitHub Actions workflow via act.
# Structural tests validate the workflow YAML and file references.

BeforeAll {
    $script:ProjectRoot = $PSScriptRoot
    $script:WorkflowPath = Join-Path $ProjectRoot '.github/workflows/semantic-version-bumper.yml'
    $script:ScriptPath = Join-Path $ProjectRoot 'Bump-SemanticVersion.ps1'
    $script:FixturesDir = Join-Path $ProjectRoot 'fixtures'
    $script:ActResultFile = Join-Path $ProjectRoot 'act-result.txt'

    # Start fresh act-result.txt
    Set-Content -Path $script:ActResultFile -Value "ACT TEST RESULTS`n================`n"

    # Helper: set up an isolated git repo with fixtures and run act push
    function Invoke-ActTest {
        param(
            [string]$TestName,
            [string]$InitialVersion,
            [string[]]$CommitMessages
        )

        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "svb-$(New-Guid)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        try {
            Push-Location $tempDir

            # Initialize git repo
            git init --initial-branch=main 2>&1 | Out-Null
            git config user.email "test@example.com" 2>&1 | Out-Null
            git config user.name "Test User" 2>&1 | Out-Null

            # Copy project files into the temp repo
            Copy-Item $script:ScriptPath -Destination $tempDir
            New-Item -ItemType Directory -Path (Join-Path $tempDir '.github/workflows') -Force | Out-Null
            Copy-Item $script:WorkflowPath -Destination (Join-Path $tempDir '.github/workflows/')
            Copy-Item (Join-Path $script:ProjectRoot '.actrc') -Destination $tempDir -ErrorAction SilentlyContinue

            # Create VERSION file with the initial version
            Set-Content -Path (Join-Path $tempDir 'VERSION') -Value $InitialVersion -NoNewline

            # Initial commit (includes all project files)
            git add -A 2>&1 | Out-Null
            git commit -m "chore: initial project setup" 2>&1 | Out-Null

            # Create test commits - each needs a unique file change
            $i = 0
            foreach ($msg in $CommitMessages) {
                $i++
                Set-Content -Path (Join-Path $tempDir "change-$i.txt") -Value "change $i"
                git add -A 2>&1 | Out-Null
                git commit -m $msg 2>&1 | Out-Null
            }

            # Run act - simulate a push event (--pull=false uses local image)
            $actOutput = act push --rm --pull=false 2>&1 | Out-String
            $actExit = $LASTEXITCODE

            Pop-Location

            # Append results to act-result.txt
            $separator = "`n" + ("=" * 60) + "`n"
            $entry = @(
                $separator
                "TEST CASE: $TestName"
                "Initial Version: $InitialVersion"
                "Commits: $($CommitMessages -join '; ')"
                "Exit Code: $actExit"
                $separator
                $actOutput
                $separator
            ) -join "`n"
            Add-Content -Path $script:ActResultFile -Value $entry

            return @{
                Output   = $actOutput
                ExitCode = $actExit
            }
        } finally {
            if ((Get-Location).Path -eq $tempDir) { Pop-Location }
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# --- Workflow Structure Tests ---
Describe "Workflow Structure" {

    It "workflow YAML file exists at expected path" {
        $script:WorkflowPath | Should -Exist
    }

    It "main script file exists" {
        $script:ScriptPath | Should -Exist
    }

    It "fixture files exist" {
        Join-Path $script:FixturesDir 'patch-bump.psd1' | Should -Exist
        Join-Path $script:FixturesDir 'minor-bump.psd1' | Should -Exist
        Join-Path $script:FixturesDir 'major-bump.psd1' | Should -Exist
    }

    It "workflow has push trigger" {
        $yaml = Get-Content $script:WorkflowPath -Raw
        $yaml | Should -Match 'on:' -Because "workflow must define triggers"
        $yaml | Should -Match 'push:' -Because "workflow must trigger on push"
    }

    It "workflow has workflow_dispatch trigger" {
        $yaml = Get-Content $script:WorkflowPath -Raw
        $yaml | Should -Match 'workflow_dispatch' -Because "workflow must support manual dispatch"
    }

    It "workflow references Bump-SemanticVersion.ps1" {
        $yaml = Get-Content $script:WorkflowPath -Raw
        $yaml | Should -Match 'Bump-SemanticVersion\.ps1' -Because "workflow must reference the script"
    }

    It "workflow uses pwsh shell" {
        $yaml = Get-Content $script:WorkflowPath -Raw
        $yaml | Should -Match 'shell:\s*pwsh' -Because "workflow must use pwsh shell"
    }

    It "workflow uses actions/checkout@v4 with fetch-depth 0" {
        $yaml = Get-Content $script:WorkflowPath -Raw
        $yaml | Should -Match 'actions/checkout@v4' -Because "workflow must check out code"
        $yaml | Should -Match 'fetch-depth:\s*0' -Because "full git history is needed"
    }

    It "passes actionlint validation" {
        $output = actionlint $script:WorkflowPath 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $output"
    }
}

# --- Act Integration Tests ---
# Each test loads a fixture, sets up a temp repo, runs act, and asserts exact values.
Describe "Act Integration - Version Bumping" {

    It "patch bump: fix commits bump 1.0.0 -> 1.0.1" {
        $fixture = Import-PowerShellDataFile (Join-Path $script:FixturesDir 'patch-bump.psd1')

        $result = Invoke-ActTest `
            -TestName $fixture.Name `
            -InitialVersion $fixture.InitialVersion `
            -CommitMessages $fixture.Commits

        # Assert act succeeded
        $result.ExitCode | Should -Be 0 -Because "act must exit cleanly"
        $result.Output | Should -Match 'Job succeeded' -Because "the workflow job must succeed"

        # Assert exact version output
        $result.Output | Should -Match "Current version: $([regex]::Escape($fixture.InitialVersion))"
        $result.Output | Should -Match "NEW_VERSION=$([regex]::Escape($fixture.ExpectedVersion))"
        $result.Output | Should -Match "BUMP_TYPE=$([regex]::Escape($fixture.ExpectedBump))"

        # Assert the VERSION file was updated (shown in "Show results" step)
        $result.Output | Should -Match $([regex]::Escape($fixture.ExpectedVersion))
    }

    It "minor bump: feat commits bump 1.1.0 -> 1.2.0" {
        $fixture = Import-PowerShellDataFile (Join-Path $script:FixturesDir 'minor-bump.psd1')

        $result = Invoke-ActTest `
            -TestName $fixture.Name `
            -InitialVersion $fixture.InitialVersion `
            -CommitMessages $fixture.Commits

        $result.ExitCode | Should -Be 0 -Because "act must exit cleanly"
        $result.Output | Should -Match 'Job succeeded' -Because "the workflow job must succeed"

        $result.Output | Should -Match "Current version: $([regex]::Escape($fixture.InitialVersion))"
        $result.Output | Should -Match "NEW_VERSION=$([regex]::Escape($fixture.ExpectedVersion))"
        $result.Output | Should -Match "BUMP_TYPE=$([regex]::Escape($fixture.ExpectedBump))"
    }

    It "major bump: breaking change bumps 2.0.0 -> 3.0.0" {
        $fixture = Import-PowerShellDataFile (Join-Path $script:FixturesDir 'major-bump.psd1')

        $result = Invoke-ActTest `
            -TestName $fixture.Name `
            -InitialVersion $fixture.InitialVersion `
            -CommitMessages $fixture.Commits

        $result.ExitCode | Should -Be 0 -Because "act must exit cleanly"
        $result.Output | Should -Match 'Job succeeded' -Because "the workflow job must succeed"

        $result.Output | Should -Match "Current version: $([regex]::Escape($fixture.InitialVersion))"
        $result.Output | Should -Match "NEW_VERSION=$([regex]::Escape($fixture.ExpectedVersion))"
        $result.Output | Should -Match "BUMP_TYPE=$([regex]::Escape($fixture.ExpectedBump))"
    }
}

# Verify act-result.txt was created with content
Describe "Act Result Artifact" {
    It "act-result.txt exists and has content" {
        $script:ActResultFile | Should -Exist
        (Get-Content $script:ActResultFile -Raw).Length | Should -BeGreaterThan 100
    }
}
