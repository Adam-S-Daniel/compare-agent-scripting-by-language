# Docker Image Tag Generator - Pester Tests
# TDD: Write failing tests first, then implement the minimum code to pass

BeforeAll {
    # Import the module under test — must use BeforeAll in Pester v5 for proper scoping
    $ScriptPath = Join-Path $PSScriptRoot "New-DockerImageTags.ps1"
    . $ScriptPath
}

Describe "New-DockerImageTags - Main Branch" {
    It "Returns 'latest' for main branch" {
        # RED: This test will fail until we implement the function
        $result = New-DockerImageTags -BranchName "main" -CommitSha "abc1234def5678"
        $result | Should -Contain "latest"
    }

    It "Returns 'latest' for master branch" {
        $result = New-DockerImageTags -BranchName "master" -CommitSha "abc1234def5678"
        $result | Should -Contain "latest"
    }

    It "Does NOT return branch-sha tag for main branch" {
        $result = New-DockerImageTags -BranchName "main" -CommitSha "abc1234def5678"
        $result | Should -Not -Contain "main-abc1234"
    }
}

Describe "New-DockerImageTags - PR Branches" {
    It "Returns 'pr-{number}' for pull requests" {
        $result = New-DockerImageTags -BranchName "feature/my-feature" -CommitSha "abc1234def5678" -PrNumber "42"
        $result | Should -Contain "pr-42"
    }

    It "PR tag takes precedence over branch-sha tag" {
        $result = New-DockerImageTags -BranchName "feature/my-feature" -CommitSha "abc1234def5678" -PrNumber "42"
        # Should have pr tag but not branch-sha when PR number provided
        $result | Should -Contain "pr-42"
        $branchShaTags = $result | Where-Object { $_ -match "^feature" }
        $branchShaTags | Should -BeNullOrEmpty
    }

    It "Does NOT return 'latest' for PR branches" {
        $result = New-DockerImageTags -BranchName "feature/my-feature" -CommitSha "abc1234def5678" -PrNumber "42"
        $result | Should -Not -Contain "latest"
    }
}

Describe "New-DockerImageTags - Semver Tags" {
    It "Returns 'v{semver}' tag when a semver git tag is present" {
        $result = New-DockerImageTags -BranchName "main" -CommitSha "abc1234def5678" -GitTags @("v1.2.3")
        $result | Should -Contain "v1.2.3"
    }

    It "Returns multiple semver tags when multiple git tags present" {
        $result = New-DockerImageTags -BranchName "main" -CommitSha "abc1234def5678" -GitTags @("v1.2.3", "v1.2")
        $result | Should -Contain "v1.2.3"
        $result | Should -Contain "v1.2"
    }

    It "Ignores non-semver git tags" {
        $result = New-DockerImageTags -BranchName "main" -CommitSha "abc1234def5678" -GitTags @("v1.2.3", "not-a-version")
        $result | Should -Contain "v1.2.3"
        $result | Should -Not -Contain "not-a-version"
    }

    It "Returns semver tag with pre-release suffix" {
        $result = New-DockerImageTags -BranchName "main" -CommitSha "abc1234def5678" -GitTags @("v1.2.3-beta.1")
        $result | Should -Contain "v1.2.3-beta.1"
    }
}

Describe "New-DockerImageTags - Feature Branches" {
    It "Returns '{branch}-{short-sha}' for feature branches" {
        $result = New-DockerImageTags -BranchName "feature/my-feature" -CommitSha "abc1234def5678"
        $result | Should -Contain "feature-my-feature-abc1234"
    }

    It "Uses only 7 characters of the commit SHA" {
        $result = New-DockerImageTags -BranchName "feature/new-thing" -CommitSha "abcdef1234567890"
        $result | Should -Contain "feature-new-thing-abcdef1"
    }

    It "Does NOT return 'latest' for feature branches" {
        $result = New-DockerImageTags -BranchName "feature/my-feature" -CommitSha "abc1234def5678"
        $result | Should -Not -Contain "latest"
    }
}

Describe "New-DockerImageTags - Tag Sanitization" {
    It "Converts branch names to lowercase" {
        $result = New-DockerImageTags -BranchName "Feature/MyFeature" -CommitSha "abc1234def5678"
        $result | Should -Contain "feature-myfeature-abc1234"
    }

    It "Replaces slashes with hyphens" {
        $result = New-DockerImageTags -BranchName "feature/my/nested" -CommitSha "abc1234def5678"
        $result | Should -Contain "feature-my-nested-abc1234"
    }

    It "Removes leading/trailing hyphens from sanitized tags" {
        $result = New-DockerImageTags -BranchName "/leading-slash" -CommitSha "abc1234def5678"
        # Should not start with a hyphen
        $branchTags = $result | Where-Object { $_ -match "abc1234$" }
        $branchTags | ForEach-Object { $_ | Should -Not -Match "^-" }
    }

    It "Collapses multiple hyphens into one" {
        $result = New-DockerImageTags -BranchName "feat--double" -CommitSha "abc1234def5678"
        $result | Should -Contain "feat-double-abc1234"
    }

    It "Handles branch with underscores (converts to hyphens)" {
        $result = New-DockerImageTags -BranchName "feature_underscore" -CommitSha "abc1234def5678"
        $result | Should -Contain "feature-underscore-abc1234"
    }
}

Describe "Get-SanitizedTag" {
    It "Lowercases the input" {
        Get-SanitizedTag -Tag "MyBranch" | Should -Be "mybranch"
    }

    It "Replaces special chars with hyphens" {
        Get-SanitizedTag -Tag "my/branch@name" | Should -Be "my-branch-name"
    }

    It "Trims leading and trailing hyphens" {
        Get-SanitizedTag -Tag "/branch/" | Should -Be "branch"
    }

    It "Collapses consecutive hyphens" {
        Get-SanitizedTag -Tag "my--branch" | Should -Be "my-branch"
    }
}

Describe "Get-ShortSha" {
    It "Returns first 7 characters" {
        Get-ShortSha -Sha "abcdef1234567890" | Should -Be "abcdef1"
    }

    It "Returns full SHA if shorter than 7 chars" {
        Get-ShortSha -Sha "abc12" | Should -Be "abc12"
    }
}

Describe "Workflow Structure Tests" {
    BeforeAll {
        $WorkflowPath = Join-Path $PSScriptRoot ".github/workflows/docker-image-tag-generator.yml"
        $WorkflowContent = Get-Content $WorkflowPath -Raw -ErrorAction SilentlyContinue
    }

    It "Workflow file exists" {
        Test-Path $WorkflowPath | Should -Be $true
    }

    It "Script file referenced in workflow exists" {
        $scriptPath = Join-Path $PSScriptRoot "New-DockerImageTags.ps1"
        Test-Path $scriptPath | Should -Be $true
    }

    It "Tests file referenced in workflow exists" {
        $testsPath = Join-Path $PSScriptRoot "New-DockerImageTags.Tests.ps1"
        Test-Path $testsPath | Should -Be $true
    }

    It "Workflow has push trigger" {
        $WorkflowContent | Should -Match 'push:'
    }

    It "Workflow has pull_request trigger" {
        $WorkflowContent | Should -Match 'pull_request'
    }

    It "Workflow has workflow_dispatch trigger" {
        $WorkflowContent | Should -Match 'workflow_dispatch'
    }

    It "Workflow references actions/checkout@v4" {
        $WorkflowContent | Should -Match 'actions/checkout@v4'
    }

    It "Workflow has generate-tags job" {
        $WorkflowContent | Should -Match 'generate-tags:'
    }

    It "Workflow has fixture test jobs" {
        $WorkflowContent | Should -Match 'test-fixture-main'
        $WorkflowContent | Should -Match 'test-fixture-pr'
        $WorkflowContent | Should -Match 'test-fixture-semver'
        $WorkflowContent | Should -Match 'test-fixture-feature-branch'
    }

    It "Workflow passes actionlint validation" {
        # Run actionlint as a subprocess and assert exit code 0
        $output = & actionlint $WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint found errors: $output"
    }
}

Describe "Act Integration Tests" -Tag "Integration" {
    BeforeAll {
        $ActResultPath = Join-Path $PSScriptRoot "act-result.txt"
        $WorkflowPath  = Join-Path $PSScriptRoot ".github/workflows/docker-image-tag-generator.yml"
        $WorkDir       = $PSScriptRoot

        # Helper: create temp git repo with project files and run a specific act job
        function Invoke-ActJob {
            param([string]$JobName, [string[]]$ExpectedStrings)

            $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-act-$(Get-Random)"
            New-Item -ItemType Directory -Path $tmpDir | Out-Null

            try {
                # Copy project files
                Copy-Item (Join-Path $WorkDir "New-DockerImageTags.ps1")       $tmpDir
                Copy-Item (Join-Path $WorkDir "New-DockerImageTags.Tests.ps1") $tmpDir

                $wfDir = Join-Path $tmpDir ".github/workflows"
                New-Item -ItemType Directory -Path $wfDir -Force | Out-Null
                Copy-Item $WorkflowPath (Join-Path $wfDir "docker-image-tag-generator.yml")

                # Initialize git repo and run act FROM the temp dir
                Push-Location $tmpDir
                & git init -q
                & git config user.email "test@test.com"
                & git config user.name "Test"
                & git add -A
                & git commit -q -m "test"

                # Run act FROM the temp dir (so it uses the local git repo)
                $actOutput = & act push --job $JobName --rm 2>&1 |
                             ForEach-Object { $_.ToString() }
                $actExitCode = $LASTEXITCODE
                $actStr = $actOutput -join "`n"
                Pop-Location

                # Append to act-result.txt
                $delimiter = "=" * 60
                @(
                    $delimiter,
                    "ACT JOB: $JobName",
                    "Exit code: $actExitCode",
                    "--- Output ---",
                    $actStr,
                    ""
                ) | Add-Content -Path $ActResultPath

                return @{ ExitCode = $actExitCode; Output = $actStr }
            }
            finally {
                # Ensure we restore location even if act failed mid-run
                if ((Get-Location).Path -eq $tmpDir) { Pop-Location }
                Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It "act runs test-fixture-main job and produces 'latest' tag" {
        $result = Invoke-ActJob -JobName "test-fixture-main" -ExpectedStrings @("latest")
        $result.ExitCode | Should -Be 0 -Because "act should exit 0 for successful job"
        $result.Output   | Should -Match "latest"
        $result.Output   | Should -Match "Job succeeded|success"
        $result.Output   | Should -Match "PASS.*latest"
    }

    It "act runs test-fixture-pr job and produces 'pr-42' tag" {
        $result = Invoke-ActJob -JobName "test-fixture-pr" -ExpectedStrings @("pr-42")
        $result.ExitCode | Should -Be 0 -Because "act should exit 0 for successful job"
        $result.Output   | Should -Match "pr-42"
        $result.Output   | Should -Match "Job succeeded|success"
        $result.Output   | Should -Match "PASS.*pr-42"
    }

    It "act runs test-fixture-semver job and produces 'v1.2.3' and 'latest' tags" {
        $result = Invoke-ActJob -JobName "test-fixture-semver" -ExpectedStrings @("v1.2.3", "latest")
        $result.ExitCode | Should -Be 0 -Because "act should exit 0 for successful job"
        $result.Output   | Should -Match "v1\.2\.3"
        $result.Output   | Should -Match "latest"
        $result.Output   | Should -Match "Job succeeded|success"
    }

    It "act runs test-fixture-feature-branch job and produces 'feature-my-cool-feature-1a2b3c4'" {
        $result = Invoke-ActJob -JobName "test-fixture-feature-branch" -ExpectedStrings @("feature-my-cool-feature-1a2b3c4")
        $result.ExitCode | Should -Be 0 -Because "act should exit 0 for successful job"
        $result.Output   | Should -Match "feature-my-cool-feature-1a2b3c4"
        $result.Output   | Should -Match "Job succeeded|success"
        $result.Output   | Should -Match "PASS.*branch-sha"
    }

    It "act-result.txt artifact exists and contains test output" {
        Test-Path $ActResultPath | Should -Be $true
        $content = Get-Content $ActResultPath -Raw
        $content.Length | Should -BeGreaterThan 0
    }
}
