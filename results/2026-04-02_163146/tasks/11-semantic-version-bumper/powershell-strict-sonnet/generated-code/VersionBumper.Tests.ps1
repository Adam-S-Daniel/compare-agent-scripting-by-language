# VersionBumper.Tests.ps1
# TDD Red/Green cycle:
# STEP 1 (RED): This test file is written FIRST. Running it fails because
#               VersionBumper.ps1 does not yet exist.
# STEP 2 (GREEN): VersionBumper.ps1 is then written to make all tests pass.
# STEP 3 (REFACTOR): Code is cleaned up while tests remain green.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    # Dot-source the module under test
    . "$PSScriptRoot/VersionBumper.ps1"

    # Helper: create a temp file with given content and extension
    function New-TempVersionFile {
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory)]
            [string]$Content,
            [Parameter()]
            [string]$Extension = '.txt'
        )
        [string]$base = [System.IO.Path]::Combine(
            [System.IO.Path]::GetTempPath(),
            [System.IO.Path]::GetRandomFileName()
        )
        [string]$path = [System.IO.Path]::ChangeExtension($base, $Extension)
        Set-Content -LiteralPath $path -Value $Content -Encoding UTF8
        return $path
    }
}

# ---------------------------------------------------------------------------
# Get-SemanticVersion
# ---------------------------------------------------------------------------
Describe 'Get-SemanticVersion' {

    Context 'Parsing package.json' {
        It 'Returns version string from package.json' {
            [string]$json = '{"name":"my-app","version":"1.2.3"}'
            [string]$path = New-TempVersionFile -Content $json -Extension '.json'
            try {
                [string]$result = Get-SemanticVersion -FilePath $path
                $result | Should -Be '1.2.3'
            }
            finally { Remove-Item -LiteralPath $path -Force }
        }

        It 'Throws when version field is absent from JSON' {
            [string]$path = New-TempVersionFile -Content '{"name":"no-version"}' -Extension '.json'
            try {
                { Get-SemanticVersion -FilePath $path } | Should -Throw
            }
            finally { Remove-Item -LiteralPath $path -Force }
        }
    }

    Context 'Parsing plain-text version file' {
        It 'Returns version string from version.txt' {
            [string]$path = New-TempVersionFile -Content '2.5.1'
            try {
                [string]$result = Get-SemanticVersion -FilePath $path
                $result | Should -Be '2.5.1'
            }
            finally { Remove-Item -LiteralPath $path -Force }
        }
    }

    Context 'Error handling' {
        It 'Throws when file does not exist' {
            { Get-SemanticVersion -FilePath '/nonexistent/version.txt' } | Should -Throw
        }

        It 'Throws on malformed version string in plain-text file' {
            [string]$path = New-TempVersionFile -Content 'not-a-semver'
            try {
                { Get-SemanticVersion -FilePath $path } | Should -Throw
            }
            finally { Remove-Item -LiteralPath $path -Force }
        }

        It 'Throws on malformed version string in package.json' {
            [string]$path = New-TempVersionFile -Content '{"version":"bad"}' -Extension '.json'
            try {
                { Get-SemanticVersion -FilePath $path } | Should -Throw
            }
            finally { Remove-Item -LiteralPath $path -Force }
        }
    }
}

# ---------------------------------------------------------------------------
# Get-BumpType
# ---------------------------------------------------------------------------
Describe 'Get-BumpType' {

    Context 'fix / chore commits -> patch' {
        It 'Returns patch for a single fix commit' {
            Get-BumpType -CommitMessages @('fix: resolve null pointer in auth') |
                Should -Be 'patch'
        }

        It 'Returns patch for chore commit' {
            Get-BumpType -CommitMessages @('chore: update dependencies') |
                Should -Be 'patch'
        }

        It 'Returns patch for docs commit' {
            Get-BumpType -CommitMessages @('docs: update README') |
                Should -Be 'patch'
        }
    }

    Context 'feat commits -> minor' {
        It 'Returns minor for a feat commit' {
            Get-BumpType -CommitMessages @('feat: add user profile page') |
                Should -Be 'minor'
        }

        It 'Returns minor for a feat commit with scope' {
            Get-BumpType -CommitMessages @('feat(auth): implement OAuth2 login') |
                Should -Be 'minor'
        }
    }

    Context 'breaking changes -> major' {
        It 'Returns major for BREAKING CHANGE footer' {
            Get-BumpType -CommitMessages @('feat: something', 'BREAKING CHANGE: remove legacy API') |
                Should -Be 'major'
        }

        It 'Returns major for commit with ! marker (feat!)' {
            Get-BumpType -CommitMessages @('feat!: redesign public API') |
                Should -Be 'major'
        }

        It 'Returns major for fix! marker' {
            Get-BumpType -CommitMessages @('fix!: change error codes') |
                Should -Be 'major'
        }

        It 'Returns major for feat with scope and ! marker' {
            Get-BumpType -CommitMessages @('feat(api)!: rename endpoints') |
                Should -Be 'major'
        }
    }

    Context 'Priority: major > minor > patch' {
        It 'Prioritises major over minor when both present' {
            Get-BumpType -CommitMessages @('feat: new feature', 'BREAKING CHANGE: old endpoint removed') |
                Should -Be 'major'
        }

        It 'Prioritises minor over patch when both present' {
            Get-BumpType -CommitMessages @('fix: bug fix', 'feat: new feature') |
                Should -Be 'minor'
        }
    }
}

# ---------------------------------------------------------------------------
# Get-NextVersion
# ---------------------------------------------------------------------------
Describe 'Get-NextVersion' {

    Context 'Patch bump' {
        It 'Increments patch: 1.2.3 -> 1.2.4' {
            Get-NextVersion -CurrentVersion '1.2.3' -BumpType 'patch' | Should -Be '1.2.4'
        }

        It 'Increments patch from zero: 1.0.0 -> 1.0.1' {
            Get-NextVersion -CurrentVersion '1.0.0' -BumpType 'patch' | Should -Be '1.0.1'
        }
    }

    Context 'Minor bump' {
        It 'Increments minor and resets patch: 1.2.3 -> 1.3.0' {
            Get-NextVersion -CurrentVersion '1.2.3' -BumpType 'minor' | Should -Be '1.3.0'
        }

        It 'Resets patch to zero on minor bump: 2.0.9 -> 2.1.0' {
            Get-NextVersion -CurrentVersion '2.0.9' -BumpType 'minor' | Should -Be '2.1.0'
        }
    }

    Context 'Major bump' {
        It 'Increments major and resets minor+patch: 1.2.3 -> 2.0.0' {
            Get-NextVersion -CurrentVersion '1.2.3' -BumpType 'major' | Should -Be '2.0.0'
        }

        It 'Resets minor and patch: 3.7.12 -> 4.0.0' {
            Get-NextVersion -CurrentVersion '3.7.12' -BumpType 'major' | Should -Be '4.0.0'
        }
    }

    Context 'Error handling' {
        It 'Throws on invalid version string' {
            { Get-NextVersion -CurrentVersion 'bad-version' -BumpType 'patch' } | Should -Throw
        }

        It 'Throws on unknown bump type' {
            { Get-NextVersion -CurrentVersion '1.0.0' -BumpType 'invalid' } | Should -Throw
        }
    }
}

# ---------------------------------------------------------------------------
# Update-VersionFile
# ---------------------------------------------------------------------------
Describe 'Update-VersionFile' {

    Context 'Updating package.json' {
        It 'Updates the version field in package.json' {
            [string]$path = New-TempVersionFile -Content '{"name":"my-app","version":"1.0.0"}' -Extension '.json'
            try {
                Update-VersionFile -FilePath $path -NewVersion '1.1.0'
                Get-SemanticVersion -FilePath $path | Should -Be '1.1.0'
            }
            finally { Remove-Item -LiteralPath $path -Force }
        }

        It 'Preserves other fields in package.json' {
            [string]$json = '{"name":"my-app","version":"1.0.0","description":"test app"}'
            [string]$path = New-TempVersionFile -Content $json -Extension '.json'
            try {
                Update-VersionFile -FilePath $path -NewVersion '2.0.0'
                $parsed = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
                $parsed.name        | Should -Be 'my-app'
                $parsed.description | Should -Be 'test app'
                $parsed.version     | Should -Be '2.0.0'
            }
            finally { Remove-Item -LiteralPath $path -Force }
        }
    }

    Context 'Updating plain-text version file' {
        It 'Overwrites content of version.txt with new version' {
            [string]$path = New-TempVersionFile -Content '1.0.0'
            try {
                Update-VersionFile -FilePath $path -NewVersion '1.2.0'
                Get-SemanticVersion -FilePath $path | Should -Be '1.2.0'
            }
            finally { Remove-Item -LiteralPath $path -Force }
        }
    }

    Context 'Error handling' {
        It 'Throws when file does not exist' {
            { Update-VersionFile -FilePath '/no/such/file.txt' -NewVersion '1.0.0' } | Should -Throw
        }

        It 'Throws on invalid new version format' {
            [string]$path = New-TempVersionFile -Content '1.0.0'
            try {
                { Update-VersionFile -FilePath $path -NewVersion 'bad' } | Should -Throw
            }
            finally { Remove-Item -LiteralPath $path -Force }
        }
    }
}

# ---------------------------------------------------------------------------
# New-ChangelogEntry
# ---------------------------------------------------------------------------
Describe 'New-ChangelogEntry' {

    It 'Includes version and date in the header' {
        [string]$entry = New-ChangelogEntry -NewVersion '1.0.1' -CommitMessages @('fix: crash') -Date '2024-01-15'
        $entry | Should -Match '\[1\.0\.1\]'
        $entry | Should -Match '2024-01-15'
    }

    It 'Groups feat commits under Features section' {
        [string[]]$commits = @('feat: add dark mode', 'feat(ui): new button')
        [string]$entry = New-ChangelogEntry -NewVersion '1.1.0' -CommitMessages $commits -Date '2024-01-15'
        $entry | Should -Match '### Features'
        $entry | Should -Match 'add dark mode'
        $entry | Should -Match 'new button'
    }

    It 'Groups fix commits under Bug Fixes section' {
        [string[]]$commits = @('fix: null pointer', 'fix(auth): token refresh')
        [string]$entry = New-ChangelogEntry -NewVersion '1.0.1' -CommitMessages $commits -Date '2024-01-15'
        $entry | Should -Match '### Bug Fixes'
        $entry | Should -Match 'null pointer'
        $entry | Should -Match 'token refresh'
    }

    It 'Groups BREAKING CHANGE commits under BREAKING CHANGES section' {
        [string[]]$commits = @('BREAKING CHANGE: removed deprecated API', 'feat!: new auth system')
        [string]$entry = New-ChangelogEntry -NewVersion '2.0.0' -CommitMessages $commits -Date '2024-01-15'
        $entry | Should -Match '### BREAKING CHANGES'
    }

    It 'Puts unrecognised commits under Other Changes' {
        [string[]]$commits = @('feat: feature', 'fix: bug', 'chore: update deps')
        [string]$entry = New-ChangelogEntry -NewVersion '1.1.1' -CommitMessages $commits -Date '2024-01-15'
        $entry | Should -Match '### Other Changes'
        $entry | Should -Match 'update deps'
    }

    It 'Produces a non-empty string for any list of commits' {
        [string]$entry = New-ChangelogEntry -NewVersion '0.1.0' -CommitMessages @('fix: init') -Date '2024-01-15'
        $entry | Should -Not -BeNullOrEmpty
    }
}

# ---------------------------------------------------------------------------
# Invoke-VersionBump  (integration tests)
# ---------------------------------------------------------------------------
Describe 'Invoke-VersionBump (integration)' {

    It 'Patch bump: fix commit on package.json' {
        [string]$path = New-TempVersionFile -Content '{"name":"app","version":"1.2.3"}' -Extension '.json'
        try {
            [hashtable]$result = Invoke-VersionBump -VersionFilePath $path -CommitMessages @('fix: login crash', 'chore: lint')
            $result.OldVersion | Should -Be '1.2.3'
            $result.NewVersion | Should -Be '1.2.4'
            $result.BumpType   | Should -Be 'patch'
            Get-SemanticVersion -FilePath $path | Should -Be '1.2.4'
        }
        finally { Remove-Item -LiteralPath $path -Force }
    }

    It 'Minor bump: feat commit on version.txt' {
        [string]$path = New-TempVersionFile -Content '2.0.0'
        try {
            [hashtable]$result = Invoke-VersionBump -VersionFilePath $path -CommitMessages @('feat: search', 'fix: typo')
            $result.NewVersion | Should -Be '2.1.0'
            $result.BumpType   | Should -Be 'minor'
        }
        finally { Remove-Item -LiteralPath $path -Force }
    }

    It 'Major bump: BREAKING CHANGE on package.json' {
        [string]$path = New-TempVersionFile -Content '{"version":"3.1.4"}' -Extension '.json'
        try {
            [hashtable]$result = Invoke-VersionBump -VersionFilePath $path -CommitMessages @('BREAKING CHANGE: API restructured', 'feat: new endpoints')
            $result.NewVersion | Should -Be '4.0.0'
            $result.BumpType   | Should -Be 'major'
        }
        finally { Remove-Item -LiteralPath $path -Force }
    }

    It 'Creates a changelog file when ChangelogPath is provided' {
        [string]$vPath = New-TempVersionFile -Content '{"version":"1.0.0"}' -Extension '.json'
        [string]$cPath = [System.IO.Path]::Combine(
            [System.IO.Path]::GetTempPath(),
            "CHANGELOG_$([System.IO.Path]::GetRandomFileName()).md"
        )
        try {
            [void](Invoke-VersionBump -VersionFilePath $vPath -CommitMessages @('feat: initial release') -ChangelogPath $cPath)
            Test-Path -LiteralPath $cPath | Should -Be $true
            [string]$content = Get-Content -LiteralPath $cPath -Raw
            $content | Should -Match '\[1\.1\.0\]'
        }
        finally {
            Remove-Item -LiteralPath $vPath -Force
            if (Test-Path -LiteralPath $cPath) { Remove-Item -LiteralPath $cPath -Force }
        }
    }

    It 'Result hashtable contains a non-empty ChangelogEntry' {
        [string]$path = New-TempVersionFile -Content '{"version":"0.1.0"}' -Extension '.json'
        try {
            [hashtable]$result = Invoke-VersionBump -VersionFilePath $path -CommitMessages @('feat: first feature')
            $result.ChangelogEntry | Should -Not -BeNullOrEmpty
        }
        finally { Remove-Item -LiteralPath $path -Force }
    }

    It 'Appends to an existing changelog file' {
        [string]$vPath  = New-TempVersionFile -Content '{"version":"1.0.0"}' -Extension '.json'
        [string]$cPath  = New-TempVersionFile -Content "## [1.0.0] - 2024-01-01`n`n- initial"
        try {
            [void](Invoke-VersionBump -VersionFilePath $vPath -CommitMessages @('fix: small fix') -ChangelogPath $cPath)
            [string]$content = Get-Content -LiteralPath $cPath -Raw
            # Both old and new entries should be present
            $content | Should -Match '\[1\.0\.1\]'
            $content | Should -Match '\[1\.0\.0\]'
        }
        finally {
            Remove-Item -LiteralPath $vPath -Force
            Remove-Item -LiteralPath $cPath -Force
        }
    }
}
