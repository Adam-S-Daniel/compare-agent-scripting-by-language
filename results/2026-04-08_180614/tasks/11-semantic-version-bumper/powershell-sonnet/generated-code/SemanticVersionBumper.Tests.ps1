# SemanticVersionBumper.Tests.ps1
# TDD tests for the semantic version bumper script.
# Red/Green cycle: each Describe block was written as failing before implementation.

BeforeAll {
    # Import the module under test
    . "$PSScriptRoot/SemanticVersionBumper.ps1"

    # Fixture helper — defined inside BeforeAll so it is available
    # in all It blocks (Pester 5 scoping rule).
    function New-TempVersionFile {
        param([string]$Version = "1.0.0", [string]$Format = "plain")
        $tmp = [System.IO.Path]::GetTempFileName()
        if ($Format -eq "json") {
            @{ version = $Version } | ConvertTo-Json | Set-Content $tmp
        } else {
            $Version | Set-Content $tmp
        }
        return $tmp
    }
}

# ─────────────────────────────────────────────────────────────
# 1. Read version from plain text file  [RED → GREEN]
# ─────────────────────────────────────────────────────────────
Describe "Get-CurrentVersion (plain file)" {
    It "reads a plain version string" {
        $file = New-TempVersionFile -Version "2.3.4" -Format "plain"
        try {
            $result = Get-CurrentVersion -VersionFile $file
            $result | Should -Be "2.3.4"
        } finally { Remove-Item $file -Force }
    }
}

# ─────────────────────────────────────────────────────────────
# 2. Read version from package.json  [RED → GREEN]
# ─────────────────────────────────────────────────────────────
Describe "Get-CurrentVersion (package.json)" {
    It "reads version from package.json" {
        $file = New-TempVersionFile -Version "0.9.1" -Format "json"
        try {
            $result = Get-CurrentVersion -VersionFile $file
            $result | Should -Be "0.9.1"
        } finally { Remove-Item $file -Force }
    }
}

# ─────────────────────────────────────────────────────────────
# 3. Parse conventional commits  [RED → GREEN]
# ─────────────────────────────────────────────────────────────
Describe "Get-BumpType" {
    It "returns Patch for a fix commit" {
        $commits = @("fix: correct null reference error")
        Get-BumpType -Commits $commits | Should -Be "patch"
    }

    It "returns Minor for a feat commit" {
        $commits = @("feat: add user authentication")
        Get-BumpType -Commits $commits | Should -Be "minor"
    }

    It "returns Major for a breaking change footer" {
        $commits = @("feat: redesign API`n`nBREAKING CHANGE: remove /v1 routes")
        Get-BumpType -Commits $commits | Should -Be "major"
    }

    It "returns Major for a ! breaking change" {
        $commits = @("feat!: completely new API")
        Get-BumpType -Commits $commits | Should -Be "major"
    }

    It "returns highest bump when commits are mixed" {
        $commits = @(
            "fix: patch bug",
            "feat: new feature",
            "docs: update readme"
        )
        Get-BumpType -Commits $commits | Should -Be "minor"
    }

    It "returns Patch when no conventional commits match" {
        $commits = @("random commit message")
        Get-BumpType -Commits $commits | Should -Be "patch"
    }

    It "handles empty commit list with patch" {
        Get-BumpType -Commits @() | Should -Be "patch"
    }
}

# ─────────────────────────────────────────────────────────────
# 4. Bump version number  [RED → GREEN]
# ─────────────────────────────────────────────────────────────
Describe "Invoke-VersionBump" {
    It "bumps patch: 1.0.0 -> 1.0.1" {
        Invoke-VersionBump -Version "1.0.0" -BumpType "patch" | Should -Be "1.0.1"
    }

    It "bumps minor: 1.0.0 -> 1.1.0 and resets patch" {
        Invoke-VersionBump -Version "1.0.0" -BumpType "minor" | Should -Be "1.1.0"
    }

    It "bumps major: 1.2.3 -> 2.0.0 and resets minor+patch" {
        Invoke-VersionBump -Version "1.2.3" -BumpType "major" | Should -Be "2.0.0"
    }

    It "bumps minor: 1.1.0 -> 1.2.0 (feat scenario)" {
        Invoke-VersionBump -Version "1.1.0" -BumpType "minor" | Should -Be "1.2.0"
    }

    It "throws on invalid version string" {
        { Invoke-VersionBump -Version "not-a-version" -BumpType "patch" } | Should -Throw
    }
}

# ─────────────────────────────────────────────────────────────
# 5. Write version back to file  [RED → GREEN]
# ─────────────────────────────────────────────────────────────
Describe "Set-Version" {
    It "writes new version to plain file" {
        $file = New-TempVersionFile -Version "1.0.0" -Format "plain"
        try {
            Set-Version -VersionFile $file -NewVersion "1.1.0"
            Get-Content $file | Should -Be "1.1.0"
        } finally { Remove-Item $file -Force }
    }

    It "writes new version to package.json preserving other fields" {
        $tmp = [System.IO.Path]::GetTempFileName()
        try {
            @{ name = "my-app"; version = "0.1.0"; description = "test" } |
                ConvertTo-Json | Set-Content $tmp
            Set-Version -VersionFile $tmp -NewVersion "1.0.0"
            $json = Get-Content $tmp | ConvertFrom-Json
            $json.version | Should -Be "1.0.0"
            $json.name    | Should -Be "my-app"
        } finally { Remove-Item $tmp -Force }
    }
}

# ─────────────────────────────────────────────────────────────
# 6. Generate changelog entry  [RED → GREEN]
# ─────────────────────────────────────────────────────────────
Describe "New-ChangelogEntry" {
    It "produces a non-empty changelog string" {
        $commits = @("feat: add login", "fix: typo in docs")
        $entry = New-ChangelogEntry -Version "1.1.0" -Commits $commits -Date "2026-04-08"
        $entry | Should -Not -BeNullOrEmpty
    }

    It "contains the version number" {
        $commits = @("feat: add login")
        $entry = New-ChangelogEntry -Version "2.0.0" -Commits $commits -Date "2026-04-08"
        $entry | Should -Match "2\.0\.0"
    }

    It "contains the date" {
        $commits = @("fix: crash on startup")
        $entry = New-ChangelogEntry -Version "1.0.1" -Commits $commits -Date "2026-04-08"
        $entry | Should -Match "2026-04-08"
    }

    It "lists each commit message" {
        $commits = @("feat: login", "fix: button color")
        $entry = New-ChangelogEntry -Version "1.1.0" -Commits $commits -Date "2026-04-08"
        $entry | Should -Match "login"
        $entry | Should -Match "button color"
    }
}

# ─────────────────────────────────────────────────────────────
# 7. End-to-end: Invoke-SemanticVersionBump  [RED → GREEN]
# ─────────────────────────────────────────────────────────────
Describe "Invoke-SemanticVersionBump (end-to-end)" {
    It "returns 1.2.0 when bumping 1.1.0 with a feat commit" {
        $file = New-TempVersionFile -Version "1.1.0" -Format "plain"
        try {
            $commits = @("feat: new dashboard widget")
            $result = Invoke-SemanticVersionBump -VersionFile $file -Commits $commits -Date "2026-04-08"
            $result.NewVersion | Should -Be "1.2.0"
            $result.BumpType   | Should -Be "minor"
            Get-Content $file  | Should -Be "1.2.0"
        } finally { Remove-Item $file -Force }
    }

    It "returns 1.0.1 when bumping 1.0.0 with a fix commit" {
        $file = New-TempVersionFile -Version "1.0.0" -Format "plain"
        try {
            $commits = @("fix: correct null pointer")
            $result = Invoke-SemanticVersionBump -VersionFile $file -Commits $commits -Date "2026-04-08"
            $result.NewVersion | Should -Be "1.0.1"
        } finally { Remove-Item $file -Force }
    }

    It "returns 2.0.0 when bumping 1.9.9 with a breaking change" {
        $file = New-TempVersionFile -Version "1.9.9" -Format "plain"
        try {
            $commits = @("feat!: rewrite public API")
            $result = Invoke-SemanticVersionBump -VersionFile $file -Commits $commits -Date "2026-04-08"
            $result.NewVersion | Should -Be "2.0.0"
        } finally { Remove-Item $file -Force }
    }

    It "outputs the changelog in the result" {
        $file = New-TempVersionFile -Version "1.0.0" -Format "plain"
        try {
            $commits = @("feat: fancy feature")
            $result = Invoke-SemanticVersionBump -VersionFile $file -Commits $commits -Date "2026-04-08"
            $result.Changelog | Should -Not -BeNullOrEmpty
            $result.Changelog | Should -Match "1\.1\.0"
        } finally { Remove-Item $file -Force }
    }
}

# ─────────────────────────────────────────────────────────────
# 8. Fixture file tests  [RED → GREEN]
# ─────────────────────────────────────────────────────────────
Describe "Fixture files" {
    It "fixture patch-commits.txt exists and contains fix commits" {
        $path = "$PSScriptRoot/fixtures/patch-commits.txt"
        $path | Should -Exist
        $content = Get-Content $path -Raw
        $content | Should -Match "fix:"
    }

    It "fixture minor-commits.txt exists and contains feat commits" {
        $path = "$PSScriptRoot/fixtures/minor-commits.txt"
        $path | Should -Exist
        $content = Get-Content $path -Raw
        $content | Should -Match "feat:"
    }

    It "fixture major-commits.txt exists and contains breaking change" {
        $path = "$PSScriptRoot/fixtures/major-commits.txt"
        $path | Should -Exist
        $content = Get-Content $path -Raw
        # Either BREAKING CHANGE footer or ! notation
        ($content -match "BREAKING CHANGE" -or $content -match "feat!") | Should -Be $true
    }
}
