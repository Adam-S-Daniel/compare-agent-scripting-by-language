# Workflow.Tests.ps1
# Pester tests that run the GitHub Actions workflow through `act` and assert on
# the captured output. All output is appended to ./act-result.txt.

BeforeDiscovery {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:Workflow = Join-Path $RepoRoot '.github/workflows/environment-matrix-generator.yml'
    $script:ActLog   = Join-Path $RepoRoot 'act-result.txt'
}

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:Workflow = Join-Path $RepoRoot '.github/workflows/environment-matrix-generator.yml'
    $script:ActLog   = Join-Path $RepoRoot 'act-result.txt'

    # Reset the act log once per test run.
    if (Test-Path -LiteralPath $script:ActLog) { Remove-Item -LiteralPath $script:ActLog -Force }

    function script:Invoke-ActPush {
        param([string]$Label)
        Push-Location $script:RepoRoot
        try {
            # Set up a fresh temp git repo so act sees a checkout-able workspace
            $stagedDir = Join-Path ([IO.Path]::GetTempPath()) ("matrix-harness-" + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Force -Path $stagedDir | Out-Null
            # Use rsync-like copy that includes dotfiles (e.g. .actrc, .github)
            Get-ChildItem -Force -Path $script:RepoRoot | Where-Object { $_.Name -ne '.git' -and $_.Name -ne 'act-result.txt' } |
                ForEach-Object { Copy-Item -Recurse -Force -Path $_.FullName -Destination $stagedDir }
            # Remove any prior git state from the copy
            $gitCopy = Join-Path $stagedDir '.git'
            if (Test-Path $gitCopy) { Remove-Item -Recurse -Force $gitCopy }
            Push-Location $stagedDir
            try {
                git init -q -b main 2>&1 | Out-Null
                git config user.email 'harness@example.com' 2>&1 | Out-Null
                git config user.name 'harness' 2>&1 | Out-Null
                git add -A 2>&1 | Out-Null
                git commit -q -m 'harness fixture' 2>&1 | Out-Null
                $out = & act push --rm --pull=false -P ubuntu-latest=act-ubuntu-pwsh:latest --workflows .github/workflows/environment-matrix-generator.yml 2>&1
                $code = $LASTEXITCODE
                $delim = "`n`n===== ACT RUN: $Label =====`n"
                Add-Content -LiteralPath $script:ActLog -Value ($delim + ($out -join "`n") + "`nEXIT=$code`n")
                return [pscustomobject]@{ ExitCode = $code; Output = ($out -join "`n") }
            }
            finally { Pop-Location }
        }
        finally { Pop-Location }
    }
}

Describe 'Workflow file structure' {
    It 'exists at the expected path' {
        Test-Path -LiteralPath $script:Workflow | Should -BeTrue
    }

    It 'passes actionlint' {
        $out = & actionlint $script:Workflow 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($out -join "`n")
    }

    It 'references the real script files' {
        $text = Get-Content -Raw -LiteralPath $script:Workflow
        $text | Should -Match 'Invoke-Matrix\.ps1'
        Test-Path -LiteralPath (Join-Path $script:RepoRoot 'Invoke-Matrix.ps1') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:RepoRoot 'MatrixGenerator.ps1') | Should -BeTrue
    }

    It 'defines expected triggers and jobs' {
        $text = Get-Content -Raw -LiteralPath $script:Workflow
        $text | Should -Match 'on:'
        $text | Should -Match 'push:'
        $text | Should -Match 'pull_request:'
        $text | Should -Match 'workflow_dispatch:'
        $text | Should -Match 'schedule:'
        $text | Should -Match 'jobs:\s*\n\s*test:'
        $text | Should -Match 'generate:'
    }
}

Describe 'Workflow executes under act' {
    BeforeAll {
        function Get-ActJsonBlock {
            param([string]$Haystack, [string]$StartTag, [string]$EndTag)
            $m = [regex]::Match($Haystack, [regex]::Escape($StartTag) + '(?<b>.*?)' + [regex]::Escape($EndTag), 'Singleline')
            if (-not $m.Success) { return $null }
            $lines = $m.Groups['b'].Value -split "`n"
            $clean = foreach ($l in $lines) { $l -replace '^\s*\[[^\]]*\]\s*\|\s?', '' }
            return ($clean -join "`n").Trim()
        }
        $script:Run = script:Invoke-ActPush -Label 'all-fixtures'
    }

    It 'exits with code 0' {
        $script:Run.ExitCode | Should -Be 0 -Because $script:Run.Output
    }

    It 'reports both jobs succeeded' {
        $script:Run.Output | Should -Match 'Job succeeded'
        # 2 jobs => at least 2 "Job succeeded" lines
        ([regex]::Matches($script:Run.Output, 'Job succeeded')).Count | Should -BeGreaterOrEqual 2
    }

    It 'emits the simple matrix with count=4, fail-fast=true, max-parallel=2' {
        $body = Get-ActJsonBlock -Haystack $script:Run.Output -StartTag '=== SIMPLE_START ===' -EndTag '=== SIMPLE_END ==='
        $body | Should -Not -BeNullOrEmpty
        $obj = $body | ConvertFrom-Json
        $obj.count | Should -Be 4
        $obj.'fail-fast' | Should -Be $true
        $obj.'max-parallel' | Should -Be 2
    }

    It 'emits the include/exclude matrix with count=5 and flagged combo' {
        $body = Get-ActJsonBlock -Haystack $script:Run.Output -StartTag '=== IE_START ===' -EndTag '=== IE_END ==='
        $body | Should -Not -BeNullOrEmpty
        $obj = $body | ConvertFrom-Json
        $obj.count | Should -Be 5
        $obj.'fail-fast' | Should -Be $false
        $obj.'max-parallel' | Should -Be 3
        $flagged = $obj.combinations | Where-Object { $_.os -eq 'ubuntu-latest' -and $_.node -eq '20' }
        $flagged.experimental | Should -Be $true
    }

    It 'reports the oversize fixture as failing max_size validation' {
        $body = Get-ActJsonBlock -Haystack $script:Run.Output -StartTag '=== OVERSIZE_START ===' -EndTag '=== OVERSIZE_END ==='
        $body | Should -Not -BeNullOrEmpty
        $body | Should -Match 'exceeds max_size'
        $body | Should -Match 'exit=1'
    }
}
