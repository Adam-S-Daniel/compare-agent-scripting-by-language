# ConfigMigrator.Tests.ps1
# TDD tests for INI config file migrator using Pester
# Approach: Red/Green/Refactor cycle - write failing test first, then implement

# Ensure we have Pester 5.x available
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version.Major -ge 5 })) {
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
}

# Import the module under test (will fail until ConfigMigrator.ps1 exists)
$modulePath = Join-Path $PSScriptRoot "ConfigMigrator.ps1"
. $modulePath

# ============================================================
# CYCLE 1: Basic INI parsing - sections and key-value pairs
# ============================================================
Describe "ConvertFrom-IniContent" {
    Context "Basic section and key-value parsing" {
        It "parses a simple INI string with one section" {
            $ini = @"
[database]
host = localhost
port = 5432
"@
            $result = ConvertFrom-IniContent -Content $ini
            $result | Should -Not -BeNullOrEmpty
            $result['database'] | Should -Not -BeNullOrEmpty
            $result['database']['host'] | Should -Be 'localhost'
            $result['database']['port'] | Should -Be '5432'
        }

        It "parses multiple sections" {
            $ini = @"
[server]
host = 0.0.0.0
port = 8080

[database]
name = mydb
"@
            $result = ConvertFrom-IniContent -Content $ini
            $result.Keys.Count | Should -Be 2
            $result['server']['host'] | Should -Be '0.0.0.0'
            $result['database']['name'] | Should -Be 'mydb'
        }

        It "handles keys without a section (global section)" {
            $ini = @"
version = 1.0
name = myapp

[section1]
key = value
"@
            $result = ConvertFrom-IniContent -Content $ini
            $result['__global__']['version'] | Should -Be '1.0'
            $result['__global__']['name'] | Should -Be 'myapp'
            $result['section1']['key'] | Should -Be 'value'
        }

        It "trims whitespace around keys and values" {
            $ini = @"
[section]
  key1  =  value1
key2=value2
"@
            $result = ConvertFrom-IniContent -Content $ini
            $result['section']['key1'] | Should -Be 'value1'
            $result['section']['key2'] | Should -Be 'value2'
        }
    }

    # ============================================================
    # CYCLE 2: Comment handling
    # ============================================================
    Context "Comment handling" {
        It "ignores lines starting with semicolon" {
            $ini = @"
[section]
; this is a comment
key = value
"@
            $result = ConvertFrom-IniContent -Content $ini
            $result['section'].Keys.Count | Should -Be 1
            $result['section']['key'] | Should -Be 'value'
        }

        It "ignores lines starting with hash" {
            $ini = @"
[section]
# this is also a comment
key = value
"@
            $result = ConvertFrom-IniContent -Content $ini
            $result['section'].Keys.Count | Should -Be 1
        }

        It "ignores inline comments after values" {
            $ini = @"
[section]
key = value ; inline comment
"@
            $result = ConvertFrom-IniContent -Content $ini
            $result['section']['key'] | Should -Be 'value'
        }

        It "ignores empty lines" {
            $ini = @"
[section]

key = value

other = data

"@
            $result = ConvertFrom-IniContent -Content $ini
            $result['section'].Keys.Count | Should -Be 2
        }
    }

    # ============================================================
    # CYCLE 3: Type coercion
    # ============================================================
    Context "Type coercion" {
        It "coerces integer strings to integers" {
            $ini = @"
[app]
port = 8080
count = 42
"@
            $result = ConvertFrom-IniContent -Content $ini -CoerceTypes
            $result['app']['port'] | Should -Be 8080
            $result['app']['port'] | Should -BeOfType [int]
        }

        It "coerces float strings to doubles" {
            $ini = @"
[app]
ratio = 3.14
threshold = 0.5
"@
            $result = ConvertFrom-IniContent -Content $ini -CoerceTypes
            $result['app']['ratio'] | Should -Be 3.14
            $result['app']['ratio'] | Should -BeOfType [double]
        }

        It "coerces 'true'/'false' strings to booleans" {
            $ini = @"
[features]
enabled = true
debug = false
verbose = True
"@
            $result = ConvertFrom-IniContent -Content $ini -CoerceTypes
            $result['features']['enabled'] | Should -Be $true
            $result['features']['enabled'] | Should -BeOfType [bool]
            $result['features']['debug'] | Should -Be $false
            $result['features']['verbose'] | Should -Be $true
        }

        It "coerces 'yes'/'no' strings to booleans" {
            $ini = @"
[features]
active = yes
inactive = no
"@
            $result = ConvertFrom-IniContent -Content $ini -CoerceTypes
            $result['features']['active'] | Should -Be $true
            $result['features']['inactive'] | Should -Be $false
        }

        It "leaves non-numeric strings as strings" {
            $ini = @"
[app]
name = myapp
host = localhost
"@
            $result = ConvertFrom-IniContent -Content $ini -CoerceTypes
            $result['app']['name'] | Should -Be 'myapp'
            $result['app']['name'] | Should -BeOfType [string]
        }
    }

    # ============================================================
    # CYCLE 4: Multi-line values
    # ============================================================
    Context "Multi-line values" {
        It "handles backslash line continuation" {
            $ini = @"
[section]
description = This is a long \
              description that \
              spans multiple lines
"@
            $result = ConvertFrom-IniContent -Content $ini
            $result['section']['description'] | Should -Be 'This is a long description that spans multiple lines'
        }

        It "handles quoted multi-line values" {
            $ini = @"
[section]
message = "Hello World"
"@
            $result = ConvertFrom-IniContent -Content $ini
            $result['section']['message'] | Should -Be 'Hello World'
        }
    }
}

# ============================================================
# CYCLE 5 & 6: Schema validation
# ============================================================
Describe "Test-ConfigSchema" {
    Context "Required key validation" {
        It "passes when all required keys are present" {
            $config = @{
                database = @{
                    host = 'localhost'
                    port = 5432
                    name = 'mydb'
                }
            }
            $schema = @{
                database = @{
                    required = @('host', 'port', 'name')
                    types    = @{}
                }
            }
            $result = Test-ConfigSchema -Config $config -Schema $schema
            $result.IsValid | Should -Be $true
            $result.Errors.Count | Should -Be 0
        }

        It "fails when required keys are missing" {
            $config = @{
                database = @{
                    host = 'localhost'
                }
            }
            $schema = @{
                database = @{
                    required = @('host', 'port', 'name')
                    types    = @{}
                }
            }
            $result = Test-ConfigSchema -Config $config -Schema $schema
            $result.IsValid | Should -Be $false
            $result.Errors.Count | Should -Be 2
        }

        It "reports missing section as an error" {
            $config = @{}
            $schema = @{
                database = @{
                    required = @('host')
                    types    = @{}
                }
            }
            $result = Test-ConfigSchema -Config $config -Schema $schema
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Contain "Missing required section: database"
        }
    }

    Context "Type validation" {
        It "validates integer type" {
            $config = @{
                server = @{
                    port = 'not-a-number'
                }
            }
            $schema = @{
                server = @{
                    required = @('port')
                    types    = @{ port = 'int' }
                }
            }
            $result = Test-ConfigSchema -Config $config -Schema $schema
            $result.IsValid | Should -Be $false
            $result.Errors[0] | Should -Match 'port'
        }

        It "validates boolean type" {
            $config = @{
                features = @{
                    enabled = 'maybe'
                }
            }
            $schema = @{
                features = @{
                    required = @('enabled')
                    types    = @{ enabled = 'bool' }
                }
            }
            $result = Test-ConfigSchema -Config $config -Schema $schema
            $result.IsValid | Should -Be $false
        }

        It "passes type validation for correct types" {
            $config = @{
                server = @{
                    port    = 8080
                    enabled = $true
                    name    = 'myserver'
                }
            }
            $schema = @{
                server = @{
                    required = @('port', 'enabled', 'name')
                    types    = @{
                        port    = 'int'
                        enabled = 'bool'
                        name    = 'string'
                    }
                }
            }
            $result = Test-ConfigSchema -Config $config -Schema $schema
            $result.IsValid | Should -Be $true
        }
    }
}

# ============================================================
# CYCLE 7: JSON output
# ============================================================
Describe "ConvertTo-ConfigJson" {
    It "converts config hashtable to valid JSON string" {
        $config = @{
            database = @{
                host = 'localhost'
                port = 5432
            }
        }
        $json = ConvertTo-ConfigJson -Config $config
        $json | Should -Not -BeNullOrEmpty
        $parsed = $json | ConvertFrom-Json
        $parsed.database.host | Should -Be 'localhost'
        $parsed.database.port | Should -Be 5432
    }

    It "outputs pretty-printed JSON by default" {
        $config = @{
            server = @{ host = '0.0.0.0' }
        }
        $json = ConvertTo-ConfigJson -Config $config
        # Pretty JSON has newlines
        $json | Should -Match "`n"
    }

    It "handles nested values correctly" {
        $config = @{
            __global__ = @{ version = '1.0' }
            section1   = @{ key = 'val'; num = 42 }
        }
        $json = ConvertTo-ConfigJson -Config $config
        $parsed = $json | ConvertFrom-Json
        $parsed.section1.num | Should -Be 42
    }
}

# ============================================================
# CYCLE 8: YAML output
# ============================================================
Describe "ConvertTo-ConfigYaml" {
    It "converts config hashtable to YAML string" {
        $config = @{
            database = @{
                host = 'localhost'
                port = 5432
            }
        }
        $yaml = ConvertTo-ConfigYaml -Config $config
        $yaml | Should -Not -BeNullOrEmpty
        $yaml | Should -Match 'database:'
        $yaml | Should -Match 'host:'
        $yaml | Should -Match 'localhost'
    }

    It "outputs valid YAML with proper indentation" {
        $config = @{
            server = @{
                host = '0.0.0.0'
                port = 8080
            }
        }
        $yaml = ConvertTo-ConfigYaml -Config $config
        # Nested keys should be indented
        $yaml | Should -Match '  host:'
        $yaml | Should -Match '  port:'
    }

    It "properly quotes string values that need quoting" {
        $config = @{
            app = @{
                name    = 'my app'
                version = '1.0.0'
            }
        }
        $yaml = ConvertTo-ConfigYaml -Config $config
        $yaml | Should -Match 'name:'
    }

    It "outputs boolean values as yaml booleans" {
        $config = @{
            features = @{
                enabled = $true
                debug   = $false
            }
        }
        $yaml = ConvertTo-ConfigYaml -Config $config
        $yaml | Should -Match 'true'
        $yaml | Should -Match 'false'
    }
}

# ============================================================
# Integration tests using fixture files
# ============================================================
Describe "Integration: Read INI file and export" {
    BeforeAll {
        # Create temp directory for test fixtures
        $script:tempDir = Join-Path $PSScriptRoot "fixtures"
        if (-not (Test-Path $script:tempDir)) {
            New-Item -ItemType Directory -Path $script:tempDir | Out-Null
        }

        # Write the basic test fixture
        $script:basicIniPath = Join-Path $script:tempDir "basic.ini"
        @"
; Basic configuration file
# Another comment style

[database]
host = localhost
port = 5432
name = mydb
enabled = true

[server]
host = 0.0.0.0
port = 8080
workers = 4
debug = false

[logging]
level = INFO
file = /var/log/app.log
max_size = 10485760
"@ | Set-Content -Path $script:basicIniPath

        # Write the edge-case fixture
        $script:edgeCaseIniPath = Join-Path $script:tempDir "edge_cases.ini"
        @"
; Edge cases fixture

version = 2.0
app_name = My Application

[database]
host = db.example.com
port = 5432
name = production_db
ssl = true
pool_size = 10
timeout = 30.5
; password is intentionally omitted

[cache]
enabled = yes
ttl = 3600
max_entries = 1000

[multiline]
description = This is a long \
              description that \
              spans multiple lines
addresses = 192.168.1.1 \
            192.168.1.2

[quoted]
message = "Hello, World!"
path = "/usr/local/bin"
"@ | Set-Content -Path $script:edgeCaseIniPath
    }

    It "reads INI file and parses it correctly" {
        $content = Get-Content -Path $script:basicIniPath -Raw
        $config = ConvertFrom-IniContent -Content $content -CoerceTypes
        $config['database']['host'] | Should -Be 'localhost'
        $config['database']['port'] | Should -Be 5432
        $config['database']['enabled'] | Should -Be $true
        $config['server']['workers'] | Should -Be 4
    }

    It "exports to JSON file" {
        $content = Get-Content -Path $script:basicIniPath -Raw
        $config = ConvertFrom-IniContent -Content $content -CoerceTypes
        $jsonPath = Join-Path $script:tempDir "basic.json"
        Export-ConfigAsJson -Config $config -Path $jsonPath
        Test-Path $jsonPath | Should -Be $true
        $json = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json
        $json.database.host | Should -Be 'localhost'
    }

    It "exports to YAML file" {
        $content = Get-Content -Path $script:basicIniPath -Raw
        $config = ConvertFrom-IniContent -Content $content -CoerceTypes
        $yamlPath = Join-Path $script:tempDir "basic.yaml"
        Export-ConfigAsYaml -Config $config -Path $yamlPath
        Test-Path $yamlPath | Should -Be $true
        $yaml = Get-Content -Path $yamlPath -Raw
        $yaml | Should -Match 'database:'
        $yaml | Should -Match 'localhost'
    }

    It "handles edge cases fixture correctly" {
        $content = Get-Content -Path $script:edgeCaseIniPath -Raw
        $config = ConvertFrom-IniContent -Content $content -CoerceTypes
        # Global keys
        $config['__global__']['version'] | Should -Be 2.0
        $config['__global__']['app_name'] | Should -Be 'My Application'
        # Type coercion
        $config['database']['ssl'] | Should -Be $true
        $config['database']['pool_size'] | Should -Be 10
        $config['database']['timeout'] | Should -Be 30.5
        # yes/no coercion
        $config['cache']['enabled'] | Should -Be $true
        # Multi-line
        $config['multiline']['description'] | Should -Match 'spans multiple lines'
    }

    It "validates config against schema" {
        $content = Get-Content -Path $script:basicIniPath -Raw
        $config = ConvertFrom-IniContent -Content $content -CoerceTypes
        $schema = @{
            database = @{
                required = @('host', 'port', 'name')
                types    = @{ port = 'int'; enabled = 'bool' }
            }
            server   = @{
                required = @('host', 'port')
                types    = @{ port = 'int'; workers = 'int' }
            }
        }
        $result = Test-ConfigSchema -Config $config -Schema $schema
        $result.IsValid | Should -Be $true
    }
}
