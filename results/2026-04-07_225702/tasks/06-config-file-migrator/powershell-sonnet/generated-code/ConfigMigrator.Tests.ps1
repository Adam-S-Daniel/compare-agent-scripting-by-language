# ConfigMigrator.Tests.ps1
# TDD test suite for INI config file migration to JSON/YAML
# Red/Green/Refactor cycle: each Describe block represents one TDD iteration

#Requires -Modules Pester

BeforeAll {
    # Import the module under test
    . "$PSScriptRoot/ConfigMigrator.ps1"
}

# =============================================================================
# ITERATION 1: Parse a simple INI file (RED -> GREEN)
# =============================================================================
Describe "Parse-IniFile" {
    Context "Basic key-value parsing" {
        It "parses a simple key=value pair in the global section" {
            $content = "name=Alice"
            $result = Parse-IniContent -Content $content
            $result[""]["name"] | Should -Be "Alice"
        }

        It "parses multiple key-value pairs" {
            $content = @"
name=Alice
age=30
"@
            $result = Parse-IniContent -Content $content
            $result[""]["name"] | Should -Be "Alice"
            $result[""]["age"] | Should -Be "30"
        }

        It "trims whitespace around keys and values" {
            $content = "  name  =  Alice  "
            $result = Parse-IniContent -Content $content
            $result[""]["name"] | Should -Be "Alice"
        }
    }

    Context "Section handling" {
        It "parses keys under a named section" {
            $content = @"
[database]
host=localhost
port=5432
"@
            $result = Parse-IniContent -Content $content
            $result["database"]["host"] | Should -Be "localhost"
            $result["database"]["port"] | Should -Be "5432"
        }

        It "handles multiple sections" {
            $content = @"
[database]
host=localhost

[server]
port=8080
"@
            $result = Parse-IniContent -Content $content
            $result["database"]["host"] | Should -Be "localhost"
            $result["server"]["port"] | Should -Be "8080"
        }

        It "handles global keys before any section" {
            $content = @"
app=myapp

[database]
host=localhost
"@
            $result = Parse-IniContent -Content $content
            $result[""]["app"] | Should -Be "myapp"
            $result["database"]["host"] | Should -Be "localhost"
        }
    }

    Context "Comment handling" {
        It "ignores lines starting with semicolon" {
            $content = @"
; this is a comment
name=Alice
"@
            $result = Parse-IniContent -Content $content
            $result[""]["name"] | Should -Be "Alice"
            $result[""].Contains("; this is a comment") | Should -BeFalse
        }

        It "ignores lines starting with hash" {
            $content = @"
# this is a comment
name=Alice
"@
            $result = Parse-IniContent -Content $content
            $result[""]["name"] | Should -Be "Alice"
        }

        It "ignores inline comments after semicolon" {
            $content = "name=Alice ; inline comment"
            $result = Parse-IniContent -Content $content
            $result[""]["name"] | Should -Be "Alice"
        }
    }

    Context "Multi-line values" {
        It "joins continuation lines ending with backslash" {
            $content = @"
description=line one \
line two
"@
            $result = Parse-IniContent -Content $content
            $result[""]["description"] | Should -Be "line one line two"
        }
    }

    Context "Edge cases" {
        It "handles empty file" {
            $result = Parse-IniContent -Content ""
            $result | Should -Not -BeNullOrEmpty
            $result[""] | Should -Not -BeNullOrEmpty
        }

        It "handles file with only comments" {
            $content = @"
; just a comment
# another comment
"@
            $result = Parse-IniContent -Content $content
            $result[""].Count | Should -Be 0
        }

        It "handles values with equals sign in them" {
            $content = "url=http://example.com?a=1&b=2"
            $result = Parse-IniContent -Content $content
            $result[""]["url"] | Should -Be "http://example.com?a=1&b=2"
        }
    }
}

# =============================================================================
# ITERATION 2: Type coercion (RED -> GREEN)
# =============================================================================
Describe "Convert-IniValues" {
    It "coerces integer strings to integers" {
        $raw = @{ "" = @{ port = "5432" } }
        $result = Convert-IniValues -ParsedIni $raw
        $result[""]["port"] | Should -Be 5432
        $result[""]["port"] | Should -BeOfType [int]
    }

    It "coerces float strings to doubles" {
        $raw = @{ "" = @{ ratio = "3.14" } }
        $result = Convert-IniValues -ParsedIni $raw
        $result[""]["ratio"] | Should -Be 3.14
        $result[""]["ratio"] | Should -BeOfType [double]
    }

    It "coerces 'true' to boolean true" {
        $raw = @{ "" = @{ enabled = "true" } }
        $result = Convert-IniValues -ParsedIni $raw
        $result[""]["enabled"] | Should -BeTrue
        $result[""]["enabled"] | Should -BeOfType [bool]
    }

    It "coerces 'false' to boolean false" {
        $raw = @{ "" = @{ enabled = "false" } }
        $result = Convert-IniValues -ParsedIni $raw
        $result[""]["enabled"] | Should -BeFalse
        $result[""]["enabled"] | Should -BeOfType [bool]
    }

    It "coerces 'yes'/'no' to booleans" {
        $raw = @{ "" = @{ active = "yes"; archived = "no" } }
        $result = Convert-IniValues -ParsedIni $raw
        $result[""]["active"] | Should -BeTrue
        $result[""]["archived"] | Should -BeFalse
    }

    It "leaves plain strings as strings" {
        $raw = @{ "" = @{ name = "Alice" } }
        $result = Convert-IniValues -ParsedIni $raw
        $result[""]["name"] | Should -Be "Alice"
        $result[""]["name"] | Should -BeOfType [string]
    }
}

# =============================================================================
# ITERATION 3: Schema validation (RED -> GREEN)
# =============================================================================
Describe "Test-IniSchema" {
    BeforeAll {
        $schema = @{
            sections = @{
                "" = @{
                    required = @("app_name")
                    types = @{ max_connections = "int"; debug = "bool" }
                }
                "database" = @{
                    required = @("host", "port")
                    types = @{ port = "int" }
                }
            }
        }
    }

    It "passes validation when all required keys are present" {
        $data = @{
            "" = @{ app_name = "myapp" }
            "database" = @{ host = "localhost"; port = 5432 }
        }
        $result = Test-IniSchema -Data $data -Schema $schema
        $result.IsValid | Should -BeTrue
        $result.Errors | Should -HaveCount 0
    }

    It "fails validation when a required key is missing" {
        $data = @{
            "" = @{ }
            "database" = @{ host = "localhost"; port = 5432 }
        }
        $result = Test-IniSchema -Data $data -Schema $schema
        $result.IsValid | Should -BeFalse
        $result.Errors | Should -Contain "[]: required key 'app_name' is missing"
    }

    It "fails validation when a required section key is missing" {
        $data = @{
            "" = @{ app_name = "myapp" }
            "database" = @{ host = "localhost" }
        }
        $result = Test-IniSchema -Data $data -Schema $schema
        $result.IsValid | Should -BeFalse
        $result.Errors | Should -Contain "[database]: required key 'port' is missing"
    }

    It "fails validation when a value has the wrong type" {
        $data = @{
            "" = @{ app_name = "myapp"; max_connections = "not-a-number" }
            "database" = @{ host = "localhost"; port = 5432 }
        }
        $result = Test-IniSchema -Data $data -Schema $schema
        $result.IsValid | Should -BeFalse
        $result.Errors[0] | Should -Match "max_connections"
    }

    It "passes when optional typed keys are absent" {
        $data = @{
            "" = @{ app_name = "myapp" }
            "database" = @{ host = "localhost"; port = 5432 }
        }
        $result = Test-IniSchema -Data $data -Schema $schema
        $result.IsValid | Should -BeTrue
    }
}

# =============================================================================
# ITERATION 4: JSON output (RED -> GREEN)
# =============================================================================
Describe "ConvertTo-JsonOutput" {
    It "converts parsed INI data to valid JSON string" {
        $data = @{
            "" = @{ app_name = "myapp" }
            "database" = @{ host = "localhost"; port = 5432 }
        }
        $json = ConvertTo-JsonOutput -Data $data
        $parsed = $json | ConvertFrom-Json -AsHashtable
        $parsed["app_name"] | Should -Be "myapp"
        $parsed["database"]["host"] | Should -Be "localhost"
        $parsed["database"]["port"] | Should -Be 5432
    }

    It "omits the empty global section key when no global keys exist" {
        $data = @{
            "" = @{ }
            "server" = @{ port = 8080 }
        }
        $json = ConvertTo-JsonOutput -Data $data
        $parsed = $json | ConvertFrom-Json -AsHashtable
        $parsed.ContainsKey("") | Should -BeFalse
    }
}

# =============================================================================
# ITERATION 5: YAML output (RED -> GREEN)
# =============================================================================
Describe "ConvertTo-YamlOutput" {
    It "produces valid YAML with section as top-level key" {
        $data = @{
            "" = @{ app_name = "myapp" }
            "database" = @{ host = "localhost"; port = 5432 }
        }
        $yaml = ConvertTo-YamlOutput -Data $data
        $yaml | Should -Match "app_name: myapp"
        $yaml | Should -Match "database:"
        $yaml | Should -Match "host: localhost"
    }

    It "quotes string values that look like other types" {
        $data = @{
            "" = @{ version = "1.0" }
        }
        $yaml = ConvertTo-YamlOutput -Data $data
        # "1.0" is ambiguous YAML float — should be quoted
        $yaml | Should -Match 'version: [''"]?1\.0[''"]?'
    }

    It "renders booleans as yaml true/false" {
        $data = @{
            "" = @{ debug = $true; verbose = $false }
        }
        $yaml = ConvertTo-YamlOutput -Data $data
        $yaml | Should -Match "debug: true"
        $yaml | Should -Match "verbose: false"
    }

    It "renders integers without quotes" {
        $data = @{
            "" = @{ port = 8080 }
        }
        $yaml = ConvertTo-YamlOutput -Data $data
        $yaml | Should -Match "port: 8080"
    }
}

# =============================================================================
# ITERATION 6: End-to-end with file fixtures (RED -> GREEN)
# =============================================================================
Describe "Convert-IniToFormats (end-to-end)" {
    BeforeAll {
        $fixturesDir = "$PSScriptRoot/fixtures"
        if (-not (Test-Path $fixturesDir)) { New-Item -ItemType Directory $fixturesDir | Out-Null }
    }

    Context "Full pipeline from file" {
        BeforeEach {
            $testIni = @"
; Application configuration
# Global settings

app_name = MyApp
version  = 2.1
debug    = true

[database]
host = localhost
port = 5432
ssl  = false

[server]
host    = 0.0.0.0
port    = 8080
timeout = 30
"@
            $iniPath = "$PSScriptRoot/fixtures/test.ini"
            Set-Content -Path $iniPath -Value $testIni
        }

        It "reads the file and returns a result object" {
            $result = Convert-IniToFormats -Path "$PSScriptRoot/fixtures/test.ini"
            $result | Should -Not -BeNullOrEmpty
        }

        It "produces valid JSON output" {
            $result = Convert-IniToFormats -Path "$PSScriptRoot/fixtures/test.ini"
            { $result.Json | ConvertFrom-Json } | Should -Not -Throw
        }

        It "produces YAML output containing expected keys" {
            $result = Convert-IniToFormats -Path "$PSScriptRoot/fixtures/test.ini"
            $result.Yaml | Should -Match "app_name"
            $result.Yaml | Should -Match "database"
        }

        It "coerces types correctly end-to-end" {
            $result = Convert-IniToFormats -Path "$PSScriptRoot/fixtures/test.ini"
            $parsed = $result.Json | ConvertFrom-Json
            $parsed.database.port | Should -Be 5432
            $parsed.debug | Should -BeTrue
        }
    }

    Context "Error handling" {
        It "throws a meaningful error for a non-existent file" {
            { Convert-IniToFormats -Path "does_not_exist.ini" } | Should -Throw "*not found*"
        }
    }
}

# =============================================================================
# ITERATION 7: Edge-case fixtures (RED -> GREEN)
# =============================================================================
Describe "Edge-case fixtures" {
    Context "Multi-line values fixture" {
        BeforeEach {
            $content = @"
[app]
description = This is a long \
    description that spans \
    multiple lines
"@
            Set-Content -Path "$PSScriptRoot/fixtures/multiline.ini" -Value $content
        }

        It "joins multi-line values into a single string" {
            $result = Convert-IniToFormats -Path "$PSScriptRoot/fixtures/multiline.ini"
            $parsed = $result.Json | ConvertFrom-Json
            $parsed.app.description | Should -Match "This is a long"
            $parsed.app.description | Should -Match "multiple lines"
        }
    }

    Context "Empty sections fixture" {
        BeforeEach {
            $content = @"
[empty_section]

[real_section]
key=value
"@
            Set-Content -Path "$PSScriptRoot/fixtures/empty_section.ini" -Value $content
        }

        It "handles empty sections without error" {
            { Convert-IniToFormats -Path "$PSScriptRoot/fixtures/empty_section.ini" } | Should -Not -Throw
        }
    }

    Context "Special characters in values" {
        BeforeEach {
            $content = @"
[urls]
api=https://api.example.com/v1?key=abc&format=json
path=C:\Users\admin\config
"@
            Set-Content -Path "$PSScriptRoot/fixtures/special_chars.ini" -Value $content
        }

        It "preserves URLs with query parameters" {
            $result = Convert-IniToFormats -Path "$PSScriptRoot/fixtures/special_chars.ini"
            $parsed = $result.Json | ConvertFrom-Json
            $parsed.urls.api | Should -Be "https://api.example.com/v1?key=abc&format=json"
        }

        It "preserves Windows-style paths" {
            $result = Convert-IniToFormats -Path "$PSScriptRoot/fixtures/special_chars.ini"
            $parsed = $result.Json | ConvertFrom-Json
            $parsed.urls.path | Should -Be 'C:\Users\admin\config'
        }
    }
}
