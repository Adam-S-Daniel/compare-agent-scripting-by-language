# Pester tests for Aggregate-TestResults.ps1
# Approach: red-green TDD. Each Describe block is one feature in the aggregator.
# Tests use a fresh temp directory per Describe to keep fixtures self-contained.

BeforeAll {
    # Resolve the script under test relative to this test file so the suite is
    # location-independent (works under Invoke-Pester, the workflow, or act).
    $script:ScriptPath = Join-Path $PSScriptRoot '..' 'Aggregate-TestResults.ps1'
    . $script:ScriptPath
}

Describe 'Read-JUnitXml' {
    BeforeAll {
        $script:JUnitDir = Join-Path ([System.IO.Path]::GetTempPath()) ("agg-junit-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:JUnitDir | Out-Null

        $xml = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="suiteA" tests="3" failures="1" skipped="1" time="0.45">
  <testcase classname="suiteA" name="passes_one" time="0.10"/>
  <testcase classname="suiteA" name="fails_one" time="0.20">
    <failure message="boom">stack</failure>
  </testcase>
  <testcase classname="suiteA" name="skipped_one" time="0.15">
    <skipped/>
  </testcase>
</testsuite>
'@
        $script:JUnitFile = Join-Path $script:JUnitDir 'suite.xml'
        Set-Content -Path $script:JUnitFile -Value $xml -Encoding UTF8
    }

    AfterAll {
        Remove-Item -Recurse -Force -Path $script:JUnitDir -ErrorAction SilentlyContinue
    }

    It 'returns one record per testcase' {
        $records = Read-JUnitXml -Path $script:JUnitFile
        $records.Count | Should -Be 3
    }

    It 'maps statuses to passed / failed / skipped' {
        $records = Read-JUnitXml -Path $script:JUnitFile
        ($records | Where-Object { $_.Name -eq 'passes_one' }).Status  | Should -Be 'passed'
        ($records | Where-Object { $_.Name -eq 'fails_one' }).Status   | Should -Be 'failed'
        ($records | Where-Object { $_.Name -eq 'skipped_one' }).Status | Should -Be 'skipped'
    }

    It 'records duration as a [double] in seconds' {
        $records = Read-JUnitXml -Path $script:JUnitFile
        $rec = $records | Where-Object { $_.Name -eq 'passes_one' }
        $rec.Duration | Should -BeOfType [double]
        $rec.Duration | Should -Be 0.10
    }

    It 'tags the record with the source file name' {
        $records = Read-JUnitXml -Path $script:JUnitFile
        $records[0].Source | Should -Be 'suite.xml'
    }

    It 'handles a testsuites root with multiple suites' {
        $multi = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="s1"><testcase classname="s1" name="a" time="0.1"/></testsuite>
  <testsuite name="s2"><testcase classname="s2" name="b" time="0.2"/></testsuite>
</testsuites>
'@
        $f = Join-Path $script:JUnitDir 'multi.xml'
        Set-Content -Path $f -Value $multi -Encoding UTF8
        $records = Read-JUnitXml -Path $f
        $records.Count | Should -Be 2
        ($records | ForEach-Object Suite | Sort-Object) -join ',' | Should -Be 's1,s2'
    }

    It 'throws a meaningful error for malformed XML' {
        $bad = Join-Path $script:JUnitDir 'bad.xml'
        Set-Content -Path $bad -Value '<not-junit><whoops' -Encoding UTF8
        { Read-JUnitXml -Path $bad } | Should -Throw -ExpectedMessage '*JUnit*'
    }
}

Describe 'Read-JsonResults' {
    BeforeAll {
        $script:JsonDir = Join-Path ([System.IO.Path]::GetTempPath()) ("agg-json-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:JsonDir | Out-Null

        $json = @'
{
  "suite": "api",
  "tests": [
    { "name": "login_ok",   "status": "passed",  "duration": 0.05 },
    { "name": "login_fail", "status": "failed",  "duration": 0.07 },
    { "name": "login_todo", "status": "skipped", "duration": 0.00 }
  ]
}
'@
        $script:JsonFile = Join-Path $script:JsonDir 'results.json'
        Set-Content -Path $script:JsonFile -Value $json -Encoding UTF8
    }

    AfterAll {
        Remove-Item -Recurse -Force -Path $script:JsonDir -ErrorAction SilentlyContinue
    }

    It 'returns one record per test' {
        (Read-JsonResults -Path $script:JsonFile).Count | Should -Be 3
    }

    It 'preserves status / duration / suite' {
        $records = Read-JsonResults -Path $script:JsonFile
        $rec = $records | Where-Object { $_.Name -eq 'login_fail' }
        $rec.Status   | Should -Be 'failed'
        $rec.Duration | Should -Be 0.07
        $rec.Suite    | Should -Be 'api'
    }

    It 'tags the record with the source file name' {
        $records = Read-JsonResults -Path $script:JsonFile
        $records[0].Source | Should -Be 'results.json'
    }

    It 'normalizes alternative status spellings (pass/fail/skip)' {
        $alt = @'
{"suite":"alt","tests":[
  {"name":"a","status":"pass","duration":0.01},
  {"name":"b","status":"fail","duration":0.01},
  {"name":"c","status":"skip","duration":0.00}
]}
'@
        $f = Join-Path $script:JsonDir 'alt.json'
        Set-Content -Path $f -Value $alt -Encoding UTF8
        $records = Read-JsonResults -Path $f
        ($records | ForEach-Object Status | Sort-Object) -join ',' | Should -Be 'failed,passed,skipped'
    }
}

Describe 'Read-TestResults (auto-dispatch by extension)' {
    BeforeAll {
        $script:DispatchDir = Join-Path ([System.IO.Path]::GetTempPath()) ("agg-dispatch-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:DispatchDir | Out-Null
        Set-Content -Path (Join-Path $script:DispatchDir 'a.xml') -Encoding UTF8 -Value @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="s"><testcase classname="s" name="t" time="0.1"/></testsuite>
'@
        Set-Content -Path (Join-Path $script:DispatchDir 'b.json') -Encoding UTF8 -Value '{"suite":"s","tests":[{"name":"u","status":"passed","duration":0.2}]}'
    }
    AfterAll { Remove-Item -Recurse -Force -Path $script:DispatchDir -ErrorAction SilentlyContinue }

    It 'reads every .xml and .json file under a directory' {
        $records = Read-TestResults -InputDir $script:DispatchDir
        $records.Count | Should -Be 2
        ($records | ForEach-Object Source | Sort-Object) -join ',' | Should -Be 'a.xml,b.json'
    }

    It 'throws when the directory does not exist' {
        { Read-TestResults -InputDir (Join-Path $script:DispatchDir 'nope') } |
            Should -Throw -ExpectedMessage '*not found*'
    }
}

Describe 'Get-TestSummary' {
    It 'sums passed / failed / skipped / duration across records' {
        $records = @(
            [pscustomobject]@{ Name='a'; Status='passed';  Duration=0.10; Source='1' }
            [pscustomobject]@{ Name='b'; Status='failed';  Duration=0.20; Source='1' }
            [pscustomobject]@{ Name='c'; Status='skipped'; Duration=0.00; Source='1' }
            [pscustomobject]@{ Name='d'; Status='passed';  Duration=0.05; Source='2' }
        )
        $s = Get-TestSummary -Records $records
        $s.Total    | Should -Be 4
        $s.Passed   | Should -Be 2
        $s.Failed   | Should -Be 1
        $s.Skipped  | Should -Be 1
        # Use round to avoid floating-point noise in comparisons.
        [math]::Round($s.Duration, 4) | Should -Be 0.35
    }

    It 'returns zeros for empty input' {
        $s = Get-TestSummary -Records @()
        $s.Total | Should -Be 0
        $s.Passed | Should -Be 0
        $s.Failed | Should -Be 0
        $s.Skipped | Should -Be 0
        $s.Duration | Should -Be 0
    }
}

Describe 'Find-FlakyTests' {
    It 'flags tests that both passed and failed across runs' {
        $records = @(
            [pscustomobject]@{ Name='login'; Suite='auth'; Status='passed'; Source='r1' }
            [pscustomobject]@{ Name='login'; Suite='auth'; Status='failed'; Source='r2' }
            [pscustomobject]@{ Name='stable'; Suite='auth'; Status='passed'; Source='r1' }
            [pscustomobject]@{ Name='stable'; Suite='auth'; Status='passed'; Source='r2' }
        )
        $flaky = Find-FlakyTests -Records $records
        $flaky.Count | Should -Be 1
        $flaky[0].Name | Should -Be 'login'
        # Caller can see which sources disagreed -- aids triage.
        ($flaky[0].PassedIn  | Sort-Object) -join ',' | Should -Be 'r1'
        ($flaky[0].FailedIn  | Sort-Object) -join ',' | Should -Be 'r2'
    }

    It 'uses Suite + Name as identity (same name in different suites is not flaky)' {
        $records = @(
            [pscustomobject]@{ Name='same'; Suite='A'; Status='passed'; Source='r1' }
            [pscustomobject]@{ Name='same'; Suite='B'; Status='failed'; Source='r1' }
        )
        (Find-FlakyTests -Records $records).Count | Should -Be 0
    }

    It 'does not flag skipped-only or single-status tests' {
        $records = @(
            [pscustomobject]@{ Name='only_pass';  Suite='s'; Status='passed';  Source='r1' }
            [pscustomobject]@{ Name='only_pass';  Suite='s'; Status='passed';  Source='r2' }
            [pscustomobject]@{ Name='only_skip';  Suite='s'; Status='skipped'; Source='r1' }
            [pscustomobject]@{ Name='only_skip';  Suite='s'; Status='passed';  Source='r2' }
            [pscustomobject]@{ Name='only_fail';  Suite='s'; Status='failed';  Source='r1' }
        )
        # Skipped + passed alone is NOT flaky -- requires both passed AND failed observed.
        (Find-FlakyTests -Records $records).Count | Should -Be 0
    }
}

Describe 'Format-MarkdownSummary' {
    BeforeAll {
        $script:Records = @(
            [pscustomobject]@{ Name='login'; Suite='auth'; Status='passed'; Duration=0.10; Source='run-1.xml' }
            [pscustomobject]@{ Name='login'; Suite='auth'; Status='failed'; Duration=0.12; Source='run-2.xml' }
            [pscustomobject]@{ Name='stable'; Suite='auth'; Status='passed'; Duration=0.05; Source='run-1.xml' }
            [pscustomobject]@{ Name='stable'; Suite='auth'; Status='passed'; Duration=0.06; Source='run-2.xml' }
            [pscustomobject]@{ Name='broken'; Suite='auth'; Status='failed'; Duration=0.30; Source='run-1.xml' }
        )
        $script:Md = Format-MarkdownSummary -Records $script:Records
    }

    It 'starts with a level-2 heading' {
        $script:Md | Should -Match '(?m)^## Test Results Summary'
    }

    It 'reports total / passed / failed / skipped / duration' {
        $script:Md | Should -Match 'Total\s*\|\s*5'
        $script:Md | Should -Match 'Passed\s*\|\s*3'
        $script:Md | Should -Match 'Failed\s*\|\s*2'
        $script:Md | Should -Match 'Skipped\s*\|\s*0'
        $script:Md | Should -Match 'Duration\s*\|\s*0\.63s'
    }

    It 'lists flaky tests with their suite + name' {
        $script:Md | Should -Match '### Flaky Tests'
        $script:Md | Should -Match 'auth\s*\|\s*login'
    }

    It 'lists failed tests in their own section' {
        $script:Md | Should -Match '### Failed Tests'
        $script:Md | Should -Match 'broken'
    }

    It 'shows a no-flaky-tests note when there are none' {
        $clean = @(
            [pscustomobject]@{ Name='a'; Suite='s'; Status='passed'; Duration=0.1; Source='r1' }
            [pscustomobject]@{ Name='a'; Suite='s'; Status='passed'; Duration=0.1; Source='r2' }
        )
        $md = Format-MarkdownSummary -Records $clean
        $md | Should -Match 'No flaky tests detected'
    }
}

Describe 'Invoke-Aggregator (end-to-end)' {
    BeforeAll {
        $script:E2eDir = Join-Path ([System.IO.Path]::GetTempPath()) ("agg-e2e-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:E2eDir | Out-Null

        # Two matrix-shard fixtures with one flaky test (`login`).
        $shard1 = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="auth" tests="2" failures="0" skipped="0" time="0.20">
  <testcase classname="auth" name="login" time="0.10"/>
  <testcase classname="auth" name="logout" time="0.10"/>
</testsuite>
'@
        $shard2 = @'
{"suite":"auth","tests":[
  {"name":"login","status":"failed","duration":0.12},
  {"name":"logout","status":"passed","duration":0.11}
]}
'@
        Set-Content -Path (Join-Path $script:E2eDir 'shard-1.xml')  -Value $shard1 -Encoding UTF8
        Set-Content -Path (Join-Path $script:E2eDir 'shard-2.json') -Value $shard2 -Encoding UTF8

        $script:OutFile = Join-Path $script:E2eDir 'summary.md'
        Invoke-Aggregator -InputDir $script:E2eDir -OutputPath $script:OutFile | Out-Null
    }

    AfterAll { Remove-Item -Recurse -Force -Path $script:E2eDir -ErrorAction SilentlyContinue }

    It 'writes the markdown summary to OutputPath' {
        Test-Path $script:OutFile | Should -BeTrue
    }

    It 'aggregates totals across XML and JSON shards' {
        $md = Get-Content -Path $script:OutFile -Raw
        $md | Should -Match 'Total\s*\|\s*4'
        $md | Should -Match 'Passed\s*\|\s*3'
        $md | Should -Match 'Failed\s*\|\s*1'
    }

    It 'identifies the flaky test across formats' {
        $md = Get-Content -Path $script:OutFile -Raw
        $md | Should -Match '### Flaky Tests'
        $md | Should -Match 'auth\s*\|\s*login'
    }
}
