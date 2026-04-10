# Get-DockerImageTags.Tests.ps1
# Pester test harness that validates workflow structure, runs all test cases
# through act (GitHub Actions in Docker), and asserts on exact expected tag values.

BeforeAll {
    $script:ProjectRoot = $PSScriptRoot
    $script:WorkflowPath = Join-Path $script:ProjectRoot '.github' 'workflows' 'docker-image-tag-generator.yml'
    $script:ScriptPath = Join-Path $script:ProjectRoot 'Get-DockerImageTags.ps1'
    $script:ActResultFile = Join-Path $script:ProjectRoot 'act-result.txt'
}

Describe 'Workflow Structure Tests' {
    It 'workflow YAML file exists' {
        $script:WorkflowPath | Should -Exist
    }

    It 'has valid YAML with expected triggers' {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match 'on:'
        $content | Should -Match 'push:'
        $content | Should -Match 'pull_request:'
        $content | Should -Match 'workflow_dispatch:'
    }

    It 'has expected jobs and steps structure' {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match 'jobs:'
        $content | Should -Match 'generate-tags:'
        $content | Should -Match 'runs-on:\s*ubuntu-latest'
        $content | Should -Match 'actions/checkout@v4'
        $content | Should -Match 'shell:\s*pwsh'
    }

    It 'references the script file which exists on disk' {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match 'Get-DockerImageTags\.ps1'
        $script:ScriptPath | Should -Exist
    }

    It 'passes actionlint validation' {
        $lintOutput = & actionlint $script:WorkflowPath 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0 -Because "actionlint errors: $lintOutput"
    }
}

Describe 'Docker Image Tag Generation via Act' {
    BeforeAll {
        # Create an isolated temp directory with a git repo containing our project files
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "docker-tag-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null

        # Copy the script and workflow into the temp repo
        Copy-Item $script:ScriptPath -Destination $script:tempDir
        $wfDir = Join-Path $script:tempDir '.github' 'workflows'
        New-Item -ItemType Directory -Path $wfDir -Force | Out-Null
        Copy-Item $script:WorkflowPath -Destination $wfDir

        # Copy .actrc if present (maps ubuntu-latest to the custom container)
        $actrcSrc = Join-Path $script:ProjectRoot '.actrc'
        if (Test-Path $actrcSrc) {
            Copy-Item $actrcSrc -Destination $script:tempDir
        }

        # Initialize git repo, commit, and run act
        Push-Location $script:tempDir
        try {
            & git init --initial-branch=main 2>&1 | Out-Null
            & git config user.email "test@test.com" 2>&1 | Out-Null
            & git config user.name "test" 2>&1 | Out-Null
            & git add -A 2>&1 | Out-Null
            & git commit -m "test" 2>&1 | Out-Null

            $script:actOutput = & act push --rm --pull=false 2>&1 | Out-String
            $script:actExitCode = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }

        # Write act output to the required act-result.txt artifact
        "=== ACT RUN: Docker Image Tag Generator - All Test Cases ===" | Set-Content $script:ActResultFile
        $script:actOutput | Add-Content $script:ActResultFile
        "=== END ACT RUN ===" | Add-Content $script:ActResultFile

        # Parse the act output to extract tags per test case for exact assertions
        $script:testCaseTags = @{}
        $currentCase = $null
        foreach ($line in ($script:actOutput -split '\r?\n')) {
            if ($line -match '=== TEST CASE (\d+):') {
                $currentCase = $Matches[1]
                $script:testCaseTags[$currentCase] = [System.Collections.Generic.List[string]]::new()
            }
            elseif ($line -match '=== END TEST CASE') {
                $currentCase = $null
            }
            elseif ($null -ne $currentCase -and $line -match 'TAG:\s+(.+)') {
                $tag = $Matches[1].Trim()
                if ($tag.Length -gt 0) {
                    $script:testCaseTags[$currentCase].Add($tag)
                }
            }
        }

        # Cleanup temp directory
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'act exits with code 0' {
        $script:actExitCode | Should -Be 0 -Because "Act failed. Output: $($script:actOutput.Substring(0, [Math]::Min(2000, $script:actOutput.Length)))"
    }

    It 'job succeeded' {
        $script:actOutput | Should -Match 'Job succeeded'
    }

    # Test Case 1: main branch produces exactly "latest" and "main-abc1234"
    It 'Test Case 1: main branch generates latest and branch-sha tags' {
        $tags = $script:testCaseTags['1']
        $tags | Should -Not -BeNullOrEmpty -Because "No tags parsed for test case 1"
        $tags | Should -Contain 'latest'
        $tags | Should -Contain 'main-abc1234'
        $tags.Count | Should -Be 2
    }

    # Test Case 2: feature branch produces only the sanitized branch-sha tag
    It 'Test Case 2: feature branch generates sanitized branch-sha tag only' {
        $tags = $script:testCaseTags['2']
        $tags | Should -Not -BeNullOrEmpty -Because "No tags parsed for test case 2"
        $tags | Should -Contain 'feature-add-login-def5678'
        $tags.Count | Should -Be 1
    }

    # Test Case 3: PR produces pr-42 and the branch-sha tag
    It 'Test Case 3: pull request generates pr-N and branch-sha tags' {
        $tags = $script:testCaseTags['3']
        $tags | Should -Not -BeNullOrEmpty -Because "No tags parsed for test case 3"
        $tags | Should -Contain 'pr-42'
        $tags | Should -Contain 'feature-fix-bug-1112223'
        $tags.Count | Should -Be 2
    }

    # Test Case 4: semver tag on main produces latest, v1.2.3, 1.2.3, 1.2, and branch-sha
    It 'Test Case 4: semver tag generates version tags plus latest and branch-sha' {
        $tags = $script:testCaseTags['4']
        $tags | Should -Not -BeNullOrEmpty -Because "No tags parsed for test case 4"
        $tags | Should -Contain 'latest'
        $tags | Should -Contain 'v1.2.3'
        $tags | Should -Contain '1.2.3'
        $tags | Should -Contain '1.2'
        $tags | Should -Contain 'main-aaa1111'
        $tags.Count | Should -Be 5
    }

    # Test Case 5: branch with uppercase and special chars is sanitized
    It 'Test Case 5: branch name sanitization works correctly' {
        $tags = $script:testCaseTags['5']
        $tags | Should -Not -BeNullOrEmpty -Because "No tags parsed for test case 5"
        $tags | Should -Contain 'feature-upper-case-ccc3333'
        $tags.Count | Should -Be 1
    }

    # Test Case 6: master branch also gets the "latest" tag
    It 'Test Case 6: master branch generates latest and branch-sha tags' {
        $tags = $script:testCaseTags['6']
        $tags | Should -Not -BeNullOrEmpty -Because "No tags parsed for test case 6"
        $tags | Should -Contain 'latest'
        $tags | Should -Contain 'master-eee5555'
        $tags.Count | Should -Be 2
    }
}
