Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    . "$PSScriptRoot/ConfigMigrator.ps1"
}

Describe 'ConvertFrom-Ini' {
    Context 'Basic key-value parsing' {
        It 'parses a simple key=value pair under a section' {
            $ini = @"
[section1]
key1=value1
"@
            $result = ConvertFrom-Ini -Content $ini
            $result | Should -Not -BeNullOrEmpty
            $result['section1']['key1'] | Should -Be 'value1'
        }

        It 'parses multiple sections with multiple keys' {
            $ini = @"
[database]
host=localhost
port=5432

[app]
name=MyApp
debug=true
"@
            $result = ConvertFrom-Ini -Content $ini
            $result['database']['host'] | Should -Be 'localhost'
            $result['database']['port'] | Should -Be 5432
            $result['app']['name'] | Should -Be 'MyApp'
            $result['app']['debug'] | Should -Be $true
        }
    }

    Context 'Comment handling' {
        It 'ignores lines starting with ; or #' {
            $ini = @"
; This is a comment
# This is also a comment
[section]
key1=value1
; inline section comment
key2=value2
"@
            $result = ConvertFrom-Ini -Content $ini
            $result['section']['key1'] | Should -Be 'value1'
            $result['section']['key2'] | Should -Be 'value2'
            $result['section'].Keys.Count | Should -Be 2
        }
    }

    Context 'Type coercion' {
        It 'coerces integer values' {
            $ini = @"
[types]
port=8080
count=0
negative=-42
"@
            $result = ConvertFrom-Ini -Content $ini
            $result['types']['port'] | Should -BeOfType [int]
            $result['types']['port'] | Should -Be 8080
            $result['types']['count'] | Should -Be 0
            $result['types']['negative'] | Should -Be -42
        }

        It 'coerces float values' {
            $ini = @"
[types]
ratio=3.14
"@
            $result = ConvertFrom-Ini -Content $ini
            $result['types']['ratio'] | Should -BeOfType [double]
            $result['types']['ratio'] | Should -Be 3.14
        }

        It 'coerces boolean values' {
            $ini = @"
[types]
enabled=true
disabled=false
yes_val=yes
no_val=no
"@
            $result = ConvertFrom-Ini -Content $ini
            $result['types']['enabled'] | Should -Be $true
            $result['types']['disabled'] | Should -Be $false
            $result['types']['yes_val'] | Should -Be $true
            $result['types']['no_val'] | Should -Be $false
        }

        It 'keeps quoted strings as strings even if they look numeric' {
            $ini = @"
[types]
zip="90210"
label="true"
"@
            $result = ConvertFrom-Ini -Content $ini
            $result['types']['zip'] | Should -BeOfType [string]
            $result['types']['zip'] | Should -Be '90210'
            $result['types']['label'] | Should -Be 'true'
        }
    }

    Context 'Multi-line values' {
        It 'supports continuation lines (leading whitespace)' {
            $ini = @"
[section]
description=This is a long
    value that spans
    multiple lines
other=normal
"@
            $result = ConvertFrom-Ini -Content $ini
            $result['section']['description'] | Should -Be "This is a long`nvalue that spans`nmultiple lines"
            $result['section']['other'] | Should -Be 'normal'
        }
    }

    Context 'Whitespace handling' {
        It 'trims whitespace around keys and values' {
            $ini = @"
[section]
  key1  =  value1
key2 = value2
"@
            $result = ConvertFrom-Ini -Content $ini
            $result['section']['key1'] | Should -Be 'value1'
            $result['section']['key2'] | Should -Be 'value2'
        }

        It 'skips blank lines' {
            $ini = @"

[section]

key1=value1

"@
            $result = ConvertFrom-Ini -Content $ini
            $result['section']['key1'] | Should -Be 'value1'
        }
    }

    Context 'Edge cases' {
        It 'handles values containing equals signs' {
            $ini = @"
[section]
connection=host=localhost;port=5432
"@
            $result = ConvertFrom-Ini -Content $ini
            $result['section']['connection'] | Should -Be 'host=localhost;port=5432'
        }

        It 'handles empty values' {
            $ini = @"
[section]
empty=
"@
            $result = ConvertFrom-Ini -Content $ini
            $result['section']['empty'] | Should -Be ''
        }

        It 'throws on keys outside a section' {
            $ini = @"
orphan=value
[section]
key=value
"@
            { ConvertFrom-Ini -Content $ini } | Should -Throw '*outside*section*'
        }
    }
}

Describe 'Test-IniAgainstSchema' {
    It 'passes validation when all required keys are present with correct types' {
        $data = [ordered]@{
            database = [ordered]@{
                host = 'localhost'
                port = [int]5432
            }
        }
        $schema = [ordered]@{
            database = [ordered]@{
                host = @{ type = 'string'; required = $true }
                port = @{ type = 'int'; required = $true }
            }
        }
        $result = Test-IniAgainstSchema -Data $data -Schema $schema
        $result.Valid | Should -Be $true
        $result.Errors.Count | Should -Be 0
    }

    It 'fails when a required key is missing' {
        $data = [ordered]@{
            database = [ordered]@{
                host = 'localhost'
            }
        }
        $schema = [ordered]@{
            database = [ordered]@{
                host = @{ type = 'string'; required = $true }
                port = @{ type = 'int'; required = $true }
            }
        }
        $result = Test-IniAgainstSchema -Data $data -Schema $schema
        $result.Valid | Should -Be $false
        $result.Errors | Should -Contain "Missing required key 'port' in section 'database'"
    }

    It 'fails when a value has wrong type' {
        $data = [ordered]@{
            database = [ordered]@{
                host = 'localhost'
                port = 'not_a_number'
            }
        }
        $schema = [ordered]@{
            database = [ordered]@{
                host = @{ type = 'string'; required = $true }
                port = @{ type = 'int'; required = $true }
            }
        }
        $result = Test-IniAgainstSchema -Data $data -Schema $schema
        $result.Valid | Should -Be $false
        $result.Errors[0] | Should -BeLike "*port*int*"
    }

    It 'fails when a required section is missing' {
        $data = [ordered]@{
            app = [ordered]@{ name = 'test' }
        }
        $schema = [ordered]@{
            database = [ordered]@{
                host = @{ type = 'string'; required = $true }
            }
        }
        $result = Test-IniAgainstSchema -Data $data -Schema $schema
        $result.Valid | Should -Be $false
        $result.Errors | Should -Contain "Missing required section 'database'"
    }
}

Describe 'ConvertTo-JsonConfig' {
    It 'converts parsed INI data to valid JSON string' {
        $data = [ordered]@{
            section = [ordered]@{
                key = 'value'
                num = [int]42
            }
        }
        $json = ConvertTo-JsonConfig -Data $data
        $json | Should -Not -BeNullOrEmpty
        $parsed = $json | ConvertFrom-Json
        $parsed.section.key | Should -Be 'value'
        $parsed.section.num | Should -Be 42
    }
}

Describe 'ConvertTo-YamlConfig' {
    It 'converts parsed INI data to valid YAML string' {
        $data = [ordered]@{
            section = [ordered]@{
                key = 'value'
                num = [int]42
                flag = $true
            }
        }
        $yaml = ConvertTo-YamlConfig -Data $data
        $yaml | Should -Not -BeNullOrEmpty
        # YAML output should contain section and keys
        $yaml | Should -BeLike '*section:*'
        $yaml | Should -BeLike '*key: value*'
        $yaml | Should -BeLike '*num: 42*'
        $yaml | Should -BeLike '*flag: true*'
    }
}

Describe 'End-to-end: INI file to JSON and YAML' {
    BeforeAll {
        # Create a test fixture INI file
        $fixtureDir = Join-Path $PSScriptRoot 'fixtures'
        if (-not (Test-Path $fixtureDir)) {
            New-Item -Path $fixtureDir -ItemType Directory | Out-Null
        }
        $fixtureFile = Join-Path $fixtureDir 'test-app.ini'
        @"
; Application configuration
[server]
host=0.0.0.0
port=8080
debug=false

# Database settings
[database]
host=db.example.com
port=5432
name=mydb
max_connections=100
timeout=30.5

[logging]
level=info
file=/var/log/app.log
verbose=no
"@ | Set-Content -Path $fixtureFile -NoNewline
    }

    It 'reads an INI file and produces JSON output' {
        $content = Get-Content -Path (Join-Path $PSScriptRoot 'fixtures/test-app.ini') -Raw
        $data = ConvertFrom-Ini -Content $content
        $json = ConvertTo-JsonConfig -Data $data
        $parsed = $json | ConvertFrom-Json
        $parsed.server.host | Should -Be '0.0.0.0'
        $parsed.server.port | Should -Be 8080
        $parsed.database.max_connections | Should -Be 100
        $parsed.database.timeout | Should -Be 30.5
        $parsed.logging.verbose | Should -Be $false
    }

    It 'reads an INI file and produces YAML output' {
        $content = Get-Content -Path (Join-Path $PSScriptRoot 'fixtures/test-app.ini') -Raw
        $data = ConvertFrom-Ini -Content $content
        $yaml = ConvertTo-YamlConfig -Data $data
        $yaml | Should -BeLike '*host: 0.0.0.0*'
        $yaml | Should -BeLike '*port: 8080*'
        $yaml | Should -BeLike '*max_connections: 100*'
    }
}

Describe 'Edge-case fixtures' {
    BeforeAll {
        $fixtureDir = Join-Path $PSScriptRoot 'fixtures'
        if (-not (Test-Path $fixtureDir)) {
            New-Item -Path $fixtureDir -ItemType Directory | Out-Null
        }
    }

    It 'handles INI with special characters in values' {
        $ini = @"
[paths]
home=/home/user/.config
url=https://example.com/api?key=abc&token=xyz
regex=^[a-z]+$
"@
        $result = ConvertFrom-Ini -Content $ini
        $result['paths']['url'] | Should -Be 'https://example.com/api?key=abc&token=xyz'
        $result['paths']['regex'] | Should -Be '^[a-z]+$'
    }

    It 'handles INI with unicode values' {
        $ini = @"
[i18n]
greeting=こんにちは
emoji=Hello 🌍
"@
        $result = ConvertFrom-Ini -Content $ini
        $result['i18n']['greeting'] | Should -Be 'こんにちは'
        $result['i18n']['emoji'] | Should -Be 'Hello 🌍'
    }

    It 'handles large number of sections' {
        $sb = [System.Text.StringBuilder]::new()
        for ($i = 0; $i -lt 50; $i++) {
            [void]$sb.AppendLine("[section$i]")
            [void]$sb.AppendLine("key=value$i")
        }
        $result = ConvertFrom-Ini -Content $sb.ToString()
        $result.Keys.Count | Should -Be 50
        $result['section49']['key'] | Should -Be 'value49'
    }

    It 'validates boolean type in schema' {
        $data = [ordered]@{
            app = [ordered]@{ debug = $true }
        }
        $schema = [ordered]@{
            app = [ordered]@{
                debug = @{ type = 'bool'; required = $true }
            }
        }
        $result = Test-IniAgainstSchema -Data $data -Schema $schema
        $result.Valid | Should -Be $true
    }

    It 'validates double type in schema' {
        $data = [ordered]@{
            app = [ordered]@{ rate = [double]3.14 }
        }
        $schema = [ordered]@{
            app = [ordered]@{
                rate = @{ type = 'double'; required = $true }
            }
        }
        $result = Test-IniAgainstSchema -Data $data -Schema $schema
        $result.Valid | Should -Be $true
    }

    It 'allows optional keys to be missing' {
        $data = [ordered]@{
            app = [ordered]@{ name = 'test' }
        }
        $schema = [ordered]@{
            app = [ordered]@{
                name = @{ type = 'string'; required = $true }
                version = @{ type = 'string'; required = $false }
            }
        }
        $result = Test-IniAgainstSchema -Data $data -Schema $schema
        $result.Valid | Should -Be $true
    }
}
