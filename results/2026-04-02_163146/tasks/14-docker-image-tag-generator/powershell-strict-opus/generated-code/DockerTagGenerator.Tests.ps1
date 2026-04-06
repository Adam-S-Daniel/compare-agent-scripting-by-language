# DockerTagGenerator.Tests.ps1
# Pester tests for Docker image tag generator
# TDD: Each Describe block was written BEFORE the corresponding implementation

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    . "$PSScriptRoot/DockerTagGenerator.ps1"
}

Describe 'Get-DockerImageTags' {

    # TDD Round 1: Main branch should produce "latest" tag
    Context 'When on main branch' {
        It 'Should return "latest" tag for main branch' {
            [hashtable]$context = @{
                BranchName = 'main'
                CommitSha  = 'abc1234567890def'
                Tags       = @()
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'latest'
        }

        It 'Should return "latest" tag for master branch' {
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

    # TDD Round 2: PR number should produce "pr-{number}" tag
    Context 'When a PR number is provided' {
        It 'Should return pr-{number} tag' {
            [hashtable]$context = @{
                BranchName = 'feature/add-login'
                CommitSha  = 'abc1234567890def'
                Tags       = @()
                PrNumber   = [int]42
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'pr-42'
        }

        It 'Should not include "latest" for PR branches' {
            [hashtable]$context = @{
                BranchName = 'feature/add-login'
                CommitSha  = 'abc1234567890def'
                Tags       = @()
                PrNumber   = [int]42
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Not -Contain 'latest'
        }
    }

    # TDD Round 3: Semver tags should produce "v{semver}" tags
    Context 'When semver tags are provided' {
        It 'Should return the semver tag as-is for v-prefixed tags' {
            [hashtable]$context = @{
                BranchName = 'main'
                CommitSha  = 'abc1234567890def'
                Tags       = @('v1.2.3')
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'v1.2.3'
        }

        It 'Should add v prefix to bare semver tags' {
            [hashtable]$context = @{
                BranchName = 'main'
                CommitSha  = 'abc1234567890def'
                Tags       = @('1.2.3')
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'v1.2.3'
        }

        It 'Should include major and major.minor version tags' {
            [hashtable]$context = @{
                BranchName = 'main'
                CommitSha  = 'abc1234567890def'
                Tags       = @('v2.5.1')
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'v2.5.1'
            $result | Should -Contain 'v2.5'
            $result | Should -Contain 'v2'
        }

        It 'Should handle multiple semver tags' {
            [hashtable]$context = @{
                BranchName = 'main'
                CommitSha  = 'abc1234567890def'
                Tags       = @('v1.0.0', 'v1.0.1')
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'v1.0.0'
            $result | Should -Contain 'v1.0.1'
        }
    }

    # TDD Round 4: Feature branches produce {branch}-{short-sha}
    Context 'When on a feature branch' {
        It 'Should return sanitized branch-sha tag' {
            [hashtable]$context = @{
                BranchName = 'feature/add-login'
                CommitSha  = 'abc1234567890def'
                Tags       = @()
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'feature-add-login-abc1234'
        }

        It 'Should not include "latest" for feature branches' {
            [hashtable]$context = @{
                BranchName = 'feature/add-login'
                CommitSha  = 'abc1234567890def'
                Tags       = @()
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Not -Contain 'latest'
        }
    }

    # TDD Round 5: Tag sanitization
    Context 'Tag sanitization' {
        It 'Should lowercase all tags' {
            [hashtable]$context = @{
                BranchName = 'Feature/My-BRANCH'
                CommitSha  = 'ABC1234567890DEF'
                Tags       = @()
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            foreach ($tag in $result) {
                $tag | Should -MatchExactly '^[a-z0-9._-]+$'
            }
        }

        It 'Should replace slashes and special chars with hyphens' {
            [hashtable]$context = @{
                BranchName = 'feature/my_cool@branch!name'
                CommitSha  = 'abc1234567890def'
                Tags       = @()
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            # The branch tag should have special chars replaced
            $branchTag = $result | Where-Object { $_ -match 'feature' }
            $branchTag | Should -Not -BeNullOrEmpty
            foreach ($t in $branchTag) {
                $t | Should -Not -Match '[/@!]'
            }
        }

        It 'Should collapse multiple consecutive hyphens' {
            [hashtable]$context = @{
                BranchName = 'feature//double--slash'
                CommitSha  = 'abc1234567890def'
                Tags       = @()
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            foreach ($tag in $result) {
                $tag | Should -Not -Match '--'
            }
        }

        It 'Should trim leading and trailing hyphens' {
            [hashtable]$context = @{
                BranchName = '-leading-trailing-'
                CommitSha  = 'abc1234567890def'
                Tags       = @()
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            foreach ($tag in $result) {
                $tag | Should -Not -Match '^-'
                $tag | Should -Not -Match '-$'
            }
        }
    }

    # TDD Round 6: Short SHA is always included
    Context 'Short SHA tag' {
        It 'Should always include the short SHA as a tag' {
            [hashtable]$context = @{
                BranchName = 'main'
                CommitSha  = 'abc1234567890def'
                Tags       = @()
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'sha-abc1234'
        }

        It 'Should use first 7 chars of SHA' {
            [hashtable]$context = @{
                BranchName = 'main'
                CommitSha  = 'deadbeef12345678'
                Tags       = @()
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            $result | Should -Contain 'sha-deadbee'
        }
    }

    # TDD Round 7: Error handling
    Context 'Error handling' {
        It 'Should throw on empty branch name' {
            {
                Get-DockerImageTags -BranchName '' -CommitSha 'abc1234' -Tags @() -PrNumber $null
            } | Should -Throw '*BranchName*'
        }

        It 'Should throw on empty commit SHA' {
            {
                Get-DockerImageTags -BranchName 'main' -CommitSha '' -Tags @() -PrNumber $null
            } | Should -Throw '*CommitSha*'
        }

        It 'Should throw on commit SHA shorter than 7 characters' {
            {
                Get-DockerImageTags -BranchName 'main' -CommitSha 'abc' -Tags @() -PrNumber $null
            } | Should -Throw '*at least 7*'
        }
    }

    # TDD Round 8: Combined scenario
    Context 'Combined scenarios' {
        It 'Should produce correct tags for tagged main branch with PR' {
            [hashtable]$context = @{
                BranchName = 'main'
                CommitSha  = 'abc1234567890def'
                Tags       = @('v1.0.0')
                PrNumber   = [int]10
            }
            [string[]]$result = Get-DockerImageTags @context
            # Main branch: latest
            $result | Should -Contain 'latest'
            # PR: pr-10
            $result | Should -Contain 'pr-10'
            # Semver: v1.0.0, v1.0, v1
            $result | Should -Contain 'v1.0.0'
            $result | Should -Contain 'v1.0'
            $result | Should -Contain 'v1'
            # SHA always present
            $result | Should -Contain 'sha-abc1234'
        }

        It 'Should return no duplicates' {
            [hashtable]$context = @{
                BranchName = 'main'
                CommitSha  = 'abc1234567890def'
                Tags       = @('v1.0.0', 'v1.0.0')
                PrNumber   = $null
            }
            [string[]]$result = Get-DockerImageTags @context
            [int]$uniqueCount = ($result | Select-Object -Unique).Count
            $uniqueCount | Should -Be $result.Count
        }
    }
}

Describe 'Format-SanitizedTag' {
    It 'Should lowercase input' {
        [string]$result = Format-SanitizedTag -RawTag 'HELLO'
        $result | Should -Be 'hello'
    }

    It 'Should replace special characters with hyphens' {
        [string]$result = Format-SanitizedTag -RawTag 'hello/world@test'
        $result | Should -Be 'hello-world-test'
    }

    It 'Should collapse consecutive hyphens' {
        [string]$result = Format-SanitizedTag -RawTag 'a//b--c'
        $result | Should -Be 'a-b-c'
    }

    It 'Should trim leading and trailing hyphens' {
        [string]$result = Format-SanitizedTag -RawTag '-hello-'
        $result | Should -Be 'hello'
    }

    It 'Should handle dots and underscores (valid Docker tag chars)' {
        [string]$result = Format-SanitizedTag -RawTag 'v1.2.3_beta'
        $result | Should -Be 'v1.2.3_beta'
    }
}
