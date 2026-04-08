# ConfigMigrator.ps1
# INI -> JSON/YAML config file migrator
#
# TDD implementation order:
#   1. Parse-IniContent  — parse raw INI text into nested hashtable
#   2. Convert-IniValues — coerce string values to typed PS objects
#   3. Test-IniSchema    — validate a parsed config against a schema
#   4. ConvertTo-JsonOutput — serialize to JSON
#   5. ConvertTo-YamlOutput — serialize to hand-rolled YAML
#   6. Convert-IniToFormats — end-to-end pipeline (file -> JSON + YAML)

# =============================================================================
# ITERATION 1: Parse INI content
# =============================================================================

<#
.SYNOPSIS
    Parse INI-formatted text into a nested hashtable.

.DESCRIPTION
    Returns an ordered hashtable keyed by section name (empty string for global).
    Each section value is itself an ordered hashtable of key -> raw string value.

    Rules applied:
      - Lines starting with ; or # (after trimming) are comments → skipped
      - [SectionName] lines set the current section
      - key = value lines populate the current section
        • Only the first '=' is treated as delimiter; the rest of the value is kept
        • Inline ; comments are stripped (unless inside a quoted value)
        • Values are trimmed
      - Lines ending with \ are continuation lines — joined with the next line
#>
function Parse-IniContent {
    [CmdletBinding()]
    param(
        # AllowEmptyString so callers can pass "" for an empty config
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content
    )

    # Normalise line endings and split
    $lines = $Content -replace "`r`n", "`n" -split "`n"

    $result = [ordered]@{}
    $currentSection = ""
    $result[$currentSection] = [ordered]@{}

    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        $i++

        # --- Handle continuation lines (trailing backslash) ---
        while ($line -match '\\$') {
            $line = ($line -replace '\\$', '').TrimEnd()
            if ($i -lt $lines.Count) {
                $line = $line + " " + $lines[$i].Trim()
                $i++
            }
        }

        $trimmed = $line.Trim()

        # Skip blank lines and comment lines
        if ($trimmed -eq '' -or $trimmed -match '^[;#]') { continue }

        # Section header
        if ($trimmed -match '^\[(.+)\]$') {
            $currentSection = $Matches[1].Trim()
            if (-not $result.Contains($currentSection)) {
                $result[$currentSection] = [ordered]@{}
            }
            continue
        }

        # Key = value  (split on first '=' only)
        if ($trimmed -match '^([^=]+)=(.*)$') {
            $key   = $Matches[1].Trim()
            $value = $Matches[2].Trim()

            # Strip inline ; comment — but only when not inside quotes
            # Simple approach: find first unquoted ';'
            $value = Remove-InlineComment -Value $value

            $result[$currentSection][$key] = $value
        }
        # Lines that match neither section nor key=value are silently ignored
    }

    return $result
}

<#
.SYNOPSIS
    Remove an inline comment (after ';') from a value string.
    Respects quoted values so URLs like "key=value ; comment" are handled.
#>
function Remove-InlineComment {
    param([string]$Value)

    # If the value starts with a quote, find the closing quote first
    if ($Value -match '^"') {
        $closeIdx = $Value.IndexOf('"', 1)
        if ($closeIdx -gt 0) {
            return $Value.Substring(1, $closeIdx - 1)
        }
        return $Value.TrimStart('"')
    }

    # Otherwise strip from first unescaped ';'
    $idx = $Value.IndexOf(' ;')
    if ($idx -ge 0) {
        return $Value.Substring(0, $idx).TrimEnd()
    }
    return $Value
}

# =============================================================================
# ITERATION 2: Type coercion
# =============================================================================

<#
.SYNOPSIS
    Walk the parsed INI hashtable and coerce string values to native PS types.

.DESCRIPTION
    Coercion rules (applied in order):
      - "true" / "yes"  -> [bool] $true
      - "false" / "no"  -> [bool] $false
      - Integer strings -> [int]
      - Float strings   -> [double]
      - Anything else   -> [string] (unchanged)
#>
function Convert-IniValues {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$ParsedIni
    )

    $result = [ordered]@{}

    foreach ($section in $ParsedIni.Keys) {
        $result[$section] = [ordered]@{}
        foreach ($key in $ParsedIni[$section].Keys) {
            $result[$section][$key] = Coerce-Value -Raw $ParsedIni[$section][$key]
        }
    }

    return $result
}

function Coerce-Value {
    param([string]$Raw)

    # Boolean literals (case-insensitive)
    switch -Regex ($Raw) {
        '^(?i:true|yes)$'  { return $true  }
        '^(?i:false|no)$'  { return $false }
    }

    # Integer
    $intVal = 0
    if ([int]::TryParse($Raw, [ref]$intVal)) {
        return $intVal
    }

    # Float / double
    $dblVal = 0.0
    $styles = [System.Globalization.NumberStyles]::Float
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    if ([double]::TryParse($Raw, $styles, $culture, [ref]$dblVal)) {
        return $dblVal
    }

    return $Raw
}

# =============================================================================
# ITERATION 3: Schema validation
# =============================================================================

<#
.SYNOPSIS
    Validate a typed config hashtable against a schema.

.DESCRIPTION
    Schema format:
    @{
        sections = @{
            ""         = @{ required = @("key1"); types = @{ key2 = "int" } }
            "database" = @{ required = @("host","port"); types = @{ port = "int" } }
        }
    }

    Supported type names: "int", "bool", "string", "double"

.OUTPUTS
    A hashtable with:
      IsValid [bool]
      Errors  [string[]]
#>
function Test-IniSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Data,
        [Parameter(Mandatory)][hashtable]$Schema
    )

    $errors = [System.Collections.Generic.List[string]]::new()

    foreach ($section in $Schema.sections.Keys) {
        $sectionLabel = if ($section -eq "") { "[]" } else { "[$section]" }
        $sectionSchema = $Schema.sections[$section]
        $sectionData   = if ($Data.Contains($section)) { $Data[$section] } else { @{} }

        # Check required keys
        foreach ($requiredKey in $sectionSchema.required) {
            if (-not $sectionData.Contains($requiredKey)) {
                $errors.Add("${sectionLabel}: required key '$requiredKey' is missing")
            }
        }

        # Check type constraints for keys that are present
        if ($sectionSchema.ContainsKey('types')) {
            foreach ($key in $sectionSchema.types.Keys) {
                if (-not $sectionData.Contains($key)) { continue }

                $expectedType = $sectionSchema.types[$key]
                $actualValue  = $sectionData[$key]
                $typeOk       = Test-ValueType -Value $actualValue -TypeName $expectedType

                if (-not $typeOk) {
                    $errors.Add("${sectionLabel}: key '$key' must be of type '$expectedType', got '$actualValue'")
                }
            }
        }
    }

    return @{
        IsValid = ($errors.Count -eq 0)
        Errors  = $errors.ToArray()
    }
}

function Test-ValueType {
    param($Value, [string]$TypeName)
    switch ($TypeName) {
        "int"    { return ($Value -is [int]) }
        "bool"   { return ($Value -is [bool]) }
        "double" { return ($Value -is [double]) }
        "string" { return ($Value -is [string]) }
        default  { return $true }   # unknown type = no constraint
    }
}

# =============================================================================
# ITERATION 4: JSON output
# =============================================================================

<#
.SYNOPSIS
    Convert typed INI data to a JSON string.

.DESCRIPTION
    Global section keys (section = "") are promoted to the top level.
    Named sections become nested objects.
    Empty global section is omitted.
#>
function ConvertTo-JsonOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Data
    )

    $output = [ordered]@{}

    # Promote global keys
    if ($Data.Contains("") -and $Data[""].Count -gt 0) {
        foreach ($key in $Data[""].Keys) {
            $output[$key] = $Data[""][$key]
        }
    }

    # Add sections as nested objects
    foreach ($section in $Data.Keys) {
        if ($section -eq "") { continue }
        $output[$section] = [ordered]@{}
        foreach ($key in $Data[$section].Keys) {
            $output[$section][$key] = $Data[$section][$key]
        }
    }

    return $output | ConvertTo-Json -Depth 10
}

# =============================================================================
# ITERATION 5: YAML output (hand-rolled, no external dependency)
# =============================================================================

<#
.SYNOPSIS
    Convert typed INI data to a YAML string.

.DESCRIPTION
    Hand-rolled YAML serializer sufficient for flat key-value configs.
    Global section keys appear at the top level.
    Named sections become YAML mappings (indented with 2 spaces).

    Value rendering:
      - [bool]   → true / false
      - [int]    → unquoted integer
      - [double] → unquoted decimal
      - [string] → quoted if ambiguous (empty, looks like bool/number/special)
#>
function ConvertTo-YamlOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Data
    )

    $sb = [System.Text.StringBuilder]::new()

    # Global section first
    $globalSection = $Data[""]
    if ($Data.Contains("") -and $globalSection.Count -gt 0) {
        foreach ($key in $globalSection.Keys) {
            $val  = Format-YamlValue $globalSection[$key]
            $null = $sb.AppendLine("${key}: $val")
        }
    }

    # Named sections
    foreach ($section in $Data.Keys) {
        if ($section -eq "") { continue }
        $null = $sb.AppendLine("${section}:")
        foreach ($key in $Data[$section].Keys) {
            $null = $sb.AppendLine("  ${key}: $(Format-YamlValue $Data[$section][$key])")
        }
    }

    return $sb.ToString().TrimEnd()
}

function Format-YamlValue {
    param($Value)

    if ($Value -is [bool])   { if ($Value) { return "true" } else { return "false" } }
    if ($Value -is [int])    { return "$Value" }
    if ($Value -is [double]) { return "$Value" }

    # String — quote if it might be misread by a YAML parser:
    # empty, looks like bool, looks like number, contains : or # or leading/trailing space
    $s = [string]$Value
    $needsQuotes = (
        $s -eq "" -or
        $s -match '(?i)^(true|false|yes|no|null|~)$' -or
        $s -match '^\d+(\.\d+)?$' -or
        $s -match '^\s|\s$' -or
        $s -match '[:#]'
    )

    if ($needsQuotes) { return "'$($s -replace "'", "''")'" }
    return $s
}

# =============================================================================
# ITERATION 6: End-to-end pipeline
# =============================================================================

<#
.SYNOPSIS
    Read an INI file and produce JSON and YAML representations.

.PARAMETER Path
    Path to the INI file.

.PARAMETER Schema
    Optional schema hashtable for validation (see Test-IniSchema).

.OUTPUTS
    A hashtable with keys: Json, Yaml, Data, ValidationResult
#>
function Convert-IniToFormats {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [hashtable]$Schema
    )

    # Validate file existence with a meaningful error
    if (-not (Test-Path $Path)) {
        throw "Config file not found: '$Path'"
    }

    $content = Get-Content -Path $Path -Raw -Encoding UTF8

    # Pipeline: parse -> coerce -> (validate) -> serialize
    $raw   = Parse-IniContent  -Content $content
    $typed = Convert-IniValues -ParsedIni $raw

    $validationResult = $null
    if ($PSBoundParameters.ContainsKey('Schema')) {
        $validationResult = Test-IniSchema -Data $typed -Schema $Schema
        if (-not $validationResult.IsValid) {
            Write-Warning "Schema validation failed:`n$($validationResult.Errors -join "`n")"
        }
    }

    $json = ConvertTo-JsonOutput  -Data $typed
    $yaml = ConvertTo-YamlOutput  -Data $typed

    return @{
        Data             = $typed
        Json             = $json
        Yaml             = $yaml
        ValidationResult = $validationResult
    }
}
