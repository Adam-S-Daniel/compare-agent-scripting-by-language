BeforeAll {
    . "$PSScriptRoot/Bump-SemanticVersion.ps1"
}

Describe 'Parse-SemanticVersion' {
    It 'parses a standard semver string' {
        $result = Parse-SemanticVersion '2.4.1'
        $result.Major | Should -Be 2
        $result.Minor | Should -Be 4
        $result.Patch | Should -Be 1
    }

    It 'parses version with v prefix' {
        $result = Parse-SemanticVersion 'v1.0.0'
        $result.Major | Should -Be 1
        $result.Minor | Should -Be 0
        $result.Patch | Should -Be 0
    }

    It 'throws on invalid version string' {
        { Parse-SemanticVersion 'not-a-version' } | Should -Throw
    }
}

Describe 'Get-BumpType' {
    It 'returns patch for fix commits only' {
        $commits = @('fix: resolve null reference', 'fix: handle empty input')
        Get-BumpType $commits | Should -Be 'patch'
    }

    It 'returns minor for feat commits' {
        $commits = @('feat: add export', 'fix: correct error')
        Get-BumpType $commits | Should -Be 'minor'
    }

    It 'returns major for breaking change with bang' {
        $commits = @('feat!: redesign API', 'feat: add flow')
        Get-BumpType $commits | Should -Be 'major'
    }

    It 'returns major for BREAKING CHANGE footer' {
        $commits = @('feat: overhaul config', 'BREAKING CHANGE: format changed')
        Get-BumpType $commits | Should -Be 'major'
    }

    It 'returns patch for unknown commit types' {
        $commits = @('chore: update deps', 'docs: fix typo')
        Get-BumpType $commits | Should -Be 'patch'
    }
}

Describe 'Invoke-VersionBump' {
    It 'bumps patch version' {
        $ver = @{ Major = 1; Minor = 2; Patch = 3 }
        $result = Invoke-VersionBump $ver 'patch'
        $result | Should -Be '1.2.4'
    }

    It 'bumps minor version and resets patch' {
        $ver = @{ Major = 1; Minor = 2; Patch = 3 }
        $result = Invoke-VersionBump $ver 'minor'
        $result | Should -Be '1.3.0'
    }

    It 'bumps major version and resets minor and patch' {
        $ver = @{ Major = 1; Minor = 2; Patch = 3 }
        $result = Invoke-VersionBump $ver 'major'
        $result | Should -Be '2.0.0'
    }
}

Describe 'Read-VersionFile' {
    BeforeEach {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "svb-test-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $script:testDir | Out-Null
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:testDir -ErrorAction SilentlyContinue
    }

    It 'reads version from a plain VERSION file' {
        Set-Content -Path (Join-Path $script:testDir 'VERSION') -Value '1.5.0'
        $result = Read-VersionFile $script:testDir
        $result | Should -Be '1.5.0'
    }

    It 'reads version from package.json' {
        $json = '{"name":"test","version":"3.1.4"}'
        Set-Content -Path (Join-Path $script:testDir 'package.json') -Value $json
        $result = Read-VersionFile $script:testDir
        $result | Should -Be '3.1.4'
    }

    It 'prefers VERSION file over package.json' {
        Set-Content -Path (Join-Path $script:testDir 'VERSION') -Value '2.0.0'
        $json = '{"name":"test","version":"1.0.0"}'
        Set-Content -Path (Join-Path $script:testDir 'package.json') -Value $json
        $result = Read-VersionFile $script:testDir
        $result | Should -Be '2.0.0'
    }

    It 'throws when no version file exists' {
        { Read-VersionFile $script:testDir } | Should -Throw
    }
}

Describe 'Write-VersionFile' {
    BeforeEach {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "svb-test-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $script:testDir | Out-Null
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:testDir -ErrorAction SilentlyContinue
    }

    It 'writes new version to VERSION file' {
        Set-Content -Path (Join-Path $script:testDir 'VERSION') -Value '1.0.0'
        Write-VersionFile $script:testDir '1.1.0'
        Get-Content (Join-Path $script:testDir 'VERSION') | Should -Be '1.1.0'
    }

    It 'writes new version to package.json' {
        $json = '{"name":"test","version":"1.0.0"}'
        Set-Content -Path (Join-Path $script:testDir 'package.json') -Value $json
        Write-VersionFile $script:testDir '1.1.0'
        $content = Get-Content (Join-Path $script:testDir 'package.json') | ConvertFrom-Json
        $content.version | Should -Be '1.1.0'
    }
}

Describe 'New-ChangelogEntry' {
    It 'generates a changelog with categorized commits' {
        $commits = @('feat: add search', 'fix: null check', 'feat!: new API')
        $entry = New-ChangelogEntry '2.0.0' $commits
        $entry | Should -Match '## 2.0.0'
        $entry | Should -Match 'add search'
        $entry | Should -Match 'null check'
        $entry | Should -Match 'new API'
    }

    It 'includes breaking changes section' {
        $commits = @('feat!: drop legacy support')
        $entry = New-ChangelogEntry '3.0.0' $commits
        $entry | Should -Match 'Breaking'
    }
}

Describe 'Integration: full version bump pipeline' {
    BeforeEach {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "svb-int-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $script:testDir | Out-Null
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:testDir -ErrorAction SilentlyContinue
    }

    It 'bumps 1.0.0 to 1.0.1 with patch commits' {
        Set-Content -Path (Join-Path $script:testDir 'VERSION') -Value '1.0.0'
        $commits = @('fix: resolve null reference', 'fix: handle empty input')
        $result = Invoke-SemanticVersionBump -ProjectPath $script:testDir -CommitMessages $commits
        $result.NewVersion | Should -Be '1.0.1'
        $result.BumpType | Should -Be 'patch'
    }

    It 'bumps 1.1.0 to 1.2.0 with minor commits' {
        Set-Content -Path (Join-Path $script:testDir 'VERSION') -Value '1.1.0'
        $commits = @('feat: add export functionality', 'fix: correct off-by-one error')
        $result = Invoke-SemanticVersionBump -ProjectPath $script:testDir -CommitMessages $commits
        $result.NewVersion | Should -Be '1.2.0'
        $result.BumpType | Should -Be 'minor'
    }

    It 'bumps 2.3.1 to 3.0.0 with breaking commits' {
        Set-Content -Path (Join-Path $script:testDir 'VERSION') -Value '2.3.1'
        $commits = @('feat!: redesign authentication API', 'feat: add new login flow')
        $result = Invoke-SemanticVersionBump -ProjectPath $script:testDir -CommitMessages $commits
        $result.NewVersion | Should -Be '3.0.0'
        $result.BumpType | Should -Be 'major'
    }

    It 'produces a changelog entry' {
        Set-Content -Path (Join-Path $script:testDir 'VERSION') -Value '1.0.0'
        $commits = @('feat: add search', 'fix: null check')
        $result = Invoke-SemanticVersionBump -ProjectPath $script:testDir -CommitMessages $commits
        $result.Changelog | Should -Match '## 1.1.0'
    }

    It 'updates the VERSION file on disk' {
        Set-Content -Path (Join-Path $script:testDir 'VERSION') -Value '1.0.0'
        $commits = @('feat: add feature')
        Invoke-SemanticVersionBump -ProjectPath $script:testDir -CommitMessages $commits
        Get-Content (Join-Path $script:testDir 'VERSION') | Should -Be '1.1.0'
    }
}
