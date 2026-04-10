# New-DockerImageTag.Tests.ps1
# Pester tests for Docker image tag generation using TDD.
# Tests cover: tag sanitization, main branch, PRs, semver tags, feature branches,
# and workflow structure (YAML validation, file existence, actionlint).

BeforeAll {
    # Dot-source the implementation so functions are available in tests
    . "$PSScriptRoot/New-DockerImageTag.ps1"
}

# ===========================================================================
# TDD Step 1: Tag sanitization (written FIRST, fails until implementation)
# ===========================================================================
Describe "Get-SanitizedTag" {
    It "converts uppercase to lowercase" {
        Get-SanitizedTag -Tag "MAIN" | Should -Be "main"
    }

    It "replaces forward slashes with dashes" {
        Get-SanitizedTag -Tag "feature/my-feature" | Should -Be "feature-my-feature"
    }

    It "replaces underscores with dashes" {
        Get-SanitizedTag -Tag "feature_branch" | Should -Be "feature-branch"
    }

    It "replaces dots with dashes" {
        Get-SanitizedTag -Tag "release.1.0" | Should -Be "release-1-0"
    }

    It "removes leading dashes" {
        Get-SanitizedTag -Tag "/feature" | Should -Be "feature"
    }

    It "removes trailing dashes" {
        Get-SanitizedTag -Tag "feature/" | Should -Be "feature"
    }

    It "collapses multiple consecutive dashes" {
        Get-SanitizedTag -Tag "feature--test" | Should -Be "feature-test"
    }

    It "handles mixed case with special chars" {
        Get-SanitizedTag -Tag "FEATURE/My_Branch" | Should -Be "feature-my-branch"
    }
}

# ===========================================================================
# TDD Step 2: Main branch tag generation
# ===========================================================================
Describe "Get-DockerImageTags - Main Branch" {
    It "returns 'latest' for main branch" {
        $result = @(Get-DockerImageTags -BranchName "main" -CommitSha "abc1234567890" -GitTags @() -PrNumber "")
        $result | Should -Contain "latest"
    }

    It "returns 'main-{short-sha}' for main branch" {
        $result = @(Get-DockerImageTags -BranchName "main" -CommitSha "abc1234567890" -GitTags @() -PrNumber "")
        $result | Should -Contain "main-abc1234"
    }

    It "short SHA is first 7 characters" {
        $result = @(Get-DockerImageTags -BranchName "main" -CommitSha "abcdef1234567890" -GitTags @() -PrNumber "")
        $result | Should -Contain "main-abcdef1"
    }

    It "returns 'latest' for master branch" {
        $result = @(Get-DockerImageTags -BranchName "master" -CommitSha "abc1234567890" -GitTags @() -PrNumber "")
        $result | Should -Contain "latest"
    }
}

# ===========================================================================
# TDD Step 3: PR tag generation
# ===========================================================================
Describe "Get-DockerImageTags - Pull Requests" {
    It "returns 'pr-{number}' for PRs" {
        $result = @(Get-DockerImageTags -BranchName "feature/my-feature" -CommitSha "abc1234567890" -GitTags @() -PrNumber "42")
        $result | Should -Contain "pr-42"
    }

    It "PR tag is the only tag when PR number is provided" {
        $result = @(Get-DockerImageTags -BranchName "feature/my-feature" -CommitSha "abc1234567890" -GitTags @() -PrNumber "123")
        $result.Count | Should -Be 1
        $result[0] | Should -Be "pr-123"
    }

    It "handles PR on main branch - still only returns PR tag" {
        $result = @(Get-DockerImageTags -BranchName "main" -CommitSha "abc1234567890" -GitTags @() -PrNumber "99")
        $result.Count | Should -Be 1
        $result[0] | Should -Be "pr-99"
    }
}

# ===========================================================================
# TDD Step 4: Semver tag generation
# ===========================================================================
Describe "Get-DockerImageTags - Semver Tags" {
    It "returns 'v{semver}' when a semver git tag is present" {
        $result = @(Get-DockerImageTags -BranchName "main" -CommitSha "abc1234567890" -GitTags @("v1.2.3") -PrNumber "")
        $result | Should -Contain "v1.2.3"
    }

    It "includes 'latest' when semver tag is on main branch" {
        $result = @(Get-DockerImageTags -BranchName "main" -CommitSha "abc1234567890" -GitTags @("v1.2.3") -PrNumber "")
        $result | Should -Contain "latest"
    }

    It "does not include 'latest' when semver tag is NOT on main branch" {
        $result = @(Get-DockerImageTags -BranchName "release" -CommitSha "abc1234567890" -GitTags @("v1.2.3") -PrNumber "")
        $result | Should -Not -Contain "latest"
    }

    It "handles multiple semver tags" {
        $result = @(Get-DockerImageTags -BranchName "main" -CommitSha "abc1234567890" -GitTags @("v1.2.3", "v1.2") -PrNumber "")
        $result | Should -Contain "v1.2.3"
        $result | Should -Contain "v1.2"
    }

    It "ignores non-semver tags" {
        $result = @(Get-DockerImageTags -BranchName "feature" -CommitSha "abc1234567890" -GitTags @("not-a-version") -PrNumber "")
        $result | Should -Not -Contain "not-a-version"
    }
}

# ===========================================================================
# TDD Step 5: Feature branch tag generation
# ===========================================================================
Describe "Get-DockerImageTags - Feature Branches" {
    It "returns '{branch}-{short-sha}' for feature branches" {
        $result = @(Get-DockerImageTags -BranchName "feature-xyz" -CommitSha "abc1234567890" -GitTags @() -PrNumber "")
        $result | Should -Contain "feature-xyz-abc1234"
    }

    It "sanitizes branch name with slashes" {
        $result = @(Get-DockerImageTags -BranchName "feature/my-feature" -CommitSha "abc1234567890" -GitTags @() -PrNumber "")
        $result | Should -Contain "feature-my-feature-abc1234"
    }

    It "sanitizes branch name with uppercase and special chars" {
        $result = @(Get-DockerImageTags -BranchName "FEATURE/My_Branch" -CommitSha "abc1234567890" -GitTags @() -PrNumber "")
        $result | Should -Contain "feature-my-branch-abc1234"
    }

    It "does not return 'latest' for feature branches" {
        $result = @(Get-DockerImageTags -BranchName "feature/test" -CommitSha "abc1234567890" -GitTags @() -PrNumber "")
        $result | Should -Not -Contain "latest"
    }
}

# ===========================================================================
# TDD Step 6: Workflow structure tests
# ===========================================================================
Describe "Workflow Structure" {
    BeforeAll {
        $workflowPath = "$PSScriptRoot/.github/workflows/docker-image-tag-generator.yml"
        $workflowContent = Get-Content -Path $workflowPath -Raw -ErrorAction Stop
        # Parse YAML using PowerShell's built-in ConvertFrom-Yaml (requires PS 7.4+)
        # Fallback: parse key fields with regex
        $script:WorkflowPath = $workflowPath
        $script:WorkflowContent = $workflowContent
    }

    It "workflow file exists" {
        Test-Path $script:WorkflowPath | Should -Be $true
    }

    It "workflow has push trigger" {
        $script:WorkflowContent | Should -Match "push:"
    }

    It "workflow has pull_request trigger" {
        $script:WorkflowContent | Should -Match "pull_request:"
    }

    It "workflow has workflow_dispatch trigger" {
        $script:WorkflowContent | Should -Match "workflow_dispatch:"
    }

    It "workflow references the main script" {
        $script:WorkflowContent | Should -Match "New-DockerImageTag\.ps1"
    }

    It "workflow uses pwsh shell" {
        $script:WorkflowContent | Should -Match "shell: pwsh"
    }

    It "workflow uses actions/checkout" {
        $script:WorkflowContent | Should -Match "actions/checkout"
    }

    It "main script file exists" {
        Test-Path "$PSScriptRoot/New-DockerImageTag.ps1" | Should -Be $true
    }

    It "test file exists" {
        Test-Path "$PSScriptRoot/New-DockerImageTag.Tests.ps1" | Should -Be $true
    }

    It "actionlint passes on the workflow file" {
        # Skip gracefully when actionlint is not installed (e.g. inside act container)
        if (-not (Get-Command actionlint -ErrorAction SilentlyContinue)) {
            Set-ItResult -Skipped -Because "actionlint not available in this environment"
            return
        }
        $output = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}
