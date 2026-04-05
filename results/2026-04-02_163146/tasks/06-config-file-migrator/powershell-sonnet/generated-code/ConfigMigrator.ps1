# ConfigMigrator.ps1
# INI configuration file reader, validator, and exporter to JSON and YAML
#
# Architecture:
#   - ConvertFrom-IniContent : Parse INI text -> ordered hashtable of sections
#   - Test-ConfigSchema       : Validate parsed config against a schema definition
#   - ConvertTo-ConfigJson    : Serialize config hashtable to JSON string
#   - ConvertTo-ConfigYaml    : Serialize config hashtable to YAML string
#   - Export-ConfigAsJson     : Write JSON output to file
#   - Export-ConfigAsYaml     : Write YAML output to file

# ============================================================
# CYCLE 1 + 2 + 3 + 4: INI Parser
# ============================================================

function ConvertFrom-IniContent {
    <#
    .SYNOPSIS
        Parses INI-format text into a nested hashtable.
    .PARAMETER Content
        The raw INI text to parse.
    .PARAMETER CoerceTypes
        When set, automatically coerce string values to integers, doubles, or booleans.
    .OUTPUTS
        Ordered hashtable keyed by section name. Global (sectionless) keys go into '__global__'.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Content,

        [switch]$CoerceTypes
    )

    # Use ordered hashtable so insertion order is preserved in JSON/YAML output
    $config = [ordered]@{}
    $currentSection = '__global__'
    $config[$currentSection] = [ordered]@{}

    # Split content into lines, normalizing CRLF to LF
    $lines = $Content -replace "`r`n", "`n" -split "`n"

    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]

        # --- Handle backslash line continuation ---
        # Collect continuation lines before processing
        while ($line -match '\\$') {
            # Remove trailing backslash, trim leading whitespace from next line
            $line = $line -replace '\\$', ''
            $i++
            if ($i -lt $lines.Count) {
                $nextLine = $lines[$i].TrimStart()
                $line = $line + $nextLine
            }
        }

        # --- Skip empty lines ---
        if ([string]::IsNullOrWhiteSpace($line)) {
            $i++
            continue
        }

        # --- Skip full-line comments (# or ;) ---
        if ($line -match '^\s*[;#]') {
            $i++
            continue
        }

        # --- Section header: [SectionName] ---
        if ($line -match '^\s*\[([^\]]+)\]\s*$') {
            $currentSection = $Matches[1].Trim()
            if (-not $config.Contains($currentSection)) {
                $config[$currentSection] = [ordered]@{}
            }
            $i++
            continue
        }

        # --- Key = Value pair ---
        if ($line -match '^\s*([^=;#]+?)\s*=\s*(.*)$') {
            $key   = $Matches[1].Trim()
            $value = $Matches[2].Trim()

            # Strip inline comments: remove trailing ; ... or # ... unless inside quotes
            $value = Remove-InlineComment -Value $value

            # Strip surrounding quotes if present
            if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'`$") {
                $value = $Matches[1]
            }

            # Optionally coerce types
            if ($CoerceTypes) {
                $value = Invoke-TypeCoercion -Value $value
            }

            $config[$currentSection][$key] = $value
        }

        $i++
    }

    # Remove the global section if it is empty (no sectionless keys found)
    if ($config['__global__'].Count -eq 0) {
        $config.Remove('__global__')
    }

    return $config
}

# ============================================================
# Helper: Remove inline comments from a value string
# ============================================================
function Remove-InlineComment {
    [CmdletBinding()]
    param(
        [string]$Value
    )

    # If the value is quoted, leave it alone
    if ($Value -match '^".*"$' -or $Value -match "^'.*'`$") {
        return $Value
    }

    # Remove inline comment: requires at least one whitespace before ; or #
    # This prevents stripping # or ; that appear mid-value without surrounding spaces
    $stripped = $Value -replace '\s+[;#].*$', ''
    return $stripped.TrimEnd()
}

# ============================================================
# Helper: Coerce a string value to a more specific type
# ============================================================
function Invoke-TypeCoercion {
    [CmdletBinding()]
    param(
        [string]$Value
    )

    # Boolean: true/false (case-insensitive)
    if ($Value -match '^(true|false)$') {
        return [System.Convert]::ToBoolean($Value.ToLower())
    }

    # Boolean: yes/no (case-insensitive)
    if ($Value -match '^yes$') { return $true }
    if ($Value -match '^no$')  { return $false }

    # Integer (no decimal point)
    [int]$intVal = 0
    if ([int]::TryParse($Value, [ref]$intVal)) {
        return $intVal
    }

    # Double (has decimal point or exponent)
    [double]$dblVal = 0
    if ([double]::TryParse($Value,
            [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref]$dblVal)) {
        # Only promote to double if the original string contained a decimal point / exponent
        if ($Value -match '[.eE]') {
            return $dblVal
        }
    }

    # Default: leave as string
    return $Value
}

# ============================================================
# CYCLE 5 + 6: Schema Validator
# ============================================================

function Test-ConfigSchema {
    <#
    .SYNOPSIS
        Validates a parsed config hashtable against a schema definition.
    .PARAMETER Config
        The parsed config (output of ConvertFrom-IniContent — may be a Hashtable or OrderedDictionary).
    .PARAMETER Schema
        A hashtable describing the expected shape:
          @{
            sectionName = @{
              required = @('key1', 'key2')   # keys that must be present
              types    = @{ key1 = 'int'; key2 = 'bool'; key3 = 'string' }
            }
          }
    .OUTPUTS
        PSCustomObject with:
          .IsValid  [bool]    — $true if all checks passed
          .Errors   [string[]] — list of human-readable error messages
    #>
    [CmdletBinding()]
    param(
        # Accept both Hashtable and OrderedDictionary (produced by ConvertFrom-IniContent)
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Config,

        [Parameter(Mandatory)]
        [hashtable]$Schema
    )

    $errors = [System.Collections.Generic.List[string]]::new()

    foreach ($sectionName in $Schema.Keys) {
        $sectionSchema = $Schema[$sectionName]

        # --- Check section exists (IDictionary.Contains works for both Hashtable and OrderedDictionary) ---
        if (-not $Config.Contains($sectionName)) {
            $errors.Add("Missing required section: $sectionName")
            continue
        }

        # Cast section to IDictionary for uniform key access
        $section = [System.Collections.IDictionary]$Config[$sectionName]

        # --- Check required keys ---
        foreach ($requiredKey in $sectionSchema.required) {
            if (-not $section.Contains($requiredKey)) {
                $errors.Add("[$sectionName] Missing required key: $requiredKey")
            }
        }

        # --- Check value types ---
        if ($sectionSchema.types) {
            foreach ($keyName in $sectionSchema.types.Keys) {
                if (-not $section.Contains($keyName)) {
                    # Type mismatch only matters if the key is present
                    continue
                }

                $expectedType = $sectionSchema.types[$keyName]
                $actualValue  = $section[$keyName]
                $typeOk       = Test-ValueType -Value $actualValue -ExpectedType $expectedType

                if (-not $typeOk) {
                    $errors.Add("[$sectionName] Key '$keyName' expected type '$expectedType' but got value '$actualValue' ($(($actualValue.GetType()).Name))")
                }
            }
        }
    }

    return [PSCustomObject]@{
        IsValid = $errors.Count -eq 0
        Errors  = $errors.ToArray()
    }
}

# ============================================================
# Helper: Type check
# ============================================================
function Test-ValueType {
    [CmdletBinding()]
    param(
        $Value,
        [string]$ExpectedType
    )

    switch ($ExpectedType.ToLower()) {
        'int' {
            if ($Value -is [int] -or $Value -is [long]) { return $true }
            [int]$tmp = 0
            return [int]::TryParse([string]$Value, [ref]$tmp)
        }
        'float' {
            if ($Value -is [double] -or $Value -is [float]) { return $true }
            [double]$tmp = 0
            return [double]::TryParse([string]$Value, [ref]$tmp)
        }
        'bool' {
            if ($Value -is [bool]) { return $true }
            $strVal = [string]$Value
            return $strVal -match '^(true|false|yes|no|1|0)$'
        }
        'string' {
            return $true   # Everything can be a string
        }
        default {
            Write-Warning "Unknown expected type '$ExpectedType'; treating as string"
            return $true
        }
    }
}

# ============================================================
# CYCLE 7: JSON Exporter
# ============================================================

function ConvertTo-ConfigJson {
    <#
    .SYNOPSIS
        Converts a config hashtable to a pretty-printed JSON string.
    .PARAMETER Config
        The parsed config (Hashtable or OrderedDictionary).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Config
    )

    # ConvertTo-Json handles ordered hashtables and nested structures natively.
    # Depth 10 ensures deeply nested values are not truncated.
    return $Config | ConvertTo-Json -Depth 10
}

function Export-ConfigAsJson {
    <#
    .SYNOPSIS
        Writes a config hashtable to a JSON file.
    .PARAMETER Config
        The parsed config (Hashtable or OrderedDictionary).
    .PARAMETER Path
        Destination file path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Config,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $json = ConvertTo-ConfigJson -Config $Config
    $json | Set-Content -Path $Path -Encoding UTF8
    Write-Verbose "JSON config written to: $Path"
}

# ============================================================
# CYCLE 8: YAML Exporter (custom serializer — no external module needed)
# ============================================================

function ConvertTo-ConfigYaml {
    <#
    .SYNOPSIS
        Converts a config hashtable to a YAML string.
        Implements a lightweight YAML serializer without external dependencies.
    .PARAMETER Config
        The parsed config (Hashtable or OrderedDictionary).
    .PARAMETER IndentSize
        Number of spaces per indent level (default: 2).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Config,

        [int]$IndentSize = 2
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    Write-YamlObject -Object $Config -Lines $lines -Depth 0 -IndentSize $IndentSize
    return ($lines -join "`n") + "`n"
}

function Write-YamlObject {
    # Recursive helper that appends YAML lines for a given object.
    param(
        $Object,
        [System.Collections.Generic.List[string]]$Lines,
        [int]$Depth,
        [int]$IndentSize
    )

    $indent = ' ' * ($Depth * $IndentSize)

    if ($Object -is [System.Collections.IDictionary]) {
        foreach ($key in $Object.Keys) {
            $val = $Object[$key]
            if ($val -is [System.Collections.IDictionary]) {
                $Lines.Add("${indent}${key}:")
                Write-YamlObject -Object $val -Lines $Lines -Depth ($Depth + 1) -IndentSize $IndentSize
            }
            elseif ($val -is [System.Collections.IEnumerable] -and $val -isnot [string]) {
                $Lines.Add("${indent}${key}:")
                foreach ($item in $val) {
                    $itemStr = Format-YamlScalar -Value $item
                    $Lines.Add("${indent}  - $itemStr")
                }
            }
            else {
                $valStr = Format-YamlScalar -Value $val
                $Lines.Add("${indent}${key}: $valStr")
            }
        }
    }
    elseif ($Object -is [System.Collections.IEnumerable] -and $Object -isnot [string]) {
        foreach ($item in $Object) {
            $itemStr = Format-YamlScalar -Value $item
            $Lines.Add("${indent}- $itemStr")
        }
    }
    else {
        $Lines.Add("${indent}$(Format-YamlScalar -Value $Object)")
    }
}

function Format-YamlScalar {
    # Format a scalar value for YAML output.
    # Booleans -> true/false (lowercase), nulls -> null, strings -> quoted if needed.
    param($Value)

    if ($null -eq $Value)           { return 'null' }
    if ($Value -is [bool])          { return $Value.ToString().ToLower() }
    if ($Value -is [int])           { return [string]$Value }
    if ($Value -is [long])          { return [string]$Value }
    if ($Value -is [double])        { return [string]$Value }
    if ($Value -is [float])         { return [string]$Value }

    # String: quote if it contains special YAML characters or looks like a reserved word
    $str = [string]$Value
    $needsQuoting = $str -match '[:#\[\]{},&*!|>''"%@`]' `
                 -or $str -match '^\s' `
                 -or $str -match '\s$' `
                 -or $str -match '^(true|false|yes|no|null|~)$' `
                 -or $str -eq ''

    if ($needsQuoting) {
        # Escape any double-quotes inside the string
        $escaped = $str -replace '"', '\"'
        return "`"$escaped`""
    }

    return $str
}

function Export-ConfigAsYaml {
    <#
    .SYNOPSIS
        Writes a config hashtable to a YAML file.
    .PARAMETER Config
        The parsed config (Hashtable or OrderedDictionary).
    .PARAMETER Path
        Destination file path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Config,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $yaml = ConvertTo-ConfigYaml -Config $Config
    $yaml | Set-Content -Path $Path -Encoding UTF8
    Write-Verbose "YAML config written to: $Path"
}
