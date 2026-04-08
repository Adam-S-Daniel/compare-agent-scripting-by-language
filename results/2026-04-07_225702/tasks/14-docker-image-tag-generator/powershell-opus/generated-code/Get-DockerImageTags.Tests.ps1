# Tests for Docker image tag generator
# Using red/green TDD: each test is written before the implementation

BeforeAll {
    . "$PSScriptRoot/Get-DockerImageTags.ps1"
}

Describe 'Get-DockerImageTags' {

    Context 'Main branch' {
        It 'should return "latest" for the main branch' {
            $result = Get-DockerImageTags -BranchName 'main' -CommitSha 'abc1234567890'
            $result | Should -Contain 'latest'
        }

        It 'should return "latest" for the master branch' {
            $result = Get-DockerImageTags -BranchName 'master' -CommitSha 'abc1234567890'
            $result | Should -Contain 'latest'
        }
    }

    Context 'Pull request' {
        It 'should return "pr-{number}" when a PR number is provided' {
            $result = Get-DockerImageTags -BranchName 'feature/login' -CommitSha 'abc1234567890' -PrNumber 42
            $result | Should -Contain 'pr-42'
        }

        It 'should include both latest and pr tag for PR to main' {
            $result = Get-DockerImageTags -BranchName 'main' -CommitSha 'abc1234567890' -PrNumber 99
            $result | Should -Contain 'latest'
            $result | Should -Contain 'pr-99'
        }
    }

    Context 'Semver tags' {
        It 'should return the tag as-is when it already has a v prefix' {
            $result = Get-DockerImageTags -BranchName 'main' -CommitSha 'abc1234567890' -Tag 'v1.2.3'
            $result | Should -Contain 'v1.2.3'
        }

        It 'should add a v prefix when the tag is a bare semver' {
            $result = Get-DockerImageTags -BranchName 'main' -CommitSha 'abc1234567890' -Tag '2.0.0'
            $result | Should -Contain 'v2.0.0'
        }

        It 'should handle semver with pre-release suffix' {
            $result = Get-DockerImageTags -BranchName 'main' -CommitSha 'abc1234567890' -Tag 'v1.0.0-beta.1'
            $result | Should -Contain 'v1.0.0-beta.1'
        }

        It 'should pass through non-semver tags unchanged' {
            $result = Get-DockerImageTags -BranchName 'main' -CommitSha 'abc1234567890' -Tag 'release-candidate'
            $result | Should -Contain 'release-candidate'
        }
    }

    Context 'Feature branches' {
        It 'should return "{branch}-{short-sha}" for a simple feature branch' {
            $result = Get-DockerImageTags -BranchName 'feature-login' -CommitSha 'abc1234567890'
            $result | Should -Contain 'feature-login-abc1234'
        }

        It 'should use the first 7 chars of the commit SHA' {
            $result = Get-DockerImageTags -BranchName 'develop' -CommitSha 'deadbeefcafe123'
            $result | Should -Contain 'develop-deadbee'
        }

        It 'should not add branch-sha tag for main branch (already gets latest)' {
            $result = Get-DockerImageTags -BranchName 'main' -CommitSha 'abc1234567890'
            $result | Should -Not -Contain 'main-abc1234'
        }
    }

    Context 'Tag sanitization' {
        It 'should convert branch names with slashes to hyphens' {
            $result = Get-DockerImageTags -BranchName 'feature/add-login' -CommitSha 'abc1234567890'
            $result | Should -Contain 'feature-add-login-abc1234'
        }

        It 'should lowercase all tags' {
            $result = Get-DockerImageTags -BranchName 'Feature/ADD-Login' -CommitSha 'ABC1234567890'
            $result | Should -Contain 'feature-add-login-abc1234'
        }

        It 'should remove characters not valid in Docker tags' {
            # Docker tags allow [a-zA-Z0-9_.-] — invalid chars become hyphens
            $result = Get-DockerImageTags -BranchName 'feat/some@weird#branch!' -CommitSha 'abc1234567890'
            $result | Should -Contain 'feat-some-weird-branch-abc1234'
        }

        It 'should collapse multiple consecutive hyphens into one' {
            $result = Get-DockerImageTags -BranchName 'feature//double--slash' -CommitSha 'abc1234567890'
            $result | Should -Contain 'feature-double-slash-abc1234'
        }

        It 'should trim leading and trailing hyphens from sanitized tags' {
            $result = Get-DockerImageTags -BranchName '/leading-slash' -CommitSha 'abc1234567890'
            $result | Should -Contain 'leading-slash-abc1234'
        }
    }

    Context 'Error handling' {
        It 'should throw when BranchName is empty' {
            { Get-DockerImageTags -BranchName '' -CommitSha 'abc1234' } | Should -Throw '*BranchName*empty*'
        }

        It 'should throw when CommitSha is empty' {
            { Get-DockerImageTags -BranchName 'main' -CommitSha '' } | Should -Throw '*CommitSha*empty*'
        }

        It 'should handle a very short commit SHA gracefully' {
            $result = Get-DockerImageTags -BranchName 'dev' -CommitSha 'abc'
            $result | Should -Contain 'dev-abc'
        }
    }

    Context 'Combined inputs' {
        It 'should return all applicable tags for a tagged PR on a feature branch' {
            $result = Get-DockerImageTags -BranchName 'release/1.0' -CommitSha 'cafe123456' -Tag 'v1.0.0' -PrNumber 5
            $result | Should -Contain 'pr-5'
            $result | Should -Contain 'release-1.0-cafe123'
            $result | Should -Contain 'v1.0.0'
        }

        It 'should deduplicate identical tags' {
            # Tag that happens to match the sanitized branch-sha form
            $result = Get-DockerImageTags -BranchName 'main' -CommitSha 'abc1234567890' -Tag 'latest'
            # "latest" should appear only once
            ($result | Where-Object { $_ -eq 'latest' }).Count | Should -Be 1
        }
    }
}
