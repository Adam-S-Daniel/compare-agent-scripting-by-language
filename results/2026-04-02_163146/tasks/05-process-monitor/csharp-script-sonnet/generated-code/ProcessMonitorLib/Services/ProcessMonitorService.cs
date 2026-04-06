// ProcessMonitorService.cs — core business logic
//
// TDD Green phase: minimum implementation to satisfy all tests.
// No direct dependency on System.Diagnostics.Process — callers inject
// process data via IProcessProvider or plain IEnumerable<ProcessInfo>.
//
// Responsibilities:
//   1. Filter processes by CPU/memory thresholds
//   2. Rank top N consumers
//   3. Compose and return an AlertReport

using ProcessMonitorLib.Models;

namespace ProcessMonitorLib.Services;

public sealed class ProcessMonitorService
{
    // ----------------------------------------------------------------
    // Filtering — returns processes strictly ABOVE the threshold
    // ----------------------------------------------------------------

    public List<ProcessInfo> FilterByCpu(
        IEnumerable<ProcessInfo> processes,
        double cpuThreshold)
        => processes.Where(p => p.CpuPercent > cpuThreshold).ToList();

    public List<ProcessInfo> FilterByMemory(
        IEnumerable<ProcessInfo> processes,
        double memoryThresholdMb)
        => processes.Where(p => p.MemoryMb > memoryThresholdMb).ToList();

    // ----------------------------------------------------------------
    // Ranking — top N, sorted descending by the chosen metric
    // ----------------------------------------------------------------

    public List<ProcessInfo> GetTopCpuConsumers(
        IEnumerable<ProcessInfo> processes,
        int topN)
        => processes
            .OrderByDescending(p => p.CpuPercent)
            .Take(topN)
            .ToList();

    public List<ProcessInfo> GetTopMemoryConsumers(
        IEnumerable<ProcessInfo> processes,
        int topN)
        => processes
            .OrderByDescending(p => p.MemoryMb)
            .Take(topN)
            .ToList();

    // ----------------------------------------------------------------
    // Validation — called before using a ThresholdConfig
    // ----------------------------------------------------------------

    /// <summary>
    /// Validates a ThresholdConfig. Throws ArgumentException on invalid values.
    /// </summary>
    public void ValidateConfig(ThresholdConfig config)
    {
        if (config.CpuThresholdPercent < 0)
            throw new ArgumentException(
                $"CpuThresholdPercent must be >= 0, got {config.CpuThresholdPercent}.",
                nameof(config));

        if (config.MemoryThresholdMb < 0)
            throw new ArgumentException(
                $"MemoryThresholdMb must be >= 0, got {config.MemoryThresholdMb}.",
                nameof(config));

        if (config.TopN <= 0)
            throw new ArgumentException(
                $"TopN must be >= 1, got {config.TopN}.",
                nameof(config));
    }

    // ----------------------------------------------------------------
    // Report generation — composes the full AlertReport
    // ----------------------------------------------------------------

    /// <summary>
    /// Scans <paramref name="processes"/> against <paramref name="config"/> thresholds
    /// and returns a complete AlertReport with alerts and top-N rankings.
    /// </summary>
    public AlertReport GenerateReport(
        IEnumerable<ProcessInfo> processes,
        ThresholdConfig config)
    {
        ValidateConfig(config);

        var processList = processes.ToList(); // materialise once

        // Build CPU alerts
        var cpuAlerts = processList
            .Where(p => p.CpuPercent > config.CpuThresholdPercent)
            .OrderByDescending(p => p.CpuPercent)
            .Select(p => new ProcessAlert
            {
                Pid         = p.Pid,
                ProcessName = p.Name,
                Value       = p.CpuPercent,
                Threshold   = config.CpuThresholdPercent,
                Metric      = "CPU",
            })
            .ToList();

        // Build memory alerts
        var memAlerts = processList
            .Where(p => p.MemoryMb > config.MemoryThresholdMb)
            .OrderByDescending(p => p.MemoryMb)
            .Select(p => new ProcessAlert
            {
                Pid         = p.Pid,
                ProcessName = p.Name,
                Value       = p.MemoryMb,
                Threshold   = config.MemoryThresholdMb,
                Metric      = "Memory",
            })
            .ToList();

        return new AlertReport
        {
            CpuAlerts          = cpuAlerts,
            MemoryAlerts       = memAlerts,
            TopCpuConsumers    = GetTopCpuConsumers(processList, config.TopN),
            TopMemoryConsumers = GetTopMemoryConsumers(processList, config.TopN),
            Summary = new ReportSummary
            {
                TotalProcessesScanned = processList.Count,
                CpuAlertsCount        = cpuAlerts.Count,
                MemoryAlertsCount     = memAlerts.Count,
                GeneratedAt           = DateTime.UtcNow,
            },
        };
    }
}
