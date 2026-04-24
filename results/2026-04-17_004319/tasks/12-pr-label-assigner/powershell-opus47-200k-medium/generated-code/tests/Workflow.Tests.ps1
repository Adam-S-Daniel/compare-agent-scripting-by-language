# Tests that drive the workflow end-to-end via `act` and assert on exact output.
# Every assertion runs through the GitHub Actions pipeline (per benchmark spec).

BeforeDiscovery {
    # Must be set at discovery time so -ForEach can expand into test cases.
    $casesForDiscovery = @(
        @{ Name = 'case-docs';    File = 'fixtures/case-docs.json';    Expected = @('documentation') }
        @{ Name = 'case-mixed';   File = 'fixtures/case-mixed.json';   Expected = @('api','backend','documentation','frontend','tests') }
        @{ Name = 'case-nomatch'; File = 'fixtures/case-nomatch.json'; Expected = @() }
    )
}

BeforeAll {
    $script:RepoRoot  = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:Workflow  = Join-Path $script:RepoRoot '.github' 'workflows' 'pr-label-assigner.yml'
    $script:ActResult = Join-Path $script:RepoRoot 'act-result.txt'
    # Re-declare cases in the run phase — BeforeDiscovery-scoped values don't
    # carry over into BeforeAll in Pester 5.
    $script:Cases = @(
        @{ Name = 'case-docs';    File = 'fixtures/case-docs.json';    Expected = @('documentation') }
        @{ Name = 'case-mixed';   File = 'fixtures/case-mixed.json';   Expected = @('api','backend','documentation','frontend','tests') }
        @{ Name = 'case-nomatch'; File = 'fixtures/case-nomatch.json'; Expected = @() }
    )
}

Describe 'Workflow YAML structure' {
    BeforeAll {
        # Pester 5 ships with powershell-yaml? Not guaranteed; parse as text.
        $script:WorkflowText = Get-Content -Raw -LiteralPath $script:Workflow
    }

    It 'exists at the expected path' {
        Test-Path $script:Workflow | Should -BeTrue
    }

    It 'declares the expected triggers' {
        $script:WorkflowText | Should -Match '(?m)^on:'
        $script:WorkflowText | Should -Match 'push:'
        $script:WorkflowText | Should -Match 'pull_request:'
        $script:WorkflowText | Should -Match 'workflow_dispatch:'
    }

    It 'declares both expected jobs' {
        $script:WorkflowText | Should -Match 'unit-tests:'
        $script:WorkflowText | Should -Match 'assign-labels:'
    }

    It 'references the real script and module paths' {
        Test-Path (Join-Path $script:RepoRoot 'scripts' 'Invoke-LabelAssigner.ps1') | Should -BeTrue
        Test-Path (Join-Path $script:RepoRoot 'src' 'LabelAssigner.psm1') | Should -BeTrue
        Test-Path (Join-Path $script:RepoRoot 'tests' 'LabelAssigner.Tests.ps1') | Should -BeTrue
        $script:WorkflowText | Should -Match 'scripts/Invoke-LabelAssigner.ps1'
        $script:WorkflowText | Should -Match 'tests/LabelAssigner.Tests.ps1'
    }

    It 'passes actionlint' {
        Push-Location $script:RepoRoot
        try {
            & actionlint .github/workflows/pr-label-assigner.yml
            $LASTEXITCODE | Should -Be 0
        } finally { Pop-Location }
    }
}

Describe 'End-to-end via act' {
    BeforeAll {
        if (Test-Path $script:ActResult) { Remove-Item -Force $script:ActResult }

        $runCase = {
            param($Case)
            $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("labelact-" + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $tmp | Out-Null
            try {
                # Copy project files (not .git / not accumulated artifact) into the temp repo.
                # .actrc must travel with the repo so act picks up the local image pin,
                # so we iterate with -Force to include dotfiles.
                Get-ChildItem -LiteralPath $script:RepoRoot -Force |
                    Where-Object { $_.Name -notin @('.git','act-result.txt') } |
                    ForEach-Object {
                        Copy-Item -LiteralPath $_.FullName -Destination $tmp -Recurse -Force
                    }

                Push-Location $tmp
                try {
                    git init -q 2>&1 | Out-Null
                    git -c user.email=t@t -c user.name=t add -A 2>&1 | Out-Null
                    git -c user.email=t@t -c user.name=t commit -q -m "fixture" 2>&1 | Out-Null

                    # --pull=false: the act-ubuntu-pwsh:latest image is built locally;
                    # without this act force-pulls and fails against Docker Hub.
                    $actArgs = @(
                        'push','--rm','--pull=false',
                        '--env', "CASE_FILE=$($Case.File)"
                    )
                    $output = & act @actArgs 2>&1 | Out-String
                    $exit = $LASTEXITCODE

                    Add-Content -LiteralPath $script:ActResult -Value "===CASE:$($Case.Name)==="
                    Add-Content -LiteralPath $script:ActResult -Value "EXITCODE=$exit"
                    Add-Content -LiteralPath $script:ActResult -Value $output
                    Add-Content -LiteralPath $script:ActResult -Value "===END:$($Case.Name)==="

                    return [pscustomobject]@{ Exit = $exit; Output = $output }
                } finally { Pop-Location }
            } finally {
                Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
            }
        }

        # Execute each case. Only 3 cases total -> at most 3 act push runs.
        $script:Results = @{}
        foreach ($c in $script:Cases) {
            $script:Results[$c.Name] = & $runCase $c
        }
    }

    It 'produced act-result.txt' {
        Test-Path $script:ActResult | Should -BeTrue
    }

    It '<Name>: act exited with code 0' -ForEach $casesForDiscovery {
        $script:Results[$Name].Exit | Should -Be 0
    }

    It '<Name>: every job reports success' -ForEach $casesForDiscovery {
        $out = $script:Results[$Name].Output
        # Assert both jobs show "Job succeeded" somewhere in the act output.
        ([regex]::Matches($out, 'Job succeeded')).Count | Should -BeGreaterOrEqual 2
    }

    It '<Name>: emits exactly the expected labels' -ForEach $casesForDiscovery {
        $out = $script:Results[$Name].Output
        # Extract the delimited labels block printed by the workflow.
        $m = [regex]::Match($out, '(?s)===LABELS-BEGIN===\s*(.*?)\s*===LABELS-END===')
        $m.Success | Should -BeTrue -Because 'the workflow must print the label block'

        # act prefixes every workflow log line with "| " inside a box; strip that.
        $body = $m.Groups[1].Value
        $labels = @($body -split "`n" |
            ForEach-Object { ($_ -replace '^[^|]*\|\s?','').Trim() } |
            Where-Object { $_ -and $_ -notmatch '^===' })

        # Compare sorted to be independent of emission order.
        (@($labels) | Sort-Object) | Should -Be (@($Expected) | Sort-Object)
    }
}
