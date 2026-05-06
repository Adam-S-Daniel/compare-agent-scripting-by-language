# MockFixtures.ps1
# Provides test fixtures and mock data for semantic version bumper tests

# Mock git commit logs for different scenarios
$script:CommitFixtures = @{
    # Single patch fix
    "single-fix" = @(
        @{
            hash    = "abc123"
            type    = "fix"
            subject = "resolve memory leak in database connection"
            breaking = $false
        }
    )

    # Multiple patches
    "multiple-patches" = @(
        @{
            hash    = "def456"
            type    = "fix"
            subject = "fix off-by-one error in pagination"
            breaking = $false
        },
        @{
            hash    = "ghi789"
            type    = "fix"
            subject = "close file handle properly"
            breaking = $false
        }
    )

    # Single feature (minor bump)
    "single-feature" = @(
        @{
            hash    = "jkl012"
            type    = "feat"
            subject = "add user authentication endpoint"
            breaking = $false
        }
    )

    # Multiple features
    "multiple-features" = @(
        @{
            hash    = "mno345"
            type    = "feat"
            subject = "implement refresh token mechanism"
            breaking = $false
        },
        @{
            hash    = "pqr678"
            type    = "feat"
            subject = "add role-based access control"
            breaking = $false
        }
    )

    # Breaking change with exclamation
    "breaking-with-bang" = @(
        @{
            hash    = "stu901"
            type    = "feat"
            subject = "redesign API response format"
            breaking = $true
        }
    )

    # Breaking change in footer
    "breaking-in-footer" = @(
        @{
            hash    = "vwx234"
            type    = "refactor"
            subject = "restructure database schema"
            breaking = $true
        }
    )

    # Mixed commits (should pick highest priority)
    "mixed-commits" = @(
        @{
            hash    = "yza567"
            type    = "chore"
            subject = "update dependencies"
            breaking = $false
        },
        @{
            hash    = "bcd890"
            type    = "fix"
            subject = "handle null pointer exception"
            breaking = $false
        },
        @{
            hash    = "efg123"
            type    = "feat"
            subject = "add webhook support"
            breaking = $false
        }
    )

    # Breaking change with multiple commits
    "breaking-with-others" = @(
        @{
            hash    = "hij456"
            type    = "fix"
            subject = "fix typo in error message"
            breaking = $false
        },
        @{
            hash    = "klm789"
            type    = "feat"
            subject = "add new validation rules"
            breaking = $true
        },
        @{
            hash    = "nop012"
            type    = "fix"
            subject = "resolve race condition"
            breaking = $false
        }
    )

    # No semantic commits (all chore/docs)
    "non-semantic" = @(
        @{
            hash    = "qrs345"
            type    = "chore"
            subject = "bump version"
            breaking = $false
        },
        @{
            hash    = "tuv678"
            type    = "docs"
            subject = "update README"
            breaking = $false
        }
    )
}

# Version string fixtures
$script:VersionFixtures = @{
    "0.0.0" = @{ Major = 0; Minor = 0; Patch = 0 }
    "1.0.0" = @{ Major = 1; Minor = 0; Patch = 0 }
    "1.2.3" = @{ Major = 1; Minor = 2; Patch = 3 }
    "2.5.10" = @{ Major = 2; Minor = 5; Patch = 10 }
    "10.20.30" = @{ Major = 10; Minor = 20; Patch = 30 }
}

# Test expectations based on commit type and current version
$script:ExpectedVersions = @{
    "1.0.0:single-fix" = "1.0.1"
    "1.0.0:multiple-patches" = "1.0.2"
    "1.0.0:single-feature" = "1.1.0"
    "1.0.0:multiple-features" = "1.2.0"
    "1.0.0:breaking-with-bang" = "2.0.0"
    "1.0.0:breaking-in-footer" = "2.0.0"
    "1.0.0:mixed-commits" = "1.1.0"
    "1.0.0:breaking-with-others" = "2.0.0"
    "1.0.0:non-semantic" = "1.0.0"
    "1.2.3:single-fix" = "1.2.4"
    "1.2.3:single-feature" = "1.3.0"
    "1.2.3:breaking-with-bang" = "2.0.0"
    "2.5.10:single-fix" = "2.5.11"
}

function Get-CommitFixture {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($script:CommitFixtures.ContainsKey($Name)) {
        return $script:CommitFixtures[$Name]
    }
    else {
        throw "Fixture '$Name' not found. Available: $(($script:CommitFixtures.Keys -join ', '))"
    }
}

function Get-VersionFixture {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    if ($script:VersionFixtures.ContainsKey($Version)) {
        return $script:VersionFixtures[$Version]
    }
    else {
        throw "Version fixture '$Version' not found. Available: $(($script:VersionFixtures.Keys -join ', '))"
    }
}

function Get-ExpectedVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CurrentVersion,

        [Parameter(Mandatory = $true)]
        [string]$FixtureName
    )

    $key = "$CurrentVersion`:$FixtureName"
    if ($script:ExpectedVersions.ContainsKey($key)) {
        return $script:ExpectedVersions[$key]
    }
    else {
        throw "Expected version for '$key' not defined"
    }
}

function Create-MockGitRepo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$InitialVersion = "1.0.0"
    )

    # Create directory
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location $Path

    # Initialize git repo
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create package.json with initial version
    @{
        name    = "test-package"
        version = $InitialVersion
        description = "Mock package for testing"
    } | ConvertTo-Json | Set-Content "package.json"

    # Create initial commit
    git add package.json
    git commit -m "chore: initial commit"

    return $Path
}

Export-ModuleMember -Variable @(
    'CommitFixtures',
    'VersionFixtures',
    'ExpectedVersions'
) -Function @(
    'Get-CommitFixture',
    'Get-VersionFixture',
    'Get-ExpectedVersion',
    'Create-MockGitRepo'
)
