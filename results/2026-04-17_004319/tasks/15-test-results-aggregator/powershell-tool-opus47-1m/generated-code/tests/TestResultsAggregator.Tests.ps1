# Pester tests for the TestResultsAggregator module.
#
# Built TDD: each Context block was added as a red test, then the module
# function was extended until the test turned green. Kept the tests
# concrete and fixture-driven so the module behavior is pinned down.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'src' 'TestResultsAggregator.psm1'
    Import-Module $script:ModulePath -Force
    $script:FixtureDir = Join-Path $PSScriptRoot 'fixtures'
    if (-not (Test-Path -LiteralPath $script:FixtureDir)) {
        New-Item -ItemType Directory -Path $script:FixtureDir -Force | Out-Null
    }
}

Describe 'ConvertFrom-JUnitXml' {
    BeforeAll {
        $script:SimpleXmlPath = Join-Path $script:FixtureDir 'simple.xml'
        @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="Unit" tests="3" failures="1" skipped="1" time="0.650">
    <testcase classname="Unit.Math" name="Add" time="0.100"/>
    <testcase classname="Unit.Math" name="Divide" time="0.200">
      <failure message="expected 2 got 0" type="AssertionError">stacktrace</failure>
    </testcase>
    <testcase classname="Unit.Math" name="Square" time="0.350">
      <skipped/>
    </testcase>
  </testsuite>
</testsuites>
'@ | Set-Content -LiteralPath $script:SimpleXmlPath -Encoding utf8
    }

    It 'parses passed, failed, and skipped counts from a JUnit XML file' {
        $rs = ConvertFrom-JUnitXml -Path $script:SimpleXmlPath
        $rs.Total   | Should -Be 3
        $rs.Passed  | Should -Be 1
        $rs.Failed  | Should -Be 1
        $rs.Skipped | Should -Be 1
    }

    It 'sums durations of all test cases' {
        $rs = ConvertFrom-JUnitXml -Path $script:SimpleXmlPath
        # 0.1 + 0.2 + 0.35 = 0.65, allow floating-point rounding.
        [math]::Abs($rs.Duration - 0.65) | Should -BeLessThan 0.001
    }

    It 'emits fully qualified test names combining classname and name' {
        $rs = ConvertFrom-JUnitXml -Path $script:SimpleXmlPath
        $names = @($rs.Tests | ForEach-Object { $_.Name })
        $names | Should -Contain 'Unit.Math.Add'
        $names | Should -Contain 'Unit.Math.Divide'
        $names | Should -Contain 'Unit.Math.Square'
    }

    It 'captures the failure message on failed tests' {
        $rs = ConvertFrom-JUnitXml -Path $script:SimpleXmlPath
        $fail = $rs.Tests | Where-Object { $_.Status -eq 'failed' } | Select-Object -First 1
        $fail.Message | Should -Match 'expected 2 got 0'
    }

    It 'throws a meaningful error for a missing file' {
        { ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'does-not-exist.xml') } |
            Should -Throw -ErrorId '*' -ExpectedMessage '*not found*'
    }

    It 'throws on malformed XML' {
        $bad = Join-Path $script:FixtureDir 'bad.xml'
        'not xml at all <<<' | Set-Content -LiteralPath $bad -Encoding utf8
        { ConvertFrom-JUnitXml -Path $bad } | Should -Throw -ExpectedMessage '*XML*'
    }
}

Describe 'ConvertFrom-TestJson' {
    BeforeAll {
        $script:SimpleJsonPath = Join-Path $script:FixtureDir 'simple.json'
        @'
{
  "duration": 2.5,
  "tests": [
    {"name": "Net.Connect", "status": "passed", "duration": 0.5},
    {"name": "Net.Retry",   "status": "failed", "duration": 1.0, "message": "timeout"},
    {"name": "Net.Close",   "status": "skipped","duration": 0.0}
  ]
}
'@ | Set-Content -LiteralPath $script:SimpleJsonPath -Encoding utf8
    }

    It 'parses passed, failed, and skipped counts from JSON' {
        $rs = ConvertFrom-TestJson -Path $script:SimpleJsonPath
        $rs.Total   | Should -Be 3
        $rs.Passed  | Should -Be 1
        $rs.Failed  | Should -Be 1
        $rs.Skipped | Should -Be 1
    }

    It 'uses the document-level duration when present' {
        $rs = ConvertFrom-TestJson -Path $script:SimpleJsonPath
        $rs.Duration | Should -Be 2.5
    }

    It 'rejects invalid status values with a helpful error' {
        $bad = Join-Path $script:FixtureDir 'bad-status.json'
        '{ "tests": [ { "name": "x", "status": "nope" } ] }' |
            Set-Content -LiteralPath $bad -Encoding utf8
        { ConvertFrom-TestJson -Path $bad } |
            Should -Throw -ExpectedMessage '*status*'
    }

    It 'throws when the tests array is missing' {
        $bad = Join-Path $script:FixtureDir 'no-tests.json'
        '{ "duration": 1.0 }' | Set-Content -LiteralPath $bad -Encoding utf8
        { ConvertFrom-TestJson -Path $bad } |
            Should -Throw -ExpectedMessage "*'tests'*"
    }
}

Describe 'Import-TestResults' {
    BeforeAll {
        $script:MixedDir = Join-Path $script:FixtureDir 'mixed'
        New-Item -ItemType Directory -Path $script:MixedDir -Force | Out-Null
        @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="S" tests="1" failures="0" time="0.1">
  <testcase classname="S" name="only" time="0.1"/>
</testsuite>
'@ | Set-Content -LiteralPath (Join-Path $script:MixedDir 'one.xml') -Encoding utf8
        @'
{ "duration": 0.2, "tests": [ { "name": "other", "status": "passed", "duration": 0.2 } ] }
'@ | Set-Content -LiteralPath (Join-Path $script:MixedDir 'two.json') -Encoding utf8
    }

    It 'discovers both XML and JSON files in a directory' {
        $sets = Import-TestResults -Path $script:MixedDir
        @($sets).Count | Should -Be 2
        ($sets | ForEach-Object Format | Sort-Object) -join ',' | Should -Be 'json,junit-xml'
    }

    It 'supports a single file path as input' {
        $sets = Import-TestResults -Path (Join-Path $script:MixedDir 'one.xml')
        @($sets).Count | Should -Be 1
        @($sets)[0].Format | Should -Be 'junit-xml'
    }

    It 'throws when a non-existent path is given' {
        { Import-TestResults -Path (Join-Path $script:FixtureDir 'nope-nope') } |
            Should -Throw -ExpectedMessage '*not found*'
    }
}

Describe 'Get-AggregatedResults' {
    It 'sums totals across multiple result sets' {
        $a = ConvertFrom-JUnitXml -Path $script:SimpleXmlPath   # 1 pass, 1 fail, 1 skip
        $b = ConvertFrom-TestJson  -Path $script:SimpleJsonPath  # 1 pass, 1 fail, 1 skip
        $agg = Get-AggregatedResults -ResultSets @($a, $b)
        $agg.Files      | Should -Be 2
        $agg.TotalTests | Should -Be 6
        $agg.Passed     | Should -Be 2
        $agg.Failed     | Should -Be 2
        $agg.Skipped    | Should -Be 2
        # 0.65 (xml) + 2.5 (json, explicit) = 3.15
        [math]::Abs($agg.Duration - 3.15) | Should -BeLessThan 0.01
    }
}

Describe 'Get-FlakyTest' {
    It 'returns tests that both passed and failed across runs' {
        $xmlPath  = Join-Path $script:FixtureDir 'flaky-a.xml'
        $jsonPath = Join-Path $script:FixtureDir 'flaky-b.json'
        @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="F" tests="2" failures="0" time="0.2">
  <testcase classname="F" name="Flaky"  time="0.1"/>
  <testcase classname="F" name="Stable" time="0.1"/>
</testsuite>
'@ | Set-Content -LiteralPath $xmlPath -Encoding utf8
        @'
{ "duration": 0.2, "tests": [
  { "name": "F.Flaky",  "status": "failed", "duration": 0.1, "message": "x" },
  { "name": "F.Stable", "status": "passed", "duration": 0.1 }
]}
'@ | Set-Content -LiteralPath $jsonPath -Encoding utf8
        $a = ConvertFrom-JUnitXml -Path $xmlPath
        $b = ConvertFrom-TestJson  -Path $jsonPath
        $flaky = @(Get-FlakyTest -ResultSets @($a, $b))
        $flaky.Count | Should -Be 1
        $flaky[0].Name   | Should -Be 'F.Flaky'
        $flaky[0].Passed | Should -Be 1
        $flaky[0].Failed | Should -Be 1
    }

    It 'returns an empty array when no flakes exist' {
        $xml = Join-Path $script:FixtureDir 'stable.xml'
        @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="S" tests="1" failures="0" time="0.1">
  <testcase classname="S" name="stable" time="0.1"/>
</testsuite>
'@ | Set-Content -LiteralPath $xml -Encoding utf8
        $a = ConvertFrom-JUnitXml -Path $xml
        $b = ConvertFrom-JUnitXml -Path $xml
        $flaky = @(Get-FlakyTest -ResultSets @($a, $b))
        $flaky.Count | Should -Be 0
    }
}

Describe 'New-SummaryMarkdown' {
    It 'produces a markdown document with totals and flaky sections' {
        $a = ConvertFrom-JUnitXml -Path $script:SimpleXmlPath
        $agg = Get-AggregatedResults -ResultSets @($a)
        $md = New-SummaryMarkdown -Aggregated $agg -FlakyTests @()
        $md | Should -Match '# Test Results Summary'
        $md | Should -Match '## Totals'
        $md | Should -Match '## Flaky Tests'
        $md | Should -Match 'No flaky tests detected\.'
    }

    It 'renders the flaky table when flaky tests are supplied' {
        $a = ConvertFrom-JUnitXml -Path $script:SimpleXmlPath
        $agg = Get-AggregatedResults -ResultSets @($a)
        $flaky = @([pscustomobject]@{ Name='X.Y'; Runs=2; Passed=1; Failed=1 })
        $md = New-SummaryMarkdown -Aggregated $agg -FlakyTests $flaky
        $md | Should -Match 'X\.Y'
        $md | Should -Match '\| Test \| Runs \|'
    }

    It 'shows PASS when there are no failures' {
        $a = ConvertFrom-JUnitXml -Path $script:SimpleXmlPath  # has a failure
        $synthetic = [pscustomobject]@{
            Files=1; TotalTests=2; Passed=2; Failed=0; Skipped=0; Duration=0.1
            ResultSets = @($a)
        }
        $md = New-SummaryMarkdown -Aggregated $synthetic -FlakyTests @()
        $md | Should -Match 'PASS'
    }
}
