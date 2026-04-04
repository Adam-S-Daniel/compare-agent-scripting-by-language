// Models.cs — data transfer objects for process monitoring
// These are plain data classes with no dependencies on live system state,
// making them trivially injectable and mockable in tests.

namespace ProcessMonitorLib.Models;

/// <summary>
/// Snapshot of a single process's resource usage at a point in time.
/// All values are set externally (from a provider), never read from Process directly.
/// </summary>
public sealed class ProcessInfo
{
    public int    Pid        { get; init; }
    public string Name       { get; init; } = string.Empty;
    public double CpuPercent { get; init; }   // 0–100 (per CPU core on some OSes)
    public double MemoryMb   { get; init; }   // Working set in megabytes
}

/// <summary>
/// Configurable thresholds that control what counts as a resource alert.
/// </summary>
public sealed class ThresholdConfig
{
    /// <summary>CPU usage percentage above which a process is flagged.</summary>
    public double CpuThresholdPercent { get; init; } = 80.0;

    /// <summary>Memory usage in MB above which a process is flagged.</summary>
    public double MemoryThresholdMb   { get; init; } = 1024.0;

    /// <summary>How many top consumers to include in the report.</summary>
    public int    TopN                { get; init; } = 5;
}

/// <summary>
/// A single alert entry for a process that exceeded a threshold.
/// </summary>
public sealed class ProcessAlert
{
    public int    Pid         { get; init; }
    public string ProcessName { get; init; } = string.Empty;
    public double Value       { get; init; }   // The offending metric value
    public double Threshold   { get; init; }   // The threshold that was exceeded
    public string Metric      { get; init; } = string.Empty; // "CPU" or "Memory"
}

/// <summary>
/// Aggregated summary counts for the report.
/// </summary>
public sealed class ReportSummary
{
    public int TotalProcessesScanned { get; init; }
    public int CpuAlertsCount        { get; init; }
    public int MemoryAlertsCount     { get; init; }
    public DateTime GeneratedAt      { get; init; } = DateTime.UtcNow;
}

/// <summary>
/// The full alert report produced by a single monitoring run.
/// </summary>
public sealed class AlertReport
{
    public required IReadOnlyList<ProcessAlert> CpuAlerts        { get; init; }
    public required IReadOnlyList<ProcessAlert> MemoryAlerts     { get; init; }
    public required IReadOnlyList<ProcessInfo>  TopCpuConsumers  { get; init; }
    public required IReadOnlyList<ProcessInfo>  TopMemoryConsumers { get; init; }
    public required ReportSummary              Summary           { get; init; }

    /// <summary>
    /// Formats the report as a human-readable text block.
    /// </summary>
    public string FormatAsText()
    {
        var sb = new System.Text.StringBuilder();
        sb.AppendLine("========================================");
        sb.AppendLine("  Process Monitor Alert Report");
        sb.AppendLine($"  Generated: {Summary.GeneratedAt:yyyy-MM-dd HH:mm:ss} UTC");
        sb.AppendLine("========================================");
        sb.AppendLine();

        sb.AppendLine($"Processes scanned : {Summary.TotalProcessesScanned}");
        sb.AppendLine($"CPU alerts        : {Summary.CpuAlertsCount}");
        sb.AppendLine($"Memory alerts     : {Summary.MemoryAlertsCount}");
        sb.AppendLine();

        sb.AppendLine("--- CPU Alerts ---");
        if (CpuAlerts.Count == 0)
        {
            sb.AppendLine("  (none)");
        }
        else
        {
            foreach (var a in CpuAlerts)
                sb.AppendLine($"  PID {a.Pid,6}  {a.ProcessName,-30}  CPU: {a.Value,6:F1}%  (threshold: {a.Threshold:F1}%)");
        }
        sb.AppendLine();

        sb.AppendLine("--- Memory Alerts ---");
        if (MemoryAlerts.Count == 0)
        {
            sb.AppendLine("  (none)");
        }
        else
        {
            foreach (var a in MemoryAlerts)
                sb.AppendLine($"  PID {a.Pid,6}  {a.ProcessName,-30}  Mem: {a.Value,8:F1} MB  (threshold: {a.Threshold:F1} MB)");
        }
        sb.AppendLine();

        sb.AppendLine("--- Top CPU Consumers ---");
        foreach (var p in TopCpuConsumers)
            sb.AppendLine($"  PID {p.Pid,6}  {p.Name,-30}  CPU: {p.CpuPercent,6:F1}%  Mem: {p.MemoryMb,8:F1} MB");
        sb.AppendLine();

        sb.AppendLine("--- Top Memory Consumers ---");
        foreach (var p in TopMemoryConsumers)
            sb.AppendLine($"  PID {p.Pid,6}  {p.Name,-30}  CPU: {p.CpuPercent,6:F1}%  Mem: {p.MemoryMb,8:F1} MB");

        return sb.ToString();
    }
}
