# WorkflowStructure.Tests.ps1
# Verifies the workflow YAML exists, has expected structure, references real files,
# and passes actionlint validation.

BeforeAll {
    $script:workflowPath = (Resolve-Path "$PSScriptRoot/../.github/workflows/secret-rotation-validator.yml").Path
    $script:projectRoot  = (Resolve-Path "$PSScriptRoot/..").Path
    $script:wf           = Get-Content $script:workflowPath -Raw
}

Describe "Workflow file" {
    It "exists at the expected path" {
        Test-Path $workflowPath | Should -BeTrue
    }

    It "contains push trigger" {
        $wf | Should -Match "push:"
    }

    It "contains schedule trigger" {
        $wf | Should -Match "schedule:"
    }

    It "contains workflow_dispatch trigger" {
        $wf | Should -Match "workflow_dispatch:"
    }

    It "uses actions/checkout@v4" {
        $wf | Should -Match "actions/checkout@v4"
    }

    It "uses shell: pwsh for run steps" {
        $wf | Should -Match "shell: pwsh"
    }

    It "references the main script" {
        $wf | Should -Match "Invoke-SecretRotationValidator\.ps1"
    }

    It "references the fixture file" {
        $wf | Should -Match "test-secrets\.json"
    }

    It "has at least one job" {
        $wf | Should -Match "jobs:"
    }

    It "emits ROTATION-STATUS lines" {
        $wf | Should -Match "ROTATION-STATUS"
    }
}

Describe "Referenced files exist" {
    It "main script exists" {
        Test-Path "$projectRoot/Invoke-SecretRotationValidator.ps1" | Should -BeTrue
    }

    It "functions library exists" {
        Test-Path "$projectRoot/SecretRotationFunctions.ps1" | Should -BeTrue
    }

    It "fixture file exists" {
        Test-Path "$projectRoot/fixtures/test-secrets.json" | Should -BeTrue
    }

    It "unit test file exists" {
        Test-Path "$projectRoot/tests/SecretRotationValidator.Tests.ps1" | Should -BeTrue
    }
}

Describe "Actionlint validation" {
    It "workflow passes actionlint with exit code 0" {
        $output = & actionlint $workflowPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}
