// TDD Round 1: Tests for parsing dependency manifests (package.json and requirements.txt)
// We start with the simplest case: parsing a package.json to extract dependency names and versions.

using Xunit;
using LicenseChecker;

namespace LicenseChecker.Tests;

public class ManifestParserTests
{
    // RED: First failing test - parse package.json with dependencies
    [Fact]
    public void ParsePackageJson_ExtractsDependencies()
    {
        var json = """
        {
            "name": "my-app",
            "version": "1.0.0",
            "dependencies": {
                "express": "^4.18.2",
                "lodash": "~4.17.21"
            },
            "devDependencies": {
                "jest": "^29.0.0"
            }
        }
        """;

        var deps = ManifestParser.ParsePackageJson(json);

        Assert.Equal(3, deps.Count);
        Assert.Contains(deps, d => d.Name == "express" && d.Version == "^4.18.2");
        Assert.Contains(deps, d => d.Name == "lodash" && d.Version == "~4.17.21");
        Assert.Contains(deps, d => d.Name == "jest" && d.Version == "^29.0.0");
    }

    // RED: package.json with no dependencies section
    [Fact]
    public void ParsePackageJson_NoDependencies_ReturnsEmpty()
    {
        var json = """
        {
            "name": "empty-app",
            "version": "1.0.0"
        }
        """;

        var deps = ManifestParser.ParsePackageJson(json);

        Assert.Empty(deps);
    }

    // RED: package.json with only devDependencies
    [Fact]
    public void ParsePackageJson_OnlyDevDependencies_ExtractsThem()
    {
        var json = """
        {
            "name": "dev-only",
            "devDependencies": {
                "typescript": "^5.0.0"
            }
        }
        """;

        var deps = ManifestParser.ParsePackageJson(json);

        Assert.Single(deps);
        Assert.Equal("typescript", deps[0].Name);
    }

    // RED: Parse requirements.txt format
    [Fact]
    public void ParseRequirementsTxt_ExtractsDependencies()
    {
        var content = """
        flask==2.3.0
        requests>=2.28.0
        numpy~=1.24.0
        # this is a comment
        pandas==2.0.1
        """;

        var deps = ManifestParser.ParseRequirementsTxt(content);

        Assert.Equal(4, deps.Count);
        Assert.Contains(deps, d => d.Name == "flask" && d.Version == "==2.3.0");
        Assert.Contains(deps, d => d.Name == "requests" && d.Version == ">=2.28.0");
        Assert.Contains(deps, d => d.Name == "numpy" && d.Version == "~=1.24.0");
        Assert.Contains(deps, d => d.Name == "pandas" && d.Version == "==2.0.1");
    }

    // RED: requirements.txt with blank lines and comments
    [Fact]
    public void ParseRequirementsTxt_IgnoresCommentsAndBlankLines()
    {
        var content = """
        # Main dependencies
        flask==2.3.0

        # Utils
        requests>=2.28.0

        """;

        var deps = ManifestParser.ParseRequirementsTxt(content);

        Assert.Equal(2, deps.Count);
    }

    // RED: requirements.txt with no version specifier
    [Fact]
    public void ParseRequirementsTxt_NoVersion_UsesLatest()
    {
        var content = "flask\n";

        var deps = ManifestParser.ParseRequirementsTxt(content);

        Assert.Single(deps);
        Assert.Equal("flask", deps[0].Name);
        Assert.Equal("*", deps[0].Version);
    }

    // RED: Invalid JSON throws meaningful error
    [Fact]
    public void ParsePackageJson_InvalidJson_ThrowsWithMessage()
    {
        var badJson = "not valid json {{{";

        var ex = Assert.Throws<ManifestParseException>(
            () => ManifestParser.ParsePackageJson(badJson));

        Assert.Contains("package.json", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    // RED: Auto-detect manifest format from filename
    [Fact]
    public void ParseManifest_DetectsPackageJson()
    {
        var json = """
        {
            "dependencies": { "express": "^4.0.0" }
        }
        """;

        var deps = ManifestParser.Parse("package.json", json);

        Assert.Single(deps);
        Assert.Equal("express", deps[0].Name);
    }

    [Fact]
    public void ParseManifest_DetectsRequirementsTxt()
    {
        var content = "flask==2.3.0\n";

        var deps = ManifestParser.Parse("requirements.txt", content);

        Assert.Single(deps);
        Assert.Equal("flask", deps[0].Name);
    }

    [Fact]
    public void ParseManifest_UnsupportedFormat_Throws()
    {
        var ex = Assert.Throws<ManifestParseException>(
            () => ManifestParser.Parse("Gemfile", "gem 'rails'"));

        Assert.Contains("unsupported", ex.Message, StringComparison.OrdinalIgnoreCase);
    }
}
