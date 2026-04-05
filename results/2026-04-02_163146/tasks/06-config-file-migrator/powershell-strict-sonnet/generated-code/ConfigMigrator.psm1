# ConfigMigrator.psm1
# INI -> JSON/YAML configuration file migrator
# Uses strict mode throughout for correctness.
Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Parses INI-format text into a nested hashtable.
.DESCRIPTION
    Sections become top-level keys. Keys without a section go under '__global__'.
    Comments (lines starting with ; or #) are ignored.
    Inline comments (text after ' ;') are stripped.
    Multi-line values (line ending with \) are joined.
.PARAMETER Content
    The raw INI text to parse.
.OUTPUTS
    [hashtable]  Section -> (Key -> raw string value)
#>
function ConvertFrom-IniContent {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string]$Content
    )

    # Result: section -> hashtable of key/value
    [hashtable]$result = @{}
    [string]$currentSection = '__global__'
    $result[$currentSection] = @{}

    # Accumulator for multi-line values
    [string]$pendingKey   = ''
    [string]$pendingValue = ''
    [bool]$inContinuation = $false

    [string[]]$lines = $Content -split "`r?`n"

    foreach ($rawLine in $lines) {
        [string]$line = $rawLine.TrimEnd()

        # Handle continuation from previous line
        if ($inContinuation) {
            # Strip leading whitespace on continuation lines
            [string]$trimmed = $line.TrimStart()

            if ($trimmed.EndsWith('\')) {
                # Still more continuation
                $pendingValue += ' ' + $trimmed.Substring(0, $trimmed.Length - 1).TrimEnd()
            } else {
                # Last continuation line
                $pendingValue += ' ' + $trimmed
                $inContinuation = $false
                $result[$currentSection][$pendingKey] = $pendingValue
                $pendingKey   = ''
                $pendingValue = ''
            }
            continue
        }

        # Skip blank lines
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        # Skip comment lines (starting with ; or #)
        [string]$trimmedLine = $line.TrimStart()
        if ($trimmedLine.StartsWith(';') -or $trimmedLine.StartsWith('#')) { continue }

        # Section header [SectionName]
        if ($trimmedLine -match '^\[([^\]]+)\]') {
            $currentSection = $Matches[1].Trim()
            if (-not $result.ContainsKey($currentSection)) {
                $result[$currentSection] = @{}
            }
            continue
        }

        # Key=value pair
        if ($trimmedLine -match '^([^=]+)=(.*)$') {
            [string]$key   = $Matches[1].Trim()
            [string]$value = $Matches[2]

            # Strip inline comment (space + semicolon)
            $inlineCommentMatch = [regex]::Match($value, '\s+;.*$')
            if ($inlineCommentMatch.Success) {
                $value = $value.Substring(0, $inlineCommentMatch.Index)
            }
            $value = $value.Trim()

            # Check for line continuation
            if ($value.EndsWith('\')) {
                $pendingKey   = $key
                $pendingValue = $value.Substring(0, $value.Length - 1).TrimEnd()
                $inContinuation = $true
            } else {
                $result[$currentSection][$key] = $value
            }
            continue
        }
    }

    # If file ended mid-continuation, flush it
    if ($inContinuation -and $pendingKey -ne '') {
        $result[$currentSection][$pendingKey] = $pendingValue
    }

    return $result
}

<#
.SYNOPSIS
    Coerces a raw INI string value to the most appropriate PowerShell type.
.DESCRIPTION
    'true'/'false' (case-insensitive) -> [bool]
    Integer strings                   -> [int]
    Float strings                     -> [double]
    Everything else                   -> [string]
.PARAMETER Value
    The raw string value to coerce.
.OUTPUTS
    [object]  The coerced value.
#>
function Invoke-TypeCoercion {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [string]$Value
    )

    # Boolean check (case-insensitive)
    if ($Value -ieq 'true')  { return [bool]$true  }
    if ($Value -ieq 'false') { return [bool]$false }

    # Integer check
    [int]$intOut = 0
    if ([int]::TryParse($Value, [ref]$intOut)) {
        return [int]$intOut
    }

    # Double/float check
    [double]$dblOut = 0.0
    $invariant = [System.Globalization.CultureInfo]::InvariantCulture
    if ([double]::TryParse($Value, [System.Globalization.NumberStyles]::Float, $invariant, [ref]$dblOut)) {
        return [double]$dblOut
    }

    # Default: plain string
    return [string]$Value
}

<#
.SYNOPSIS
    Validates a parsed INI hashtable against a schema definition.
.DESCRIPTION
    Schema is a hashtable mapping section names to a hashtable with key 'Required'
    containing an array of required key names.
    Throws a descriptive error if validation fails.
.PARAMETER ParsedIni
    The parsed INI hashtable (output of ConvertFrom-IniContent).
.PARAMETER Schema
    A schema hashtable, e.g.:
        @{ 'database' = @{ Required = @('host','port') } }
.OUTPUTS
    [void]
#>
function Test-IniSchema {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [hashtable]$ParsedIni,
        [hashtable]$Schema
    )

    foreach ($section in $Schema.Keys) {
        # Check that the section exists
        if (-not $ParsedIni.ContainsKey($section)) {
            throw "Schema validation failed: required section '[$section]' is missing from the INI file."
        }

        [hashtable]$sectionDef = [hashtable]$Schema[$section]

        if ($sectionDef.ContainsKey('Required')) {
            [string[]]$requiredKeys = [string[]]$sectionDef['Required']
            foreach ($key in $requiredKeys) {
                if (-not $ParsedIni[$section].ContainsKey($key)) {
                    throw "Schema validation failed: required key '$key' is missing from section '[$section]'."
                }
            }
        }
    }
}

<#
.SYNOPSIS
    Converts a parsed INI hashtable to a JSON string with type coercion.
.PARAMETER ParsedIni
    The parsed INI hashtable.
.OUTPUTS
    [string]  JSON text.
#>
function ConvertTo-JsonConfig {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [hashtable]$ParsedIni
    )

    [hashtable]$output = @{}

    foreach ($section in $ParsedIni.Keys) {
        # Rename __global__ -> global for clean JSON
        [string]$jsonSection = if ($section -eq '__global__') { 'global' } else { $section }
        [hashtable]$sectionOut = @{}

        foreach ($key in $ParsedIni[$section].Keys) {
            $sectionOut[$key] = Invoke-TypeCoercion -Value ([string]$ParsedIni[$section][$key])
        }

        $output[$jsonSection] = $sectionOut
    }

    return $output | ConvertTo-Json -Depth 10
}

<#
.SYNOPSIS
    Converts a parsed INI hashtable to a YAML string with type coercion.
.DESCRIPTION
    Produces simple block-style YAML without external dependencies.
    Strings are quoted only when they contain YAML-special characters.
.PARAMETER ParsedIni
    The parsed INI hashtable.
.OUTPUTS
    [string]  YAML text.
#>
function ConvertTo-YamlConfig {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [hashtable]$ParsedIni
    )

    # Characters that force quoting in YAML values
    [string[]]$yamlSpecial = @(':', '{', '}', '[', ']', ',', '#', '&', '*', '?', '|', '-', '<', '>', '=', '!', '%', '@', '`')

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    # Helper: format a coerced value as YAML scalar
    $FormatYamlValue = {
        param([object]$Val)

        if ($Val -is [bool]) {
            # YAML booleans are lowercase unquoted
            return $(if ([bool]$Val) { 'true' } else { 'false' })
        }

        if ($Val -is [int] -or $Val -is [double]) {
            return [string]$Val
        }

        # String — check if quoting is needed
        [string]$str = [string]$Val
        [bool]$needsQuote = $false
        foreach ($ch in $yamlSpecial) {
            if ($str.Contains($ch)) {
                $needsQuote = $true
                break
            }
        }
        if ($needsQuote) {
            # Escape any single quotes inside, then wrap
            $str = $str.Replace("'", "''")
            return "'$str'"
        }
        return $str
    }

    foreach ($section in ($ParsedIni.Keys | Sort-Object)) {
        [string]$yamlSection = if ($section -eq '__global__') { 'global' } else { $section }
        [void]$sb.AppendLine("${yamlSection}:")

        foreach ($key in ($ParsedIni[$section].Keys | Sort-Object)) {
            $coerced = Invoke-TypeCoercion -Value ([string]$ParsedIni[$section][$key])
            [string]$yamlVal = & $FormatYamlValue $coerced
            [void]$sb.AppendLine("  ${key}: ${yamlVal}")
        }
    }

    return $sb.ToString()
}

<#
.SYNOPSIS
    End-to-end migration: reads an INI file, validates it, writes JSON and YAML.
.PARAMETER IniPath
    Path to the source INI file.
.PARAMETER JsonOutputPath
    Path where the JSON output file will be written.
.PARAMETER YamlOutputPath
    Path where the YAML output file will be written.
.PARAMETER Schema
    Optional validation schema hashtable.
.OUTPUTS
    [void]
#>
function Invoke-ConfigMigration {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [string]$IniPath,
        [string]$JsonOutputPath,
        [string]$YamlOutputPath,
        [hashtable]$Schema = @{}
    )

    if (-not (Test-Path $IniPath)) {
        throw "INI file not found: $IniPath"
    }

    [string]$content   = Get-Content -Path $IniPath -Raw -Encoding UTF8
    [hashtable]$parsed = ConvertFrom-IniContent -Content $content

    # Validate if schema provided
    if ($Schema.Count -gt 0) {
        Test-IniSchema -ParsedIni $parsed -Schema $Schema
    }

    [string]$json = ConvertTo-JsonConfig -ParsedIni $parsed
    [string]$yaml = ConvertTo-YamlConfig -ParsedIni $parsed

    Set-Content -Path $JsonOutputPath -Value $json -Encoding UTF8
    Set-Content -Path $YamlOutputPath -Value $yaml -Encoding UTF8

    Write-Verbose "Migration complete. JSON -> $JsonOutputPath | YAML -> $YamlOutputPath"
}

Export-ModuleMember -Function ConvertFrom-IniContent, Invoke-TypeCoercion, Test-IniSchema, ConvertTo-JsonConfig, ConvertTo-YamlConfig, Invoke-ConfigMigration
