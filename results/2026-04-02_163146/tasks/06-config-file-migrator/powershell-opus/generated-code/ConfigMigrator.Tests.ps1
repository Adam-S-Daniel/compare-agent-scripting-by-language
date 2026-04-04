# ConfigMigrator.Tests.ps1
# TDD tests for INI config file migrator
# Tests are organized by feature area, written RED first then made GREEN

BeforeAll {
    . "$PSScriptRoot/ConfigMigrator.ps1"
}

# ============================================================================
# RED/GREEN CYCLE 1: Basic INI Parsing
# ============================================================================
Describe 'ConvertFrom-Ini - Basic Parsing' {
    Context 'When parsing a simple INI file' {
        BeforeAll {
            $iniContent = @"
[server]
host = localhost
port = 8080
"@
            $result = ConvertFrom-Ini -Content $iniContent
        }

        It 'Should return an ordered dictionary' {
            $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
        }

        It 'Should parse section names' {
            $result.Contains('server') | Should -BeTrue
        }

        It 'Should parse key-value pairs within sections' {
            $result['server']['host'] | Should -Be 'localhost'
            $result['server']['port'] | Should -Be 8080
        }
    }

    Context 'When parsing multiple sections' {
        BeforeAll {
            $iniContent = @"
[server]
host = localhost

[database]
host = db.example.com
"@
            $result = ConvertFrom-Ini -Content $iniContent
        }

        It 'Should parse all sections' {
            $result.Keys.Count | Should -Be 2
            $result.Contains('server') | Should -BeTrue
            $result.Contains('database') | Should -BeTrue
        }

        It 'Should keep values in correct sections' {
            $result['server']['host'] | Should -Be 'localhost'
            $result['database']['host'] | Should -Be 'db.example.com'
        }
    }

    Context 'When parsing from a file path' {
        BeforeAll {
            $result = ConvertFrom-Ini -Path "$PSScriptRoot/fixtures/basic.ini"
        }

        It 'Should parse the file successfully' {
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should have both sections' {
            $result.Contains('server') | Should -BeTrue
            $result.Contains('database') | Should -BeTrue
        }

        It 'Should parse all key-value pairs' {
            $result['server']['host'] | Should -Be 'localhost'
            $result['database']['max_connections'] | Should -Be 100
        }
    }
}

# ============================================================================
# RED/GREEN CYCLE 2: Comments and Blank Lines
# ============================================================================
Describe 'ConvertFrom-Ini - Comments and Blank Lines' {
    Context 'When INI contains comments' {
        BeforeAll {
            $iniContent = @"
; This is a semicolon comment
# This is a hash comment
[section]
; inline section comment
key1 = value1
# another comment
key2 = value2
"@
            $result = ConvertFrom-Ini -Content $iniContent
        }

        It 'Should ignore semicolon comments' {
            $result.Keys.Count | Should -Be 1
        }

        It 'Should ignore hash comments' {
            $result['section'].Keys.Count | Should -Be 2
        }

        It 'Should parse values correctly despite comments' {
            $result['section']['key1'] | Should -Be 'value1'
            $result['section']['key2'] | Should -Be 'value2'
        }
    }

    Context 'When INI contains blank lines' {
        BeforeAll {
            $iniContent = @"

[section]

key1 = value1

key2 = value2

"@
            $result = ConvertFrom-Ini -Content $iniContent
        }

        It 'Should handle blank lines gracefully' {
            $result['section']['key1'] | Should -Be 'value1'
            $result['section']['key2'] | Should -Be 'value2'
        }
    }
}

# ============================================================================
# RED/GREEN CYCLE 3: Multi-line Values
# ============================================================================
Describe 'ConvertFrom-Ini - Multi-line Values' {
    Context 'When values use backslash line continuation' {
        BeforeAll {
            $iniContent = @"
[section]
description = This is a long \
    multi-line value that \
    spans three lines
other = normal
"@
            $result = ConvertFrom-Ini -Content $iniContent
        }

        It 'Should join multi-line values' {
            $result['section']['description'] | Should -Be 'This is a long multi-line value that spans three lines'
        }

        It 'Should not affect other values' {
            $result['section']['other'] | Should -Be 'normal'
        }
    }
}

# ============================================================================
# RED/GREEN CYCLE 4: Type Coercion
# ============================================================================
Describe 'ConvertFrom-Ini - Type Coercion' {
    Context 'When values are integers' {
        BeforeAll {
            $iniContent = @"
[section]
positive = 42
negative = -7
zero = 0
"@
            $result = ConvertFrom-Ini -Content $iniContent
        }

        It 'Should coerce positive integers' {
            $result['section']['positive'] | Should -Be 42
            $result['section']['positive'] | Should -BeOfType [int64]
        }

        It 'Should coerce negative integers' {
            $result['section']['negative'] | Should -Be -7
            $result['section']['negative'] | Should -BeOfType [int64]
        }

        It 'Should coerce zero' {
            $result['section']['zero'] | Should -Be 0
            $result['section']['zero'] | Should -BeOfType [int64]
        }
    }

    Context 'When values are floats' {
        BeforeAll {
            $iniContent = @"
[section]
pi = 3.14159
negative_float = -2.5
timeout = 30.5
scientific = 1.5e10
"@
            $result = ConvertFrom-Ini -Content $iniContent
        }

        It 'Should coerce float values' {
            $result['section']['pi'] | Should -Be 3.14159
            $result['section']['pi'] | Should -BeOfType [double]
        }

        It 'Should coerce negative floats' {
            $result['section']['negative_float'] | Should -Be -2.5
        }

        It 'Should coerce scientific notation' {
            $result['section']['scientific'] | Should -Be 1.5e10
            $result['section']['scientific'] | Should -BeOfType [double]
        }
    }

    Context 'When values are booleans' {
        BeforeAll {
            $iniContent = @"
[section]
bool_true = true
bool_false = false
bool_yes = yes
bool_no = no
bool_on = on
bool_off = off
"@
            $result = ConvertFrom-Ini -Content $iniContent
        }

        It 'Should coerce true/false' {
            $result['section']['bool_true'] | Should -BeTrue
            $result['section']['bool_false'] | Should -BeFalse
        }

        It 'Should coerce yes/no' {
            $result['section']['bool_yes'] | Should -BeTrue
            $result['section']['bool_no'] | Should -BeFalse
        }

        It 'Should coerce on/off' {
            $result['section']['bool_on'] | Should -BeTrue
            $result['section']['bool_off'] | Should -BeFalse
        }
    }

    Context 'When values are null-like' {
        BeforeAll {
            $iniContent = @"
[section]
null_val = null
none_val = none
empty_val =
"@
            $result = ConvertFrom-Ini -Content $iniContent
        }

        It 'Should coerce null to $null' {
            $result['section']['null_val'] | Should -BeNullOrEmpty
        }

        It 'Should coerce none to $null' {
            $result['section']['none_val'] | Should -BeNullOrEmpty
        }

        It 'Should treat empty values as empty string' {
            $result['section']['empty_val'] | Should -Be ''
        }
    }

    Context 'When values are quoted strings' {
        BeforeAll {
            $iniContent = @"
[section]
quoted = "hello world"
number_as_string = "42"
bool_as_string = "true"
"@
            $result = ConvertFrom-Ini -Content $iniContent
        }

        It 'Should strip quotes and keep as string' {
            $result['section']['quoted'] | Should -Be 'hello world'
            $result['section']['quoted'] | Should -BeOfType [string]
        }

        It 'Should not coerce quoted numbers' {
            $result['section']['number_as_string'] | Should -Be '42'
            $result['section']['number_as_string'] | Should -BeOfType [string]
        }

        It 'Should not coerce quoted booleans' {
            $result['section']['bool_as_string'] | Should -Be 'true'
            $result['section']['bool_as_string'] | Should -BeOfType [string]
        }
    }
}

# ============================================================================
# RED/GREEN CYCLE 5: Empty Sections
# ============================================================================
Describe 'ConvertFrom-Ini - Empty Sections' {
    Context 'When a section has no keys' {
        BeforeAll {
            $iniContent = @"
[empty]

[notempty]
key = value
"@
            $result = ConvertFrom-Ini -Content $iniContent
        }

        It 'Should create the empty section' {
            $result.Contains('empty') | Should -BeTrue
        }

        It 'Should have no keys in empty section' {
            $result['empty'].Keys.Count | Should -Be 0
        }

        It 'Should still parse subsequent sections' {
            $result['notempty']['key'] | Should -Be 'value'
        }
    }
}

# ============================================================================
# RED/GREEN CYCLE 6: Schema Validation
# ============================================================================
Describe 'Test-IniSchema - Schema Validation' {
    Context 'When config matches schema' {
        BeforeAll {
            $config = ConvertFrom-Ini -Path "$PSScriptRoot/fixtures/basic.ini"
            $schema = Get-Content "$PSScriptRoot/fixtures/schema-basic.json" -Raw | ConvertFrom-Json
            $result = Test-IniSchema -Config $config -Schema $schema
        }

        It 'Should return a validation result object' {
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should report valid' {
            $result.IsValid | Should -BeTrue
        }

        It 'Should have no errors' {
            $result.Errors.Count | Should -Be 0
        }
    }

    Context 'When required keys are missing' {
        BeforeAll {
            $config = ConvertFrom-Ini -Path "$PSScriptRoot/fixtures/basic.ini"
            $schema = Get-Content "$PSScriptRoot/fixtures/schema-strict.json" -Raw | ConvertFrom-Json
            $result = Test-IniSchema -Config $config -Schema $schema
        }

        It 'Should report invalid' {
            $result.IsValid | Should -BeFalse
        }

        It 'Should list missing required keys in errors' {
            $result.Errors | Should -Contain "Section 'server': missing required key 'missing_key'"
        }
    }

    Context 'When value types do not match schema' {
        BeforeAll {
            $config = ConvertFrom-Ini -Path "$PSScriptRoot/fixtures/type-mismatch.ini"
            $schemaJson = @'
{
    "server": {
        "required": ["host", "port"],
        "properties": {
            "host": { "type": "string" },
            "port": { "type": "integer" }
        }
    }
}
'@
            $schema = $schemaJson | ConvertFrom-Json
            $result = Test-IniSchema -Config $config -Schema $schema
        }

        It 'Should report invalid for type mismatch' {
            $result.IsValid | Should -BeFalse
        }

        It 'Should describe the type error' {
            $result.Errors | Where-Object { $_ -match "type" -and $_ -match "port" } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'When section is missing entirely' {
        BeforeAll {
            $iniContent = @"
[other]
key = value
"@
            $config = ConvertFrom-Ini -Content $iniContent
            $schemaJson = @'
{
    "server": {
        "required": ["host"],
        "properties": {
            "host": { "type": "string" }
        }
    }
}
'@
            $schema = $schemaJson | ConvertFrom-Json
            $result = Test-IniSchema -Config $config -Schema $schema
        }

        It 'Should report invalid for missing section' {
            $result.IsValid | Should -BeFalse
        }

        It 'Should describe the missing section' {
            $result.Errors | Where-Object { $_ -match "section.*'server'" } | Should -Not -BeNullOrEmpty
        }
    }
}

# ============================================================================
# RED/GREEN CYCLE 7: JSON Output
# ============================================================================
Describe 'ConvertTo-JsonConfig - JSON Output' {
    Context 'When converting parsed config to JSON' {
        BeforeAll {
            $config = ConvertFrom-Ini -Path "$PSScriptRoot/fixtures/basic.ini"
            $json = ConvertTo-JsonConfig -Config $config
            $parsed = $json | ConvertFrom-Json
        }

        It 'Should return valid JSON' {
            { $json | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Should preserve section structure' {
            $parsed.server | Should -Not -BeNullOrEmpty
            $parsed.database | Should -Not -BeNullOrEmpty
        }

        It 'Should preserve string values' {
            $parsed.server.host | Should -Be 'localhost'
            $parsed.database.name | Should -Be 'myapp'
        }

        It 'Should preserve integer values' {
            $parsed.server.port | Should -Be 8080
            $parsed.database.max_connections | Should -Be 100
        }

        It 'Should preserve boolean values' {
            $parsed.server.debug | Should -BeTrue
            $parsed.database.ssl | Should -BeFalse
        }
    }

    Context 'When converting config with null values' {
        BeforeAll {
            $iniContent = @"
[section]
key = null
name = hello
"@
            $config = ConvertFrom-Ini -Content $iniContent
            $json = ConvertTo-JsonConfig -Config $config
            $parsed = $json | ConvertFrom-Json
        }

        It 'Should represent null values as JSON null' {
            $parsed.section.key | Should -BeNullOrEmpty
        }

        It 'Should preserve non-null values' {
            $parsed.section.name | Should -Be 'hello'
        }
    }
}

# ============================================================================
# RED/GREEN CYCLE 8: YAML Output
# ============================================================================
Describe 'ConvertTo-YamlConfig - YAML Output' {
    Context 'When converting parsed config to YAML' {
        BeforeAll {
            $config = ConvertFrom-Ini -Path "$PSScriptRoot/fixtures/basic.ini"
            $yaml = ConvertTo-YamlConfig -Config $config
        }

        It 'Should return a non-empty string' {
            $yaml | Should -Not -BeNullOrEmpty
        }

        It 'Should contain section headers' {
            $yaml | Should -Match 'server:'
            $yaml | Should -Match 'database:'
        }

        It 'Should contain string values' {
            $yaml | Should -Match 'host: localhost'
            $yaml | Should -Match 'host: db\.example\.com'
        }

        It 'Should contain integer values without quotes' {
            $yaml | Should -Match 'port: 8080'
            $yaml | Should -Match 'max_connections: 100'
        }

        It 'Should contain boolean values as true/false' {
            $yaml | Should -Match 'debug: true'
            $yaml | Should -Match 'ssl: false'
        }
    }

    Context 'When converting config with special YAML values' {
        BeforeAll {
            $iniContent = @"
[section]
null_val = null
empty_val =
name = hello world
number = 42
flag = true
"@
            $config = ConvertFrom-Ini -Content $iniContent
            $yaml = ConvertTo-YamlConfig -Config $config
        }

        It 'Should represent null as YAML null' {
            $yaml | Should -Match 'null_val: null'
        }

        It 'Should represent empty string with quotes' {
            $yaml | Should -Match "empty_val: ''"
        }

        It 'Should quote strings that could be ambiguous' {
            # "hello world" is fine unquoted in YAML, but we check it's present
            $yaml | Should -Match 'name: hello world'
        }
    }

    Context 'When YAML has strings needing quoting' {
        BeforeAll {
            $iniContent = @"
[section]
colon_val = "value: with colon"
hash_val = "value # with hash"
"@
            $config = ConvertFrom-Ini -Content $iniContent
            $yaml = ConvertTo-YamlConfig -Config $config
        }

        It 'Should quote strings containing colons' {
            $yaml | Should -Match "colon_val: 'value: with colon'"
        }

        It 'Should quote strings containing hash' {
            $yaml | Should -Match "hash_val: 'value # with hash'"
        }
    }
}

# ============================================================================
# RED/GREEN CYCLE 9: Error Handling
# ============================================================================
Describe 'Error Handling' {
    Context 'When file does not exist' {
        It 'Should throw a meaningful error' {
            { ConvertFrom-Ini -Path '/nonexistent/file.ini' } | Should -Throw '*does not exist*'
        }
    }

    Context 'When key appears outside any section' {
        BeforeAll {
            $iniContent = @"
orphan_key = value
[section]
key = value
"@
            $result = ConvertFrom-Ini -Content $iniContent
        }

        It 'Should place orphan keys in a _global section' {
            $result.Contains('_global') | Should -BeTrue
            $result['_global']['orphan_key'] | Should -Be 'value'
        }
    }

    Context 'When schema is null' {
        It 'Should throw for null schema' {
            $config = [ordered]@{ section = [ordered]@{ key = 'val' } }
            { Test-IniSchema -Config $config -Schema $null } | Should -Throw
        }
    }
}

# ============================================================================
# RED/GREEN CYCLE 10: Full Integration - ConvertFrom-Ini piped to outputs
# ============================================================================
Describe 'Integration - Full Pipeline' {
    Context 'When processing the complex fixture file' {
        BeforeAll {
            $config = ConvertFrom-Ini -Path "$PSScriptRoot/fixtures/complex.ini"
        }

        It 'Should parse all sections including empty' {
            $config.Contains('application') | Should -BeTrue
            $config.Contains('paths') | Should -BeTrue
            $config.Contains('empty_section') | Should -BeTrue
            $config.Contains('special_values') | Should -BeTrue
        }

        It 'Should handle type coercion for yes/no' {
            $config['application']['enabled'] | Should -BeTrue
        }

        It 'Should coerce version as float' {
            $config['application']['version'] | Should -Be 2.5
        }

        It 'Should handle multi-line values' {
            $config['paths']['description'] | Should -Be 'This is a long multi-line value that spans three lines'
        }

        It 'Should produce valid JSON output' {
            $json = ConvertTo-JsonConfig -Config $config
            { $json | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Should produce valid YAML output' {
            $yaml = ConvertTo-YamlConfig -Config $config
            $yaml | Should -Not -BeNullOrEmpty
            # YAML should have all section headers
            $yaml | Should -Match 'application:'
            $yaml | Should -Match 'paths:'
            $yaml | Should -Match 'empty_section:'
            $yaml | Should -Match 'special_values:'
        }
    }
}
