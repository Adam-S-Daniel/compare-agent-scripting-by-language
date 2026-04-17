# Workflow structure tests. These validate the GitHub Actions YAML
# file itself: that it parses, uses the expected triggers/jobs/steps,
# and references script paths that actually exist in the repo.
#
# We intentionally don't shell out to actionlint from here because
# actionlint isn't guaranteed to be present inside the act container.
# The outer harness (run-act-tests.ps1) runs actionlint before act.

BeforeAll {
    $script:Root = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:WorkflowPath = Join-Path $script:Root '.github/workflows/test-results-aggregator.yml'
    $script:WorkflowText = Get-Content -LiteralPath $script:WorkflowPath -Raw
}

Describe 'Workflow file' {
    It 'exists at the expected path' {
        Test-Path -LiteralPath $script:WorkflowPath | Should -BeTrue
    }

    It 'is not empty' {
        $script:WorkflowText.Length | Should -BeGreaterThan 0
    }

    It 'is valid YAML (basic structural sniff test)' {
        # We don't require the powershell-yaml module in the act image, so
        # we validate structurally with regex. A real YAML parser would be
        # nicer but these smoke checks catch indentation/key errors quickly.
        $script:WorkflowText | Should -Match '(?m)^name:\s*Test Results Aggregator'
        $script:WorkflowText | Should -Match '(?m)^on:'
        $script:WorkflowText | Should -Match '(?m)^jobs:'
    }
}

Describe 'Workflow triggers' {
    It 'triggers on push' {
        $script:WorkflowText | Should -Match '(?m)^\s*push:'
    }
    It 'triggers on pull_request' {
        $script:WorkflowText | Should -Match '(?m)^\s*pull_request:'
    }
    It 'triggers on workflow_dispatch' {
        $script:WorkflowText | Should -Match '(?m)^\s*workflow_dispatch:'
    }
    It 'triggers on schedule' {
        $script:WorkflowText | Should -Match '(?m)^\s*schedule:'
    }
}

Describe 'Workflow jobs' {
    It 'declares a pester job' {
        $script:WorkflowText | Should -Match '(?m)^\s*pester:'
    }
    It 'declares an aggregate job' {
        $script:WorkflowText | Should -Match '(?m)^\s*aggregate:'
    }
    It 'aggregate depends on pester via needs' {
        $script:WorkflowText | Should -Match 'needs:\s*pester'
    }
    It 'both jobs run on ubuntu-latest' {
        $matches = [regex]::Matches($script:WorkflowText, 'runs-on:\s*ubuntu-latest')
        $matches.Count | Should -BeGreaterOrEqual 2
    }
}

Describe 'Workflow references' {
    It 'checks out the repo with actions/checkout@v4' {
        $script:WorkflowText | Should -Match 'uses:\s*actions/checkout@v4'
    }

    It 'uses shell: pwsh for PowerShell run steps' {
        $script:WorkflowText | Should -Match 'shell:\s*pwsh'
    }

    It 'sets least-privilege contents:read permission' {
        $script:WorkflowText | Should -Match 'permissions:'
        $script:WorkflowText | Should -Match 'contents:\s*read'
    }

    It 'references the TestResultsAggregator module by a real path' {
        $modulePath = Join-Path $script:Root 'src/TestResultsAggregator.psm1'
        Test-Path -LiteralPath $modulePath | Should -BeTrue
        $script:WorkflowText | Should -Match 'src/TestResultsAggregator\.psm1'
    }

    It 'references the Invoke-Aggregator entrypoint by a real path' {
        $entry = Join-Path $script:Root 'src/Invoke-Aggregator.ps1'
        Test-Path -LiteralPath $entry | Should -BeTrue
        $script:WorkflowText | Should -Match 'src/Invoke-Aggregator\.ps1'
    }

    It 'points at the fixtures directory that exists' {
        $fixtures = Join-Path $script:Root 'fixtures'
        Test-Path -LiteralPath $fixtures | Should -BeTrue
        $script:WorkflowText | Should -Match 'FIXTURES_DIR'
    }

    It 'runs Invoke-Pester inside the pester job' {
        $script:WorkflowText | Should -Match 'Invoke-Pester'
    }
}
