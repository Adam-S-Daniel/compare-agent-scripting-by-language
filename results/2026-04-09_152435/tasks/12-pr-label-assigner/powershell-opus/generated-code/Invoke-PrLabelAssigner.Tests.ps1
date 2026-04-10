# Invoke-PrLabelAssigner.Tests.ps1
# Pester tests for PR Label Assigner
# Tests cover: glob-to-regex conversion, label assignment logic, priority/exclusive handling,
# error handling, and workflow structure validation.

BeforeAll {
    . $PSScriptRoot/PrLabelAssigner.ps1
}

Describe 'ConvertTo-GlobRegex' {
    It 'converts docs/** to match files under docs/' {
        $regex = ConvertTo-GlobRegex -Pattern 'docs/**'
        'docs/readme.md' | Should -Match $regex
        'docs/api/v2/spec.md' | Should -Match $regex
        'src/docs/readme.md' | Should -Not -Match $regex
    }

    It 'converts src/api/** to match files under src/api/' {
        $regex = ConvertTo-GlobRegex -Pattern 'src/api/**'
        'src/api/handler.ps1' | Should -Match $regex
        'src/api/v2/routes.js' | Should -Match $regex
        'src/utils.ps1' | Should -Not -Match $regex
    }

    It 'converts **/*.test.* to match test files at any depth' {
        $regex = ConvertTo-GlobRegex -Pattern '**/*.test.*'
        'foo.test.js' | Should -Match $regex
        'src/foo.test.ts' | Should -Match $regex
        'a/b/c/bar.test.py' | Should -Match $regex
        'src/main.ps1' | Should -Not -Match $regex
    }

    It 'converts *.js to match JS files at root only' {
        $regex = ConvertTo-GlobRegex -Pattern '*.js'
        'app.js' | Should -Match $regex
        'src/app.js' | Should -Not -Match $regex
    }

    It 'converts **/*.spec.* to match spec files at any depth' {
        $regex = ConvertTo-GlobRegex -Pattern '**/*.spec.*'
        'lib/utils.spec.ts' | Should -Match $regex
        'foo.spec.js' | Should -Match $regex
        'a/b/widget.spec.jsx' | Should -Match $regex
    }

    It 'handles ? wildcard for single character' {
        $regex = ConvertTo-GlobRegex -Pattern 'src/?.js'
        'src/a.js' | Should -Match $regex
        'src/ab.js' | Should -Not -Match $regex
    }

    It 'handles pattern with dots correctly' {
        $regex = ConvertTo-GlobRegex -Pattern '*.config.json'
        'app.config.json' | Should -Match $regex
        'appconfigjson' | Should -Not -Match $regex
    }
}

Describe 'Get-PrLabels' {
    Context 'Basic matching' {
        It 'returns labels for files matching a single rule' {
            $config = @{
                rules = @(
                    @{ pattern = 'docs/**'; label = 'documentation'; priority = 1 }
                )
            }
            $result = Get-PrLabels -Config $config -FilePaths @('docs/readme.md', 'src/main.ps1')
            $result | Should -Be @('documentation')
        }

        It 'returns empty array when no files match any rule' {
            $config = @{
                rules = @(
                    @{ pattern = 'docs/**'; label = 'documentation'; priority = 1 }
                )
            }
            $result = Get-PrLabels -Config $config -FilePaths @('src/main.ps1')
            $result.Count | Should -Be 0
        }
    }

    Context 'Multiple labels' {
        It 'returns multiple labels when files match different rules' {
            $config = @{
                rules = @(
                    @{ pattern = 'docs/**'; label = 'documentation'; priority = 1 },
                    @{ pattern = 'src/**'; label = 'core'; priority = 2 },
                    @{ pattern = '**/*.test.*'; label = 'tests'; priority = 3 }
                )
            }
            $result = Get-PrLabels -Config $config -FilePaths @(
                'docs/readme.md',
                'src/main.ps1',
                'src/app.test.js'
            )
            $result | Should -Be @('core', 'documentation', 'tests')
        }

        It 'deduplicates labels when multiple files match the same rule' {
            $config = @{
                rules = @(
                    @{ pattern = 'docs/**'; label = 'documentation'; priority = 1 }
                )
            }
            $result = Get-PrLabels -Config $config -FilePaths @('docs/a.md', 'docs/b.md')
            $result | Should -Be @('documentation')
        }
    }

    Context 'Priority and exclusive rules' {
        It 'applies exclusive flag to stop further rule evaluation for a file' {
            $config = @{
                rules = @(
                    @{ pattern = 'src/api/**'; label = 'api'; priority = 1; exclusive = $true },
                    @{ pattern = 'src/**'; label = 'core'; priority = 2 }
                )
            }
            # src/api/handler.ps1 matches api (exclusive) -> only gets 'api', not 'core'
            # src/utils.ps1 matches core -> gets 'core'
            $result = Get-PrLabels -Config $config -FilePaths @('src/api/handler.ps1', 'src/utils.ps1')
            $result | Should -Be @('api', 'core')
        }

        It 'without exclusive flag, file gets multiple labels' {
            $config = @{
                rules = @(
                    @{ pattern = 'src/api/**'; label = 'api'; priority = 1 },
                    @{ pattern = 'src/**'; label = 'core'; priority = 2 }
                )
            }
            # src/api/handler.ps1 matches both api and core
            $result = Get-PrLabels -Config $config -FilePaths @('src/api/handler.ps1')
            $result | Should -Be @('api', 'core')
        }

        It 'processes rules in priority order' {
            $config = @{
                rules = @(
                    @{ pattern = 'src/**'; label = 'core'; priority = 3 },
                    @{ pattern = 'src/api/**'; label = 'api'; priority = 1; exclusive = $true }
                )
            }
            # Even though core rule is listed first, api has higher priority (1 < 3)
            # and is exclusive, so src/api/handler.ps1 gets only 'api'
            $result = Get-PrLabels -Config $config -FilePaths @('src/api/handler.ps1')
            $result | Should -Be @('api')
        }
    }

    Context 'Wildcard patterns' {
        It 'matches test and spec files with ** glob' {
            $config = @{
                rules = @(
                    @{ pattern = '**/*.test.*'; label = 'tests'; priority = 1 },
                    @{ pattern = '**/*.spec.*'; label = 'tests'; priority = 2 },
                    @{ pattern = '**/*.js'; label = 'javascript'; priority = 3 }
                )
            }
            $result = Get-PrLabels -Config $config -FilePaths @(
                'src/app.test.js',
                'lib/utils.spec.ts'
            )
            # Both test and spec files match 'tests'; app.test.js also matches javascript
            $result | Should -Be @('javascript', 'tests')
        }
    }

    Context 'Error handling' {
        It 'throws on missing rules key' {
            $config = @{}
            { Get-PrLabels -Config $config -FilePaths @('file.txt') } |
                Should -Throw "*must contain a 'rules' array*"
        }

        It 'throws on empty rules array' {
            $config = @{ rules = @() }
            { Get-PrLabels -Config $config -FilePaths @('file.txt') } |
                Should -Throw "*must not be empty*"
        }

        It 'throws when a rule is missing pattern' {
            $config = @{
                rules = @(
                    @{ label = 'docs'; priority = 1 }
                )
            }
            { Get-PrLabels -Config $config -FilePaths @('file.txt') } |
                Should -Throw "*must have 'pattern' and 'label'*"
        }

        It 'throws when a rule is missing priority' {
            $config = @{
                rules = @(
                    @{ pattern = 'docs/**'; label = 'docs' }
                )
            }
            { Get-PrLabels -Config $config -FilePaths @('file.txt') } |
                Should -Throw "*must have a 'priority'*"
        }
    }
}

Describe 'CLI Integration' {
    It 'produces correct output with basic config fixture' {
        $output = & "$PSScriptRoot/Invoke-PrLabelAssigner.ps1" `
            -ConfigPath "$PSScriptRoot/fixtures/basic-config.json" `
            -FilePaths 'docs/readme.md', 'src/main.ps1'
        $output | Should -Be 'Labels: documentation'
    }

    It 'produces correct output with multi-label config fixture' {
        $output = & "$PSScriptRoot/Invoke-PrLabelAssigner.ps1" `
            -ConfigPath "$PSScriptRoot/fixtures/multi-label-config.json" `
            -FilePaths 'docs/readme.md', 'src/main.ps1', 'src/app.test.js'
        $output | Should -Be 'Labels: core, documentation, tests'
    }

    It 'produces correct output with priority config fixture' {
        $output = & "$PSScriptRoot/Invoke-PrLabelAssigner.ps1" `
            -ConfigPath "$PSScriptRoot/fixtures/priority-config.json" `
            -FilePaths 'src/api/handler.ps1', 'src/utils.ps1'
        $output | Should -Be 'Labels: api, core'
    }

    It 'produces no-match output when nothing matches' {
        $output = & "$PSScriptRoot/Invoke-PrLabelAssigner.ps1" `
            -ConfigPath "$PSScriptRoot/fixtures/basic-config.json" `
            -FilePaths 'src/main.ps1'
        $output | Should -Be 'No labels matched'
    }

    It 'produces correct output with wildcard config fixture' {
        $output = & "$PSScriptRoot/Invoke-PrLabelAssigner.ps1" `
            -ConfigPath "$PSScriptRoot/fixtures/wildcard-config.json" `
            -FilePaths 'src/app.test.js', 'lib/utils.spec.ts'
        $output | Should -Be 'Labels: javascript, tests'
    }
}

Describe 'Workflow Structure' {
    BeforeAll {
        $workflowPath = "$PSScriptRoot/.github/workflows/pr-label-assigner.yml"
        $workflowContent = Get-Content $workflowPath -Raw -ErrorAction SilentlyContinue
    }

    It 'workflow YAML file exists' {
        Test-Path $workflowPath | Should -BeTrue
    }

    It 'has push trigger' {
        $workflowContent | Should -Match 'push'
    }

    It 'has pull_request trigger' {
        $workflowContent | Should -Match 'pull_request'
    }

    It 'has a job defined' {
        $workflowContent | Should -Match 'jobs:'
    }

    It 'uses actions/checkout@v4' {
        $workflowContent | Should -Match 'actions/checkout@v4'
    }

    It 'uses shell: pwsh for run steps' {
        $workflowContent | Should -Match 'shell: pwsh'
    }

    It 'references PrLabelAssigner.ps1 which exists' {
        $workflowContent | Should -Match 'PrLabelAssigner\.ps1'
        Test-Path "$PSScriptRoot/PrLabelAssigner.ps1" | Should -BeTrue
    }

    It 'references Invoke-PrLabelAssigner.ps1 which exists' {
        $workflowContent | Should -Match 'Invoke-PrLabelAssigner\.ps1'
        Test-Path "$PSScriptRoot/Invoke-PrLabelAssigner.ps1" | Should -BeTrue
    }

    It 'references Pester test file which exists' {
        $workflowContent | Should -Match 'Invoke-PrLabelAssigner\.Tests\.ps1'
        Test-Path "$PSScriptRoot/Invoke-PrLabelAssigner.Tests.ps1" | Should -BeTrue
    }

    It 'passes actionlint validation' {
        $actionlint = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $actionlint) {
            Set-ItResult -Inconclusive -Because 'actionlint not installed in this environment'
            return
        }
        $output = & actionlint $workflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $output"
    }
}
