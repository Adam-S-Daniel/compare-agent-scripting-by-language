#Requires -Modules Pester
Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Import the module under test
$ModulePath = Join-Path $PSScriptRoot 'ConfigMigrator.psm1'

# Describe block for INI parsing
Describe 'ConvertFrom-IniContent' {

    BeforeAll {
        Import-Module $ModulePath -Force
    }

    Context 'Basic key=value parsing' {
        It 'Parses a simple key=value pair in the global section' {
            $ini = @'
key1=value1
key2=value2
'@
            $result = ConvertFrom-IniContent -Content $ini
            $result['__global__']['key1'] | Should -Be 'value1'
            $result['__global__']['key2'] | Should -Be 'value2'
        }

        It 'Parses key = value with surrounding spaces' {
            $ini = 'name = Alice'
            $result = ConvertFrom-IniContent -Content $ini
            $result['__global__']['name'] | Should -Be 'Alice'
        }
    }

    Context 'Section parsing' {
        It 'Parses a named section' {
            $ini = @'
[database]
host=localhost
port=5432
'@
            $result = ConvertFrom-IniContent -Content $ini
            $result['database']['host'] | Should -Be 'localhost'
            $result['database']['port'] | Should -Be '5432'
        }

        It 'Parses multiple sections' {
            $ini = @'
[server]
host=0.0.0.0

[database]
name=mydb
'@
            $result = ConvertFrom-IniContent -Content $ini
            $result['server']['host'] | Should -Be '0.0.0.0'
            $result['database']['name'] | Should -Be 'mydb'
        }
    }

    Context 'Comment handling' {
        It 'Ignores lines starting with semicolon' {
            $ini = @'
; this is a comment
key=value
'@
            $result = ConvertFrom-IniContent -Content $ini
            $result['__global__'].ContainsKey('; this is a comment') | Should -BeFalse
            $result['__global__']['key'] | Should -Be 'value'
        }

        It 'Ignores lines starting with hash' {
            $ini = @'
# another comment
key=value
'@
            $result = ConvertFrom-IniContent -Content $ini
            $result['__global__'].ContainsKey('# another comment') | Should -BeFalse
            $result['__global__']['key'] | Should -Be 'value'
        }

        It 'Ignores inline comments after semicolon' {
            $ini = 'key=value ; inline comment'
            $result = ConvertFrom-IniContent -Content $ini
            $result['__global__']['key'] | Should -Be 'value'
        }
    }

    Context 'Multi-line values' {
        It 'Joins lines continued with backslash' {
            $ini = @'
description=line one \
  line two \
  line three
'@
            $result = ConvertFrom-IniContent -Content $ini
            $result['__global__']['description'] | Should -Be 'line one line two line three'
        }
    }

    Context 'Edge cases' {
        It 'Handles empty file' {
            $result = ConvertFrom-IniContent -Content ''
            $result | Should -BeOfType [hashtable]
        }

        It 'Handles blank lines' {
            $ini = @'
key1=a

key2=b
'@
            $result = ConvertFrom-IniContent -Content $ini
            $result['__global__']['key1'] | Should -Be 'a'
            $result['__global__']['key2'] | Should -Be 'b'
        }

        It 'Handles keys with no value (empty string)' {
            $ini = 'emptykey='
            $result = ConvertFrom-IniContent -Content $ini
            $result['__global__']['emptykey'] | Should -Be ''
        }
    }
}

Describe 'Invoke-TypeCoercion' {

    BeforeAll {
        Import-Module $ModulePath -Force
    }

    It 'Coerces "true" to boolean $true' {
        $result = Invoke-TypeCoercion -Value 'true'
        $result | Should -Be $true
        $result | Should -BeOfType [bool]
    }

    It 'Coerces "false" to boolean $false' {
        $result = Invoke-TypeCoercion -Value 'false'
        $result | Should -Be $false
        $result | Should -BeOfType [bool]
    }

    It 'Coerces "True" (mixed case) to boolean $true' {
        $result = Invoke-TypeCoercion -Value 'True'
        $result | Should -Be $true
    }

    It 'Coerces integer strings to [int]' {
        $result = Invoke-TypeCoercion -Value '42'
        $result | Should -Be 42
        $result | Should -BeOfType [int]
    }

    It 'Coerces float strings to [double]' {
        $result = Invoke-TypeCoercion -Value '3.14'
        $result | Should -Be 3.14
        $result | Should -BeOfType [double]
    }

    It 'Leaves plain strings as strings' {
        $result = Invoke-TypeCoercion -Value 'hello'
        $result | Should -Be 'hello'
        $result | Should -BeOfType [string]
    }

    It 'Leaves empty string as string' {
        $result = Invoke-TypeCoercion -Value ''
        $result | Should -Be ''
        $result | Should -BeOfType [string]
    }
}

Describe 'Test-IniSchema' {

    BeforeAll {
        Import-Module $ModulePath -Force
    }

    It 'Passes when all required keys are present' {
        $parsed = @{
            '__global__' = @{ 'app_name' = 'MyApp' }
            'database'   = @{ 'host' = 'localhost'; 'port' = '5432' }
        }
        $schema = @{
            '__global__' = @{ Required = @('app_name') }
            'database'   = @{ Required = @('host', 'port') }
        }
        { Test-IniSchema -ParsedIni $parsed -Schema $schema } | Should -Not -Throw
    }

    It 'Throws when a required key is missing' {
        $parsed = @{
            'database' = @{ 'host' = 'localhost' }
        }
        $schema = @{
            'database' = @{ Required = @('host', 'port') }
        }
        { Test-IniSchema -ParsedIni $parsed -Schema $schema } | Should -Throw -ExpectedMessage '*port*'
    }

    It 'Throws when a required section is missing' {
        $parsed = @{
            '__global__' = @{}
        }
        $schema = @{
            'database' = @{ Required = @('host') }
        }
        { Test-IniSchema -ParsedIni $parsed -Schema $schema } | Should -Throw -ExpectedMessage '*database*'
    }
}

Describe 'ConvertTo-JsonConfig' {

    BeforeAll {
        Import-Module $ModulePath -Force
    }

    It 'Outputs valid JSON with type-coerced values' {
        $parsed = @{
            '__global__' = @{ 'debug' = 'true'; 'version' = '2' }
            'server'     = @{ 'port' = '8080'; 'name' = 'web' }
        }
        $json = ConvertTo-JsonConfig -ParsedIni $parsed
        $obj = $json | ConvertFrom-Json
        $obj.global.debug | Should -Be $true
        $obj.global.version | Should -Be 2
        $obj.server.port | Should -Be 8080
        $obj.server.name | Should -Be 'web'
    }
}

Describe 'ConvertTo-YamlConfig' {

    BeforeAll {
        Import-Module $ModulePath -Force
    }

    It 'Outputs YAML with section headers' {
        $parsed = @{
            '__global__' = @{ 'app' = 'test' }
            'database'   = @{ 'host' = 'localhost' }
        }
        $yaml = ConvertTo-YamlConfig -ParsedIni $parsed
        $yaml | Should -Match 'global:'
        $yaml | Should -Match 'app: test'
        $yaml | Should -Match 'database:'
        $yaml | Should -Match 'host: localhost'
    }

    It 'Renders booleans without quotes' {
        $parsed = @{
            '__global__' = @{ 'enabled' = 'true' }
        }
        $yaml = ConvertTo-YamlConfig -ParsedIni $parsed
        $yaml | Should -Match 'enabled: true'
        # Booleans must NOT be quoted
        $yaml | Should -Not -Match "enabled: 'true'"
    }

    It 'Renders integers without quotes' {
        $parsed = @{
            '__global__' = @{ 'count' = '10' }
        }
        $yaml = ConvertTo-YamlConfig -ParsedIni $parsed
        $yaml | Should -Match 'count: 10'
        $yaml | Should -Not -Match "count: '10'"
    }

    It 'Quotes string values that contain special YAML characters' {
        $parsed = @{
            '__global__' = @{ 'label' = 'hello: world' }
        }
        $yaml = ConvertTo-YamlConfig -ParsedIni $parsed
        # Should be wrapped in quotes because of the colon
        $yaml | Should -Match "label: ['""]hello: world['""]"
    }
}

Describe 'Invoke-ConfigMigration (end-to-end)' {

    BeforeAll {
        Import-Module $ModulePath -Force
        $FixturesDir = Join-Path $PSScriptRoot 'fixtures'
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ('ConfigMigratorTest_' + [System.IO.Path]::GetRandomFileName())
        New-Item -ItemType Directory -Path $script:TempDir | Out-Null
    }

    AfterAll {
        if (Test-Path $script:TempDir) {
            Remove-Item $script:TempDir -Recurse -Force
        }
    }

    It 'Migrates the sample INI fixture to JSON and YAML' {
        $iniPath  = Join-Path $PSScriptRoot 'fixtures/sample.ini'
        $jsonPath = Join-Path $script:TempDir 'output.json'
        $yamlPath = Join-Path $script:TempDir 'output.yaml'

        $schema = @{
            '__global__' = @{ Required = @('app_name', 'version') }
            'database'   = @{ Required = @('host', 'port') }
            'server'     = @{ Required = @('host', 'port') }
        }

        Invoke-ConfigMigration -IniPath $iniPath -JsonOutputPath $jsonPath -YamlOutputPath $yamlPath -Schema $schema

        Test-Path $jsonPath | Should -BeTrue
        Test-Path $yamlPath | Should -BeTrue

        $json = Get-Content $jsonPath -Raw | ConvertFrom-Json
        $json.database.port | Should -Be 5432
        $json.global.app_name | Should -Be 'MyApp'
    }

    It 'Throws a validation error for invalid INI fixture' {
        $iniPath  = Join-Path $PSScriptRoot 'fixtures/invalid.ini'
        $jsonPath = Join-Path $script:TempDir 'invalid_output.json'
        $yamlPath = Join-Path $script:TempDir 'invalid_output.yaml'

        $schema = @{
            'database' = @{ Required = @('host', 'port', 'name') }
        }

        { Invoke-ConfigMigration -IniPath $iniPath -JsonOutputPath $jsonPath -YamlOutputPath $yamlPath -Schema $schema } |
            Should -Throw
    }
}
