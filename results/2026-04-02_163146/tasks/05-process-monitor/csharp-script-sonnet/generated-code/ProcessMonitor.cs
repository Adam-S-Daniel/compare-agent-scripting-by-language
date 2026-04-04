// ProcessMonitor.cs — .NET 10 file-based app entry point
//
// Run with:  dotnet run ProcessMonitor.cs [--cpu <pct>] [--mem <mb>] [--top <n>]
//
// The #:project directive is a .NET 10 file-based-app feature that lets this
// single-file script reference a local library project, keeping business logic
// in ProcessMonitorLib (where it can be unit-tested) and the entry point thin.
//
// Exit codes:
//   0 — ran successfully, no thresholds exceeded
//   1 — ran successfully, at least one alert triggered
//   2 — configuration or process-enumeration error

#:project ProcessMonitorLib/ProcessMonitorLib.csproj

using ProcessMonitorLib;
using ProcessMonitorLib.Models;
using ProcessMonitorLib.Services;

int Run(string[] arguments)
{
    // ── Parse CLI arguments ──────────────────────────────────────────────────
    double cpuThreshold   = 80.0;
    double memThresholdMb = 1024.0;
    int    topN           = 5;

    for (int i = 0; i < arguments.Length - 1; i++)
    {
        switch (arguments[i].ToLowerInvariant())
        {
            case "--cpu" or "-c":
                if (double.TryParse(arguments[i + 1], out double c)) cpuThreshold = c;
                break;
            case "--mem" or "-m":
                if (double.TryParse(arguments[i + 1], out double m)) memThresholdMb = m;
                break;
            case "--top" or "-n":
                if (int.TryParse(arguments[i + 1], out int n)) topN = n;
                break;
        }
    }

    var config = new ThresholdConfig
    {
        CpuThresholdPercent = cpuThreshold,
        MemoryThresholdMb   = memThresholdMb,
        TopN                = topN,
    };

    // ── Validate config ──────────────────────────────────────────────────────
    var monitorService = new ProcessMonitorService();
    try
    {
        monitorService.ValidateConfig(config);
    }
    catch (ArgumentException ex)
    {
        Console.Error.WriteLine($"[ERROR] Invalid configuration: {ex.Message}");
        return 2;
    }

    // ── Collect live process data ────────────────────────────────────────────
    Console.WriteLine("Collecting process data (500 ms sample)...");
    IProcessProvider provider = new SystemProcessProvider();

    IReadOnlyList<ProcessInfo> processes;
    try
    {
        processes = provider.GetProcesses();
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"[ERROR] Failed to read process list: {ex.Message}");
        return 2;
    }

    // ── Generate and print report ────────────────────────────────────────────
    var report = monitorService.GenerateReport(processes, config);
    Console.WriteLine(report.FormatAsText());

    // Exit code 1 = alerts present (useful for shell scripting / alerting pipelines)
    return report.Summary.CpuAlertsCount > 0 || report.Summary.MemoryAlertsCount > 0
        ? 1
        : 0;
}

Environment.Exit(Run(args));
