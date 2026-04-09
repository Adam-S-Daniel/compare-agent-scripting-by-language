<#
.SYNOPSIS
    Pester test harness for the Secret Rotation Validator.
    All functional tests run through GitHub Actions via `act`.
    Workflow structure tests validate YAML, actionlint, and file references.
#>

BeforeAll {
    $script:ProjectRoot = $PSScriptRoot
    $script:WorkflowPath = Join-Path $ProjectRoot ".github/workflows/secret-rotation-validator.yml"
    $script:ActResultFile = Join-Path $ProjectRoot "act-result.txt"

    # Clear previous act results
    if (Test-Path $ActResultFile) { Remove-Item $ActResultFile -Force }

    # Helper: set up a temp git repo with project files + a specific fixture,
    # run act push --rm, capture output, and return it.
    function Invoke-ActWithFixture {
        param(
            [string]$FixturePath,
            [string]$TestLabel,
            [string]$WarningDays = "7",
            [string]$OutputFormat = "markdown",
            [string]$ReferenceDate = "2026-04-09"
        )

        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        try {
            Push-Location $tempDir
            & git init --initial-branch=master 2>&1 | Out-Null

            # Copy project files
            Copy-Item -Path (Join-Path $script:ProjectRoot ".github") -Destination $tempDir -Recurse
            Copy-Item -Path (Join-Path $script:ProjectRoot "Validate-SecretRotation.ps1") -Destination $tempDir

            # Create fixtures directory and copy the specific fixture as the config
            New-Item -ItemType Directory -Path (Join-Path $tempDir "fixtures") -Force | Out-Null
            Copy-Item -Path $FixturePath -Destination (Join-Path $tempDir "fixtures/test-config.json")

            # Modify the workflow env block using SRVAL_ prefixed vars (case-sensitive)
            $wfPath = Join-Path $tempDir ".github/workflows/secret-rotation-validator.yml"
            $wfContent = Get-Content $wfPath -Raw
            $wfContent = $wfContent -creplace "SRVAL_CONFIG_FILE: '[^']*'", "SRVAL_CONFIG_FILE: 'fixtures/test-config.json'"
            $wfContent = $wfContent -creplace "SRVAL_WARNING_DAYS: '[^']*'", "SRVAL_WARNING_DAYS: '$WarningDays'"
            $wfContent = $wfContent -creplace "SRVAL_REFERENCE_DATE: '[^']*'", "SRVAL_REFERENCE_DATE: '$ReferenceDate'"
            $wfContent = $wfContent -creplace "SRVAL_OUTPUT_FORMAT: '[^']*'", "SRVAL_OUTPUT_FORMAT: '$OutputFormat'"
            Set-Content -Path $wfPath -Value $wfContent -NoNewline

            & git add -A 2>&1 | Out-Null
            & git commit -m "test: $TestLabel" 2>&1 | Out-Null

            # Run act
            $actOutput = & act push --rm 2>&1 | Out-String
            $actExit = $LASTEXITCODE

            # Append to act-result.txt
            $delimiter = "`n$('=' * 60)`n=== TEST CASE: $TestLabel`n$('=' * 60)`n"
            Add-Content -Path $script:ActResultFile -Value "$delimiter$actOutput"

            return @{
                Output   = $actOutput
                ExitCode = $actExit
            }
        }
        finally {
            Pop-Location
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================
# WORKFLOW STRUCTURE TESTS
# ============================================================
Describe "Workflow Structure Tests" {

    It "Workflow YAML file exists" {
        $script:WorkflowPath | Should -Exist
    }

    It "Workflow YAML parses correctly and has expected triggers" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "on:"
        $content | Should -Match "push:"
        $content | Should -Match "pull_request:"
        $content | Should -Match "schedule:"
        $content | Should -Match "workflow_dispatch:"
    }

    It "Workflow references Validate-SecretRotation.ps1 and the file exists" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "Validate-SecretRotation.ps1"

        $scriptPath = Join-Path $script:ProjectRoot "Validate-SecretRotation.ps1"
        $scriptPath | Should -Exist
    }

    It "Workflow references fixture files and they exist" {
        $fixturesDir = Join-Path $script:ProjectRoot "fixtures"
        $fixturesDir | Should -Exist
        (Get-ChildItem -Path $fixturesDir -Filter "*.json").Count | Should -BeGreaterThan 0
    }

    It "Workflow has correct job structure" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "jobs:"
        $content | Should -Match "validate-secrets:"
        $content | Should -Match "runs-on:"
        $content | Should -Match "actions/checkout@v4"
    }

    It "Workflow has permissions configured" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "permissions:"
    }

    It "actionlint passes with exit code 0" {
        $result = & actionlint $script:WorkflowPath 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0 -Because "actionlint should pass cleanly: $result"
    }
}

# ============================================================
# FUNCTIONAL TESTS VIA ACT
# ============================================================
Describe "Mixed Secrets - Markdown Output" {

    BeforeAll {
        $fixturePath = Join-Path $script:ProjectRoot "fixtures/mixed-secrets.json"
        $script:mixedMdResult = Invoke-ActWithFixture `
            -FixturePath $fixturePath `
            -TestLabel "mixed-secrets-markdown" `
            -OutputFormat "markdown" `
            -ReferenceDate "2026-04-09"
    }

    It "act exits with code 0" {
        $script:mixedMdResult.ExitCode | Should -Be 0
    }

    It "Job succeeded" {
        $script:mixedMdResult.Output | Should -Match "Job succeeded"
    }

    It "Markdown report contains the header" {
        $script:mixedMdResult.Output | Should -Match "Secret Rotation Report"
    }

    It "Reports 2 expired secrets in summary" {
        $script:mixedMdResult.Output | Should -Match "\| Expired\s*\| 2 \|"
    }

    It "Reports 1 warning secret in summary" {
        $script:mixedMdResult.Output | Should -Match "\| Warning\s*\| 1 \|"
    }

    It "Reports 2 ok secrets in summary" {
        $script:mixedMdResult.Output | Should -Match "\| OK\s*\| 2 \|"
    }

    It "DB_PASSWORD appears in expired section" {
        $script:mixedMdResult.Output | Should -Match "DB_PASSWORD"
    }

    It "AWS_SECRET_KEY appears in expired section" {
        $script:mixedMdResult.Output | Should -Match "AWS_SECRET_KEY"
    }

    It "JWT_SIGNING_KEY appears in output" {
        $script:mixedMdResult.Output | Should -Match "JWT_SIGNING_KEY"
    }

    It "Detects expired secrets notification" {
        $script:mixedMdResult.Output | Should -Match "Expired secrets detected"
    }
}

Describe "Mixed Secrets - JSON Output" {

    BeforeAll {
        $fixturePath = Join-Path $script:ProjectRoot "fixtures/mixed-secrets.json"
        $script:mixedJsonResult = Invoke-ActWithFixture `
            -FixturePath $fixturePath `
            -TestLabel "mixed-secrets-json" `
            -OutputFormat "json" `
            -ReferenceDate "2026-04-09"
    }

    It "act exits with code 0" {
        $script:mixedJsonResult.ExitCode | Should -Be 0
    }

    It "Job succeeded" {
        $script:mixedJsonResult.Output | Should -Match "Job succeeded"
    }

    It "JSON output contains referenceDate 2026-04-09" {
        $script:mixedJsonResult.Output | Should -Match '"referenceDate":\s*"2026-04-09"'
    }

    It "JSON summary shows 2 expired" {
        $script:mixedJsonResult.Output | Should -Match '"expired":\s*2'
    }

    It "JSON summary shows 1 warning" {
        $script:mixedJsonResult.Output | Should -Match '"warning":\s*1'
    }

    It "JSON summary shows 2 ok" {
        $script:mixedJsonResult.Output | Should -Match '"ok":\s*2'
    }

    It "DB_PASSWORD has DaysUntilExpiry of -8" {
        $script:mixedJsonResult.Output | Should -Match '"Name":\s*"DB_PASSWORD"'
        $script:mixedJsonResult.Output | Should -Match '"DaysUntilExpiry":\s*-8'
    }

    It "JWT_SIGNING_KEY has DaysUntilExpiry of 3" {
        $script:mixedJsonResult.Output | Should -Match '"Name":\s*"JWT_SIGNING_KEY"'
        $script:mixedJsonResult.Output | Should -Match '"DaysUntilExpiry":\s*3'
    }
}

Describe "All OK Secrets" {

    BeforeAll {
        $fixturePath = Join-Path $script:ProjectRoot "fixtures/all-ok-secrets.json"
        $script:allOkResult = Invoke-ActWithFixture `
            -FixturePath $fixturePath `
            -TestLabel "all-ok-secrets" `
            -OutputFormat "markdown" `
            -ReferenceDate "2026-04-09"
    }

    It "act exits with code 0" {
        $script:allOkResult.ExitCode | Should -Be 0
    }

    It "Job succeeded" {
        $script:allOkResult.Output | Should -Match "Job succeeded"
    }

    It "Reports 0 expired" {
        $script:allOkResult.Output | Should -Match "\| Expired\s*\| 0 \|"
    }

    It "Reports 0 warning" {
        $script:allOkResult.Output | Should -Match "\| Warning\s*\| 0 \|"
    }

    It "Reports 2 ok" {
        $script:allOkResult.Output | Should -Match "\| OK\s*\| 2 \|"
    }

    It "Shows all secrets within policy" {
        $script:allOkResult.Output | Should -Match "All secrets are within rotation policy"
    }
}

Describe "All Expired Secrets" {

    BeforeAll {
        $fixturePath = Join-Path $script:ProjectRoot "fixtures/all-expired-secrets.json"
        $script:allExpiredResult = Invoke-ActWithFixture `
            -FixturePath $fixturePath `
            -TestLabel "all-expired-secrets" `
            -OutputFormat "json" `
            -ReferenceDate "2026-04-09"
    }

    It "act exits with code 0" {
        $script:allExpiredResult.ExitCode | Should -Be 0
    }

    It "Job succeeded" {
        $script:allExpiredResult.Output | Should -Match "Job succeeded"
    }

    It "JSON shows 2 expired, 0 warning, 0 ok" {
        $script:allExpiredResult.Output | Should -Match '"expired":\s*2'
        $script:allExpiredResult.Output | Should -Match '"warning":\s*0'
        $script:allExpiredResult.Output | Should -Match '"ok":\s*0'
    }

    It "OLD_DB_PASS has DaysUntilExpiry of -373" {
        # lastRotated 2025-01-01 + 90 = 2025-04-01, ref 2026-04-09 => -373 days
        $script:allExpiredResult.Output | Should -Match '"Name":\s*"OLD_DB_PASS"'
        $script:allExpiredResult.Output | Should -Match '"DaysUntilExpiry":\s*-373'
    }

    It "OLD_API_KEY has DaysUntilExpiry of -282" {
        # lastRotated 2025-06-01 + 30 = 2025-07-01, ref 2026-04-09 => -282 days
        $script:allExpiredResult.Output | Should -Match '"Name":\s*"OLD_API_KEY"'
        $script:allExpiredResult.Output | Should -Match '"DaysUntilExpiry":\s*-282'
    }

    It "Detects expired secrets notification" {
        $script:allExpiredResult.Output | Should -Match "Expired secrets detected"
    }
}

Describe "Warning-Only Secrets with default warning window" {

    BeforeAll {
        $fixturePath = Join-Path $script:ProjectRoot "fixtures/warning-only-secrets.json"
        # lastRotated 2026-03-15 + 30 = 2026-04-14, ref 2026-04-09 => 5 days until expiry
        # With warningDays=7, 5 <= 7 => WARNING
        $script:warningResult = Invoke-ActWithFixture `
            -FixturePath $fixturePath `
            -TestLabel "warning-only-custom-window" `
            -WarningDays "7" `
            -OutputFormat "json" `
            -ReferenceDate "2026-04-09"
    }

    It "act exits with code 0" {
        $script:warningResult.ExitCode | Should -Be 0
    }

    It "Job succeeded" {
        $script:warningResult.Output | Should -Match "Job succeeded"
    }

    It "Shows 0 expired, 1 warning, 0 ok" {
        $script:warningResult.Output | Should -Match '"expired":\s*0'
        $script:warningResult.Output | Should -Match '"warning":\s*1'
        $script:warningResult.Output | Should -Match '"ok":\s*0'
    }

    It "EXPIRING_SOON_KEY has DaysUntilExpiry of 5" {
        $script:warningResult.Output | Should -Match '"Name":\s*"EXPIRING_SOON_KEY"'
        $script:warningResult.Output | Should -Match '"DaysUntilExpiry":\s*5'
    }

    It "EXPIRING_SOON_KEY status is WARNING" {
        $script:warningResult.Output | Should -Match '"Status":\s*"WARNING"'
    }

    It "All secrets within policy message shown (no expired)" {
        $script:warningResult.Output | Should -Match "All secrets are within rotation policy"
    }
}

Describe "Warning-Only Secret becomes OK with narrow window" {

    BeforeAll {
        $fixturePath = Join-Path $script:ProjectRoot "fixtures/warning-only-secrets.json"
        # Same fixture but warningDays=3 => 5 days until expiry > 3 => OK
        $script:narrowResult = Invoke-ActWithFixture `
            -FixturePath $fixturePath `
            -TestLabel "warning-becomes-ok-narrow-window" `
            -WarningDays "3" `
            -OutputFormat "json" `
            -ReferenceDate "2026-04-09"
    }

    It "act exits with code 0" {
        $script:narrowResult.ExitCode | Should -Be 0
    }

    It "Job succeeded" {
        $script:narrowResult.Output | Should -Match "Job succeeded"
    }

    It "Shows 0 expired, 0 warning, 1 ok when window is narrow" {
        $script:narrowResult.Output | Should -Match '"expired":\s*0'
        $script:narrowResult.Output | Should -Match '"warning":\s*0'
        $script:narrowResult.Output | Should -Match '"ok":\s*1'
    }

    It "EXPIRING_SOON_KEY status is OK with narrow window" {
        $script:narrowResult.Output | Should -Match '"Status":\s*"OK"'
    }
}

# ============================================================
# Verify act-result.txt artifact exists
# ============================================================
Describe "act-result.txt artifact" {

    It "act-result.txt exists" {
        $script:ActResultFile | Should -Exist
    }

    It "act-result.txt contains output from all test cases" {
        $content = Get-Content $script:ActResultFile -Raw
        $content | Should -Match "mixed-secrets-markdown"
        $content | Should -Match "mixed-secrets-json"
        $content | Should -Match "all-ok-secrets"
        $content | Should -Match "all-expired-secrets"
        $content | Should -Match "warning-only-custom-window"
        $content | Should -Match "warning-becomes-ok-narrow-window"
    }
}
