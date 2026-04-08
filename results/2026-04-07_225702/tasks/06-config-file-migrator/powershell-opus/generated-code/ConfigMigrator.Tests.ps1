# Pester tests for the INI Config Migrator
# Following red/green TDD: these tests are written FIRST, before implementation.

BeforeAll {
    . "$PSScriptRoot/ConfigMigrator.ps1"
    $FixturesPath = "$PSScriptRoot/fixtures"
}

Describe 'ConvertFrom-Ini' {
    # -- RED: Parse a basic INI file into a hashtable --

    It 'parses sections and key-value pairs' {
        $result = ConvertFrom-Ini -Path "$FixturesPath/basic.ini"
        $result | Should -Not -BeNullOrEmpty
        $result.server | Should -Not -BeNullOrEmpty
        $result.server.host | Should -Be 'localhost'
        $result.database.name | Should -Be 'myapp'
    }

    It 'ignores semicolon comments' {
        $result = ConvertFrom-Ini -Path "$FixturesPath/basic.ini"
        # Should only have 'server' and 'database' sections, no comment keys
        $result.Keys.Count | Should -Be 2
    }

    It 'ignores hash comments' {
        $result = ConvertFrom-Ini -Path "$FixturesPath/complex.ini"
        # Hash-style comments should be stripped
        $result.Contains('#') | Should -BeFalse
    }

    It 'handles empty sections' {
        $result = ConvertFrom-Ini -Path "$FixturesPath/complex.ini"
        $result.empty_section | Should -Not -BeNullOrEmpty
        $result.empty_section.Keys.Count | Should -Be 0
    }

    It 'handles empty values' {
        $result = ConvertFrom-Ini -Path "$FixturesPath/complex.ini"
        $result.special_values.empty_value | Should -Be ''
    }

    It 'handles multi-line values with backslash continuation' {
        $result = ConvertFrom-Ini -Path "$FixturesPath/complex.ini"
        $result.server.description | Should -BeLike 'This is a long*multiple lines'
    }

    It 'throws on non-existent file' {
        { ConvertFrom-Ini -Path "$FixturesPath/nonexistent.ini" } | Should -Throw '*does not exist*'
    }
}

Describe 'ConvertTo-TypedValue' {
    # -- RED: Type coercion from raw string values --

    It 'coerces "true" to boolean $true' {
        ConvertTo-TypedValue 'true' | Should -BeTrue
        ConvertTo-TypedValue 'True' | Should -BeTrue
        ConvertTo-TypedValue 'TRUE' | Should -BeTrue
    }

    It 'coerces "false" to boolean $false' {
        ConvertTo-TypedValue 'false' | Should -BeFalse
    }

    It 'coerces integer strings to [int]' {
        $val = ConvertTo-TypedValue '42'
        $val | Should -Be 42
        $val | Should -BeOfType [int]
    }

    It 'coerces negative integers' {
        $val = ConvertTo-TypedValue '-42'
        $val | Should -Be -42
        $val | Should -BeOfType [int]
    }

    It 'coerces float strings to [double]' {
        $val = ConvertTo-TypedValue '3.14'
        $val | Should -Be 3.14
        $val | Should -BeOfType [double]
    }

    It 'preserves quoted strings without coercion' {
        $val = ConvertTo-TypedValue '"12345"'
        $val | Should -Be '12345'
        $val | Should -BeOfType [string]
    }

    It 'returns empty string for empty input' {
        $val = ConvertTo-TypedValue ''
        $val | Should -Be ''
    }

    It 'leaves non-numeric strings as strings' {
        $val = ConvertTo-TypedValue 'hello'
        $val | Should -Be 'hello'
        $val | Should -BeOfType [string]
    }
}

Describe 'Test-IniSchema' {
    # -- RED: Schema validation --

    It 'passes validation for a conforming config' {
        $config = ConvertFrom-Ini -Path "$FixturesPath/basic.ini"
        $schema = Get-Content "$FixturesPath/schema-basic.json" -Raw | ConvertFrom-Json
        $result = Test-IniSchema -Config $config -Schema $schema
        $result.Valid | Should -BeTrue
        $result.Errors.Count | Should -Be 0
    }

    It 'reports missing required keys' {
        $config = ConvertFrom-Ini -Path "$FixturesPath/basic.ini"
        $schema = Get-Content "$FixturesPath/schema-strict.json" -Raw | ConvertFrom-Json
        # schema-strict requires 'protocol' in [server] which basic.ini lacks
        $result = Test-IniSchema -Config $config -Schema $schema
        $result.Valid | Should -BeFalse
        $result.Errors | Should -Contain "Missing required key 'protocol' in section 'server'"
    }

    It 'reports type mismatches' {
        # Build a config where port is a non-numeric string
        $config = @{
            server = [ordered]@{
                host = 'localhost'
                port = 'not_a_number'
            }
        }
        $schema = Get-Content "$FixturesPath/schema-strict.json" -Raw | ConvertFrom-Json
        $result = Test-IniSchema -Config $config -Schema $schema
        $result.Valid | Should -BeFalse
        $result.Errors | Should -Contain "Key 'port' in section 'server' should be type 'integer' but got 'not_a_number'"
    }

    It 'reports missing required sections' {
        $config = @{ server = [ordered]@{ host = 'x'; port = 80; protocol = 'http' } }
        # schema-basic expects both server and database sections
        $schema = Get-Content "$FixturesPath/schema-basic.json" -Raw | ConvertFrom-Json
        $result = Test-IniSchema -Config $config -Schema $schema
        $result.Valid | Should -BeFalse
        $result.Errors | Where-Object { $_ -like "*section 'database'*" } | Should -Not -BeNullOrEmpty
    }
}

Describe 'ConvertTo-JsonConfig' {
    # -- RED: JSON output --

    It 'converts parsed INI to valid JSON string' {
        $config = ConvertFrom-Ini -Path "$FixturesPath/basic.ini"
        $json = ConvertTo-JsonConfig -Config $config
        $json | Should -Not -BeNullOrEmpty
        # Should be parseable JSON
        { $json | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'preserves typed values in JSON output' {
        $config = ConvertFrom-Ini -Path "$FixturesPath/basic.ini"
        $json = ConvertTo-JsonConfig -Config $config
        $parsed = $json | ConvertFrom-Json
        $parsed.server.port | Should -Be 8080
        $parsed.server.debug | Should -BeTrue
        $parsed.database.ssl | Should -BeFalse
    }
}

Describe 'ConvertTo-YamlConfig' {
    # -- RED: YAML output --

    It 'converts parsed INI to valid YAML string' {
        $config = ConvertFrom-Ini -Path "$FixturesPath/basic.ini"
        $yaml = ConvertTo-YamlConfig -Config $config
        $yaml | Should -Not -BeNullOrEmpty
    }

    It 'contains section headers as YAML keys' {
        $config = ConvertFrom-Ini -Path "$FixturesPath/basic.ini"
        $yaml = ConvertTo-YamlConfig -Config $config
        $yaml | Should -BeLike '*server:*'
        $yaml | Should -BeLike '*database:*'
    }

    It 'formats booleans as YAML booleans' {
        $config = ConvertFrom-Ini -Path "$FixturesPath/basic.ini"
        $yaml = ConvertTo-YamlConfig -Config $config
        $yaml | Should -Match 'debug: true'
        $yaml | Should -Match 'ssl: false'
    }

    It 'formats integers without quotes' {
        $config = ConvertFrom-Ini -Path "$FixturesPath/basic.ini"
        $yaml = ConvertTo-YamlConfig -Config $config
        $yaml | Should -Match 'port: 8080'
    }

    It 'quotes string values that need quoting' {
        $config = @{
            test = [ordered]@{
                path = '/usr/local/bin'
            }
        }
        $yaml = ConvertTo-YamlConfig -Config $config
        $yaml | Should -BeLike '*path:*/usr/local/bin*'
    }
}

Describe 'Invoke-ConfigMigrator (integration)' {
    # -- RED: End-to-end integration test --

    BeforeAll {
        $OutDir = Join-Path $TestDrive 'output'
        New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    }

    It 'produces JSON and YAML files from an INI input' {
        $jsonOut = Join-Path $OutDir 'basic.json'
        $yamlOut = Join-Path $OutDir 'basic.yaml'
        Invoke-ConfigMigrator -IniPath "$FixturesPath/basic.ini" -JsonOutPath $jsonOut -YamlOutPath $yamlOut
        Test-Path $jsonOut | Should -BeTrue
        Test-Path $yamlOut | Should -BeTrue
    }

    It 'produces valid JSON output file' {
        $jsonOut = Join-Path $OutDir 'basic2.json'
        $yamlOut = Join-Path $OutDir 'basic2.yaml'
        Invoke-ConfigMigrator -IniPath "$FixturesPath/basic.ini" -JsonOutPath $jsonOut -YamlOutPath $yamlOut
        $content = Get-Content $jsonOut -Raw
        { $content | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'validates against schema and returns results' {
        $jsonOut = Join-Path $OutDir 'validated.json'
        $yamlOut = Join-Path $OutDir 'validated.yaml'
        $result = Invoke-ConfigMigrator -IniPath "$FixturesPath/basic.ini" `
            -JsonOutPath $jsonOut -YamlOutPath $yamlOut `
            -SchemaPath "$FixturesPath/schema-basic.json"
        $result.ValidationResult.Valid | Should -BeTrue
    }

    It 'reports validation failures with schema mismatch' {
        $jsonOut = Join-Path $OutDir 'strict.json'
        $yamlOut = Join-Path $OutDir 'strict.yaml'
        $result = Invoke-ConfigMigrator -IniPath "$FixturesPath/basic.ini" `
            -JsonOutPath $jsonOut -YamlOutPath $yamlOut `
            -SchemaPath "$FixturesPath/schema-strict.json"
        $result.ValidationResult.Valid | Should -BeFalse
    }

    It 'handles complex INI with all edge cases' {
        $jsonOut = Join-Path $OutDir 'complex.json'
        $yamlOut = Join-Path $OutDir 'complex.yaml'
        { Invoke-ConfigMigrator -IniPath "$FixturesPath/complex.ini" -JsonOutPath $jsonOut -YamlOutPath $yamlOut } | Should -Not -Throw
        $json = Get-Content $jsonOut -Raw | ConvertFrom-Json
        $json.server.port | Should -Be 443
        $json.server.ssl | Should -BeTrue
        $json.special_values.float_val | Should -Be 3.14
        $json.special_values.negative | Should -Be -42
    }
}
