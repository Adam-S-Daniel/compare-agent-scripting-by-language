# VersionBumper.Tests.ps1
# Pester v5 test suite for the Semantic Version Bumper.
# Run with: Invoke-Pester
#
# TDD approach:
#   RED  - tests written before implementation (will fail without the ps1/workflow)
#   GREEN - implementation makes every test pass
#
# Pester v5 scoping rules applied here:
#   - $script: variables set in root BeforeAll are visible everywhere.
#   - Functions defined in root BeforeAll are visible in nested BeforeAll/It blocks.

# ============================================================
# Root-level BeforeAll — runs once before any Describe block.
# ============================================================
BeforeAll {

    # --- Path constants ---
    $script:ProjectRoot   = $PSScriptRoot
    $script:ScriptPath    = Join-Path $script:ProjectRoot "Invoke-VersionBumper.ps1"
    $script:WorkflowPath  = Join-Path $script:ProjectRoot ".github/workflows/semantic-version-bumper.yml"
    $script:ActResultPath = Join-Path $script:ProjectRoot "act-result.txt"
    $script:TempRepos     = [System.Collections.Generic.List[string]]::new()

    # Reset the act-result artifact so each full test run starts fresh.
    Set-Content -Path $script:ActResultPath -Value "" -Encoding UTF8

    # -----------------------------------------------------------------
    # New-TestRepo: create a throwaway git repo with project files
    # plus caller-supplied fixture files.
    # -----------------------------------------------------------------
    function New-TestRepo {
        param(
            [hashtable]$Files   # relative path -> content string
        )

        $tmpRepo = Join-Path ([System.IO.Path]::GetTempPath()) "vb-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $tmpRepo -Force | Out-Null
        $script:TempRepos.Add($tmpRepo)

        # Copy main implementation script.
        Copy-Item $script:ScriptPath $tmpRepo

        # Copy GitHub Actions workflow.
        $wfDest = Join-Path $tmpRepo ".github/workflows"
        New-Item -ItemType Directory -Path $wfDest -Force | Out-Null
        Copy-Item $script:WorkflowPath (Join-Path $wfDest (Split-Path $script:WorkflowPath -Leaf))

        # Write caller-supplied fixture files.
        foreach ($entry in $Files.GetEnumerator()) {
            $dest    = Join-Path $tmpRepo $entry.Key
            $destDir = Split-Path $dest -Parent
            if ($destDir -and -not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Set-Content -Path $dest -Value $entry.Value -NoNewline -Encoding UTF8
        }

        # Initialise git and commit everything so act has a real repo to check out.
        & git -C $tmpRepo init --quiet 2>&1 | Out-Null
        & git -C $tmpRepo config user.email "test@test.com"
        & git -C $tmpRepo config user.name "test"
        & git -C $tmpRepo add -A 2>&1 | Out-Null
        & git -C $tmpRepo commit -m "test: initial commit" --quiet 2>&1 | Out-Null

        return $tmpRepo
    }

    # -----------------------------------------------------------------
    # Invoke-ActTest: run `act push --rm` in $RepoPath, append output
    # to act-result.txt, and return { Output: string; ExitCode: int }.
    # -----------------------------------------------------------------
    function Invoke-ActTest {
        param(
            [string]$RepoPath,
            [string]$TestName
        )

        Push-Location $RepoPath
        $rawOutput = $null
        $exitCode  = -1
        try {
            $rawOutput = & act push --rm `
                -P "ubuntu-latest=act-ubuntu-pwsh:latest" `
                --pull=false `
                -s GITHUB_TOKEN=dummy 2>&1
            $exitCode = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }

        $outputStr = ($rawOutput -join "`n")

        # Append to the required act-result.txt artifact.
        $bar   = "=" * 60
        $entry = @"
$bar
TEST: $TestName
DATE: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
$bar
$outputStr
$bar
EXIT CODE: $exitCode
$bar

"@
        Add-Content -Path $script:ActResultPath -Value $entry -Encoding UTF8

        return @{
            Output   = $outputStr
            ExitCode = $exitCode
        }
    }
}

# Root-level AfterAll — clean up temp git repos created during the run.
AfterAll {
    foreach ($dir in $script:TempRepos) {
        if (Test-Path $dir) {
            Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ===========================================================================
# 1. WORKFLOW STRUCTURE TESTS — no act needed; validate YAML & paths only.
# ===========================================================================
Describe "Workflow Structure" {

    # TDD RED: these fail before the workflow file is created.
    It "workflow file exists at expected path" {
        $script:WorkflowPath | Should -Exist
    }

    It "workflow YAML contains an 'on:' block" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "on:"
    }

    It "workflow has a push trigger" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "push:"
    }

    It "workflow has at least one job" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "jobs:"
    }

    It "workflow uses 'shell: pwsh' (not pwsh -File or pwsh -Command)" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "shell:\s*pwsh"
    }

    It "workflow references Invoke-VersionBumper.ps1" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "Invoke-VersionBumper"
    }

    It "main script file exists" {
        $script:ScriptPath | Should -Exist
    }

    It "actionlint passes with exit code 0" {
        $out = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $($out -join "`n")"
    }
}

# ===========================================================================
# 2. ACT INTEGRATION — minor bump (feat commit)
#    feat: ... should bump the minor component:  1.1.0 -> 1.2.0
# ===========================================================================
Describe "Act: Minor Bump via feat commit" {

    BeforeAll {
        # TDD RED: fails until Invoke-VersionBumper.ps1 and workflow are written.
        $repo = New-TestRepo -Files @{
            "version.txt" = "1.1.0"
            "commits.txt" = "feat: add pagination support"
        }
        $script:MinorResult = Invoke-ActTest -RepoPath $repo -TestName "Minor Bump (feat: 1.1.0 -> 1.2.0)"
    }

    It "act exits with code 0" {
        $script:MinorResult.ExitCode | Should -Be 0
    }

    It "output contains exactly NEW_VERSION=1.2.0" {
        $script:MinorResult.Output | Should -Match "NEW_VERSION=1\.2\.0"
    }

    It "job shows succeeded" {
        $script:MinorResult.Output | Should -Match "succeeded|Success"
    }
}

# ===========================================================================
# 3. ACT INTEGRATION — patch bump (fix commit)
#    fix: ... should bump the patch component:   2.0.0 -> 2.0.1
# ===========================================================================
Describe "Act: Patch Bump via fix commit" {

    BeforeAll {
        $repo = New-TestRepo -Files @{
            "version.txt" = "2.0.0"
            "commits.txt" = "fix: correct off-by-one error in range calculation"
        }
        $script:PatchResult = Invoke-ActTest -RepoPath $repo -TestName "Patch Bump (fix: 2.0.0 -> 2.0.1)"
    }

    It "act exits with code 0" {
        $script:PatchResult.ExitCode | Should -Be 0
    }

    It "output contains exactly NEW_VERSION=2.0.1" {
        $script:PatchResult.Output | Should -Match "NEW_VERSION=2\.0\.1"
    }

    It "job shows succeeded" {
        $script:PatchResult.Output | Should -Match "succeeded|Success"
    }
}

# ===========================================================================
# 4. ACT INTEGRATION — major bump (breaking change with !)
#    feat!: ... should bump the major component: 1.1.0 -> 2.0.0
# ===========================================================================
Describe "Act: Major Bump via breaking change" {

    BeforeAll {
        $repo = New-TestRepo -Files @{
            "version.txt" = "1.1.0"
            "commits.txt" = "feat!: redesign public API to use REST conventions"
        }
        $script:MajorResult = Invoke-ActTest -RepoPath $repo -TestName "Major Bump (feat!: 1.1.0 -> 2.0.0)"
    }

    It "act exits with code 0" {
        $script:MajorResult.ExitCode | Should -Be 0
    }

    It "output contains exactly NEW_VERSION=2.0.0" {
        $script:MajorResult.Output | Should -Match "NEW_VERSION=2\.0\.0"
    }

    It "job shows succeeded" {
        $script:MajorResult.Output | Should -Match "succeeded|Success"
    }
}

# ===========================================================================
# 5. ACT INTEGRATION — read version from package.json
#    fix: ... on a package.json repo: 2.3.4 -> 2.3.5
# ===========================================================================
Describe "Act: Patch Bump reading version from package.json" {

    BeforeAll {
        $pkgJson = '{"name":"my-package","version":"2.3.4","description":"test"}'
        $repo = New-TestRepo -Files @{
            "package.json" = $pkgJson
            "commits.txt"  = "fix: handle null pointer in auth middleware"
        }
        $script:PkgResult = Invoke-ActTest -RepoPath $repo -TestName "Patch Bump from package.json (fix: 2.3.4 -> 2.3.5)"
    }

    It "act exits with code 0" {
        $script:PkgResult.ExitCode | Should -Be 0
    }

    It "output contains exactly NEW_VERSION=2.3.5" {
        $script:PkgResult.Output | Should -Match "NEW_VERSION=2\.3\.5"
    }

    It "job shows succeeded" {
        $script:PkgResult.Output | Should -Match "succeeded|Success"
    }
}
