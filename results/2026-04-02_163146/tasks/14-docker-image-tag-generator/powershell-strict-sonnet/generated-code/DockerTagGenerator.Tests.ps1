# DockerTagGenerator.Tests.ps1
# TDD tests for Docker image tag generation.
# We write failing tests first, then implement minimum code to pass each.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Import the module under test
$ModulePath = Join-Path $PSScriptRoot 'DockerTagGenerator.psm1'
Import-Module $ModulePath -Force

Describe 'Get-DockerImageTags' {

    # ---------------------------------------------------------------------------
    # RED: main branch → latest
    # ---------------------------------------------------------------------------
    Context 'Main branch' {
        It 'returns "latest" tag for main branch with no PR or tags' {
            # Arrange
            $gitContext = @{
                Branch    = 'main'
                CommitSha = 'abc1234def5678'
                Tags      = @()
                PrNumber  = $null
            }

            # Act
            [string[]]$tags = Get-DockerImageTags -GitContext $gitContext

            # Assert
            $tags | Should -Contain 'latest'
        }

        It 'returns "latest" tag for master branch' {
            $gitContext = @{
                Branch    = 'master'
                CommitSha = 'abc1234def5678'
                Tags      = @()
                PrNumber  = $null
            }

            [string[]]$tags = Get-DockerImageTags -GitContext $gitContext

            $tags | Should -Contain 'latest'
        }

        It 'also returns short-sha tag for main branch' {
            $gitContext = @{
                Branch    = 'main'
                CommitSha = 'abc1234def5678'
                Tags      = @()
                PrNumber  = $null
            }

            [string[]]$tags = Get-DockerImageTags -GitContext $gitContext

            $tags | Should -Contain 'abc1234'
        }
    }

    # ---------------------------------------------------------------------------
    # RED: PR branches → pr-{number}
    # ---------------------------------------------------------------------------
    Context 'Pull Request' {
        It 'returns pr-{number} tag when PrNumber is provided' {
            $gitContext = @{
                Branch    = 'feature/my-feature'
                CommitSha = 'deadbeef1234567'
                Tags      = @()
                PrNumber  = 42
            }

            [string[]]$tags = Get-DockerImageTags -GitContext $gitContext

            $tags | Should -Contain 'pr-42'
        }

        It 'does not return latest for a PR' {
            $gitContext = @{
                Branch    = 'feature/my-feature'
                CommitSha = 'deadbeef1234567'
                Tags      = @()
                PrNumber  = 42
            }

            [string[]]$tags = Get-DockerImageTags -GitContext $gitContext

            $tags | Should -Not -Contain 'latest'
        }

        It 'returns short-sha tag for PRs' {
            $gitContext = @{
                Branch    = 'feature/my-feature'
                CommitSha = 'deadbeef1234567'
                Tags      = @()
                PrNumber  = 42
            }

            [string[]]$tags = Get-DockerImageTags -GitContext $gitContext

            # First 7 chars of 'deadbeef1234567' = 'deadbee'
            $tags | Should -Contain 'deadbee'
        }
    }

    # ---------------------------------------------------------------------------
    # RED: semver tags → v{semver}
    # ---------------------------------------------------------------------------
    Context 'Semver Tags' {
        It 'returns v-prefixed semver tag when a semver git tag is present' {
            $gitContext = @{
                Branch    = 'main'
                CommitSha = 'cafebabe1234567'
                Tags      = @('v1.2.3')
                PrNumber  = $null
            }

            [string[]]$tags = Get-DockerImageTags -GitContext $gitContext

            $tags | Should -Contain 'v1.2.3'
        }

        It 'returns latest and semver tag on main with a release tag' {
            $gitContext = @{
                Branch    = 'main'
                CommitSha = 'cafebabe1234567'
                Tags      = @('v1.2.3')
                PrNumber  = $null
            }

            [string[]]$tags = Get-DockerImageTags -GitContext $gitContext

            $tags | Should -Contain 'latest'
            $tags | Should -Contain 'v1.2.3'
        }

        It 'handles multiple semver tags' {
            $gitContext = @{
                Branch    = 'main'
                CommitSha = 'cafebabe1234567'
                Tags      = @('v2.0.0', 'v2.0.0-rc1')
                PrNumber  = $null
            }

            [string[]]$tags = Get-DockerImageTags -GitContext $gitContext

            $tags | Should -Contain 'v2.0.0'
            $tags | Should -Contain 'v2.0.0-rc1'
        }

        It 'strips v prefix from git tag to generate bare semver tag' {
            $gitContext = @{
                Branch    = 'main'
                CommitSha = 'cafebabe1234567'
                Tags      = @('v3.1.0')
                PrNumber  = $null
            }

            [string[]]$tags = Get-DockerImageTags -GitContext $gitContext

            # Also include bare semver without v prefix
            $tags | Should -Contain '3.1.0'
        }
    }

    # ---------------------------------------------------------------------------
    # RED: feature branches → {branch}-{short-sha}
    # ---------------------------------------------------------------------------
    Context 'Feature Branches' {
        It 'returns {branch}-{short-sha} for feature branches' {
            $gitContext = @{
                Branch    = 'feature/add-login'
                CommitSha = '1111aaaa2222bbbb'
                Tags      = @()
                PrNumber  = $null
            }

            [string[]]$tags = Get-DockerImageTags -GitContext $gitContext

            # First 7 chars of '1111aaaa2222bbbb' = '1111aaa'
            $tags | Should -Contain 'feature-add-login-1111aaa'
        }

        It 'does not return latest for feature branches' {
            $gitContext = @{
                Branch    = 'feature/add-login'
                CommitSha = '1111aaaa2222bbbb'
                Tags      = @()
                PrNumber  = $null
            }

            [string[]]$tags = Get-DockerImageTags -GitContext $gitContext

            $tags | Should -Not -Contain 'latest'
        }
    }

    # ---------------------------------------------------------------------------
    # RED: Tag sanitization
    # ---------------------------------------------------------------------------
    Context 'Tag Sanitization' {
        It 'lowercases all tags' {
            $gitContext = @{
                Branch    = 'Feature/Add-Login'
                CommitSha = 'AABBCCDD11223344'
                Tags      = @()
                PrNumber  = $null
            }

            [string[]]$tags = Get-DockerImageTags -GitContext $gitContext

            foreach ($tag in $tags) {
                $tag | Should -Be $tag.ToLower()
            }
        }

        It 'replaces slashes in branch names with dashes' {
            $gitContext = @{
                Branch    = 'feature/some/nested/branch'
                CommitSha = 'aabbccdd11223344'
                Tags      = @()
                PrNumber  = $null
            }

            [string[]]$tags = Get-DockerImageTags -GitContext $gitContext

            # branch part should have / replaced
            ($tags | Where-Object { $_ -match '^feature' }) | Should -Not -BeNullOrEmpty
            ($tags | Where-Object { $_ -match '/' }) | Should -BeNullOrEmpty
        }

        It 'replaces underscores with dashes in branch names' {
            $gitContext = @{
                Branch    = 'feature/my_cool_branch'
                CommitSha = 'aabbccdd11223344'
                Tags      = @()
                PrNumber  = $null
            }

            [string[]]$tags = Get-DockerImageTags -GitContext $gitContext

            ($tags | Where-Object { $_ -match '_' }) | Should -BeNullOrEmpty
        }

        It 'removes consecutive dashes' {
            $gitContext = @{
                Branch    = 'feature//double-slash'
                CommitSha = 'aabbccdd11223344'
                Tags      = @()
                PrNumber  = $null
            }

            [string[]]$tags = Get-DockerImageTags -GitContext $gitContext

            ($tags | Where-Object { $_ -match '--' }) | Should -BeNullOrEmpty
        }
    }

    # ---------------------------------------------------------------------------
    # RED: Error handling
    # ---------------------------------------------------------------------------
    Context 'Error Handling' {
        It 'throws when GitContext is missing Branch' {
            $gitContext = @{
                CommitSha = 'aabbccdd11223344'
                Tags      = @()
                PrNumber  = $null
            }

            { Get-DockerImageTags -GitContext $gitContext } | Should -Throw
        }

        It 'throws when GitContext is missing CommitSha' {
            $gitContext = @{
                Branch   = 'main'
                Tags     = @()
                PrNumber = $null
            }

            { Get-DockerImageTags -GitContext $gitContext } | Should -Throw
        }

        It 'throws when CommitSha is empty' {
            $gitContext = @{
                Branch    = 'main'
                CommitSha = ''
                Tags      = @()
                PrNumber  = $null
            }

            { Get-DockerImageTags -GitContext $gitContext } | Should -Throw
        }

        It 'throws when Branch is empty' {
            $gitContext = @{
                Branch    = ''
                CommitSha = 'aabbccdd11223344'
                Tags      = @()
                PrNumber  = $null
            }

            { Get-DockerImageTags -GitContext $gitContext } | Should -Throw
        }
    }

    # ---------------------------------------------------------------------------
    # RED: Output uniqueness
    # ---------------------------------------------------------------------------
    Context 'Output' {
        It 'returns no duplicate tags' {
            $gitContext = @{
                Branch    = 'main'
                CommitSha = 'abc1234def5678'
                Tags      = @()
                PrNumber  = $null
            }

            [string[]]$tags = Get-DockerImageTags -GitContext $gitContext

            $unique = $tags | Select-Object -Unique
            $unique.Count | Should -Be $tags.Count
        }

        It 'returns an array (even for single tag)' {
            $gitContext = @{
                Branch    = 'feature/solo'
                CommitSha = 'abc1234def5678'
                Tags      = @()
                PrNumber  = $null
            }

            [string[]]$tags = Get-DockerImageTags -GitContext $gitContext

            $tags | Should -BeOfType [string]
            $tags.Count | Should -BeGreaterThan 0
        }
    }
}

Describe 'Invoke-DockerTagGeneratorCli' {
    Context 'CLI entry point' {
        It 'outputs tags to stdout as a newline-separated list' {
            # We test the CLI function returns the same tags as Get-DockerImageTags
            $gitContext = @{
                Branch    = 'main'
                CommitSha = 'abc1234def5678'
                Tags      = @()
                PrNumber  = $null
            }

            $output = Invoke-DockerTagGeneratorCli -GitContext $gitContext

            $output | Should -Not -BeNullOrEmpty
            $output | Should -Contain 'latest'
        }
    }
}
