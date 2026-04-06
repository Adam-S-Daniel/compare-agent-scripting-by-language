// ILicenseLookup: abstracts the source of license information.
// Real implementations query npm registry, PyPI, etc.
// MockLicenseLookup is used in tests to avoid network calls.

namespace LicenseChecker.Lib;

/// <summary>Contract for resolving the SPDX license identifier of a package.</summary>
public interface ILicenseLookup
{
    /// <summary>
    /// Returns the SPDX license identifier (e.g. "MIT", "Apache-2.0") for the given
    /// package, or null if the license cannot be determined.
    /// </summary>
    Task<string?> GetLicenseAsync(string packageName, string version);
}

/// <summary>
/// In-memory mock implementation used in tests.
/// Populated via a dictionary of package → license mappings.
/// </summary>
public class MockLicenseLookup : ILicenseLookup
{
    private readonly IReadOnlyDictionary<string, string> _licenses;

    public MockLicenseLookup(Dictionary<string, string> licenses)
    {
        _licenses = licenses;
    }

    public Task<string?> GetLicenseAsync(string packageName, string version)
    {
        _licenses.TryGetValue(packageName, out var license);
        return Task.FromResult<string?>(license);
    }
}
