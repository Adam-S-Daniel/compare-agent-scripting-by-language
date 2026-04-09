# ActRunner.Tests.ps1
# Runs the GitHub Actions workflow via `act` in an isolated Docker container.
# For each test case:
#   1. Sets up a temp git repo with project files + fixture data
#   2. Runs `act push --rm` and captures output
#   3. Asserts exit code 0 and "Job succeeded"
#   4. Asserts exact expected values in the output
# All output is appended to act-result.txt in the repo root.

BeforeAll {
    $script:repoRoot    = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    $script:actResultFile = Join-Path $script:repoRoot "act-result.txt"
    # Clear/create the result file
    Set-Content -Path $script:actResultFile -Value "# act-result.txt — Act Workflow Run Results`n"

    # Helper: set up a temp git repo, copy project files, run act, return output + exit code
    function Invoke-ActRun {
        param(
            [string]$TestName,
            [hashtable]$ExtraFiles = @{}
        )

        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("act-test-" + [System.IO.Path]::GetRandomFileName())
        New-Item -ItemType Directory -Path $tmpDir | Out-Null

        try {
            # Copy all project files including hidden dirs (like .github), excluding .git and act-result.txt
            Get-ChildItem $script:repoRoot -Recurse -Force | Where-Object {
                $rel = $_.FullName.Substring($script:repoRoot.Length + 1)
                -not ($rel -match '^\.git([/\\]|$)') -and ($_.Name -ne 'act-result.txt')
            } | ForEach-Object {
                $rel  = $_.FullName.Substring($script:repoRoot.Length + 1)
                $dest = Join-Path $tmpDir $rel
                if ($_.PSIsContainer) {
                    New-Item -ItemType Directory -Path $dest -Force | Out-Null
                } else {
                    $destDir = Split-Path $dest -Parent
                    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
                    Copy-Item $_.FullName $dest -Force
                }
            }

            # Write any extra/override fixture files
            foreach ($relPath in $ExtraFiles.Keys) {
                $dest = Join-Path $tmpDir $relPath
                $destDir = Split-Path $dest -Parent
                if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir | Out-Null }
                Set-Content -Path $dest -Value $ExtraFiles[$relPath]
            }

            # Init git repo (act requires a real git repo)
            Push-Location $tmpDir
            & git init -q
            & git config user.email "test@example.com"
            & git config user.name "Test"
            & git add -A
            & git commit -q -m "test fixture"
            Pop-Location

            # Run act
            $actOutput = & act push --rm -C $tmpDir 2>&1 | Out-String
            $exitCode  = $LASTEXITCODE

            return @{
                Output   = $actOutput
                ExitCode = $exitCode
                TmpDir   = $tmpDir
            }
        } finally {
            if ($tmpDir -and (Test-Path $tmpDir)) {
                Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    $script:InvokeActRun = ${function:Invoke-ActRun}
}

Describe "Act workflow runs" {
    It "Test case 1: package.json — all standard libraries pass" {
        $result = & $script:InvokeActRun -TestName "package-json-standard"

        # Append to act-result.txt
        Add-Content -Path $script:actResultFile -Value "`n=== Test Case 1: package.json standard libraries ==="
        Add-Content -Path $script:actResultFile -Value $result.Output

        # Assert exit code
        $result.ExitCode | Should -Be 0

        # Assert job succeeded
        $result.Output | Should -Match "Job succeeded"

        # Assert exact expected values in the output
        $result.Output | Should -Match "express"
        $result.Output | Should -Match "MIT"
        $result.Output | Should -Match "approved"
        $result.Output | Should -Match "gpl-package"
        $result.Output | Should -Match "denied"
        $result.Output | Should -Match "All \d+ tests passed"
    }

    It "Test case 2: requirements.txt — Python dependencies" {
        $result = & $script:InvokeActRun -TestName "requirements-txt"

        Add-Content -Path $script:actResultFile -Value "`n=== Test Case 2: requirements.txt Python dependencies ==="
        Add-Content -Path $script:actResultFile -Value $result.Output

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match "Job succeeded"

        # Exact expected values
        $result.Output | Should -Match "flask"
        $result.Output | Should -Match "BSD-3-Clause"
        $result.Output | Should -Match "approved"
        $result.Output | Should -Match "gpl-lib"
        $result.Output | Should -Match "GPL-2.0"
        $result.Output | Should -Match "denied"
    }

    It "Test case 3: MIT-only project — no denied licenses" {
        # Uses the dedicated package-mit-only.json fixture; no file overrides needed
        $result = & $script:InvokeActRun -TestName "mit-only"

        Add-Content -Path $script:actResultFile -Value "`n=== Test Case 3: MIT-only project ==="
        Add-Content -Path $script:actResultFile -Value $result.Output

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match "Job succeeded"
        # Exact expected values from the MIT-only check step
        $result.Output | Should -Match "MIT-only check: all 2 dependencies approved"
        $result.Output | Should -Match "approved"
    }
}
