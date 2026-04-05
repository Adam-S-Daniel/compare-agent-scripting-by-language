// migrate.cs — INI Config File Migrator
// .NET 10 file-based app (top-level statements, no explicit Main/class required).
//
// Usage:
//   dotnet run --project migrate.csproj -- <input.ini> [options]
//
// Options:
//   --json <output.json>     Write JSON output to this file (default: stdout)
//   --yaml <output.yaml>     Write YAML output to this file (default: stdout)
//   --no-coerce              Disable automatic type coercion
//   --validate               Exit with error code 1 if the document is invalid
//
// Examples:
//   dotnet run --project migrate.csproj -- myapp.ini
//   dotnet run --project migrate.csproj -- myapp.ini --json out.json --yaml out.yaml
//   dotnet run --project migrate.csproj -- myapp.ini --validate

using ConfigMigratorLib;

// ── Parse command-line arguments ─────────────────────────────────────────────
if (args.Length == 0 || args[0] is "-h" or "--help")
{
    PrintHelp();
    return;
}

var inputFile   = args[0];
string? jsonOut = null;
string? yamlOut = null;
bool autoCoerce = true;
bool validate   = false;

for (int i = 1; i < args.Length; i++)
{
    switch (args[i])
    {
        case "--json"      : jsonOut    = args[++i]; break;
        case "--yaml"      : yamlOut    = args[++i]; break;
        case "--no-coerce" : autoCoerce = false;     break;
        case "--validate"  : validate   = true;      break;
        default:
            Console.Error.WriteLine($"[ERROR] Unknown option: {args[i]}");
            Environment.Exit(2);
            break;
    }
}

// ── Parse ─────────────────────────────────────────────────────────────────────
IniDocument doc;
try
{
    var parser = new IniParser();
    doc = parser.ParseFile(inputFile);
    Console.Error.WriteLine($"[INFO] Parsed '{inputFile}'");
    Console.Error.WriteLine($"       Global keys : {doc.GlobalSection.RawValues.Count}");
    Console.Error.WriteLine($"       Sections    : {doc.Sections.Count} ({string.Join(", ", doc.Sections.Keys)})");
}
catch (FileNotFoundException ex)
{
    Console.Error.WriteLine($"[ERROR] {ex.Message}");
    Environment.Exit(1);
    return;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"[ERROR] Failed to parse '{inputFile}': {ex.Message}");
    Environment.Exit(1);
    return;
}

// ── Validate (optional) ───────────────────────────────────────────────────────
if (validate)
{
    // Build a minimal schema from what's present (demonstrates the validation path).
    // In production you'd load this from a schema file.
    var schema = BuildSampleSchema(doc);
    var validator = new SchemaValidator();
    var result = validator.Validate(doc, schema);

    if (result.IsValid)
    {
        Console.Error.WriteLine("[INFO] Validation PASSED");
    }
    else
    {
        Console.Error.WriteLine("[WARN] Validation FAILED:");
        foreach (var err in result.Errors)
            Console.Error.WriteLine($"       • {err}");
    }
}

// ── Convert → JSON ────────────────────────────────────────────────────────────
var jsonConverter = new JsonOutputConverter(autoCoerce);
var jsonOutput = jsonConverter.Convert(doc);

if (jsonOut is not null)
{
    File.WriteAllText(jsonOut, jsonOutput);
    Console.Error.WriteLine($"[INFO] JSON written to '{jsonOut}'");
}
else
{
    Console.WriteLine("=== JSON OUTPUT ===");
    Console.WriteLine(jsonOutput);
}

// ── Convert → YAML ────────────────────────────────────────────────────────────
var yamlConverter = new YamlOutputConverter(autoCoerce);
var yamlOutput = yamlConverter.Convert(doc);

if (yamlOut is not null)
{
    File.WriteAllText(yamlOut, yamlOutput);
    Console.Error.WriteLine($"[INFO] YAML written to '{yamlOut}'");
}
else
{
    Console.WriteLine("=== YAML OUTPUT ===");
    Console.WriteLine(yamlOutput);
}

Console.Error.WriteLine("[INFO] Done.");

// ── Helpers ──────────────────────────────────────────────────────────────────

/// <summary>
/// Builds a permissive "all keys are optional string" schema just to demonstrate
/// the validation machinery.  In real use you would load this from a file.
/// </summary>
static IniSchema BuildSampleSchema(IniDocument doc)
{
    var sectionSchemas = new Dictionary<string, SectionSchema>();
    foreach (var (name, section) in doc.Sections)
    {
        var keys = section.RawValues.Keys
            .ToDictionary(k => k, k => new KeySchema { Name = k, Required = false });
        sectionSchemas[name] = new SectionSchema { Name = name, Keys = keys };
    }
    return new IniSchema { Sections = sectionSchemas };
}

static void PrintHelp()
{
    Console.WriteLine("""
        INI Config File Migrator — converts INI to JSON and YAML

        Usage:
          dotnet run --project migrate.csproj -- <input.ini> [options]

        Options:
          --json <file>    Save JSON output to <file>  (default: stdout)
          --yaml <file>    Save YAML output to <file>  (default: stdout)
          --no-coerce      Disable automatic type coercion (strings stay as strings)
          --validate       Validate the document and report errors
          -h, --help       Show this help message

        Examples:
          dotnet run --project migrate.csproj -- app.ini
          dotnet run --project migrate.csproj -- app.ini --json app.json --yaml app.yaml
          dotnet run --project migrate.csproj -- app.ini --validate
        """);
}
