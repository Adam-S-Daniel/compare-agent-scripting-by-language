# WorkflowStructure.Tests.ps1
# Tests that verify the GitHub Actions workflow file structure,
# file references, and actionlint compliance.

BeforeAll {
    $script:repoRoot    = Join-Path $PSScriptRoot ".."
    $script:workflowFile = Join-Path $script:repoRoot ".github" "workflows" "dependency-license-checker.yml"
    $script:workflowContent = Get-Content $script:workflowFile -Raw
    # Parse YAML as text (simple key extraction — no external YAML module needed)
}

Describe "Workflow file existence" {
    It "workflow file exists at expected path" {
        Test-Path $script:workflowFile | Should -Be $true
    }
}

Describe "Workflow trigger events" {
    It "has push trigger" {
        $script:workflowContent | Should -Match "push:"
    }

    It "has pull_request trigger" {
        $script:workflowContent | Should -Match "pull_request:"
    }

    It "has workflow_dispatch trigger" {
        $script:workflowContent | Should -Match "workflow_dispatch:"
    }

    It "has schedule trigger" {
        $script:workflowContent | Should -Match "schedule:"
    }
}

Describe "Workflow jobs" {
    It "defines a license-check job" {
        $script:workflowContent | Should -Match "license-check:"
    }

    It "uses ubuntu-latest runner" {
        $script:workflowContent | Should -Match "ubuntu-latest"
    }
}

Describe "Workflow steps" {
    It "uses actions/checkout@v4" {
        $script:workflowContent | Should -Match "actions/checkout@v4"
    }

    It "installs PowerShell" {
        $script:workflowContent | Should -Match "powershell"
    }

    It "runs Pester tests" {
        $script:workflowContent | Should -Match "Invoke-Pester"
    }

    It "runs the license checker on package.json" {
        $script:workflowContent | Should -Match "package\.json"
    }

    It "runs the license checker on requirements.txt" {
        $script:workflowContent | Should -Match "requirements\.txt"
    }
}

Describe "Referenced files exist" {
    It "LicenseChecker.ps1 exists" {
        Test-Path (Join-Path $script:repoRoot "LicenseChecker.ps1") | Should -Be $true
    }

    It "run.ps1 exists" {
        Test-Path (Join-Path $script:repoRoot "run.ps1") | Should -Be $true
    }

    It "tests/LicenseChecker.Tests.ps1 exists" {
        Test-Path (Join-Path $script:repoRoot "tests" "LicenseChecker.Tests.ps1") | Should -Be $true
    }

    It "tests/fixtures/package.json exists" {
        Test-Path (Join-Path $script:repoRoot "tests" "fixtures" "package.json") | Should -Be $true
    }

    It "tests/fixtures/requirements.txt exists" {
        Test-Path (Join-Path $script:repoRoot "tests" "fixtures" "requirements.txt") | Should -Be $true
    }

    It "tests/fixtures/license-config.json exists" {
        Test-Path (Join-Path $script:repoRoot "tests" "fixtures" "license-config.json") | Should -Be $true
    }
}

Describe "actionlint validation" {
    It "actionlint passes with exit code 0" {
        $output = & actionlint $script:workflowFile 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}
