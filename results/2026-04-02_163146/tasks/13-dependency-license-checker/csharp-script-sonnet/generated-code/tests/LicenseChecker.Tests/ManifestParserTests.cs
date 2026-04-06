// RED PHASE: First failing tests for manifest parsing
// These tests will fail until we implement the ManifestParser class

using LicenseChecker.Lib;
using Xunit;

namespace LicenseChecker.Tests;

public class ManifestParserTests
{
    // Test 1: Parse package.json and extract dependencies with versions
    [Fact]
    public void ParsePackageJson_ExtractsDependenciesWithVersions()
    {
        var json = """
        {
            "name": "my-app",
            "version": "1.0.0",
            "dependencies": {
                "express": "^4.18.2",
                "lodash": "^4.17.21"
            },
            "devDependencies": {
                "jest": "^29.0.0"
            }
        }
        """;

        var parser = new ManifestParser();
        var deps = parser.ParsePackageJson(json);

        Assert.Equal(3, deps.Count);
        Assert.Contains(deps, d => d.Name == "express" && d.Version == "^4.18.2");
        Assert.Contains(deps, d => d.Name == "lodash" && d.Version == "^4.17.21");
        Assert.Contains(deps, d => d.Name == "jest" && d.Version == "^29.0.0");
    }

    // Test 2: Parse requirements.txt and extract dependencies
    [Fact]
    public void ParseRequirementsTxt_ExtractsDependenciesWithVersions()
    {
        var content = """
        requests==2.28.1
        flask>=2.0.0
        numpy~=1.24.0
        # This is a comment
        pytest==7.2.0
        """;

        var parser = new ManifestParser();
        var deps = parser.ParseRequirementsTxt(content);

        Assert.Equal(4, deps.Count);
        Assert.Contains(deps, d => d.Name == "requests" && d.Version == "2.28.1");
        Assert.Contains(deps, d => d.Name == "flask" && d.Version == ">=2.0.0");
        Assert.Contains(deps, d => d.Name == "numpy" && d.Version == "~=1.24.0");
        Assert.Contains(deps, d => d.Name == "pytest" && d.Version == "7.2.0");
    }

    // Test 3: Handle empty package.json gracefully
    [Fact]
    public void ParsePackageJson_EmptyDependencies_ReturnsEmptyList()
    {
        var json = """{"name": "empty-app"}""";

        var parser = new ManifestParser();
        var deps = parser.ParsePackageJson(json);

        Assert.Empty(deps);
    }

    // Test 4: Auto-detect manifest format from file content
    [Fact]
    public void DetectAndParse_PackageJson_ReturnsCorrectDependencies()
    {
        var json = """
        {
            "name": "test-app",
            "dependencies": {
                "react": "^18.2.0"
            }
        }
        """;

        var parser = new ManifestParser();
        var deps = parser.DetectAndParse(json, "package.json");

        Assert.Single(deps);
        Assert.Equal("react", deps[0].Name);
    }
}
