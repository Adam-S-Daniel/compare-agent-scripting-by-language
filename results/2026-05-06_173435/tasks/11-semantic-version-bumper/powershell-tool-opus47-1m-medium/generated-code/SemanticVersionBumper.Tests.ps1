Set-StrictMode -Version Latest

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'SemanticVersionBumper.psm1') -Force
}

Describe 'Get-CurrentVersion' {
    It 'reads version from a plain version.txt file' {
        $f = New-TemporaryFile
        '1.2.3' | Set-Content -LiteralPath $f.FullName -NoNewline
        Get-CurrentVersion -Path $f.FullName | Should -Be '1.2.3'
    }
    It 'reads version from package.json' {
        $f = [System.IO.Path]::GetTempFileName() + '.json'
        '{"name":"x","version":"0.4.7"}' | Set-Content -LiteralPath $f -NoNewline
        Get-CurrentVersion -Path $f | Should -Be '0.4.7'
    }
    It 'throws on missing file' {
        { Get-CurrentVersion -Path '/tmp/does-not-exist-xyz.txt' } | Should -Throw '*not found*'
    }
    It 'throws on invalid semver' {
        $f = New-TemporaryFile
        'not-a-version' | Set-Content -LiteralPath $f.FullName -NoNewline
        { Get-CurrentVersion -Path $f.FullName } | Should -Throw '*Invalid*'
    }
}

Describe 'Get-BumpType' {
    It 'detects major from "!" syntax'      { Get-BumpType -Commits @('feat!: drop legacy api') | Should -Be 'major' }
    It 'detects major from BREAKING CHANGE' { Get-BumpType -Commits @("feat: x`n`nBREAKING CHANGE: removed Y") | Should -Be 'major' }
    It 'detects minor from feat'            { Get-BumpType -Commits @('feat: add a thing','fix: small') | Should -Be 'minor' }
    It 'detects patch from fix'             { Get-BumpType -Commits @('fix: bug','chore: deps') | Should -Be 'patch' }
    It 'returns none for chore-only'        { Get-BumpType -Commits @('chore: deps','docs: readme') | Should -Be 'none' }
    It 'handles scoped types'               { Get-BumpType -Commits @('feat(api): scoped') | Should -Be 'minor' }
    It 'breaking trumps feat'               { Get-BumpType -Commits @('feat: x','fix!: bad') | Should -Be 'major' }
}

Describe 'Get-NextVersion' {
    It 'bumps major'  { Get-NextVersion -CurrentVersion '1.2.3' -BumpType 'major' | Should -Be '2.0.0' }
    It 'bumps minor'  { Get-NextVersion -CurrentVersion '1.2.3' -BumpType 'minor' | Should -Be '1.3.0' }
    It 'bumps patch'  { Get-NextVersion -CurrentVersion '1.2.3' -BumpType 'patch' | Should -Be '1.2.4' }
    It 'no-op none'   { Get-NextVersion -CurrentVersion '1.2.3' -BumpType 'none'  | Should -Be '1.2.3' }
}

Describe 'New-ChangelogEntry' {
    It 'groups by section' {
        $c = @('feat: new', 'fix: bug', 'chore: cleanup', 'feat!: bc')
        $e = New-ChangelogEntry -Version '2.0.0' -Commits $c -Date '2026-05-07'
        $e | Should -Match '## \[2\.0\.0\] - 2026-05-07'
        $e | Should -Match 'BREAKING CHANGES'
        $e | Should -Match '- feat!: bc'
        $e | Should -Match '- feat: new'
        $e | Should -Match '- fix: bug'
    }
}

Describe 'Set-Version + package.json round-trip' {
    It 'updates package.json version preserving other fields' {
        $f = [System.IO.Path]::GetTempFileName() + '.json'
        '{"name":"x","version":"1.0.0","scripts":{"build":"echo"}}' | Set-Content -LiteralPath $f -NoNewline
        Set-Version -Path $f -NewVersion '1.1.0'
        $j = Get-Content -LiteralPath $f -Raw | ConvertFrom-Json
        $j.version | Should -Be '1.1.0'
        $j.name    | Should -Be 'x'
        $j.scripts.build | Should -Be 'echo'
    }
}

Describe 'Invoke-VersionBump (end-to-end)' {
    It 'bumps minor for feat commit and writes changelog' {
        $tmp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ("svb_" + [Guid]::NewGuid()))
        try {
            $vf = Join-Path $tmp 'VERSION'
            '1.0.0' | Set-Content -LiteralPath $vf -NoNewline
            $cf = Join-Path $tmp 'commits.txt'
            "feat: shiny`n---`nfix: oops" | Set-Content -LiteralPath $cf -NoNewline
            $cl = Join-Path $tmp 'CHANGELOG.md'
            $result = Invoke-VersionBump -VersionFile $vf -CommitsFile $cf -ChangelogFile $cl
            $result | Should -Be '1.1.0'
            (Get-Content -LiteralPath $vf -Raw) | Should -Be '1.1.0'
            (Get-Content -LiteralPath $cl -Raw) | Should -Match '## \[1\.1\.0\]'
        } finally { Remove-Item -Recurse -Force $tmp }
    }
}
