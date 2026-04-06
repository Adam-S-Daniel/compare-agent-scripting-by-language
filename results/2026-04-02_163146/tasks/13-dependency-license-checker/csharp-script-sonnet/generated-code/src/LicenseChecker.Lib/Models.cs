// Core data models for the dependency license checker

namespace LicenseChecker.Lib;

/// <summary>A dependency extracted from a manifest file.</summary>
public record Dependency(string Name, string Version);

/// <summary>License compliance status for a dependency.</summary>
public enum LicenseStatus
{
    Approved,
    Denied,
    Unknown
}

/// <summary>Result of checking a single dependency's license.</summary>
public record LicenseCheckResult(
    string Name,
    string Version,
    string? License,
    LicenseStatus Status,
    string Reason
);

/// <summary>Configuration: which licenses are allowed or denied.</summary>
public record LicenseConfig(
    IReadOnlyList<string> AllowList,
    IReadOnlyList<string> DenyList
);

/// <summary>Full compliance report for a manifest scan.</summary>
public record ComplianceReport(
    string ManifestFile,
    DateTime GeneratedAt,
    IReadOnlyList<LicenseCheckResult> Results
)
{
    public int ApprovedCount => Results.Count(r => r.Status == LicenseStatus.Approved);
    public int DeniedCount  => Results.Count(r => r.Status == LicenseStatus.Denied);
    public int UnknownCount => Results.Count(r => r.Status == LicenseStatus.Unknown);
    public bool IsCompliant => DeniedCount == 0;
}
