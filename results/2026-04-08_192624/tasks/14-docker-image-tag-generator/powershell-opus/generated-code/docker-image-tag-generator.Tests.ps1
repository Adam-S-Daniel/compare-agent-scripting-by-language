#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pester tests for docker-image-tag-generator.ps1
    Uses TDD red/green methodology - each test was written before the implementation.
#>

BeforeAll {
    # Source the script to get access to functions
    . "$PSScriptRoot/docker-image-tag-generator.ps1" -BranchName "main" -CommitSha "abc1234" 2>$null
}

Describe "Sanitize-DockerTag" {
    # RED: Test that tags are lowercased
    It "converts to lowercase" {
        Sanitize-DockerTag -Value "MyBranch" | Should -Be "mybranch"
    }

    # RED: Test that slashes are replaced with hyphens
    It "replaces slashes with hyphens" {
        Sanitize-DockerTag -Value "feature/my-feature" | Should -Be "feature-my-feature"
    }

    # RED: Test that underscores are replaced
    It "replaces underscores with hyphens" {
        Sanitize-DockerTag -Value "my_branch_name" | Should -Be "my-branch-name"
    }

    # RED: Test that special characters are removed
    It "removes special characters" {
        Sanitize-DockerTag -Value "branch@name#123" | Should -Be "branch-name-123"
    }

    # RED: Test that consecutive hyphens are collapsed
    It "collapses consecutive hyphens" {
        Sanitize-DockerTag -Value "a///b" | Should -Be "a-b"
    }

    # RED: Test that leading/trailing hyphens are trimmed
    It "trims leading and trailing hyphens" {
        Sanitize-DockerTag -Value "/branch/" | Should -Be "branch"
    }

    # RED: Dots are preserved (important for semver)
    It "preserves dots" {
        Sanitize-DockerTag -Value "v1.2.3" | Should -Be "v1.2.3"
    }
}

Describe "Get-ShortSha" {
    # RED: Returns first 7 chars
    It "returns first 7 characters of a full SHA" {
        Get-ShortSha -FullSha "abc1234def5678" | Should -Be "abc1234"
    }

    # RED: Handles short SHAs gracefully
    It "handles SHAs shorter than 7 characters" {
        Get-ShortSha -FullSha "abc" | Should -Be "abc"
    }

    # RED: Returns lowercase
    It "returns lowercase" {
        Get-ShortSha -FullSha "ABC1234DEF" | Should -Be "abc1234"
    }
}

Describe "Get-DockerImageTags" {
    # RED: Main branch produces "latest"
    It "generates 'latest' for main branch" {
        $tags = Get-DockerImageTags -BranchName "main" -CommitSha "abc1234"
        $tags | Should -Contain "latest"
    }

    # RED: Master branch also produces "latest"
    It "generates 'latest' for master branch" {
        $tags = Get-DockerImageTags -BranchName "master" -CommitSha "abc1234"
        $tags | Should -Contain "latest"
    }

    # RED: PR number produces pr-{number}
    It "generates 'pr-{number}' for pull requests" {
        $tags = Get-DockerImageTags -BranchName "feature/test" -CommitSha "abc1234" -PrNumber "42"
        $tags | Should -Contain "pr-42"
    }

    # RED: Semver tag produces version tags
    It "generates version tags for semver tags" {
        $tags = Get-DockerImageTags -BranchName "main" -CommitSha "abc1234" -Tag "v1.2.3"
        $tags | Should -Contain "v1.2.3"
        $tags | Should -Contain "v1.2"
        $tags | Should -Contain "v1"
    }

    # RED: Feature branch produces {branch}-{short-sha}
    It "generates '{branch}-{short-sha}' for feature branches" {
        $tags = Get-DockerImageTags -BranchName "feature/cool-thing" -CommitSha "abc1234def5678"
        $tags | Should -Contain "feature-cool-thing-abc1234"
    }

    # RED: Feature branch names are sanitized
    It "sanitizes branch names in tags" {
        $tags = Get-DockerImageTags -BranchName "Feature/MY_Branch" -CommitSha "ABC1234def5678"
        $tags | Should -Contain "feature-my-branch-abc1234"
    }

    # RED: Main branch does NOT get branch-sha tag
    It "does not generate branch-sha tag for main branch" {
        $tags = Get-DockerImageTags -BranchName "main" -CommitSha "abc1234def5678"
        $tags | Should -Not -Contain "main-abc1234"
    }

    # RED: PR + feature branch produces both tags
    It "generates both PR and branch tags when both are provided" {
        $tags = Get-DockerImageTags -BranchName "feature/test" -CommitSha "abc1234def" -PrNumber "99"
        $tags | Should -Contain "pr-99"
        $tags | Should -Contain "feature-test-abc1234"
    }

    # RED: Error when no inputs provided
    It "returns empty array when no inputs are given" {
        $tags = Get-DockerImageTags 2>$null
        $tags.Count | Should -Be 0
    }

    # RED: Tag without v prefix still works
    It "handles tags without v prefix" {
        $tags = Get-DockerImageTags -Tag "1.0.0" -BranchName "main" -CommitSha "abc1234"
        $tags | Should -Contain "v1.0.0"
    }

    # RED: Non-semver tags are passed through sanitized
    It "handles non-semver tags" {
        $tags = Get-DockerImageTags -Tag "release-candidate" -BranchName "main" -CommitSha "abc1234"
        $tags | Should -Contain "release-candidate"
    }
}
