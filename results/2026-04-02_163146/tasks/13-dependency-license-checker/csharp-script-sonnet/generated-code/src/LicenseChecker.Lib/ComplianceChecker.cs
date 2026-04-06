// ComplianceChecker: applies allow/deny lists to determine each dependency's
// license status.  Uses ILicenseLookup so the real HTTP call can be swapped
// for a MockLicenseLookup during tests.

namespace LicenseChecker.Lib;

public class ComplianceChecker
{
    private readonly LicenseConfig _config;
    private readonly ILicenseLookup _lookup;

    public ComplianceChecker(LicenseConfig config, ILicenseLookup lookup)
    {
        _config = config;
        _lookup = lookup;
    }

    /// <summary>Check a single dependency against the configured allow/deny lists.</summary>
    public async Task<LicenseCheckResult> CheckAsync(Dependency dep)
    {
        var license = await _lookup.GetLicenseAsync(dep.Name, dep.Version);

        if (license is null)
        {
            return new LicenseCheckResult(
                dep.Name, dep.Version,
                License: null,
                Status: LicenseStatus.Unknown,
                Reason: "License information could not be found."
            );
        }

        // Normalise to upper-case for comparison
        var norm = license.ToUpperInvariant();

        if (_config.DenyList.Any(d => d.ToUpperInvariant() == norm))
        {
            return new LicenseCheckResult(
                dep.Name, dep.Version,
                License: license,
                Status: LicenseStatus.Denied,
                Reason: $"License '{license}' is on the deny list."
            );
        }

        if (_config.AllowList.Any(a => a.ToUpperInvariant() == norm))
        {
            return new LicenseCheckResult(
                dep.Name, dep.Version,
                License: license,
                Status: LicenseStatus.Approved,
                Reason: $"License '{license}' is on the allow list."
            );
        }

        return new LicenseCheckResult(
            dep.Name, dep.Version,
            License: license,
            Status: LicenseStatus.Unknown,
            Reason: $"License '{license}' is not on either the allow list or the deny list."
        );
    }

    /// <summary>Check all dependencies concurrently and return ordered results.</summary>
    public async Task<IReadOnlyList<LicenseCheckResult>> CheckAllAsync(
        IEnumerable<Dependency> dependencies)
    {
        var tasks = dependencies.Select(CheckAsync);
        var results = await Task.WhenAll(tasks);
        return results;
    }
}
