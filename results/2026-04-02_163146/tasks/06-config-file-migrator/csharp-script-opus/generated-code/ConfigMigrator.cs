// ConfigMigrator — .NET 10 file-based app
// Reads an INI config file, validates against a schema, outputs JSON and YAML.
//
// Usage: dotnet run ConfigMigrator.cs <input.ini> [--schema schema.json] [--json output.json] [--yaml output.yaml]
//
// If no output files are specified, outputs both JSON and YAML to stdout.

#nullable enable
using System.Text.Json;

// --- Include library source files inline for file-based app execution ---
// In a real project these would be separate assemblies. For dotnet run <file>.cs
// we need everything in one compilation unit, so we reference the src/ files
// through the project. For standalone execution, the source is compiled together.

// Parse command-line arguments
if (args.Length < 1)
{
    Console.Error.WriteLine("Usage: dotnet run ConfigMigrator.cs <input.ini> [--schema schema.json] [--json output.json] [--yaml output.yaml]");
    Console.Error.WriteLine();
    Console.Error.WriteLine("Arguments:");
    Console.Error.WriteLine("  <input.ini>         Path to the INI configuration file to read");
    Console.Error.WriteLine("  --schema <file>     Optional JSON schema file for validation");
    Console.Error.WriteLine("  --json <file>       Write JSON output to file (default: stdout)");
    Console.Error.WriteLine("  --yaml <file>       Write YAML output to file (default: stdout)");
    return 1;
}

var inputPath = args[0];
string? schemaPath = null;
string? jsonOutputPath = null;
string? yamlOutputPath = null;

// Parse optional flags
for (int i = 1; i < args.Length; i++)
{
    switch (args[i])
    {
        case "--schema" when i + 1 < args.Length:
            schemaPath = args[++i];
            break;
        case "--json" when i + 1 < args.Length:
            jsonOutputPath = args[++i];
            break;
        case "--yaml" when i + 1 < args.Length:
            yamlOutputPath = args[++i];
            break;
        default:
            Console.Error.WriteLine($"Unknown argument: {args[i]}");
            return 1;
    }
}

// Read and parse the INI file
if (!File.Exists(inputPath))
{
    Console.Error.WriteLine($"Error: Input file not found: {inputPath}");
    return 1;
}

string iniContent;
try
{
    iniContent = File.ReadAllText(inputPath);
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Error reading input file: {ex.Message}");
    return 1;
}

var document = ConfigMigrator.IniParser.Parse(iniContent);
Console.Error.WriteLine($"Parsed INI file: {document.Sections.Count} section(s)");

// Load and validate schema if provided
ConfigMigrator.Schema? schema = null;
if (schemaPath != null)
{
    if (!File.Exists(schemaPath))
    {
        Console.Error.WriteLine($"Error: Schema file not found: {schemaPath}");
        return 1;
    }

    try
    {
        schema = ConfigMigrator.SchemaLoader.LoadFromFile(schemaPath);
        Console.Error.WriteLine($"Loaded schema: {schema.Rules.Count} rule(s)");
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"Error loading schema: {ex.Message}");
        return 1;
    }

    var validation = ConfigMigrator.SchemaValidator.Validate(document, schema);
    if (!validation.IsValid)
    {
        Console.Error.WriteLine("Schema validation failed:");
        foreach (var error in validation.Errors)
        {
            Console.Error.WriteLine($"  - {error}");
        }
        return 2;
    }
    Console.Error.WriteLine("Schema validation passed.");
}

// Generate JSON output
var json = ConfigMigrator.ConfigConverter.ToJson(document, schema);
if (jsonOutputPath != null)
{
    File.WriteAllText(jsonOutputPath, json);
    Console.Error.WriteLine($"JSON written to: {jsonOutputPath}");
}
else
{
    Console.WriteLine("=== JSON Output ===");
    Console.WriteLine(json);
}

// Generate YAML output
var yaml = ConfigMigrator.ConfigConverter.ToYaml(document, schema);
if (yamlOutputPath != null)
{
    File.WriteAllText(yamlOutputPath, yaml);
    Console.Error.WriteLine($"YAML written to: {yamlOutputPath}");
}
else
{
    Console.WriteLine("=== YAML Output ===");
    Console.WriteLine(yaml);
}

return 0;
