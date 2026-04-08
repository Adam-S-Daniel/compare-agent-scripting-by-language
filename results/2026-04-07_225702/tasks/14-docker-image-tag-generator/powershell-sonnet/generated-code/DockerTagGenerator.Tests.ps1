#Requires -Module Pester
# Docker Image Tag Generator - Pester Test Suite
# TDD approach: tests are written before implementation, driving the design.

BeforeAll {
    # Import the module under test
    . "$PSScriptRoot/DockerTagGenerator.ps1"
}

Describe "Get-DockerImageTags" {

    # ── RED: main branch → latest ──────────────────────────────────────────────
    Context "Main branch" {
        It "returns 'latest' for the main branch" {
            $result = Get-DockerImageTags -Branch "main" -CommitSha "abcdef01"
            $result | Should -Contain "latest"
        }

        It "returns 'latest' for the master branch" {
            $result = Get-DockerImageTags -Branch "master" -CommitSha "abcdef01"
            $result | Should -Contain "latest"
        }
    }

    # ── RED: PR branch → pr-{number} ──────────────────────────────────────────
    Context "Pull Request branch" {
        It "returns pr-{number} tag when PR number is provided" {
            $result = Get-DockerImageTags -Branch "feature/my-feature" -CommitSha "abcdef01" -PrNumber 42
            $result | Should -Contain "pr-42"
        }

        It "does not return latest for a PR branch" {
            $result = Get-DockerImageTags -Branch "feature/my-feature" -CommitSha "abcdef01" -PrNumber 42
            $result | Should -Not -Contain "latest"
        }
    }

    # ── RED: git tag → v{semver} ───────────────────────────────────────────────
    Context "Semantic version tag" {
        It "returns the semver tag when a git tag is provided" {
            $result = Get-DockerImageTags -Branch "main" -CommitSha "abcdef01" -GitTag "v1.2.3"
            $result | Should -Contain "v1.2.3"
        }

        It "also returns latest alongside semver when on main" {
            $result = Get-DockerImageTags -Branch "main" -CommitSha "abcdef01" -GitTag "v1.2.3"
            $result | Should -Contain "latest"
            $result | Should -Contain "v1.2.3"
        }

        It "strips leading v and also includes the bare semver" {
            $result = Get-DockerImageTags -Branch "main" -CommitSha "abcdef01" -GitTag "v2.0.0"
            $result | Should -Contain "2.0.0"
        }
    }

    # ── RED: feature branch → {branch}-{short-sha} ────────────────────────────
    Context "Feature branch" {
        It "returns {branch}-{short-sha} for a feature branch without PR" {
            $result = Get-DockerImageTags -Branch "feature/cool-thing" -CommitSha "deadbeef1234"
            $result | Should -Contain "feature-cool-thing-deadbeef"
        }

        It "uses the first 8 characters of the commit SHA" {
            $result = Get-DockerImageTags -Branch "dev" -CommitSha "0011223344556677"
            $result | Should -Contain "dev-00112233"
        }

        It "does not return latest for a feature branch" {
            $result = Get-DockerImageTags -Branch "feature/cool-thing" -CommitSha "deadbeef1234"
            $result | Should -Not -Contain "latest"
        }
    }

    # ── RED: tag sanitization ──────────────────────────────────────────────────
    Context "Tag sanitization" {
        It "lowercases the branch name" {
            # "abcdef01" SHA → short SHA "abcdef01"
            $result = Get-DockerImageTags -Branch "Feature/MyThing" -CommitSha "abcdef01"
            $result | Should -Contain "feature-mything-abcdef01"
        }

        It "replaces slashes with hyphens" {
            $result = Get-DockerImageTags -Branch "release/1.0" -CommitSha "abcdef01"
            $result | Should -Contain "release-1.0-abcdef01"
        }

        It "replaces non-alphanumeric characters (except hyphens and dots) with hyphens" {
            $result = Get-DockerImageTags -Branch "feat_underscore" -CommitSha "abcdef01"
            $result | Should -Contain "feat-underscore-abcdef01"
        }

        It "collapses consecutive hyphens into one" {
            $result = Get-DockerImageTags -Branch "feat--double" -CommitSha "abcdef01"
            $result | Should -Contain "feat-double-abcdef01"
        }

        It "trims leading and trailing hyphens from the branch segment" {
            $result = Get-DockerImageTags -Branch "-bad-branch-" -CommitSha "abcdef01"
            $result | Should -Contain "bad-branch-abcdef01"
        }
    }

    # ── RED: error handling ────────────────────────────────────────────────────
    Context "Error handling" {
        It "throws when Branch is empty" {
            { Get-DockerImageTags -Branch "" -CommitSha "abcdef01" } | Should -Throw
        }

        It "throws when CommitSha is empty" {
            { Get-DockerImageTags -Branch "main" -CommitSha "" } | Should -Throw
        }

        It "throws when CommitSha is fewer than 8 characters" {
            # "abc123" is 6 characters — below the 8-char minimum
            { Get-DockerImageTags -Branch "main" -CommitSha "abc123" } | Should -Throw
        }
    }

    # ── RED: output is a list of strings ──────────────────────────────────────
    Context "Return type" {
        It "always returns an array (even for main with no extras)" {
            $result = Get-DockerImageTags -Branch "main" -CommitSha "abcdef01"
            $result | Should -BeOfType [string]
            $result.Count | Should -BeGreaterOrEqual 1
        }

        It "returns no duplicate tags" {
            $result = Get-DockerImageTags -Branch "main" -CommitSha "abcdef01" -GitTag "v1.0.0"
            $result.Count | Should -Be ($result | Select-Object -Unique).Count
        }
    }
}
