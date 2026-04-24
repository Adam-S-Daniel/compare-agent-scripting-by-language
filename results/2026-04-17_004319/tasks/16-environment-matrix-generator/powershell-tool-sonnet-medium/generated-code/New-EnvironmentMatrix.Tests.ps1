# New-EnvironmentMatrix.Tests.ps1
# Pester 5 tests for the environment matrix generator.
# TDD: these tests were written before the implementation.

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "New-EnvironmentMatrix.ps1"
    $script:FixturesPath = Join-Path $PSScriptRoot "fixtures"
    $script:WorkflowPath = Join-Path $PSScriptRoot ".github/workflows/environment-matrix-generator.yml"
}

Describe "New-EnvironmentMatrix - Basic matrix generation" {
    It "generates cartesian product of OS and language versions" {
        $result = & $script:ScriptPath -ConfigFile "$($script:FixturesPath)/basic.json" | ConvertFrom-Json
        $result.strategy.matrix.os.Count | Should -Be 2
        $result.strategy.matrix.node.Count | Should -Be 2
        $result.computed_count | Should -Be 4
    }

    It "includes ubuntu-latest and windows-latest in OS list" {
        $result = & $script:ScriptPath -ConfigFile "$($script:FixturesPath)/basic.json" | ConvertFrom-Json
        $result.strategy.matrix.os | Should -Contain "ubuntu-latest"
        $result.strategy.matrix.os | Should -Contain "windows-latest"
    }

    It "includes node versions 18 and 20" {
        $result = & $script:ScriptPath -ConfigFile "$($script:FixturesPath)/basic.json" | ConvertFrom-Json
        $result.strategy.matrix.node | Should -Contain "18"
        $result.strategy.matrix.node | Should -Contain "20"
    }

    It "sets max-parallel from config" {
        $result = & $script:ScriptPath -ConfigFile "$($script:FixturesPath)/basic.json" | ConvertFrom-Json
        $result.strategy.'max-parallel' | Should -Be 4
    }

    It "sets fail-fast from config" {
        $result = & $script:ScriptPath -ConfigFile "$($script:FixturesPath)/basic.json" | ConvertFrom-Json
        $result.strategy.'fail-fast' | Should -Be $false
    }

    It "outputs valid JSON" {
        $json = & $script:ScriptPath -ConfigFile "$($script:FixturesPath)/basic.json"
        { $json | ConvertFrom-Json } | Should -Not -Throw
    }
}

Describe "New-EnvironmentMatrix - Include and exclude rules" {
    It "passes include entries through to the matrix" {
        $result = & $script:ScriptPath -ConfigFile "$($script:FixturesPath)/with-rules.json" | ConvertFrom-Json
        $result.strategy.matrix.include | Should -Not -BeNullOrEmpty
        $result.strategy.matrix.include.Count | Should -Be 1
    }

    It "passes exclude entries through to the matrix" {
        $result = & $script:ScriptPath -ConfigFile "$($script:FixturesPath)/with-rules.json" | ConvertFrom-Json
        $result.strategy.matrix.exclude | Should -Not -BeNullOrEmpty
        $result.strategy.matrix.exclude.Count | Should -Be 1
    }

    It "computes base cartesian product count (before include/exclude)" {
        # 3 OS x 2 python = 6 base combinations
        $result = & $script:ScriptPath -ConfigFile "$($script:FixturesPath)/with-rules.json" | ConvertFrom-Json
        $result.computed_count | Should -Be 6
    }

    It "respects fail-fast true from config" {
        $result = & $script:ScriptPath -ConfigFile "$($script:FixturesPath)/with-rules.json" | ConvertFrom-Json
        $result.strategy.'fail-fast' | Should -Be $true
    }

    It "respects max-parallel 2 from config" {
        $result = & $script:ScriptPath -ConfigFile "$($script:FixturesPath)/with-rules.json" | ConvertFrom-Json
        $result.strategy.'max-parallel' | Should -Be 2
    }
}

Describe "New-EnvironmentMatrix - Size validation" {
    It "throws when base matrix exceeds max_size" {
        # too-large.json: 2 OS x 4 node x 2 flags = 16, max_size = 5
        { & $script:ScriptPath -ConfigFile "$($script:FixturesPath)/too-large.json" } | Should -Throw
    }

    It "error message mentions the sizes" {
        try {
            & $script:ScriptPath -ConfigFile "$($script:FixturesPath)/too-large.json"
        } catch {
            $_.Exception.Message | Should -Match "exceed"
        }
    }
}

Describe "New-EnvironmentMatrix - Error handling" {
    It "throws for a missing config file" {
        { & $script:ScriptPath -ConfigFile "does-not-exist.json" } | Should -Throw
    }

    It "throws when os field is missing from config" {
        $tmpConfig = Join-Path $TestDrive "no-os.json"
        '{"language_versions":{"node":["18"]},"max_parallel":2,"fail_fast":false,"max_size":256}' | Set-Content $tmpConfig
        { & $script:ScriptPath -ConfigFile $tmpConfig } | Should -Throw
    }
}

Describe "Workflow Structure" {
    It "workflow file exists" {
        $script:WorkflowPath | Should -Exist
    }

    It "workflow has push trigger" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "push"
    }

    It "workflow has pull_request trigger" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "pull_request"
    }

    It "workflow has workflow_dispatch trigger" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "workflow_dispatch"
    }

    It "workflow uses shell: pwsh" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "shell: pwsh"
    }

    It "workflow references New-EnvironmentMatrix.ps1" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "New-EnvironmentMatrix.ps1"
    }

    It "script file referenced in workflow exists" {
        Join-Path $PSScriptRoot "New-EnvironmentMatrix.ps1" | Should -Exist
    }

    It "fixture files referenced in workflow exist" {
        Join-Path $PSScriptRoot "fixtures/basic.json" | Should -Exist
        Join-Path $PSScriptRoot "fixtures/with-rules.json" | Should -Exist
    }

    It "passes actionlint" {
        $al = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $al) {
            Set-ItResult -Skipped -Because "actionlint not available in this environment"
            return
        }
        $output = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}
