// TDD RED phase: These tests are written BEFORE the implementation.
// Running `dotnet test` now would fail to compile because VersionParser
// and SemanticVersion do not exist yet. That is intentional — red before green.
// (Namespaces imported via GlobalUsings.cs: VersionBumper, Xunit)

namespace VersionBumper.Tests;

/// <summary>
/// Tests for VersionParser — parsing and updating semantic version files.
/// TDD iterations:
///   1. Parse plain version.txt  (RED → implement SemanticVersion + VersionParser)
///   2. Parse package.json       (RED → extend VersionParser)
///   3. Error handling           (RED → add validation)
///   4. Update version content   (RED → add UpdateContent)
///   5. File-based operations    (RED → add async file helpers)
/// </summary>
public class VersionParserTests
{
    // ─────────────────────────────────────────────────────
    // TDD Iteration 1: Parse version from a plain text file
    // ─────────────────────────────────────────────────────

    [Fact]
    public void Parse_SimpleVersionString_ReturnsParsedVersion()
    {
        var version = VersionParser.Parse("1.2.3", "version.txt");

        Assert.Equal(1, version.Major);
        Assert.Equal(2, version.Minor);
        Assert.Equal(3, version.Patch);
    }

    [Fact]
    public void Parse_VersionWithWhitespace_TrimsAndParses()
    {
        var version = VersionParser.Parse("  2.0.0  \n", "version.txt");

        Assert.Equal(2, version.Major);
        Assert.Equal(0, version.Minor);
        Assert.Equal(0, version.Patch);
    }

    [Fact]
    public void Parse_ZeroVersion_Parses()
    {
        var version = VersionParser.Parse("0.0.1", "version.txt");

        Assert.Equal(0, version.Major);
        Assert.Equal(0, version.Minor);
        Assert.Equal(1, version.Patch);
    }

    // ─────────────────────────────────────────────────────
    // TDD Iteration 2: Parse version from package.json
    // ─────────────────────────────────────────────────────

    [Fact]
    public void Parse_PackageJson_ExtractsVersionField()
    {
        var json = """
            {
              "name": "my-package",
              "version": "3.1.4",
              "description": "A test package"
            }
            """;

        var version = VersionParser.Parse(json, "package.json");

        Assert.Equal(3, version.Major);
        Assert.Equal(1, version.Minor);
        Assert.Equal(4, version.Patch);
    }

    [Fact]
    public void Parse_MinifiedPackageJson_ExtractsVersion()
    {
        var json = """{"name":"pkg","version":"0.5.2","dependencies":{}}""";

        var version = VersionParser.Parse(json, "package.json");

        Assert.Equal(0, version.Major);
        Assert.Equal(5, version.Minor);
        Assert.Equal(2, version.Patch);
    }

    // ─────────────────────────────────────────────────────
    // TDD Iteration 3: Error handling
    // ─────────────────────────────────────────────────────

    [Fact]
    public void Parse_InvalidVersionString_ThrowsFormatException()
    {
        Assert.Throws<FormatException>(() => VersionParser.Parse("not-a-version", "version.txt"));
    }

    [Fact]
    public void Parse_VersionWithTooFewParts_ThrowsFormatException()
    {
        Assert.Throws<FormatException>(() => VersionParser.Parse("1.2", "version.txt"));
    }

    [Fact]
    public void Parse_PackageJsonMissingVersion_ThrowsInvalidOperationException()
    {
        var json = """{"name": "pkg", "description": "no version here"}""";

        Assert.Throws<InvalidOperationException>(() => VersionParser.Parse(json, "package.json"));
    }

    // ─────────────────────────────────────────────────────
    // TDD Iteration 4: Update version in file content
    // ─────────────────────────────────────────────────────

    [Fact]
    public void UpdateContent_VersionTxt_ReplacesVersion()
    {
        var updated = VersionParser.UpdateContent("1.0.0", "version.txt", new SemanticVersion(2, 0, 0));

        Assert.Equal("2.0.0", updated);
    }

    [Fact]
    public void UpdateContent_PackageJson_UpdatesVersionField()
    {
        var json = """
            {
              "name": "pkg",
              "version": "1.0.0"
            }
            """;

        var updated = VersionParser.UpdateContent(json, "package.json", new SemanticVersion(1, 1, 0));
        var reparsed = VersionParser.Parse(updated, "package.json");

        Assert.Equal(new SemanticVersion(1, 1, 0), reparsed);
    }

    [Fact]
    public void UpdateContent_PackageJson_PreservesOtherFields()
    {
        var json = """{"name":"mypkg","version":"1.0.0","private":true}""";

        var updated = VersionParser.UpdateContent(json, "package.json", new SemanticVersion(2, 0, 0));

        Assert.Contains("mypkg", updated);
        Assert.Contains("private", updated);
    }

    // ─────────────────────────────────────────────────────
    // TDD Iteration 5: File-based async operations
    // ─────────────────────────────────────────────────────

    [Fact]
    public async Task ParseFileAsync_VersionTxtFile_ReturnsParsedVersion()
    {
        var tmpFile = Path.Combine(Path.GetTempPath(), $"{Guid.NewGuid()}.txt");
        try
        {
            await File.WriteAllTextAsync(tmpFile, "4.2.1");

            var version = await VersionParser.ParseFileAsync(tmpFile);

            Assert.Equal(4, version.Major);
            Assert.Equal(2, version.Minor);
            Assert.Equal(1, version.Patch);
        }
        finally
        {
            if (File.Exists(tmpFile)) File.Delete(tmpFile);
        }
    }

    [Fact]
    public async Task UpdateFileAsync_VersionTxtFile_WritesNewVersion()
    {
        var tmpFile = Path.Combine(Path.GetTempPath(), $"{Guid.NewGuid()}.txt");
        try
        {
            await File.WriteAllTextAsync(tmpFile, "1.0.0");

            await VersionParser.UpdateFileAsync(tmpFile, new SemanticVersion(1, 0, 1));
            var content = await File.ReadAllTextAsync(tmpFile);

            Assert.Equal("1.0.1", content.Trim());
        }
        finally
        {
            if (File.Exists(tmpFile)) File.Delete(tmpFile);
        }
    }
}
