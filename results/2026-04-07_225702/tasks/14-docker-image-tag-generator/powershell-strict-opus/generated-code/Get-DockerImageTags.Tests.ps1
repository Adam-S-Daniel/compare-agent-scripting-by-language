# Import the module under test; strict mode is enforced in the source file itself
BeforeAll {
    . "$PSScriptRoot/Get-DockerImageTags.ps1"
}

Describe 'Get-DockerImageTags' {

    Context 'Main branch builds' {
        It 'Should return "latest" tag for the main branch' {
            [hashtable]$context = @{
                BranchName = 'main'
                CommitSha  = 'abc1234567890def'
                Tags       = @()
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'latest'
        }

        It 'Should return "latest" tag for the master branch' {
            [hashtable]$context = @{
                BranchName = 'master'
                CommitSha  = 'abc1234567890def'
                Tags       = @()
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'latest'
        }
    }

    Context 'Pull request builds' {
        It 'Should return "pr-{number}" tag when PrNumber is provided' {
            [hashtable]$context = @{
                BranchName = 'feature/my-feature'
                CommitSha  = 'abc1234567890def'
                Tags       = @()
                PrNumber   = [int]42
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'pr-42'
        }

        It 'Should NOT return "latest" for a PR on a feature branch' {
            [hashtable]$context = @{
                BranchName = 'feature/my-feature'
                CommitSha  = 'abc1234567890def'
                Tags       = @()
                PrNumber   = [int]42
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Not -Contain 'latest'
        }
    }

    Context 'Semver tag builds' {
        It 'Should return "v1.2.3" for a semver git tag' {
            [hashtable]$context = @{
                BranchName = 'main'
                CommitSha  = 'abc1234567890def'
                Tags       = @('v1.2.3')
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'v1.2.3'
        }

        It 'Should return multiple semver tags when present' {
            [hashtable]$context = @{
                BranchName = 'main'
                CommitSha  = 'abc1234567890def'
                Tags       = @('v1.2.3', 'v1.2.3-beta.1')
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'v1.2.3'
            $result | Should -Contain 'v1.2.3-beta.1'
        }

        It 'Should ignore non-semver tags' {
            [hashtable]$context = @{
                BranchName = 'main'
                CommitSha  = 'abc1234567890def'
                Tags       = @('release-candidate', 'v2.0.0')
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'v2.0.0'
            $result | Should -Not -Contain 'release-candidate'
        }
    }

    Context 'Feature branch builds' {
        It 'Should return "{branch}-{short-sha}" for a feature branch' {
            [hashtable]$context = @{
                BranchName = 'feature/add-login'
                CommitSha  = 'abc1234567890def'
                Tags       = @()
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'feature-add-login-abc1234'
        }

        It 'Should use first 7 chars of the commit SHA' {
            [hashtable]$context = @{
                BranchName = 'fix/bug-123'
                CommitSha  = 'deadbeef01234567'
                Tags       = @()
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'fix-bug-123-deadbee'
        }

        It 'Should also include branch-sha tag for main branch alongside latest' {
            [hashtable]$context = @{
                BranchName = 'main'
                CommitSha  = 'abc1234567890def'
                Tags       = @()
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'latest'
            $result | Should -Contain 'main-abc1234'
        }
    }

    Context 'Tag sanitization' {
        It 'Should lowercase uppercase branch names' {
            [hashtable]$context = @{
                BranchName = 'Feature/MyBranch'
                CommitSha  = 'abc1234567890def'
                Tags       = @()
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'feature-mybranch-abc1234'
        }

        It 'Should replace special characters with hyphens' {
            [hashtable]$context = @{
                BranchName = 'user@name/feature__test'
                CommitSha  = 'abc1234567890def'
                Tags       = @()
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'user-name-feature-test-abc1234'
        }

        It 'Should collapse consecutive special chars to a single hyphen' {
            [hashtable]$context = @{
                BranchName = 'feat///multi---slash'
                CommitSha  = 'abc1234567890def'
                Tags       = @()
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'feat-multi-slash-abc1234'
        }
    }

    Context 'Error handling' {
        It 'Should throw when BranchName is empty' {
            { Get-DockerImageTags -BranchName '' -CommitSha 'abc1234' } |
                Should -Throw '*null or empty*'
        }

        It 'Should throw when CommitSha is empty' {
            { Get-DockerImageTags -BranchName 'main' -CommitSha '' } |
                Should -Throw '*null or empty*'
        }

        It 'Should handle short commit SHA gracefully (less than 7 chars)' {
            [hashtable]$context = @{
                BranchName = 'main'
                CommitSha  = 'abc'
                Tags       = @()
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'main-abc'
        }
    }

    Context 'Combined scenarios' {
        It 'Should produce all applicable tags for a tagged PR on main' {
            [hashtable]$context = @{
                BranchName = 'main'
                CommitSha  = 'abc1234567890def'
                Tags       = @('v1.0.0')
                PrNumber   = [int]99
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'latest'
            $result | Should -Contain 'pr-99'
            $result | Should -Contain 'v1.0.0'
            $result | Should -Contain 'main-abc1234'
        }
    }
}
