# DockerTagGenerator.Tests.ps1
# TDD tests for the Docker image tag generator.
# We follow red/green/refactor: each Describe block was written as a failing test
# first, then the minimum implementation was added to make it pass.

# Load the module under test. If it doesn't exist yet, tests will fail (red phase).
$ModulePath = Join-Path $PSScriptRoot 'DockerTagGenerator.ps1'
if (Test-Path $ModulePath) {
    . $ModulePath
}

Describe 'Get-DockerImageTags' {

    # -------------------------------------------------------------------------
    # RED 1: main branch should emit "latest"
    # -------------------------------------------------------------------------
    Context 'Main branch' {
        It 'returns "latest" for the main branch' {
            $result = Get-DockerImageTags -Branch 'main' -CommitSha 'abc1234def5678'
            $result | Should -Contain 'latest'
        }

        It 'returns "latest" for the master branch' {
            $result = Get-DockerImageTags -Branch 'master' -CommitSha 'abc1234def5678'
            $result | Should -Contain 'latest'
        }
    }

    # -------------------------------------------------------------------------
    # RED 2: pull-request context should emit "pr-{number}"
    # -------------------------------------------------------------------------
    Context 'Pull Request' {
        It 'returns "pr-42" when PR number 42 is supplied' {
            $result = Get-DockerImageTags -Branch 'main' -CommitSha 'abc1234def5678' -PullRequestNumber 42
            $result | Should -Contain 'pr-42'
        }

        It 'does not include "latest" when a PR number is supplied' {
            $result = Get-DockerImageTags -Branch 'main' -CommitSha 'abc1234def5678' -PullRequestNumber 42
            $result | Should -Not -Contain 'latest'
        }
    }

    # -------------------------------------------------------------------------
    # RED 3: annotated / lightweight git tags should emit "v{semver}"
    # -------------------------------------------------------------------------
    Context 'Git tag (release)' {
        It 'returns the semver tag when a git tag is provided' {
            $result = Get-DockerImageTags -Branch 'main' -CommitSha 'abc1234def5678' -GitTags @('v1.2.3')
            $result | Should -Contain 'v1.2.3'
        }

        It 'returns multiple tags when multiple git tags are provided' {
            $result = Get-DockerImageTags -Branch 'main' -CommitSha 'abc1234def5678' -GitTags @('v1.2.3', 'v1.2')
            $result | Should -Contain 'v1.2.3'
            $result | Should -Contain 'v1.2'
        }

        It 'also returns "latest" when on main with a git tag' {
            $result = Get-DockerImageTags -Branch 'main' -CommitSha 'abc1234def5678' -GitTags @('v1.2.3')
            $result | Should -Contain 'latest'
        }
    }

    # -------------------------------------------------------------------------
    # RED 4: feature branch should emit "{branch}-{short-sha}"
    # -------------------------------------------------------------------------
    Context 'Feature branch' {
        It 'returns "{branch}-{short-sha}" for a feature branch' {
            $result = Get-DockerImageTags -Branch 'feature/my-feature' -CommitSha 'abc1234def5678'
            # short SHA = first 7 chars = 'abc1234'
            $result | Should -Contain 'feature-my-feature-abc1234'
        }

        It 'does not return "latest" for a feature branch' {
            $result = Get-DockerImageTags -Branch 'feature/my-feature' -CommitSha 'abc1234def5678'
            $result | Should -Not -Contain 'latest'
        }
    }

    # -------------------------------------------------------------------------
    # RED 5: tag sanitization — lowercase, replace special chars with "-"
    # -------------------------------------------------------------------------
    Context 'Tag sanitization' {
        It 'lowercases the branch name in the tag' {
            $result = Get-DockerImageTags -Branch 'Feature/MyBranch' -CommitSha 'abc1234def5678'
            $result | Should -Contain 'feature-mybranch-abc1234'
        }

        It 'replaces slashes with hyphens' {
            $result = Get-DockerImageTags -Branch 'feature/some/deep' -CommitSha 'abc1234def5678'
            $result | Should -Contain 'feature-some-deep-abc1234'
        }

        It 'replaces underscores with hyphens' {
            $result = Get-DockerImageTags -Branch 'feature_branch' -CommitSha 'abc1234def5678'
            $result | Should -Contain 'feature-branch-abc1234'
        }

        It 'collapses consecutive hyphens' {
            # e.g. branch "feat--broken" sanitizes to "feat-broken"
            $result = Get-DockerImageTags -Branch 'feat--broken' -CommitSha 'abc1234def5678'
            $result | Should -Contain 'feat-broken-abc1234'
        }

        It 'trims leading and trailing hyphens from branch component' {
            $result = Get-DockerImageTags -Branch '-bad-branch-' -CommitSha 'abc1234def5678'
            $result | Should -Contain 'bad-branch-abc1234'
        }
    }

    # -------------------------------------------------------------------------
    # RED 6: short SHA is always the first 7 characters
    # -------------------------------------------------------------------------
    Context 'Short SHA extraction' {
        It 'uses only the first 7 characters of the commit SHA' {
            $result = Get-DockerImageTags -Branch 'dev' -CommitSha '0000000fffffffff'
            $result | Should -Contain 'dev-0000000'
        }

        It 'throws when CommitSha is shorter than 7 characters' {
            { Get-DockerImageTags -Branch 'dev' -CommitSha 'abc12' } | Should -Throw
        }
    }

    # -------------------------------------------------------------------------
    # RED 7: edge cases / error handling
    # -------------------------------------------------------------------------
    Context 'Error handling' {
        It 'throws when Branch is empty' {
            { Get-DockerImageTags -Branch '' -CommitSha 'abc1234def5678' } | Should -Throw
        }

        It 'throws when CommitSha is empty' {
            { Get-DockerImageTags -Branch 'main' -CommitSha '' } | Should -Throw
        }
    }

    # -------------------------------------------------------------------------
    # RED 8: Invoke-DockerTagGenerator integration — outputs list to pipeline
    # -------------------------------------------------------------------------
    Context 'Full integration scenario' {
        It 'returns correct tags for a tagged release on main' {
            $tags = Get-DockerImageTags -Branch 'main' -CommitSha 'deadbeef12345' -GitTags @('v2.0.0')
            $tags | Should -Contain 'latest'
            $tags | Should -Contain 'v2.0.0'
        }

        It 'returns correct tags for a feature branch PR' {
            $tags = Get-DockerImageTags -Branch 'feature/login' -CommitSha 'cafebabe99999' -PullRequestNumber 99
            $tags | Should -Contain 'pr-99'
            $tags | Should -Not -Contain 'latest'
        }
    }
}
