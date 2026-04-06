// FileLoader.cs - Loads test result files with automatic format detection.
// TDD Round 6 GREEN: Implements file loading to satisfy FileLoaderTests.

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

public enum TestFileFormat
{
    JUnitXml,
    Json
}

/// <summary>
/// Loads test result files from disk, auto-detecting format from the file extension,
/// and delegates to the appropriate parser.
/// </summary>
public static class FileLoader
{
    private static readonly string[] SupportedExtensions = [".xml", ".json"];

    /// <summary>Detects the test result format from the file extension.</summary>
    public static TestFileFormat DetectFormat(string filePath)
    {
        var ext = Path.GetExtension(filePath).ToLowerInvariant();
        return ext switch
        {
            ".xml" => TestFileFormat.JUnitXml,
            ".json" => TestFileFormat.Json,
            _ => throw new TestResultParseException(
                $"Unsupported file format '{ext}' for file '{filePath}'. Supported: .xml (JUnit), .json")
        };
    }

    /// <summary>Loads a single test result file, auto-detecting its format.</summary>
    public static TestRun LoadFile(string filePath)
    {
        if (!File.Exists(filePath))
        {
            throw new TestResultParseException($"Test result file not found: {filePath}");
        }

        var format = DetectFormat(filePath);
        var content = File.ReadAllText(filePath);
        // Use the filename (without extension) as the run label
        var label = Path.GetFileNameWithoutExtension(filePath);

        return format switch
        {
            TestFileFormat.JUnitXml => JUnitParser.Parse(content, label),
            TestFileFormat.Json => JsonTestParser.Parse(content, label),
            _ => throw new TestResultParseException($"Unknown format: {format}")
        };
    }

    /// <summary>Loads all supported test result files from a directory.</summary>
    public static List<TestRun> LoadDirectory(string directoryPath)
    {
        if (!Directory.Exists(directoryPath))
        {
            throw new TestResultParseException($"Directory not found: {directoryPath}");
        }

        var files = SupportedExtensions
            .SelectMany(ext => Directory.GetFiles(directoryPath, $"*{ext}"))
            .OrderBy(f => f)
            .ToList();

        if (files.Count == 0)
        {
            throw new TestResultParseException(
                $"No supported test result files found in '{directoryPath}'. Supported: {string.Join(", ", SupportedExtensions)}");
        }

        var runs = new List<TestRun>();
        var errors = new List<string>();

        foreach (var file in files)
        {
            try
            {
                runs.Add(LoadFile(file));
            }
            catch (TestResultParseException ex)
            {
                errors.Add($"  - {Path.GetFileName(file)}: {ex.Message}");
            }
        }

        if (runs.Count == 0 && errors.Count > 0)
        {
            throw new TestResultParseException(
                $"All files in '{directoryPath}' failed to parse:\n{string.Join("\n", errors)}");
        }

        // Log warnings for partial failures (non-fatal)
        if (errors.Count > 0)
        {
            Console.Error.WriteLine($"Warning: {errors.Count} file(s) failed to parse:");
            foreach (var err in errors)
                Console.Error.WriteLine(err);
        }

        return runs;
    }
}
