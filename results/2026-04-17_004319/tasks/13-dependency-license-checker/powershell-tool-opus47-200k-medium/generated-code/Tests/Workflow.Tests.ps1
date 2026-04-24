# Workflow-level tests.
#
# Structure tests inspect the YAML. Integration tests build a temp git repo
# with per-case fixtures and run `act push --rm`, appending output to
# act-result.txt (required artifact).

BeforeAll {
    $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:Workflow = Join-Path $script:Root '.github/workflows/dependency-license-checker.yml'
    $script:ActResult = Join-Path $script:Root 'act-result.txt'
    # Reset act-result.txt at test run start (once).
    if (-not $script:ActResultInit) {
        "=== act-result.txt (run started $(Get-Date -Format o)) ===" |
            Set-Content -Path $script:ActResult
        $script:ActResultInit = $true
    }
}

Describe 'Workflow structure' {
    BeforeAll {
        if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
            Install-Module powershell-yaml -Force -Scope CurrentUser -ErrorAction SilentlyContinue
        }
        Import-Module powershell-yaml -ErrorAction SilentlyContinue
        $script:Yaml = Get-Content $script:Workflow -Raw | ConvertFrom-Yaml
    }

    It 'defines push, pull_request, workflow_dispatch, and schedule triggers' {
        # YAML parsers convert "on" to boolean $true sometimes; check either key.
        $on = if ($script:Yaml.ContainsKey('on')) { $script:Yaml['on'] } else { $script:Yaml[$true] }
        $on.Keys | Should -Contain 'push'
        $on.Keys | Should -Contain 'pull_request'
        $on.Keys | Should -Contain 'workflow_dispatch'
        $on.Keys | Should -Contain 'schedule'
    }

    It 'has a test job and a check job that depends on test' {
        $script:Yaml.jobs.Keys | Should -Contain 'test'
        $script:Yaml.jobs.Keys | Should -Contain 'check'
        $script:Yaml.jobs.check.needs | Should -Be 'test'
    }

    It 'declares least-privilege permissions' {
        $script:Yaml.permissions.contents | Should -Be 'read'
    }

    It 'references script files that actually exist' {
        (Test-Path (Join-Path $script:Root 'Invoke-LicenseCheck.ps1')) | Should -BeTrue
        (Test-Path (Join-Path $script:Root 'LicenseChecker.psm1'))     | Should -BeTrue
        (Test-Path (Join-Path $script:Root 'Tests'))                    | Should -BeTrue
    }

    It 'passes actionlint' {
        $out = & actionlint $script:Workflow 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($out -join "`n")
    }
}

Describe 'Workflow integration via act' {
    BeforeAll {
        # Define the helper inside BeforeAll so Pester 5 makes it available at run time.
        function Invoke-ActCase {
            param(
                [string]$CaseName,
                [hashtable]$Vars,
                [string]$PackageJson,
                [string]$LicensesJson,
                [string]$MockJson
            )
            $work = Join-Path ([IO.Path]::GetTempPath()) ("act-case-" + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $work | Out-Null

            Copy-Item (Join-Path $script:Root 'Invoke-LicenseCheck.ps1') $work
            Copy-Item (Join-Path $script:Root 'LicenseChecker.psm1')     $work
            Copy-Item (Join-Path $script:Root '.actrc')                  $work
            Copy-Item (Join-Path $script:Root 'Tests') (Join-Path $work 'Tests') -Recurse
            New-Item -ItemType Directory -Path (Join-Path $work '.github/workflows') -Force | Out-Null
            Copy-Item $script:Workflow (Join-Path $work '.github/workflows/dependency-license-checker.yml')

            $fix = Join-Path $work 'fixtures'
            New-Item -ItemType Directory -Path $fix -Force | Out-Null
            Set-Content -Path (Join-Path $fix 'package.json')       -Value $PackageJson
            Set-Content -Path (Join-Path $fix 'licenses.json')      -Value $LicensesJson
            Set-Content -Path (Join-Path $fix 'mock-licenses.json') -Value $MockJson

            Push-Location $work
            try {
                git init -q
                git -c user.email=t@t -c user.name=t add -A 2>$null | Out-Null
                git -c user.email=t@t -c user.name=t commit -q -m init 2>$null | Out-Null

                $varArgs = @()
                foreach ($k in $Vars.Keys) { $varArgs += '--var'; $varArgs += "$k=$($Vars[$k])" }

                $output = & act push --rm @varArgs 2>&1 | Out-String
                $code = $LASTEXITCODE

                $delim = "`n`n===== CASE: $CaseName =====`n"
                Add-Content -Path $script:ActResult -Value ($delim + $output)

                return [pscustomobject]@{ ExitCode = $code; Output = $output }
            } finally {
                Pop-Location
                Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'Case 1: all deps approved -> OverallCompliant=True, check succeeds' {
        $pkg  = '{"dependencies":{"lodash":"^4.17.21","express":"~4.18.0"}}'
        $cfg  = '{"Allow":["MIT","Apache-2.0"],"Deny":["GPL-3.0"]}'
        $mock = '{"lodash":"MIT","express":"MIT"}'
        $r = Invoke-ActCase -CaseName 'all-approved' `
            -Vars @{ EXPECT_COMPLIANT = 'true' } `
            -PackageJson $pkg -LicensesJson $cfg -MockJson $mock

        $r.ExitCode         | Should -Be 0
        $r.Output           | Should -Match 'REPORT_APPROVED=2'
        $r.Output           | Should -Match 'REPORT_DENIED=0'
        $r.Output           | Should -Match 'REPORT_COMPLIANT=True'
        $r.Output           | Should -Match 'COMPLIANCE_CHECK_OK'
        ([regex]::Matches($r.Output, 'Job succeeded')).Count | Should -BeGreaterOrEqual 2
    }

    It 'Case 2: denied license present -> OverallCompliant=False, check succeeds when expectation matches' {
        $pkg  = '{"dependencies":{"lodash":"^4.17.21","badpkg":"1.0.0"}}'
        $cfg  = '{"Allow":["MIT"],"Deny":["GPL-3.0"]}'
        $mock = '{"lodash":"MIT","badpkg":"GPL-3.0"}'
        $r = Invoke-ActCase -CaseName 'denied-present' `
            -Vars @{ EXPECT_COMPLIANT = 'false' } `
            -PackageJson $pkg -LicensesJson $cfg -MockJson $mock

        $r.ExitCode | Should -Be 0
        $r.Output   | Should -Match 'REPORT_APPROVED=1'
        $r.Output   | Should -Match 'REPORT_DENIED=1'
        $r.Output   | Should -Match 'REPORT_COMPLIANT=False'
        $r.Output   | Should -Match 'COMPLIANCE_CHECK_OK'
        ([regex]::Matches($r.Output, 'Job succeeded')).Count | Should -BeGreaterOrEqual 2
    }

    It 'Case 3: unknown license -> counted as unknown, OverallCompliant=True' {
        $pkg  = '{"dependencies":{"mystery":"0.1.0"}}'
        $cfg  = '{"Allow":["MIT"],"Deny":["GPL-3.0"]}'
        $mock = '{"mystery":null}'
        $r = Invoke-ActCase -CaseName 'unknown-license' `
            -Vars @{ EXPECT_COMPLIANT = 'true' } `
            -PackageJson $pkg -LicensesJson $cfg -MockJson $mock

        $r.ExitCode | Should -Be 0
        $r.Output   | Should -Match 'REPORT_APPROVED=0'
        $r.Output   | Should -Match 'REPORT_DENIED=0'
        $r.Output   | Should -Match 'REPORT_UNKNOWN=1'
        $r.Output   | Should -Match 'REPORT_COMPLIANT=True'
        $r.Output   | Should -Match 'COMPLIANCE_CHECK_OK'
        ([regex]::Matches($r.Output, 'Job succeeded')).Count | Should -BeGreaterOrEqual 2
    }
}
