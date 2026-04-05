// SchemaValidator.cs
// GREEN phase: validates an IniDocument against an IniSchema.
//
// Validation rules:
//   1. Required sections must be present.
//   2. Within present sections (required or optional), required keys must exist.
//   3. Present keys whose schema specifies a non-String type are coerced to
//      verify the raw value is convertible. On failure → validation error.

namespace ConfigMigratorLib;

/// <summary>
/// Validates an <see cref="IniDocument"/> against an <see cref="IniSchema"/>.
/// </summary>
public class SchemaValidator
{
    /// <summary>
    /// Runs all validation checks and returns a <see cref="ValidationResult"/>
    /// aggregating all errors found.  A document with no errors is considered valid.
    /// </summary>
    public ValidationResult Validate(IniDocument document, IniSchema schema)
    {
        var result = new ValidationResult();

        // Validate global (no-section) keys if a global schema is provided
        if (schema.GlobalSchema is not null)
            ValidateSection(document.GlobalSection, schema.GlobalSchema, result);

        foreach (var (sectionName, sectionSchema) in schema.Sections)
        {
            if (!document.HasSection(sectionName))
            {
                if (sectionSchema.Required)
                    result.Errors.Add(
                        $"Required section '[{sectionName}]' is missing from the document.");
                // Optional section absent → no error
                continue;
            }

            ValidateSection(document.Sections[sectionName], sectionSchema, result);
        }

        return result;
    }

    // -------------------------------------------------------------------------
    private static void ValidateSection(
        IniSection section, SectionSchema schema, ValidationResult result)
    {
        var sectionLabel = string.IsNullOrEmpty(section.Name)
            ? "global section"
            : $"[{section.Name}]";

        foreach (var (keyName, keySchema) in schema.Keys)
        {
            if (!section.HasKey(keyName))
            {
                if (keySchema.Required)
                    result.Errors.Add(
                        $"Required key '{keyName}' is missing from {sectionLabel}.");
                continue;
            }

            // Key is present — validate its type if not String
            if (keySchema.Type == IniValueType.String)
                continue;

            var rawValue = section.GetValue(keyName)!;
            try
            {
                TypeCoercer.Coerce(rawValue, keySchema.Type);
            }
            catch (FormatException ex)
            {
                result.Errors.Add(
                    $"Key '{keyName}' in {sectionLabel} has an invalid value: {ex.Message}");
            }
        }
    }
}
