# Test fixtures - mock commit logs and test data

function New-TestCommitLog {
    param(
        [string]$Path,
        [string[]]$CommitMessages
    )

    $content = $CommitMessages -join "`n"
    Set-Content -Path $Path -Value $content
}

function New-TestPackageJson {
    param(
        [string]$Path,
        [string]$Version = "1.0.0"
    )

    $packageJson = @{
        name = "test-project"
        version = $Version
        description = "Test project"
    } | ConvertTo-Json

    Set-Content -Path $Path -Value $packageJson
}

# Test case fixtures
$fixtures = @{
    "simple-patch" = @{
        initialVersion = "1.0.0"
        commits = @("fix: resolve bug #123")
        expectedVersion = "1.0.1"
    }

    "simple-minor" = @{
        initialVersion = "1.0.0"
        commits = @("feat: add new feature")
        expectedVersion = "1.1.0"
    }

    "breaking-change" = @{
        initialVersion = "1.0.0"
        commits = @("feat: redesign API`nBREAKING CHANGE: old API removed")
        expectedVersion = "2.0.0"
    }

    "multiple-commits" = @{
        initialVersion = "2.5.3"
        commits = @(
            "fix: improve performance",
            "feat: add caching layer",
            "fix: handle edge case",
            "feat: add logging"
        )
        expectedVersion = "2.6.0"
    }

    "complex-breaking" = @{
        initialVersion = "3.2.1"
        commits = @(
            "fix: bug fix 1",
            "feat: feature 1",
            "feat: new API`nBREAKING CHANGE: removed old endpoint",
            "fix: bug fix 2"
        )
        expectedVersion = "4.0.0"
    }
}

# Note: These are available when sourced, no need for Export-ModuleMember outside module context
