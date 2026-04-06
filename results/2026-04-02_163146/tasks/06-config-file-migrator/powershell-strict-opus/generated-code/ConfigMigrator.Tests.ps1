Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Import the module under test
BeforeAll {
    $modulePath = Join-Path $PSScriptRoot 'ConfigMigrator.psm1'
    Import-Module $modulePath -Force
}

# ============================================================================
# TDD ROUND 1: INI Parsing - basic key-value pairs and sections
# ============================================================================
Describe 'ConvertFrom-IniFile' {

    Context 'Basic INI parsing with sections' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'basic.ini'
            $result = ConvertFrom-IniFile -Path $iniPath
        }

        It 'Should return a hashtable' {
            $result | Should -BeOfType [hashtable]
        }

        It 'Should parse section names' {
            $result.ContainsKey('general') | Should -BeTrue
            $result.ContainsKey('database') | Should -BeTrue
            $result.ContainsKey('logging') | Should -BeTrue
        }

        It 'Should parse string values' {
            $result['general']['app_name'] | Should -Be 'MyApp'
            $result['database']['host'] | Should -Be 'localhost'
            $result['database']['name'] | Should -Be 'mydb'
        }

        It 'Should have correct number of sections' {
            $result.Keys.Count | Should -Be 3
        }

        It 'Should have correct number of keys per section' {
            $result['general'].Keys.Count | Should -Be 4
            $result['database'].Keys.Count | Should -Be 5
            $result['logging'].Keys.Count | Should -Be 4
        }
    }

    Context 'Comment handling' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'basic.ini'
            $result = ConvertFrom-IniFile -Path $iniPath
        }

        It 'Should ignore semicolon comments' {
            # Comments should not appear as keys or values
            $result.ContainsKey('; Basic configuration file') | Should -BeFalse
        }

        It 'Should ignore hash comments' {
            $result.ContainsKey('# Another comment style') | Should -BeFalse
        }
    }

    Context 'Multi-line value handling' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'multiline.ini'
            $result = ConvertFrom-IniFile -Path $iniPath
        }

        It 'Should join continuation lines with newlines' {
            $desc = $result['server']['description']
            $desc | Should -BeLike '*long description*'
            $desc | Should -BeLike '*spans multiple lines*'
            $desc | Should -BeLike '*joined together*'
        }

        It 'Should handle multi-line list-like values' {
            $inc = $result['paths']['include']
            $inc | Should -BeLike '*/usr/local/include*'
            $inc | Should -BeLike '*/usr/include*'
            $inc | Should -BeLike '*/opt/include*'
        }

        It 'Should parse normal keys after multi-line values' {
            $result['paths']['data_dir'] | Should -Be '/var/data'
        }
    }

    Context 'Keys without section (global scope)' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'no-section.ini'
            $result = ConvertFrom-IniFile -Path $iniPath
        }

        It 'Should place sectionless keys under _global' {
            $result.ContainsKey('_global') | Should -BeTrue
        }

        It 'Should parse global key values' {
            $result['_global']['app_name'] | Should -Be 'GlobalApp'
        }
    }

    Context 'Empty sections' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'edge-cases.ini'
            $result = ConvertFrom-IniFile -Path $iniPath
        }

        It 'Should include empty sections as empty hashtables' {
            $result.ContainsKey('empty') | Should -BeTrue
            $result['empty'].Keys.Count | Should -Be 0
        }
    }

    Context 'Error handling' {
        It 'Should throw on nonexistent file' {
            { ConvertFrom-IniFile -Path '/nonexistent/file.ini' } | Should -Throw '*does not exist*'
        }
    }
}

# ============================================================================
# TDD ROUND 2: Type Coercion
# ============================================================================
Describe 'ConvertTo-TypedValue' {

    It 'Should coerce integer strings to integers' {
        $val = ConvertTo-TypedValue -Value '42'
        $val | Should -Be 42
        $val | Should -BeOfType [int]
    }

    It 'Should coerce negative integers' {
        $val = ConvertTo-TypedValue -Value '-7'
        $val | Should -Be -7
        $val | Should -BeOfType [int]
    }

    It 'Should coerce float strings to doubles' {
        $val = ConvertTo-TypedValue -Value '3.14'
        $val | Should -Be 3.14
        $val | Should -BeOfType [double]
    }

    It 'Should coerce negative floats' {
        $val = ConvertTo-TypedValue -Value '-2.5'
        $val | Should -Be -2.5
        $val | Should -BeOfType [double]
    }

    It 'Should coerce "true" to boolean $true' {
        $val = ConvertTo-TypedValue -Value 'true'
        $val | Should -BeTrue
        $val | Should -BeOfType [bool]
    }

    It 'Should coerce "false" to boolean $false' {
        $val = ConvertTo-TypedValue -Value 'false'
        $val | Should -BeFalse
        $val | Should -BeOfType [bool]
    }

    It 'Should coerce "yes" to boolean $true' {
        $val = ConvertTo-TypedValue -Value 'yes'
        $val | Should -BeTrue
        $val | Should -BeOfType [bool]
    }

    It 'Should coerce "no" to boolean $false' {
        $val = ConvertTo-TypedValue -Value 'no'
        $val | Should -BeFalse
        $val | Should -BeOfType [bool]
    }

    It 'Should coerce "on" to boolean $true' {
        $val = ConvertTo-TypedValue -Value 'on'
        $val | Should -BeTrue
        $val | Should -BeOfType [bool]
    }

    It 'Should coerce "off" to boolean $false' {
        $val = ConvertTo-TypedValue -Value 'off'
        $val | Should -BeFalse
        $val | Should -BeOfType [bool]
    }

    It 'Should keep plain strings as strings' {
        $val = ConvertTo-TypedValue -Value 'hello world'
        $val | Should -Be 'hello world'
        $val | Should -BeOfType [string]
    }

    It 'Should strip surrounding quotes and keep as string' {
        $val = ConvertTo-TypedValue -Value '"123"'
        $val | Should -Be '123'
        $val | Should -BeOfType [string]
    }

    It 'Should return empty string for empty value' {
        $val = ConvertTo-TypedValue -Value ''
        $val | Should -Be ''
        $val | Should -BeOfType [string]
    }

    It 'Should keep URLs as strings' {
        $val = ConvertTo-TypedValue -Value 'https://example.com:8080/path?query=1&other=2'
        $val | Should -BeOfType [string]
    }
}

# ============================================================================
# TDD ROUND 3: INI parsing with type coercion applied
# ============================================================================
Describe 'ConvertFrom-IniFile with type coercion' {

    Context 'Basic file types' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'basic.ini'
            $result = ConvertFrom-IniFile -Path $iniPath -CoerceTypes
        }

        It 'Should coerce version to number' {
            $result['general']['version'] | Should -Be 2.1
            $result['general']['version'] | Should -BeOfType [double]
        }

        It 'Should coerce debug to boolean' {
            $result['general']['debug'] | Should -BeTrue
            $result['general']['debug'] | Should -BeOfType [bool]
        }

        It 'Should coerce max_retries to integer' {
            $result['general']['max_retries'] | Should -Be 5
            $result['general']['max_retries'] | Should -BeOfType [int]
        }

        It 'Should coerce port to integer' {
            $result['database']['port'] | Should -Be 5432
            $result['database']['port'] | Should -BeOfType [int]
        }

        It 'Should coerce ssl to boolean' {
            $result['database']['ssl'] | Should -BeFalse
            $result['database']['ssl'] | Should -BeOfType [bool]
        }

        It 'Should keep host as string' {
            $result['database']['host'] | Should -Be 'localhost'
            $result['database']['host'] | Should -BeOfType [string]
        }
    }

    Context 'Edge case types' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'edge-cases.ini'
            $result = ConvertFrom-IniFile -Path $iniPath -CoerceTypes
        }

        It 'Should coerce yes/no/on/off booleans' {
            $result['types']['bool_yes'] | Should -BeTrue
            $result['types']['bool_no'] | Should -BeFalse
            $result['types']['bool_on'] | Should -BeTrue
            $result['types']['bool_off'] | Should -BeFalse
        }

        It 'Should keep quoted numbers as strings' {
            $result['types']['number_as_string'] | Should -Be '123'
            $result['types']['number_as_string'] | Should -BeOfType [string]
        }

        It 'Should keep URLs as strings' {
            $result['types']['url_value'] | Should -BeOfType [string]
        }
    }
}

# ============================================================================
# TDD ROUND 4: Schema Validation
# ============================================================================
Describe 'Test-IniSchema' {

    Context 'Valid configuration' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'basic.ini'
            $schemaPath = Join-Path $PSScriptRoot 'fixtures' 'schema-basic.json'
            $config = ConvertFrom-IniFile -Path $iniPath -CoerceTypes
            $result = Test-IniSchema -Config $config -SchemaPath $schemaPath
        }

        It 'Should return a validation result object' {
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should report valid for correct config' {
            $result.IsValid | Should -BeTrue
        }

        It 'Should have no errors' {
            $result.Errors.Count | Should -Be 0
        }
    }

    Context 'Missing required keys' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'missing-required.ini'
            $schemaPath = Join-Path $PSScriptRoot 'fixtures' 'schema-strict.json'
            $config = ConvertFrom-IniFile -Path $iniPath -CoerceTypes
            $result = Test-IniSchema -Config $config -SchemaPath $schemaPath
        }

        It 'Should report invalid' {
            $result.IsValid | Should -BeFalse
        }

        It 'Should report missing required keys' {
            $result.Errors | Should -Not -BeNullOrEmpty
            ($result.Errors | Where-Object { $_ -like '*port*required*' }).Count | Should -BeGreaterThan 0
            ($result.Errors | Where-Object { $_ -like '*name*required*' }).Count | Should -BeGreaterThan 0
        }
    }

    Context 'Type mismatch' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'invalid-types.ini'
            $schemaPath = Join-Path $PSScriptRoot 'fixtures' 'schema-strict.json'
            $config = ConvertFrom-IniFile -Path $iniPath -CoerceTypes
            $result = Test-IniSchema -Config $config -SchemaPath $schemaPath
        }

        It 'Should report invalid for type mismatch' {
            $result.IsValid | Should -BeFalse
        }

        It 'Should report type error for port' {
            ($result.Errors | Where-Object { $_ -like '*port*integer*' }).Count | Should -BeGreaterThan 0
        }
    }

    Context 'Error handling' {
        It 'Should throw on nonexistent schema file' {
            $config = @{}
            { Test-IniSchema -Config $config -SchemaPath '/no/such/schema.json' } | Should -Throw '*does not exist*'
        }
    }
}

# ============================================================================
# TDD ROUND 5: JSON Output
# ============================================================================
Describe 'ConvertTo-JsonConfig' {

    Context 'Basic JSON conversion' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'basic.ini'
            $config = ConvertFrom-IniFile -Path $iniPath -CoerceTypes
            $json = ConvertTo-JsonConfig -Config $config
            # Parse it back to verify round-trip
            $parsed = $json | ConvertFrom-Json
        }

        It 'Should return valid JSON string' {
            $json | Should -Not -BeNullOrEmpty
            { $json | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Should preserve section structure' {
            $parsed.general | Should -Not -BeNullOrEmpty
            $parsed.database | Should -Not -BeNullOrEmpty
            $parsed.logging | Should -Not -BeNullOrEmpty
        }

        It 'Should preserve string values' {
            $parsed.general.app_name | Should -Be 'MyApp'
            $parsed.database.host | Should -Be 'localhost'
        }

        It 'Should preserve numeric values' {
            $parsed.general.version | Should -Be 2.1
            $parsed.database.port | Should -Be 5432
        }

        It 'Should preserve boolean values' {
            $parsed.general.debug | Should -BeTrue
            $parsed.database.ssl | Should -BeFalse
        }
    }

    Context 'File output' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'basic.ini'
            $config = ConvertFrom-IniFile -Path $iniPath -CoerceTypes
            $outPath = Join-Path $TestDrive 'output.json'
            ConvertTo-JsonConfig -Config $config -OutputPath $outPath
        }

        It 'Should write JSON file when OutputPath specified' {
            Test-Path $outPath | Should -BeTrue
        }

        It 'Should write valid JSON to file' {
            $content = Get-Content -Path $outPath -Raw
            { $content | ConvertFrom-Json } | Should -Not -Throw
        }
    }
}

# ============================================================================
# TDD ROUND 6: YAML Output
# ============================================================================
Describe 'ConvertTo-YamlConfig' {

    Context 'Basic YAML conversion' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'basic.ini'
            $config = ConvertFrom-IniFile -Path $iniPath -CoerceTypes
            $yaml = ConvertTo-YamlConfig -Config $config
        }

        It 'Should return a non-empty string' {
            $yaml | Should -Not -BeNullOrEmpty
        }

        It 'Should contain section headers' {
            $yaml | Should -BeLike '*general:*'
            $yaml | Should -BeLike '*database:*'
            $yaml | Should -BeLike '*logging:*'
        }

        It 'Should contain indented key-value pairs' {
            $yaml | Should -BeLike '*app_name: *MyApp*'
            $yaml | Should -BeLike '*host: *localhost*'
        }

        It 'Should format booleans as YAML booleans' {
            $yaml | Should -BeLike '*debug: true*'
            $yaml | Should -BeLike '*ssl: false*'
        }

        It 'Should format numbers without quotes' {
            $yaml | Should -BeLike '*port: 5432*'
            $yaml | Should -BeLike '*version: 2.1*'
        }
    }

    Context 'String quoting in YAML' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'edge-cases.ini'
            $config = ConvertFrom-IniFile -Path $iniPath -CoerceTypes
            $yaml = ConvertTo-YamlConfig -Config $config
        }

        It 'Should quote strings containing special characters' {
            # Values with colons, hashes, etc. should be quoted
            $yaml | Should -BeLike '*url_value:*https://example.com*'
        }
    }

    Context 'File output' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'basic.ini'
            $config = ConvertFrom-IniFile -Path $iniPath -CoerceTypes
            $outPath = Join-Path $TestDrive 'output.yaml'
            ConvertTo-YamlConfig -Config $config -OutputPath $outPath
        }

        It 'Should write YAML file when OutputPath specified' {
            Test-Path $outPath | Should -BeTrue
        }

        It 'Should have content in the file' {
            $content = Get-Content -Path $outPath -Raw
            $content.Length | Should -BeGreaterThan 0
        }
    }
}

# ============================================================================
# TDD ROUND 7: Full Pipeline Integration
# ============================================================================
Describe 'Convert-ConfigFile (full pipeline)' {

    Context 'End-to-end conversion with validation' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'basic.ini'
            $schemaPath = Join-Path $PSScriptRoot 'fixtures' 'schema-basic.json'
            $jsonPath = Join-Path $TestDrive 'result.json'
            $yamlPath = Join-Path $TestDrive 'result.yaml'
            $result = Convert-ConfigFile -IniPath $iniPath -SchemaPath $schemaPath `
                -JsonOutputPath $jsonPath -YamlOutputPath $yamlPath
        }

        It 'Should return a result object' {
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should indicate success' {
            $result.Success | Should -BeTrue
        }

        It 'Should create JSON output file' {
            Test-Path $jsonPath | Should -BeTrue
        }

        It 'Should create YAML output file' {
            Test-Path $yamlPath | Should -BeTrue
        }

        It 'JSON file should have correct structure' {
            $json = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json
            $json.general.app_name | Should -Be 'MyApp'
            $json.database.port | Should -Be 5432
        }
    }

    Context 'Pipeline with validation failure' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'missing-required.ini'
            $schemaPath = Join-Path $PSScriptRoot 'fixtures' 'schema-strict.json'
            $jsonPath = Join-Path $TestDrive 'fail-result.json'
            $yamlPath = Join-Path $TestDrive 'fail-result.yaml'
            $result = Convert-ConfigFile -IniPath $iniPath -SchemaPath $schemaPath `
                -JsonOutputPath $jsonPath -YamlOutputPath $yamlPath
        }

        It 'Should indicate failure' {
            $result.Success | Should -BeFalse
        }

        It 'Should include validation errors' {
            $result.Errors.Count | Should -BeGreaterThan 0
        }

        It 'Should NOT create output files on validation failure' {
            Test-Path $jsonPath | Should -BeFalse
            Test-Path $yamlPath | Should -BeFalse
        }
    }

    Context 'Pipeline without schema (skip validation)' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'basic.ini'
            $jsonPath = Join-Path $TestDrive 'noschema.json'
            $yamlPath = Join-Path $TestDrive 'noschema.yaml'
            $result = Convert-ConfigFile -IniPath $iniPath `
                -JsonOutputPath $jsonPath -YamlOutputPath $yamlPath
        }

        It 'Should succeed without schema' {
            $result.Success | Should -BeTrue
        }

        It 'Should still create output files' {
            Test-Path $jsonPath | Should -BeTrue
            Test-Path $yamlPath | Should -BeTrue
        }
    }
}

# ============================================================================
# TDD ROUND 8: Edge Cases
# ============================================================================
Describe 'Edge Cases' {

    Context 'Special characters in values' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'edge-cases.ini'
            $result = ConvertFrom-IniFile -Path $iniPath
        }

        It 'Should handle equals sign in values' {
            $result['special_chars']['equals_in_value'] | Should -Be 'key=value=extra'
        }

        It 'Should handle backslashes in values' {
            $result['special_chars']['path'] | Should -Be 'C:\Users\test\file.txt'
        }

        It 'Should handle inline hash as part of value' {
            $result['special_chars']['hash_in_value'] | Should -Be 'color #FF0000'
        }

        It 'Should handle semicolons in values when not at start' {
            $result['special_chars']['semicolon_in_value'] | Should -Be 'data; more data'
        }
    }

    Context 'Empty and whitespace values' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'edge-cases.ini'
            $result = ConvertFrom-IniFile -Path $iniPath
        }

        It 'Should handle empty values' {
            $result['types']['empty_val'] | Should -Be ''
        }

        It 'Should preserve spaces in values' {
            $result['types']['spaces_in_value'] | Should -Be 'value with   multiple   spaces'
        }
    }

    Context 'Round-trip fidelity' {
        BeforeAll {
            $iniPath = Join-Path $PSScriptRoot 'fixtures' 'basic.ini'
            $config = ConvertFrom-IniFile -Path $iniPath -CoerceTypes
            $json = ConvertTo-JsonConfig -Config $config
            $parsed = $json | ConvertFrom-Json
        }

        It 'Should preserve all sections through JSON round-trip' {
            @($parsed.PSObject.Properties.Name) | Should -Contain 'general'
            @($parsed.PSObject.Properties.Name) | Should -Contain 'database'
            @($parsed.PSObject.Properties.Name) | Should -Contain 'logging'
        }

        It 'Should preserve all key-value pairs through JSON round-trip' {
            $parsed.general.app_name | Should -Be 'MyApp'
            $parsed.general.version | Should -Be 2.1
            $parsed.general.debug | Should -BeTrue
            $parsed.general.max_retries | Should -Be 5
        }
    }
}
