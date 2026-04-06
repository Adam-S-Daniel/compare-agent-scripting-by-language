# Pester tests for Docker Image Tag Generator
# Following red/green TDD methodology:
#   Each Context block represents a TDD cycle.
#   Tests were written FIRST (red), then minimal code was added to pass (green),
#   then refactored for clarity and maintainability.

BeforeAll {
    # Import the functions under test
    . $PSScriptRoot/Get-DockerImageTags.ps1
}

# =============================================================================
# TDD Round 1: Main/master branch should produce 'latest' tag
# RED:   Wrote tests expecting 'latest' for main/master — function was a stub returning @()
# GREEN: Added main/master detection returning 'latest'
# =============================================================================
Describe 'Get-DockerImageTags - Main Branch' {
    It 'Should return "latest" when branch is main' {
        $result = Get-DockerImageTags -BranchName 'main' -CommitSha 'abc1234567890'
        $result | Should -Contain 'latest'
    }

    It 'Should return "latest" when branch is master' {
        $result = Get-DockerImageTags -BranchName 'master' -CommitSha 'abc1234567890'
        $result | Should -Contain 'latest'
    }

    It 'Should be case-insensitive for main branch detection' {
        # Branch names can vary in case
        $result = Get-DockerImageTags -BranchName 'Main' -CommitSha 'abc1234567890'
        $result | Should -Contain 'latest'
    }

    It 'Should NOT return "latest" for a non-main branch' {
        $result = Get-DockerImageTags -BranchName 'develop' -CommitSha 'abc1234567890'
        $result | Should -Not -Contain 'latest'
    }
}

# =============================================================================
# TDD Round 2: Pull requests should produce 'pr-{number}' tag
# RED:   Wrote test expecting 'pr-42' for PrNumber=42 — no PR handling existed
# GREEN: Added PrNumber parameter and pr-{number} tag generation
# =============================================================================
Describe 'Get-DockerImageTags - Pull Request' {
    It 'Should return "pr-{number}" when PrNumber is provided' {
        $result = Get-DockerImageTags -BranchName 'feature/foo' -CommitSha 'abc1234567890' -PrNumber 42
        $result | Should -Contain 'pr-42'
    }

    It 'Should return "pr-1" for PR number 1' {
        $result = Get-DockerImageTags -BranchName 'fix/bar' -CommitSha 'def5678901234' -PrNumber 1
        $result | Should -Contain 'pr-1'
    }

    It 'Should NOT return a pr tag when PrNumber is 0 (default)' {
        $result = Get-DockerImageTags -BranchName 'feature/foo' -CommitSha 'abc1234567890'
        $result | Where-Object { $_ -match '^pr-' } | Should -BeNullOrEmpty
    }

    It 'Should handle large PR numbers' {
        $result = Get-DockerImageTags -BranchName 'feature/big-pr' -CommitSha 'abc1234567890' -PrNumber 99999
        $result | Should -Contain 'pr-99999'
    }
}

# =============================================================================
# TDD Round 3: Git tags with semver should produce version tags
# RED:   Wrote test expecting 'v1.2.3' for Tags=@('v1.2.3') — no tag handling existed
# GREEN: Added Tags parameter, regex matching, and version tag generation
# =============================================================================
Describe 'Get-DockerImageTags - Semver Tags' {
    It 'Should return version tag for a semver git tag with v prefix' {
        $result = Get-DockerImageTags -BranchName 'main' -CommitSha 'abc1234567890' -Tags @('v1.2.3')
        $result | Should -Contain 'v1.2.3'
    }

    It 'Should add v prefix to semver tag without one' {
        $result = Get-DockerImageTags -BranchName 'main' -CommitSha 'abc1234567890' -Tags @('1.0.0')
        $result | Should -Contain 'v1.0.0'
    }

    It 'Should handle semver with pre-release suffix' {
        $result = Get-DockerImageTags -BranchName 'main' -CommitSha 'abc1234567890' -Tags @('v2.0.0-beta.1')
        $result | Should -Contain 'v2.0.0-beta.1'
    }

    It 'Should handle multiple semver tags' {
        $result = Get-DockerImageTags -BranchName 'main' -CommitSha 'abc1234567890' -Tags @('v1.0.0', 'v1.0.1')
        $result | Should -Contain 'v1.0.0'
        $result | Should -Contain 'v1.0.1'
    }

    It 'Should ignore non-semver tags' {
        $result = Get-DockerImageTags -BranchName 'main' -CommitSha 'abc1234567890' -Tags @('release-candidate', 'v1.2.3')
        $result | Should -Contain 'v1.2.3'
        $result | Should -Not -Contain 'release-candidate'
    }

    It 'Should still produce latest tag on main even with semver tags' {
        $result = Get-DockerImageTags -BranchName 'main' -CommitSha 'abc1234567890' -Tags @('v3.0.0')
        $result | Should -Contain 'v3.0.0'
        $result | Should -Contain 'latest'
    }
}

# =============================================================================
# TDD Round 4: Feature branches should produce '{branch}-{short-sha}' tag
# RED:   Wrote test expecting 'feature-foo-abc1234' — no feature branch handling
# GREEN: Added branch sanitization + short SHA extraction + tag composition
# =============================================================================
Describe 'Get-DockerImageTags - Feature Branch' {
    It 'Should return "{branch}-{short-sha}" for a feature branch' {
        $result = Get-DockerImageTags -BranchName 'feature/foo' -CommitSha 'abc1234567890'
        $result | Should -Contain 'feature-foo-abc1234'
    }

    It 'Should use first 7 characters of commit SHA' {
        $result = Get-DockerImageTags -BranchName 'develop' -CommitSha 'deadbeef12345'
        $result | Should -Contain 'develop-deadbee'
    }

    It 'Should handle branch names with nested slashes' {
        $result = Get-DockerImageTags -BranchName 'feature/team/cool-thing' -CommitSha 'abc1234567890'
        $result | Should -Contain 'feature-team-cool-thing-abc1234'
    }

    It 'Should NOT produce branch-sha tag for main branch' {
        $result = Get-DockerImageTags -BranchName 'main' -CommitSha 'abc1234567890'
        $result | Should -Not -Contain 'main-abc1234'
    }

    It 'Should produce both pr tag AND branch-sha tag when PR is provided on feature branch' {
        $result = Get-DockerImageTags -BranchName 'feature/bar' -CommitSha 'abc1234567890' -PrNumber 7
        $result | Should -Contain 'pr-7'
        $result | Should -Contain 'feature-bar-abc1234'
    }
}

# =============================================================================
# TDD Round 5: Tag sanitization (ConvertTo-SanitizedTag helper)
# RED:   Wrote tests for special characters, uppercase, slashes — no sanitization existed
# GREEN: Implemented ConvertTo-SanitizedTag with regex replacements
# REFACTOR: Extracted sanitization into a dedicated helper function
# =============================================================================
Describe 'ConvertTo-SanitizedTag - Sanitization' {
    It 'Should convert to lowercase' {
        $result = ConvertTo-SanitizedTag -Value 'MyBranch'
        $result | Should -Be 'mybranch'
    }

    It 'Should replace slashes with hyphens' {
        $result = ConvertTo-SanitizedTag -Value 'feature/my-thing'
        $result | Should -Be 'feature-my-thing'
    }

    It 'Should replace underscores with hyphens' {
        $result = ConvertTo-SanitizedTag -Value 'my_branch_name'
        $result | Should -Be 'my-branch-name'
    }

    It 'Should remove special characters' {
        $result = ConvertTo-SanitizedTag -Value 'branch@#$%name'
        $result | Should -Be 'branchname'
    }

    It 'Should remove leading dots and hyphens' {
        $result = ConvertTo-SanitizedTag -Value '...-branch'
        $result | Should -Be 'branch'
    }

    It 'Should remove trailing dots and hyphens' {
        $result = ConvertTo-SanitizedTag -Value 'branch---'
        $result | Should -Be 'branch'
    }

    It 'Should collapse multiple consecutive hyphens' {
        $result = ConvertTo-SanitizedTag -Value 'a---b'
        $result | Should -Be 'a-b'
    }

    It 'Should preserve dots in version-like strings' {
        $result = ConvertTo-SanitizedTag -Value 'v1.2.3'
        $result | Should -Be 'v1.2.3'
    }

    It 'Should truncate tags longer than 128 characters' {
        $longValue = 'a' * 200
        $result = ConvertTo-SanitizedTag -Value $longValue
        $result.Length | Should -Be 128
    }

    It 'Should handle complex branch names with mixed special characters' {
        $result = ConvertTo-SanitizedTag -Value 'Feature/JIRA-123_Fix@Bug'
        $result | Should -Be 'feature-jira-123-fixbug'
    }

    It 'Should return null and write error for input that sanitizes to empty' {
        $result = ConvertTo-SanitizedTag -Value '@#$%^&' -ErrorAction SilentlyContinue
        $result | Should -BeNullOrEmpty
    }
}

# =============================================================================
# TDD Round 6: Error handling and edge cases
# RED:   Wrote tests for missing inputs and invalid SHA — no validation existed
# GREEN: Added parameter validation and meaningful error messages
# =============================================================================
Describe 'Get-DockerImageTags - Error Handling' {
    It 'Should return empty array when no context is provided' {
        $result = Get-DockerImageTags -ErrorAction SilentlyContinue
        $result | Should -BeNullOrEmpty
    }

    It 'Should return empty array for invalid commit SHA' {
        $result = Get-DockerImageTags -BranchName 'main' -CommitSha 'not-a-sha' -ErrorAction SilentlyContinue
        $result | Should -BeNullOrEmpty
    }

    It 'Should return empty array for too-short commit SHA' {
        $result = Get-DockerImageTags -BranchName 'main' -CommitSha 'abc' -ErrorAction SilentlyContinue
        $result | Should -BeNullOrEmpty
    }

    It 'Should handle empty Tags array gracefully' {
        $result = Get-DockerImageTags -BranchName 'main' -CommitSha 'abc1234567890' -Tags @()
        $result | Should -Contain 'latest'
    }

    It 'Should handle branch with only special characters gracefully' {
        # Branch sanitizes to empty, so no branch-sha tag, but no crash either
        $result = Get-DockerImageTags -BranchName '@#$' -CommitSha 'abc1234567890' -ErrorAction SilentlyContinue
        # Should not contain a branch-sha tag (branch is invalid after sanitization)
        $result | Where-Object { $_ -match '-abc1234$' } | Should -BeNullOrEmpty
    }
}

# =============================================================================
# Integration: combined scenarios
# =============================================================================
Describe 'Get-DockerImageTags - Combined Scenarios' {
    It 'Should return latest + version tag for tagged main branch' {
        $result = Get-DockerImageTags -BranchName 'main' -CommitSha 'abc1234567890' -Tags @('v2.1.0')
        $result | Should -Contain 'latest'
        $result | Should -Contain 'v2.1.0'
        $result.Count | Should -Be 2
    }

    It 'Should return pr tag + branch-sha for PR on feature branch' {
        $result = Get-DockerImageTags -BranchName 'feature/auth' -CommitSha 'deadbeef12345' -PrNumber 15
        $result | Should -Contain 'pr-15'
        $result | Should -Contain 'feature-auth-deadbee'
        $result.Count | Should -Be 2
    }

    It 'Should return version + pr + branch-sha when all context is provided on feature branch' {
        $result = Get-DockerImageTags -BranchName 'release/2.0' -CommitSha 'cafe1234abcde' -Tags @('v2.0.0') -PrNumber 100
        $result | Should -Contain 'v2.0.0'
        $result | Should -Contain 'pr-100'
        $result | Should -Contain 'release-2.0-cafe123'
        $result.Count | Should -Be 3
    }

    It 'Should produce all lowercase tags for uppercase branch names' {
        $result = Get-DockerImageTags -BranchName 'Feature/MY-BRANCH' -CommitSha 'aabbccdd11223'
        foreach ($tag in $result) {
            $tag | Should -MatchExactly '^[a-z0-9\.\-]+$'
        }
    }
}
