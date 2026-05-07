# Workflow-structure + act harness tests.
#
# Two layers:
#   1. Workflow Structure - parse the YAML and verify triggers, jobs, scripts,
#      and that referenced files actually exist on disk. Also runs actionlint.
#   2. Act Harness        - actually executes the workflow via `act push --rm`,
#      streams output to act-result.txt, and asserts on EXACT expected values
#      for every matrix fixture case.
#
# Both layers run through `Invoke-Pester`. The act-harness layer is tagged
# 'ActHarness' so the workflow itself can exclude it when it runs the test
# job inside the act container (where `act` is not installed and would
# recurse anyway).

BeforeDiscovery {
    $script:RepoRoot       = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:WorkflowPath   = Join-Path $script:RepoRoot '.github/workflows/semantic-version-bumper.yml'
    $script:ActResultPath  = Join-Path $script:RepoRoot 'act-result.txt'
}

BeforeAll {
    $script:RepoRoot      = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:WorkflowPath  = Join-Path $script:RepoRoot '.github/workflows/semantic-version-bumper.yml'
    $script:ActResultPath = Join-Path $script:RepoRoot 'act-result.txt'

    function Convert-YamlToHashtable {
        # Minimal indentation-based YAML parser sufficient for our workflow:
        # scalars, mappings, lists of mappings, and lists of scalars. We
        # avoid an external module to keep the test runner self-contained.
        param([string]$Yaml)

        $lines = ($Yaml -split "`r?`n") |
            Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() -ne '' }

        $root  = [ordered]@{}
        $stack = [System.Collections.Generic.List[object]]::new()
        $stack.Add(@{ Indent = -1; Container = $root; Key = $null }) | Out-Null

        foreach ($line in $lines) {
            $indent = ($line -match '^(\s*)') ? $Matches[1].Length : 0
            $body   = $line.Trim()

            # Pop the stack until we find a parent with smaller indent.
            while ($stack.Count -gt 1 -and $stack[$stack.Count - 1].Indent -ge $indent) {
                [void]$stack.RemoveAt($stack.Count - 1)
            }
            $top = $stack[$stack.Count - 1]
            $container = $top.Container

            if ($body.StartsWith('- ')) {
                $itemText = $body.Substring(2).Trim()
                # Ensure the parent is a list.
                if ($container -isnot [System.Collections.IList]) {
                    # Convert: parent.Key = []  -- replace the dictionary
                    # placeholder created when we saw 'key:'.
                    $parent = $stack[$stack.Count - 2].Container
                    $key    = $top.Key
                    $newList = [System.Collections.Generic.List[object]]::new()
                    $parent[$key] = $newList
                    $container = $newList
                    $top.Container = $newList
                }
                if ($itemText -match '^([^:]+):\s*(.*)$') {
                    $itemDict = [ordered]@{}
                    $k = $Matches[1].Trim()
                    $v = $Matches[2].Trim()
                    if ($v) { $itemDict[$k] = $v.Trim('"').Trim("'") }
                    $container.Add($itemDict) | Out-Null
                    $stack.Add(@{ Indent = $indent; Container = $itemDict; Key = $null }) | Out-Null
                } else {
                    $container.Add($itemText.Trim('"').Trim("'")) | Out-Null
                }
                continue
            }

            if ($body -match '^([^:]+):\s*(.*)$') {
                $k = $Matches[1].Trim()
                $v = $Matches[2].Trim()
                if (-not $v) {
                    # Container value coming on subsequent lines.
                    $child = [ordered]@{}
                    $container[$k] = $child
                    $stack.Add(@{ Indent = $indent; Container = $child; Key = $k }) | Out-Null
                } elseif ($v -eq '|' -or $v -eq '>') {
                    # Block scalar - we don't need its content for our checks;
                    # store an empty marker.
                    $container[$k] = ''
                } else {
                    $container[$k] = $v.Trim('"').Trim("'")
                }
            }
        }
        return $root
    }
}

Describe 'Workflow structure' {

    BeforeAll {
        $script:WorkflowText = Get-Content -LiteralPath $script:WorkflowPath -Raw
    }

    It 'workflow file exists' {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It 'has a name' {
        $script:WorkflowText | Should -Match '(?m)^name:\s*semantic-version-bumper'
    }

    It 'declares the expected triggers' {
        # `push`, `pull_request`, and `workflow_dispatch` should all be present.
        $script:WorkflowText | Should -Match '(?m)^\s*push:'
        $script:WorkflowText | Should -Match '(?m)^\s*pull_request:'
        $script:WorkflowText | Should -Match '(?m)^\s*workflow_dispatch:'
    }

    It 'declares a test job and a bump job' {
        $script:WorkflowText | Should -Match '(?m)^\s*test:'
        $script:WorkflowText | Should -Match '(?m)^\s*bump:'
    }

    It 'pins actions/checkout to v4' {
        $script:WorkflowText | Should -Match 'actions/checkout@v4'
    }

    It 'uses pwsh shell instead of bash for run steps' {
        # Per the benchmark instructions: shell: pwsh on every run: step.
        $script:WorkflowText | Should -Match 'shell:\s*pwsh'
        $script:WorkflowText | Should -Not -Match 'pwsh\s+-Command'
        $script:WorkflowText | Should -Not -Match 'pwsh\s+-File'
    }

    It 'references the bumper script that exists in the repo' {
        $script:WorkflowText | Should -Match 'Invoke-Bumper\.ps1'
        Test-Path (Join-Path $script:RepoRoot 'Invoke-Bumper.ps1') | Should -BeTrue
    }

    It 'references fixture files that exist in the repo' {
        foreach ($f in 'fixtures/commits-feat.txt','fixtures/commits-fix.txt','fixtures/commits-breaking.txt','fixtures/commits-none.txt') {
            (Test-Path (Join-Path $script:RepoRoot $f)) | Should -BeTrue -Because "the workflow references $f"
        }
    }

    It 'references the SemverBumper module that exists in the repo' {
        Test-Path (Join-Path $script:RepoRoot 'src/SemverBumper.psm1') | Should -BeTrue
    }

    It 'declares appropriate top-level permissions' {
        $script:WorkflowText | Should -Match '(?m)^permissions:'
        $script:WorkflowText | Should -Match 'contents:\s*read'
    }

    It 'bump job depends on test job (needs:)' {
        $script:WorkflowText | Should -Match '(?ms)bump:.*?needs:\s*test'
    }
}

Describe 'actionlint validation' -Tag 'ActHarness' {
    # Tagged ActHarness because actionlint is a host-only tool; inside the
    # act container we exclude this tag so the in-pipeline Pester run skips it.

    It 'workflow passes actionlint with exit code 0' {
        $output = & actionlint $script:WorkflowPath 2>&1
        $code   = $LASTEXITCODE
        if ($code -ne 0) { Write-Host ($output -join "`n") }
        $code | Should -Be 0
    }
}

Describe 'Act harness' -Tag 'ActHarness' {

    BeforeAll {
        # Sanity-check the host environment before we attempt anything heavy.
        $script:ActAvailable = $null -ne (Get-Command act -ErrorAction SilentlyContinue)

        # We run act exactly once - the workflow's matrix strategy fans out to
        # all four bump scenarios within that single invocation, so each
        # individual case still gets its own job and its own assertion.
        if ($script:ActAvailable) {
            Push-Location $script:RepoRoot
            try {
                # Truncate the result file so previous runs don't leak in.
                Set-Content -LiteralPath $script:ActResultPath -Value '' -NoNewline

                Add-Content -LiteralPath $script:ActResultPath `
                    -Value "===== act push --rm  ($([DateTimeOffset]::Now.ToString('o'))) =====`n"

                # Run act and tee output to act-result.txt. We capture exit code separately.
                $tmp = New-TemporaryFile
                & act push --rm *>&1 | Tee-Object -FilePath $tmp.FullName | Out-Null
                $script:ActExitCode = $LASTEXITCODE

                $script:ActOutput = Get-Content -LiteralPath $tmp.FullName -Raw
                Add-Content -LiteralPath $script:ActResultPath -Value $script:ActOutput
                Add-Content -LiteralPath $script:ActResultPath -Value "===== exit=$script:ActExitCode =====`n"
                Remove-Item $tmp.FullName -ErrorAction SilentlyContinue
            } finally {
                Pop-Location
            }
        }
    }

    It 'act is installed on the host' {
        $script:ActAvailable | Should -BeTrue
    }

    It 'act exited with code 0' {
        $script:ActExitCode | Should -Be 0
    }

    It 'every job reported "Job succeeded"' {
        # The number of jobs = test (1) + bump matrix (4) = 5.
        $matches = [regex]::Matches($script:ActOutput, 'Job succeeded')
        $matches.Count | Should -BeGreaterOrEqual 5
    }

    It 'no job reported "Job failed"' {
        $script:ActOutput | Should -Not -Match 'Job failed'
    }

    It 'unit-test job ran Pester and all tests passed inside act' {
        $script:ActOutput | Should -Match 'Tests Passed:'
        $script:ActOutput | Should -Not -Match 'Failed:\s*[1-9]'
    }

    Context 'matrix case assertions' {
        # Each matrix case produces a stable BUMP_RESULT line in the workflow.
        # We assert on the EXACT version each case should produce.
        $cases = @(
            @{ Case = 'feat';     ExpectedVersion = '1.2.0' }
            @{ Case = 'fix';      ExpectedVersion = '2.4.2' }
            @{ Case = 'breaking'; ExpectedVersion = '1.0.0' }
            @{ Case = 'none';     ExpectedVersion = '3.0.0' }
        )

        It 'case <Case> bumped to exactly <ExpectedVersion>' -ForEach $cases {
            $pattern = "BUMP_RESULT case=$Case version=$ExpectedVersion expected=$ExpectedVersion OK"
            $script:ActOutput | Should -Match ([regex]::Escape($pattern))
        }
    }

    It 'wrote act-result.txt at the repo root' {
        Test-Path $script:ActResultPath | Should -BeTrue
        (Get-Item $script:ActResultPath).Length | Should -BeGreaterThan 0
    }
}
