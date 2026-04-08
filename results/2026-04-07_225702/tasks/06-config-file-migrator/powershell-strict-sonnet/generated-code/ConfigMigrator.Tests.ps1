# ConfigMigrator.Tests.ps1
# TDD test suite for Config File Migrator (INI -> JSON + YAML)
# Strict mode compliant Pester tests
#
# TDD PROGRESSION:
#   Phase 1: Convert-IniValue  - type coercion helper
#   Phase 2: Read-IniFile      - INI parser
#   Phase 3: Test-IniSchema    - schema validation
#   Phase 4: ConvertTo-JsonConfig  - JSON output
#   Phase 5: ConvertTo-YamlConfig  - YAML output
#   Phase 6: Invoke-ConfigMigration - integration

BeforeAll {
    # Strict mode enabled inside BeforeAll to avoid Pester discovery conflicts.
    # (Pester 5.x shadows Set-StrictMode at top-level during discovery.)
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # Import the module under test.
    # On first run (before ConfigMigrator.psm1 exists) every test fails — the
    # red phase. The module file is then written to make them green.
    Import-Module (Join-Path $PSScriptRoot 'ConfigMigrator.psm1') -Force

    # Shared temp directory for test fixture files
    $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "ConfigMigratorTests_$(Get-Random)"
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

    # ---------------------------------------------------------------------------
    # Helper: write a temp INI file and return its path.
    # Defined inside BeforeAll so Pester 5.x scoping rules make it visible to
    # all subsequent It blocks (functions at file scope are not reliably visible
    # in Pester 5 test execution scopes).
    # ---------------------------------------------------------------------------
    function script:New-TempIniFile {
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory)]
            [AllowEmptyString()]
            [string]$Content
        )
        [string]$filePath = Join-Path $script:TempDir "test_$(Get-Random).ini"
        Set-Content -Path $filePath -Value $Content -Encoding UTF8
        return $filePath
    }
}

AfterAll {
    Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Module ConfigMigrator -ErrorAction SilentlyContinue
}

# ===========================================================================
# PHASE 1 — Convert-IniValue (type coercion helper)
# ===========================================================================
Describe "Convert-IniValue" {

    Context "Boolean coercion" {
        It "converts 'true' to [bool] true" {
            $r = Convert-IniValue -Value 'true'
            $r | Should -BeOfType [bool]
            $r | Should -Be $true
        }
        It "converts 'True' case-insensitively" {
            $r = Convert-IniValue -Value 'True'
            $r | Should -BeOfType [bool]
            $r | Should -Be $true
        }
        It "converts 'yes' to true" {
            $r = Convert-IniValue -Value 'yes'
            $r | Should -BeOfType [bool]
            $r | Should -Be $true
        }
        It "converts 'on' to true" {
            $r = Convert-IniValue -Value 'on'
            $r | Should -BeOfType [bool]
            $r | Should -Be $true
        }
        It "converts 'false' to [bool] false" {
            $r = Convert-IniValue -Value 'false'
            $r | Should -BeOfType [bool]
            $r | Should -Be $false
        }
        It "converts 'no' to false" {
            $r = Convert-IniValue -Value 'no'
            $r | Should -BeOfType [bool]
            $r | Should -Be $false
        }
        It "converts 'off' to false" {
            $r = Convert-IniValue -Value 'off'
            $r | Should -BeOfType [bool]
            $r | Should -Be $false
        }
    }

    Context "Integer coercion" {
        It "converts '42' to [int] 42" {
            $r = Convert-IniValue -Value '42'
            $r | Should -BeOfType [int]
            $r | Should -Be 42
        }
        It "converts '0' to [int] 0" {
            $r = Convert-IniValue -Value '0'
            $r | Should -BeOfType [int]
            $r | Should -Be 0
        }
        It "converts '-10' to [int] -10" {
            $r = Convert-IniValue -Value '-10'
            $r | Should -BeOfType [int]
            $r | Should -Be -10
        }
    }

    Context "Float coercion" {
        It "converts '3.14' to [double]" {
            $r = Convert-IniValue -Value '3.14'
            $r | Should -BeOfType [double]
            $r | Should -Be 3.14
        }
        It "converts '1.0' to [double]" {
            $r = Convert-IniValue -Value '1.0'
            $r | Should -BeOfType [double]
        }
        It "converts '-0.5' to [double]" {
            $r = Convert-IniValue -Value '-0.5'
            $r | Should -BeOfType [double]
            $r | Should -Be -0.5
        }
    }

    Context "String preservation" {
        It "keeps plain strings as strings" {
            $r = Convert-IniValue -Value 'hello'
            $r | Should -BeOfType [string]
            $r | Should -Be 'hello'
        }
        It "keeps strings with spaces as strings" {
            $r = Convert-IniValue -Value 'hello world'
            $r | Should -BeOfType [string]
            $r | Should -Be 'hello world'
        }
        It "keeps empty string as string" {
            $r = Convert-IniValue -Value ''
            $r | Should -BeOfType [string]
            $r | Should -Be ''
        }
    }
}

# ===========================================================================
# PHASE 2 — Read-IniFile (INI parser)
# ===========================================================================
Describe "Read-IniFile" {

    Context "File validation" {
        It "throws for a non-existent file" {
            { Read-IniFile -Path '/nonexistent/path/missing.ini' } | Should -Throw
        }
    }

    Context "Basic key-value parsing (no sections)" {
        It "returns a [hashtable]" {
            [string]$p = New-TempIniFile -Content "key = value"
            $r = Read-IniFile -Path $p
            $r | Should -BeOfType [hashtable]
        }
        It "parses a single key=value pair" {
            [string]$p = New-TempIniFile -Content "key = value"
            $r = Read-IniFile -Path $p
            $r['key'] | Should -Be 'value'
        }
        It "parses multiple key-value pairs" {
            [string]$p = New-TempIniFile -Content "key1 = value1`nkey2 = value2"
            $r = Read-IniFile -Path $p
            $r['key1'] | Should -Be 'value1'
            $r['key2'] | Should -Be 'value2'
        }
        It "supports colon as separator" {
            [string]$p = New-TempIniFile -Content "key: value"
            $r = Read-IniFile -Path $p
            $r['key'] | Should -Be 'value'
        }
        It "trims whitespace from keys and values" {
            [string]$p = New-TempIniFile -Content "  key  =   value   "
            $r = Read-IniFile -Path $p
            $r['key'] | Should -Be 'value'
        }
    }

    Context "Section parsing" {
        It "parses a single section with keys" {
            [string]$content = "[database]`nhost = localhost`nport = 5432"
            [string]$p = New-TempIniFile -Content $content
            $r = Read-IniFile -Path $p
            $r.ContainsKey('database') | Should -Be $true
            [hashtable]$db = [hashtable]$r['database']
            $db['host'] | Should -Be 'localhost'
            $db['port'] | Should -Be 5432
        }
        It "parses multiple sections" {
            [string]$content = "[s1]`nk1 = v1`n`n[s2]`nk2 = v2"
            [string]$p = New-TempIniFile -Content $content
            $r = Read-IniFile -Path $p
            $r.ContainsKey('s1') | Should -Be $true
            $r.ContainsKey('s2') | Should -Be $true
            ([hashtable]$r['s1'])['k1'] | Should -Be 'v1'
            ([hashtable]$r['s2'])['k2'] | Should -Be 'v2'
        }
        It "allows global keys before any section" {
            [string]$content = "global = yes`n[section]`nlocal = no"
            [string]$p = New-TempIniFile -Content $content
            $r = Read-IniFile -Path $p
            $r['global'] | Should -Be $true    # 'yes' -> bool
            ([hashtable]$r['section'])['local'] | Should -Be $false
        }
    }

    Context "Comment handling" {
        It "ignores semicolon comment lines" {
            [string]$p = New-TempIniFile -Content "; comment`nkey = value"
            $r = Read-IniFile -Path $p
            $r.ContainsKey('; comment') | Should -Be $false
            $r['key'] | Should -Be 'value'
        }
        It "ignores hash comment lines" {
            [string]$p = New-TempIniFile -Content "# comment`nkey = value"
            $r = Read-IniFile -Path $p
            $r['key'] | Should -Be 'value'
        }
        It "ignores inline comments separated by a space" {
            [string]$p = New-TempIniFile -Content "key = value ; trailing comment"
            $r = Read-IniFile -Path $p
            $r['key'] | Should -Be 'value'
        }
        It "preserves semicolons inside values (no leading space)" {
            [string]$p = New-TempIniFile -Content "key = abc;def"
            $r = Read-IniFile -Path $p
            $r['key'] | Should -Be 'abc;def'
        }
    }

    Context "Multi-line values (backslash continuation)" {
        It "joins continuation lines into a single value" {
            $content = "[section]`nkey = line1 \`n      line2 \`n      line3"
            [string]$p = New-TempIniFile -Content $content
            $r = Read-IniFile -Path $p
            [hashtable]$s = [hashtable]$r['section']
            $s['key'] | Should -Be 'line1 line2 line3'
        }
    }

    Context "Type coercion in sections" {
        It "coerces boolean values" {
            [string]$content = "[app]`nenabled = true`ndebug = false"
            [string]$p = New-TempIniFile -Content $content
            $r = Read-IniFile -Path $p
            [hashtable]$app = [hashtable]$r['app']
            $app['enabled'] | Should -BeOfType [bool]
            $app['enabled'] | Should -Be $true
            $app['debug'] | Should -Be $false
        }
        It "coerces integer values" {
            [string]$content = "[server]`nport = 8080`nworkers = 4"
            [string]$p = New-TempIniFile -Content $content
            $r = Read-IniFile -Path $p
            [hashtable]$srv = [hashtable]$r['server']
            $srv['port'] | Should -BeOfType [int]
            $srv['port'] | Should -Be 8080
        }
        It "coerces float values" {
            [string]$p = New-TempIniFile -Content "[s]`ntimeout = 30.5"
            $r = Read-IniFile -Path $p
            ([hashtable]$r['s'])['timeout'] | Should -BeOfType [double]
            ([hashtable]$r['s'])['timeout'] | Should -Be 30.5
        }
    }
}

# ===========================================================================
# PHASE 3 — Test-IniSchema (schema validation)
# ===========================================================================
Describe "Test-IniSchema" {

    Context "Valid configurations" {
        It "returns IsValid=true for a config that satisfies the schema" {
            [hashtable]$config = @{
                database = @{ host = [string]'localhost'; port = [int]5432 }
            }
            [hashtable]$schema = @{
                database = @{
                    required = [string[]]@('host', 'port')
                    types    = @{ host = [string]'string'; port = [string]'int' }
                }
            }
            $r = Test-IniSchema -Config $config -Schema $schema
            $r['IsValid'] | Should -Be $true
            $r['Errors'] | Should -BeNullOrEmpty
        }
    }

    Context "Missing required keys" {
        It "returns IsValid=false when a required key is absent" {
            [hashtable]$config = @{ database = @{ host = 'localhost' } }
            [hashtable]$schema = @{
                database = @{
                    required = [string[]]@('host', 'port')
                    types    = @{}
                }
            }
            $r = Test-IniSchema -Config $config -Schema $schema
            $r['IsValid'] | Should -Be $false
        }
        It "error message mentions the missing key name" {
            [hashtable]$config = @{ database = @{ host = 'localhost' } }
            [hashtable]$schema = @{
                database = @{
                    required = [string[]]@('host', 'port')
                    types    = @{}
                }
            }
            $r = Test-IniSchema -Config $config -Schema $schema
            [string[]]$errors = [string[]]$r['Errors']
            ($errors | Where-Object { $_ -like '*port*' }) | Should -Not -BeNullOrEmpty
        }
        It "returns IsValid=false when a required section is missing entirely" {
            [hashtable]$config = @{}
            [hashtable]$schema = @{
                database = @{
                    required = [string[]]@('host')
                    types    = @{}
                }
            }
            $r = Test-IniSchema -Config $config -Schema $schema
            $r['IsValid'] | Should -Be $false
        }
    }

    Context "Type validation" {
        It "returns IsValid=false when value has wrong type" {
            [hashtable]$config = @{ database = @{ port = [string]'not-a-number' } }
            [hashtable]$schema = @{
                database = @{
                    required = [string[]]@()
                    types    = @{ port = [string]'int' }
                }
            }
            $r = Test-IniSchema -Config $config -Schema $schema
            $r['IsValid'] | Should -Be $false
        }
        It "validates bool type correctly" {
            [hashtable]$config = @{ app = @{ enabled = [bool]$true } }
            [hashtable]$schema = @{
                app = @{
                    required = [string[]]@('enabled')
                    types    = @{ enabled = [string]'bool' }
                }
            }
            $r = Test-IniSchema -Config $config -Schema $schema
            $r['IsValid'] | Should -Be $true
        }
        It "validates string type correctly" {
            [hashtable]$config = @{ app = @{ name = [string]'MyApp' } }
            [hashtable]$schema = @{
                app = @{
                    required = [string[]]@('name')
                    types    = @{ name = [string]'string' }
                }
            }
            $r = Test-IniSchema -Config $config -Schema $schema
            $r['IsValid'] | Should -Be $true
        }
        It "reports multiple errors in one pass" {
            [hashtable]$config = @{ s = @{ k1 = [string]'x' } }
            [hashtable]$schema = @{
                s = @{
                    required = [string[]]@('k1', 'k2', 'k3')
                    types    = @{}
                }
            }
            $r = Test-IniSchema -Config $config -Schema $schema
            [string[]]$errors = [string[]]$r['Errors']
            $errors.Count | Should -BeGreaterThan 1
        }
    }
}

# ===========================================================================
# PHASE 4 — ConvertTo-JsonConfig (JSON output)
# ===========================================================================
Describe "ConvertTo-JsonConfig" {

    It "returns a [string]" {
        [hashtable]$c = @{ key = [string]'value' }
        $r = ConvertTo-JsonConfig -Config $c
        $r | Should -BeOfType [string]
    }
    It "produces parseable JSON" {
        [hashtable]$c = @{ key = [string]'value' }
        $r = ConvertTo-JsonConfig -Config $c
        { $r | ConvertFrom-Json } | Should -Not -Throw
    }
    It "preserves string values" {
        [hashtable]$c = @{ key = [string]'hello' }
        $r = ConvertTo-JsonConfig -Config $c
        ($r | ConvertFrom-Json).key | Should -Be 'hello'
    }
    It "preserves nested sections" {
        [hashtable]$c = @{ database = @{ host = [string]'localhost'; port = [int]5432 } }
        $r = ConvertTo-JsonConfig -Config $c
        $parsed = $r | ConvertFrom-Json
        $parsed.database.host | Should -Be 'localhost'
        $parsed.database.port | Should -Be 5432
    }
    It "preserves boolean types" {
        [hashtable]$c = @{ app = @{ enabled = [bool]$true; debug = [bool]$false } }
        $r = ConvertTo-JsonConfig -Config $c
        $parsed = $r | ConvertFrom-Json
        $parsed.app.enabled | Should -Be $true
        $parsed.app.debug | Should -Be $false
    }
}

# ===========================================================================
# PHASE 5 — ConvertTo-YamlConfig (YAML output)
# ===========================================================================
Describe "ConvertTo-YamlConfig" {

    It "returns a non-empty [string]" {
        [hashtable]$c = @{ key = [string]'value' }
        $r = ConvertTo-YamlConfig -Config $c
        $r | Should -BeOfType [string]
        $r | Should -Not -BeNullOrEmpty
    }
    It "emits section names as top-level YAML keys" {
        [hashtable]$c = @{ database = @{ host = [string]'localhost' } }
        $r = ConvertTo-YamlConfig -Config $c
        $r | Should -Match 'database:'
        $r | Should -Match 'host: localhost'
    }
    It "indents section contents by 2 spaces" {
        [hashtable]$c = @{ section = @{ key = [string]'value' } }
        $r = ConvertTo-YamlConfig -Config $c
        $r | Should -Match '  key: value'
    }
    It "formats booleans as lowercase true/false" {
        [hashtable]$c = @{ app = @{ enabled = [bool]$true; debug = [bool]$false } }
        $r = ConvertTo-YamlConfig -Config $c
        $r | Should -Match 'enabled: true'
        $r | Should -Match 'debug: false'
    }
    It "formats integers without quotes" {
        [hashtable]$c = @{ server = @{ port = [int]8080 } }
        $r = ConvertTo-YamlConfig -Config $c
        $r | Should -Match 'port: 8080'
    }
    It "formats doubles without quotes" {
        [hashtable]$c = @{ server = @{ timeout = [double]30.5 } }
        $r = ConvertTo-YamlConfig -Config $c
        $r | Should -Match 'timeout: 30.5'
    }
    It "double-quotes strings that contain a colon" {
        [hashtable]$c = @{ s = @{ url = [string]'http://localhost:8080' } }
        $r = ConvertTo-YamlConfig -Config $c
        $r | Should -Match 'url: "http://localhost:8080"'
    }
    It "single-quotes empty string values" {
        [hashtable]$c = @{ s = @{ empty = [string]'' } }
        $r = ConvertTo-YamlConfig -Config $c
        $r | Should -Match "empty: ''"
    }
    It "double-quotes string values that look like YAML booleans" {
        [hashtable]$c = @{ s = @{ flag = [string]'yes' } }
        $r = ConvertTo-YamlConfig -Config $c
        # 'yes' as a string must be quoted to prevent YAML parsers reading it as true
        $r | Should -Match 'flag: "yes"'
    }
}

# ===========================================================================
# PHASE 6 — Invoke-ConfigMigration (integration)
# ===========================================================================
Describe "Invoke-ConfigMigration" {

    BeforeEach {
        $script:InputIni  = Join-Path $script:TempDir "in_$(Get-Random).ini"
        $script:OutJson   = Join-Path $script:TempDir "out_$(Get-Random).json"
        $script:OutYaml   = Join-Path $script:TempDir "out_$(Get-Random).yaml"
    }

    It "creates JSON and YAML output files" {
        Set-Content -Path $script:InputIni -Value "[database]`nhost = localhost`nport = 5432"
        [hashtable]$schema = @{
            database = @{
                required = [string[]]@('host', 'port')
                types    = @{ host = [string]'string'; port = [string]'int' }
            }
        }
        Invoke-ConfigMigration -InputPath $script:InputIni -Schema $schema `
            -JsonOutputPath $script:OutJson -YamlOutputPath $script:OutYaml
        Test-Path -Path $script:OutJson | Should -Be $true
        Test-Path -Path $script:OutYaml | Should -Be $true
    }

    It "throws when config fails schema validation" {
        Set-Content -Path $script:InputIni -Value "[database]`nhost = localhost"
        [hashtable]$schema = @{
            database = @{
                required = [string[]]@('host', 'port')   # port missing
                types    = @{}
            }
        }
        {
            Invoke-ConfigMigration -InputPath $script:InputIni -Schema $schema `
                -JsonOutputPath $script:OutJson -YamlOutputPath $script:OutYaml
        } | Should -Throw
    }

    It "produces valid, parseable JSON output" {
        Set-Content -Path $script:InputIni -Value "[app]`nname = MyApp`nversion = 1`ndebug = false"
        [hashtable]$schema = @{
            app = @{
                required = [string[]]@('name')
                types    = @{
                    name    = [string]'string'
                    version = [string]'int'
                    debug   = [string]'bool'
                }
            }
        }
        Invoke-ConfigMigration -InputPath $script:InputIni -Schema $schema `
            -JsonOutputPath $script:OutJson -YamlOutputPath $script:OutYaml
        [string]$json = Get-Content -Path $script:OutJson -Raw
        $parsed = $json | ConvertFrom-Json
        $parsed.app.name    | Should -Be 'MyApp'
        $parsed.app.version | Should -Be 1
        $parsed.app.debug   | Should -Be $false
    }

    It "produces non-empty YAML output" {
        Set-Content -Path $script:InputIni -Value "[app]`nname = Test`nport = 9000"
        [hashtable]$schema = @{
            app = @{
                required = [string[]]@('name')
                types    = @{ name = [string]'string'; port = [string]'int' }
            }
        }
        Invoke-ConfigMigration -InputPath $script:InputIni -Schema $schema `
            -JsonOutputPath $script:OutJson -YamlOutputPath $script:OutYaml
        [string]$yaml = Get-Content -Path $script:OutYaml -Raw
        $yaml | Should -Not -BeNullOrEmpty
        $yaml | Should -Match 'app:'
        $yaml | Should -Match 'name: Test'
        $yaml | Should -Match 'port: 9000'
    }
}

# ===========================================================================
# PHASE 7 — Fixture file edge-case tests
# ===========================================================================
Describe "Fixture Files - Edge Cases" {

    It "parses the basic fixture and returns a hashtable" {
        [string]$p = Join-Path $PSScriptRoot 'fixtures/basic.ini'
        $r = Read-IniFile -Path $p
        $r | Should -BeOfType [hashtable]
        $r.ContainsKey('database') | Should -Be $true
        $r.ContainsKey('server') | Should -Be $true
    }

    It "types fixture: int/bool/float/string values are correctly typed" {
        [string]$p = Join-Path $PSScriptRoot 'fixtures/types.ini'
        $r = Read-IniFile -Path $p
        [hashtable]$t = [hashtable]$r['types']
        $t['int_val']   | Should -BeOfType [int]
        $t['bool_true'] | Should -BeOfType [bool]
        $t['bool_true'] | Should -Be $true
        $t['float_val'] | Should -BeOfType [double]
        $t['str_val']   | Should -BeOfType [string]
    }

    It "comments fixture: no keys start with ; or #" {
        [string]$p = Join-Path $PSScriptRoot 'fixtures/comments.ini'
        $r = Read-IniFile -Path $p
        foreach ($key in $r.Keys) {
            [string]$key | Should -Not -Match '^[;#]'
            if ($r[$key] -is [hashtable]) {
                foreach ($subKey in ([hashtable]$r[$key]).Keys) {
                    [string]$subKey | Should -Not -Match '^[;#]'
                }
            }
        }
    }

    It "multiline fixture: backslash-continued value is joined" {
        [string]$p = Join-Path $PSScriptRoot 'fixtures/multiline.ini'
        $r = Read-IniFile -Path $p
        [hashtable]$lt = [hashtable]$r['longtext']
        [string]$desc = [string]$lt['description']
        $desc | Should -Match 'line1'
        $desc | Should -Match 'line2'
        $desc | Should -Match 'line3'
    }

    It "edge_cases fixture: empty value parses to empty string" {
        [string]$p = Join-Path $PSScriptRoot 'fixtures/edge_cases.ini'
        $r = Read-IniFile -Path $p
        [hashtable]$ev = [hashtable]$r['empty_values']
        $ev['empty_key'] | Should -Be ''
    }

    It "edge_cases fixture: negative number parses to int" {
        [string]$p = Join-Path $PSScriptRoot 'fixtures/edge_cases.ini'
        $r = Read-IniFile -Path $p
        [hashtable]$nums = [hashtable]$r['numbers']
        $nums['negative'] | Should -BeOfType [int]
        $nums['negative'] | Should -Be -5
    }

    It "edge_cases fixture: URL with port preserved as string" {
        [string]$p = Join-Path $PSScriptRoot 'fixtures/edge_cases.ini'
        $r = Read-IniFile -Path $p
        [hashtable]$sc = [hashtable]$r['special_chars']
        [string]$url = [string]$sc['url']
        $url | Should -Match 'http'
        $url | Should -Match '8080'
    }
}
