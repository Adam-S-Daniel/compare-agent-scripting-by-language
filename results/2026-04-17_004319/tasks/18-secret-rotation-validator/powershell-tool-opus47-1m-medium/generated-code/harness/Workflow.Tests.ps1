# Integration tests for the GitHub Actions workflow.
# Every test case sets up a disposable git repo with a chosen fixture, runs
# `act push --rm`, captures stdout+stderr, appends to act-result.txt, and
# asserts on exact expected values.

BeforeAll {
    $script:Root       = Split-Path -Parent $PSScriptRoot
    $script:Workflow   = Join-Path $script:Root '.github/workflows/secret-rotation-validator.yml'
    $script:ResultFile = Join-Path $script:Root 'act-result.txt'
    if (Test-Path $script:ResultFile) { Remove-Item -LiteralPath $script:ResultFile -Force }

    function New-ActWorkspace {
        param([string]$FixtureJson, [string]$ReferenceDate, [int]$WarningDays, [string]$Format)

        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("srv-act-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp | Out-Null
        Copy-Item -Recurse (Join-Path $script:Root '.github')    (Join-Path $tmp '.github')
        Copy-Item -Recurse (Join-Path $script:Root 'tests')       (Join-Path $tmp 'tests')
        Copy-Item -Recurse (Join-Path $script:Root 'fixtures')    (Join-Path $tmp 'fixtures')
        Copy-Item          (Join-Path $script:Root 'SecretRotationValidator.ps1') $tmp
        Copy-Item          (Join-Path $script:Root 'Invoke-Validator.ps1')         $tmp
        if (Test-Path (Join-Path $script:Root '.actrc')) {
            Copy-Item (Join-Path $script:Root '.actrc') $tmp
        }

        # Write the test case fixture to its own path so the built-in
        # fixtures/sample.json (consumed by the unit tests) stays untouched.
        Set-Content -LiteralPath (Join-Path $tmp 'fixtures/case.json') -Value $FixtureJson -Encoding utf8

        # Patch workflow env defaults so the push event uses test case values.
        $wfPath = Join-Path $tmp '.github/workflows/secret-rotation-validator.yml'
        $wf = Get-Content -LiteralPath $wfPath -Raw
        $wf = $wf -replace "CONFIG_PATH: fixtures/sample\.json", "CONFIG_PATH: fixtures/case.json"
        $wf = $wf -replace "WARNING_DAYS: \$\{\{ github.event.inputs.warning_days \|\| '14' \}\}",   "WARNING_DAYS: '$WarningDays'"
        $wf = $wf -replace "REFERENCE_DATE: \$\{\{ github.event.inputs.reference_date \|\| '2026-04-17' \}\}", "REFERENCE_DATE: '$ReferenceDate'"
        $wf = $wf -replace "REPORT_FORMAT: \$\{\{ github.event.inputs.format \|\| 'markdown' \}\}", "REPORT_FORMAT: '$Format'"
        Set-Content -LiteralPath $wfPath -Value $wf -Encoding utf8

        Push-Location $tmp
        try {
            git init -q
            git -c user.email=t@t -c user.name=t add -A | Out-Null
            git -c user.email=t@t -c user.name=t commit -qm init | Out-Null
        } finally {
            Pop-Location
        }
        return $tmp
    }

    function Invoke-Act {
        param([string]$Workspace, [string]$CaseName)
        $stdout = Join-Path ([System.IO.Path]::GetTempPath()) "act-$([guid]::NewGuid().ToString('N')).log"
        Push-Location $Workspace
        try {
            # Merge stderr into stdout.
            & act push --rm *> $stdout
            $code = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        $output = Get-Content -LiteralPath $stdout -Raw
        $delim  = "`n===== CASE: $CaseName (exit=$code) =====`n"
        Add-Content -LiteralPath $script:ResultFile -Value ($delim + $output)
        Remove-Item -LiteralPath $stdout -ErrorAction SilentlyContinue
        return [pscustomobject]@{ ExitCode = $code; Output = $output }
    }
}

Describe 'Workflow structure' {
    It 'workflow file exists' {
        Test-Path $script:Workflow | Should -BeTrue
    }

    It 'passes actionlint' {
        & actionlint $script:Workflow | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It 'references scripts that exist in the repo' {
        $wf = Get-Content -LiteralPath $script:Workflow -Raw
        $wf | Should -Match 'Invoke-Validator\.ps1'
        Test-Path (Join-Path $script:Root 'Invoke-Validator.ps1')         | Should -BeTrue
        Test-Path (Join-Path $script:Root 'SecretRotationValidator.ps1')  | Should -BeTrue
        Test-Path (Join-Path $script:Root 'fixtures/sample.json')         | Should -BeTrue
    }

    It 'declares required triggers and jobs' {
        $wf = Get-Content -LiteralPath $script:Workflow -Raw
        $wf | Should -Match '(?m)^on:'
        $wf | Should -Match 'push:'
        $wf | Should -Match 'pull_request:'
        $wf | Should -Match 'workflow_dispatch:'
        $wf | Should -Match 'schedule:'
        $wf | Should -Match '(?m)^\s+test:'
        $wf | Should -Match '(?m)^\s+report:'
        $wf | Should -Match 'needs:\s*test'
        $wf | Should -Match 'permissions:'
        $wf | Should -Match 'actions/checkout@v4'
        $wf | Should -Match 'shell:\s*pwsh'
    }
}

Describe 'Workflow execution via act' -Tag 'act' {
    It 'Case 1: sample fixture - markdown output shows expired=1, warning=1, ok=1' {
        $fixture = Get-Content -LiteralPath (Join-Path $script:Root 'fixtures/sample.json') -Raw
        $ws = New-ActWorkspace -FixtureJson $fixture -ReferenceDate '2026-04-17' -WarningDays 14 -Format 'markdown'
        try {
            $r = Invoke-Act -Workspace $ws -CaseName 'sample-markdown'
            $r.ExitCode | Should -Be 0
            ($r.Output | Select-String -Pattern 'Job succeeded' -AllMatches).Matches.Count | Should -BeGreaterOrEqual 2
            $r.Output | Should -Match 'Tests Passed: 17'
            $r.Output | Should -Match 'expired=1, warning=1, ok=1'
            $r.Output | Should -Match '\| db-password \|'
            $r.Output | Should -Match '\| stripe-api-key \|'
            $r.Output | Should -Match '\| github-token \|'
            $r.Output | Should -Match '## EXPIRED \(1\)'
            $r.Output | Should -Match '## WARNING \(1\)'
            $r.Output | Should -Match '## OK \(1\)'
        } finally {
            Remove-Item -Recurse -Force -LiteralPath $ws -ErrorAction SilentlyContinue
        }
    }

    It 'Case 2: all-expired fixture - JSON output reports summary 2/0/0 and ordering' {
        $fixture = @'
{
  "secrets": [
    { "name": "aws-root-key",  "lastRotated": "2025-01-01", "rotationDays": 60, "requiredBy": ["infra"] },
    { "name": "legacy-cookie", "lastRotated": "2024-12-01", "rotationDays": 30, "requiredBy": ["web"] }
  ]
}
'@
        $ws = New-ActWorkspace -FixtureJson $fixture -ReferenceDate '2026-04-17' -WarningDays 14 -Format 'json'
        try {
            $r = Invoke-Act -Workspace $ws -CaseName 'all-expired-json'
            $r.ExitCode | Should -Be 0
            ($r.Output | Select-String -Pattern 'Job succeeded' -AllMatches).Matches.Count | Should -BeGreaterOrEqual 2
            $r.Output | Should -Match '"expired":\s*2'
            $r.Output | Should -Match '"warning":\s*0'
            $r.Output | Should -Match '"ok":\s*0'
            $r.Output | Should -Match '"referenceDate":\s*"2026-04-17"'
            $r.Output | Should -Match '"name":\s*"aws-root-key"'
            $r.Output | Should -Match '"name":\s*"legacy-cookie"'
        } finally {
            Remove-Item -Recurse -Force -LiteralPath $ws -ErrorAction SilentlyContinue
        }
    }

    It 'Case 3: widened warning window reclassifies ok secret as warning' {
        $fixture = @'
{
  "secrets": [
    { "name": "slack-webhook", "lastRotated": "2026-04-01", "rotationDays": 90, "requiredBy": ["alerts"] }
  ]
}
'@
        # slack-webhook expires 2026-06-30; daysLeft = 74. With WarningDays=120 it is warning.
        $ws = New-ActWorkspace -FixtureJson $fixture -ReferenceDate '2026-04-17' -WarningDays 120 -Format 'markdown'
        try {
            $r = Invoke-Act -Workspace $ws -CaseName 'wide-window-markdown'
            $r.ExitCode | Should -Be 0
            ($r.Output | Select-String -Pattern 'Job succeeded' -AllMatches).Matches.Count | Should -BeGreaterOrEqual 2
            $r.Output | Should -Match 'expired=0, warning=1, ok=0'
            $r.Output | Should -Match '\| slack-webhook \|.*\| 2026-06-30 \|\s*74\s*\|'
            $r.Output | Should -Match 'Warning window: 120 days'
        } finally {
            Remove-Item -Recurse -Force -LiteralPath $ws -ErrorAction SilentlyContinue
        }
    }
}
