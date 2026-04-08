# DockerTagGenerator.Tests.ps1
# Pester tests for Docker image tag generation following TDD methodology.
# Run with: Invoke-Pester ./DockerTagGenerator.Tests.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import the module under test (will fail until module is created)
$modulePath = Join-Path $PSScriptRoot 'DockerTagGenerator.psm1'
Import-Module $modulePath -Force

Describe 'ConvertTo-SanitizedTag' {
    # RED: Tag sanitization — lowercase, replace invalid chars with hyphens
    Context 'Given a tag with uppercase letters' {
        It 'converts to lowercase' {
            ConvertTo-SanitizedTag -Tag 'MyBranch' | Should -Be 'mybranch'
        }
    }

    Context 'Given a tag with special characters' {
        It 'replaces slashes with hyphens' {
            ConvertTo-SanitizedTag -Tag 'feature/my-thing' | Should -Be 'feature-my-thing'
        }

        It 'replaces underscores with hyphens' {
            ConvertTo-SanitizedTag -Tag 'feature_branch' | Should -Be 'feature-branch'
        }

        It 'replaces dots with hyphens in branch names' {
            ConvertTo-SanitizedTag -Tag 'release.1.0' | Should -Be 'release-1-0'
        }

        It 'collapses multiple consecutive hyphens into one' {
            ConvertTo-SanitizedTag -Tag 'feature//double' | Should -Be 'feature-double'
        }

        It 'strips leading and trailing hyphens' {
            ConvertTo-SanitizedTag -Tag '/leading-slash' | Should -Be 'leading-slash'
        }
    }

    Context 'Given a valid lowercase tag' {
        It 'returns it unchanged' {
            ConvertTo-SanitizedTag -Tag 'already-valid' | Should -Be 'already-valid'
        }
    }
}

Describe 'Get-ShortSha' {
    Context 'Given a full 40-char SHA' {
        It 'returns the first 7 characters' {
            Get-ShortSha -CommitSha 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0' | Should -Be 'a1b2c3d'
        }
    }

    Context 'Given a SHA shorter than 7 chars' {
        It 'returns the full SHA' {
            Get-ShortSha -CommitSha 'abc12' | Should -Be 'abc12'
        }
    }

    Context 'Given an empty SHA' {
        It 'throws a meaningful error' {
            # PowerShell mandatory-string binding rejects empty strings before our code runs,
            # so we test via the wrapper that accepts any string and validates internally.
            { Get-ShortSha -CommitSha '' } | Should -Throw
        }
    }
}

Describe 'New-DockerImageTags' {

    # Pester 5: variables shared across Its must be set in BeforeEach/BeforeAll.
    # We use BeforeEach to give each test a fresh copy of the base context hashtable.
    BeforeEach {
        $script:baseCtx = @{
            BranchName = 'main'
            CommitSha  = 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0'
            Tags       = @()
            PrNumber   = $null
        }
    }

    Context 'Given the main branch' {
        It 'includes the "latest" tag' {
            $result = New-DockerImageTags -GitContext $script:baseCtx
            $result | Should -Contain 'latest'
        }

        It 'also includes the short-sha tag' {
            $result = New-DockerImageTags -GitContext $script:baseCtx
            $result | Should -Contain 'main-a1b2c3d'
        }
    }

    Context 'Given a PR number' {
        It 'includes a pr-{number} tag' {
            $script:baseCtx['BranchName'] = 'feature/my-feature'
            $script:baseCtx['PrNumber']   = 42
            $result = New-DockerImageTags -GitContext $script:baseCtx
            $result | Should -Contain 'pr-42'
        }

        It 'does NOT include "latest" for a PR' {
            $script:baseCtx['BranchName'] = 'feature/my-feature'
            $script:baseCtx['PrNumber']   = 42
            $result = New-DockerImageTags -GitContext $script:baseCtx
            $result | Should -Not -Contain 'latest'
        }
    }

    Context 'Given a semver git tag' {
        It 'includes the v{semver} tag' {
            $script:baseCtx['Tags'] = @('v1.2.3')
            $result = New-DockerImageTags -GitContext $script:baseCtx
            $result | Should -Contain 'v1.2.3'
        }

        It 'includes multiple semver tags when present' {
            $script:baseCtx['Tags'] = @('v1.2.3', 'v1.2')
            $result = New-DockerImageTags -GitContext $script:baseCtx
            $result | Should -Contain 'v1.2.3'
            $result | Should -Contain 'v1.2'
        }

        It 'ignores non-semver tags' {
            $script:baseCtx['Tags'] = @('not-a-version')
            $result = New-DockerImageTags -GitContext $script:baseCtx
            $result | Should -Not -Contain 'not-a-version'
        }
    }

    Context 'Given a feature branch (no PR, no tag, not main)' {
        It 'includes a sanitized {branch}-{short-sha} tag' {
            $script:baseCtx['BranchName'] = 'feature/My_Cool-Branch'
            $result = New-DockerImageTags -GitContext $script:baseCtx
            $result | Should -Contain 'feature-my-cool-branch-a1b2c3d'
        }

        It 'does NOT include "latest"' {
            $script:baseCtx['BranchName'] = 'feature/something'
            $result = New-DockerImageTags -GitContext $script:baseCtx
            $result | Should -Not -Contain 'latest'
        }
    }

    Context 'Given missing required fields' {
        It 'throws when BranchName is missing' {
            $ctx = @{ CommitSha = 'a1b2c3d'; Tags = @(); PrNumber = $null }
            { New-DockerImageTags -GitContext $ctx } | Should -Throw '*BranchName*'
        }

        It 'throws when CommitSha is missing' {
            $ctx = @{ BranchName = 'main'; Tags = @(); PrNumber = $null }
            { New-DockerImageTags -GitContext $ctx } | Should -Throw '*CommitSha*'
        }
    }

    Context 'Given duplicate tags would be generated' {
        It 'returns unique tags only' {
            # main branch with a v-tag: both latest and main-sha generated, no dupe
            $script:baseCtx['Tags'] = @('v2.0.0')
            $result = New-DockerImageTags -GitContext $script:baseCtx
            ($result | Sort-Object -Unique).Count | Should -Be $result.Count
        }
    }
}
