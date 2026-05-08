<#
    Pester test suite for the Secret Rotation Validator workflow.

    Strategy
    --------
    The benchmark harness rules require that EVERY test case execute through
    the GitHub Actions workflow via `act`. So this file does no direct script
    invocation -- each end-to-end test stages a temp git repo containing the
    project files plus that case's fixture (renamed to `secrets.json`),
    runs `act push --rm`, and then asserts on the captured output.

    The workflow's "Emit report digest" step base64-encodes the report body and
    emits a single-line `::ROTATION_REPORT_B64::<b64>::` token. This sidesteps
    every per-line log-prefixing/quoting issue the CI renderer can introduce,
    so the harness can decode back to a byte-for-byte exact match against the
    expected output committed under tests/expected/.

    Output is appended to act-result.txt at the project root with clear
    delimiters per test case.
#>

BeforeDiscovery {
    # Fixtures and their expected outputs. Listed in BeforeDiscovery so we can
    # use TestCases to expand into one Pester `It` per fixture.
    $script:Cases = @(
        @{ Name = 'case1-all-ok';          Description = 'all secrets OK (markdown)';         Format = 'markdown' }
        @{ Name = 'case2-mixed-markdown';  Description = 'mixed urgencies (markdown)';        Format = 'markdown' }
        @{ Name = 'case3-all-expired';     Description = 'all expired (markdown)';            Format = 'markdown' }
        @{ Name = 'case4-mixed-json';      Description = 'mixed urgencies (json)';            Format = 'json'     }
    )
}

BeforeAll {
    $script:RepoRoot       = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:WorkflowPath   = Join-Path $script:RepoRoot '.github/workflows/secret-rotation-validator.yml'
    $script:ScriptPath     = Join-Path $script:RepoRoot 'Invoke-SecretRotationValidator.ps1'
    $script:FixturesDir    = Join-Path $script:RepoRoot 'tests/fixtures'
    $script:ExpectedDir    = Join-Path $script:RepoRoot 'tests/expected'
    $script:ActResultPath  = Join-Path $script:RepoRoot 'act-result.txt'
    $script:ActrcPath      = Join-Path $script:RepoRoot '.actrc'

    # Reset the act-result.txt artifact at the start of every Pester run so the
    # final file reflects only this run's output.
    if (Test-Path -LiteralPath $script:ActResultPath) {
        Remove-Item -LiteralPath $script:ActResultPath -Force
    }
    "# act-result.txt generated $(Get-Date -Format o)" | Out-File -LiteralPath $script:ActResultPath -Encoding utf8

    # Cache: act runs are slow, so keep one cached result per fixture and reuse
    # it across the multiple It-blocks that assert on different aspects of the
    # same act run (exit code, expected report body, "Job succeeded" line, etc.)
    $script:ActResults = @{}

    function Append-ActResult {
        param([string]$Header, [string]$Output)
        Add-Content -LiteralPath $script:ActResultPath -Value @(
            ''
            "===== $Header ====="
            $Output
            "===== /$Header ====="
        )
    }

    function Invoke-ActForCase {
        param([string]$CaseName)

        if ($script:ActResults.ContainsKey($CaseName)) {
            return $script:ActResults[$CaseName]
        }

        $tmpRoot = [System.IO.Path]::GetTempPath()
        $work = Join-Path $tmpRoot ("act-{0}-{1}" -f $CaseName, [Guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force -Path $work | Out-Null

        try {
            # Stage project files into the temp repo.
            Copy-Item -LiteralPath $script:ScriptPath -Destination (Join-Path $work 'Invoke-SecretRotationValidator.ps1')
            $wfDir = Join-Path $work '.github/workflows'
            New-Item -ItemType Directory -Force -Path $wfDir | Out-Null
            Copy-Item -LiteralPath $script:WorkflowPath -Destination (Join-Path $wfDir 'secret-rotation-validator.yml')
            if (Test-Path -LiteralPath $script:ActrcPath) {
                Copy-Item -LiteralPath $script:ActrcPath -Destination (Join-Path $work '.actrc')
            }

            # Stage the case's fixture as the workflow's expected secrets.json.
            $fixture = Join-Path $script:FixturesDir "$CaseName.json"
            Copy-Item -LiteralPath $fixture -Destination (Join-Path $work 'secrets.json')

            # act needs a git repo to compute event context.
            Push-Location $work
            try {
                git init -q -b main 2>&1 | Out-Null
                git config user.email 'test@example.com' 2>&1 | Out-Null
                git config user.name  'Test Harness'    2>&1 | Out-Null
                git add -A 2>&1 | Out-Null
                git commit -q -m "Test fixture: $CaseName" 2>&1 | Out-Null

                # Run act. --rm removes the container post-run; --pull=false skips
                # registry lookup since `act-ubuntu-pwsh:latest` is a locally-built
                # image (mapped via the project's .actrc).
                $output = & act push --rm --pull=false 2>&1 | Out-String
                $exitCode = $LASTEXITCODE
            } finally {
                Pop-Location
            }

            $result = [PSCustomObject]@{
                CaseName = $CaseName
                ExitCode = $exitCode
                Output   = $output
            }

            Append-ActResult -Header "$CaseName (exit=$exitCode)" -Output $output
            $script:ActResults[$CaseName] = $result
            return $result
        } finally {
            Remove-Item -Recurse -Force -LiteralPath $work -ErrorAction SilentlyContinue
        }
    }

    function Get-ReportFromActOutput {
        # Pull the base64 report body emitted by the workflow's "Emit report
        # digest" step and decode it.
        param([string]$Output)
        $match = [regex]::Match($Output, '::ROTATION_REPORT_B64::([A-Za-z0-9+/=]+)::')
        if (-not $match.Success) { return $null }
        $bytes = [Convert]::FromBase64String($match.Groups[1].Value)
        return [System.Text.Encoding]::UTF8.GetString($bytes)
    }

    function Get-ExpectedReport {
        param([string]$CaseName)
        $path = Join-Path $script:ExpectedDir "$CaseName.txt"
        # Use -Raw and trim trailing newlines so the comparison is whitespace-tight.
        return (Get-Content -LiteralPath $path -Raw).TrimEnd("`r", "`n")
    }
}

Describe 'Workflow file structure' {
    BeforeAll {
        $script:WorkflowYaml = Get-Content -LiteralPath $script:WorkflowPath -Raw
    }

    It 'workflow file exists at the expected path' {
        Test-Path -LiteralPath $script:WorkflowPath | Should -BeTrue
    }

    It 'references the validator script which exists in the repo' {
        Test-Path -LiteralPath $script:ScriptPath | Should -BeTrue
        $script:WorkflowYaml | Should -Match 'Invoke-SecretRotationValidator\.ps1'
    }

    It 'declares the expected triggers' {
        # We rely on string matching since adding a YAML parser dependency would
        # bloat this harness; structural checks are still cheap and clear.
        foreach ($trigger in @('push', 'pull_request', 'schedule', 'workflow_dispatch')) {
            $script:WorkflowYaml | Should -Match "(?m)^\s+${trigger}:" -Because "trigger '$trigger' must be declared"
        }
    }

    It 'declares contents:read permissions' {
        $script:WorkflowYaml | Should -Match '(?ms)permissions:\s*\r?\n\s*contents:\s*read'
    }

    It 'pins actions/checkout to a major-version tag (v4)' {
        $script:WorkflowYaml | Should -Match 'uses:\s*actions/checkout@v4'
    }

    It 'uses pwsh as the shell for the validator step' {
        $script:WorkflowYaml | Should -Match "(?m)^\s*shell:\s*pwsh"
    }

    It 'passes actionlint validation' {
        # actionlint exits 0 on a clean pass.
        $output = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $output"
    }
}

Describe 'End-to-end: workflow runs in act and produces the expected report' {
    It 'act push exits 0 for fixture <Name> (<Description>)' -TestCases $script:Cases {
        param($Name, $Description, $Format)
        $result = Invoke-ActForCase -CaseName $Name
        $result.ExitCode | Should -Be 0 -Because "fixture $Name should run cleanly under act; tail of output:`n$($result.Output -split "`n" | Select-Object -Last 30 | Out-String)"
    }

    It 'act log reports "Job succeeded" for fixture <Name>' -TestCases $script:Cases {
        param($Name, $Description, $Format)
        $result = Invoke-ActForCase -CaseName $Name
        $result.Output | Should -Match 'Job succeeded' -Because "act should report Job succeeded for fixture $Name"
    }

    It 'extracted report exactly matches expected output for fixture <Name> (<Description>)' -TestCases $script:Cases {
        param($Name, $Description, $Format)
        $result   = Invoke-ActForCase -CaseName $Name
        $report   = Get-ReportFromActOutput -Output $result.Output
        $expected = Get-ExpectedReport -CaseName $Name

        $report | Should -Not -BeNullOrEmpty -Because 'workflow must emit ::ROTATION_REPORT_B64:: digest'

        if ($Format -eq 'json') {
            # For JSON format, validate as parsed structure first (semantic compare),
            # then assert byte-exact equality so we still gate on the precise output.
            $actualObj   = $report   | ConvertFrom-Json -Depth 10
            $expectedObj = $expected | ConvertFrom-Json -Depth 10
            $actualObj.today                | Should -Be $expectedObj.today
            $actualObj.warningDays          | Should -Be $expectedObj.warningDays
            $actualObj.summary.expired      | Should -Be $expectedObj.summary.expired
            $actualObj.summary.warning      | Should -Be $expectedObj.summary.warning
            $actualObj.summary.ok           | Should -Be $expectedObj.summary.ok
            $actualObj.expired[0].name      | Should -Be $expectedObj.expired[0].name
            $actualObj.expired[0].daysUntilExpiry | Should -Be $expectedObj.expired[0].daysUntilExpiry
            $actualObj.warning[0].name      | Should -Be $expectedObj.warning[0].name
            $actualObj.warning[0].daysUntilExpiry | Should -Be $expectedObj.warning[0].daysUntilExpiry
            $actualObj.ok[0].name           | Should -Be $expectedObj.ok[0].name
            $actualObj.ok[0].daysUntilExpiry | Should -Be $expectedObj.ok[0].daysUntilExpiry
        }

        # Byte-exact check (line endings normalized to LF for cross-platform safety).
        $normActual   = ($report   -replace "`r`n", "`n").TrimEnd("`r", "`n")
        $normExpected = ($expected -replace "`r`n", "`n").TrimEnd("`r", "`n")
        $normActual | Should -Be $normExpected
    }
}
