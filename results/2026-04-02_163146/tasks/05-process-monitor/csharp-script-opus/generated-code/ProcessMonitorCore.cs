// ProcessMonitorCore.cs — Shared business logic for process monitoring.
// This file is compiled into both the main app and the test project.
// Approach: Separate data models, filtering, ranking, and report generation
// into distinct, testable units. All process data access is behind an interface
// (IProcessProvider) so tests can supply mock data.

using System.Text;

/// <summary>
/// Immutable record representing a snapshot of a single process.
/// </summary>
public record ProcessInfo(int Pid, string Name, double CpuPercent, double MemoryMb);

/// <summary>
/// Configurable thresholds for filtering resource-heavy processes.
/// A process exceeding EITHER threshold is included in filtered results.
/// Setting a threshold to 0 (or negative) effectively disables that filter dimension.
/// </summary>
public record ThresholdConfig(double CpuThreshold, double MemoryThresholdMb);

/// <summary>
/// Interface for providing process data — mockable for testing.
/// </summary>
public interface IProcessProvider
{
    List<ProcessInfo> GetProcesses();
}

/// <summary>
/// Mock implementation of IProcessProvider for testing.
/// Returns a pre-configured list of processes.
/// </summary>
public class MockProcessProvider : IProcessProvider
{
    private readonly List<ProcessInfo> _processes;

    public MockProcessProvider(List<ProcessInfo> processes)
    {
        _processes = processes;
    }

    public List<ProcessInfo> GetProcesses() => new(_processes);
}

/// <summary>
/// Reads real process data from the OS via System.Diagnostics.
/// Not used in tests — tests use MockProcessProvider instead.
/// </summary>
public class SystemProcessProvider : IProcessProvider
{
    public List<ProcessInfo> GetProcesses()
    {
        var result = new List<ProcessInfo>();
        try
        {
            foreach (var proc in System.Diagnostics.Process.GetProcesses())
            {
                try
                {
                    result.Add(new ProcessInfo(
                        Pid: proc.Id,
                        Name: proc.ProcessName,
                        // WorkingSet64 gives current memory; CPU% needs sampling so we approximate
                        CpuPercent: 0.0,
                        MemoryMb: proc.WorkingSet64 / (1024.0 * 1024.0)
                    ));
                }
                catch
                {
                    // Some system processes may deny access — skip them
                }
                finally
                {
                    proc.Dispose();
                }
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Error reading processes: {ex.Message}");
        }
        return result;
    }
}

/// <summary>
/// Filters processes by configurable resource usage thresholds.
/// A process is included if it exceeds EITHER the CPU or memory threshold.
/// Negative thresholds are treated as 0 (include everything on that dimension).
/// </summary>
public static class ProcessFilter
{
    public static List<ProcessInfo> Apply(List<ProcessInfo> processes, ThresholdConfig config)
    {
        // Treat negative thresholds as 0 (disabled)
        var cpuThreshold = Math.Max(0, config.CpuThreshold);
        var memThreshold = Math.Max(0, config.MemoryThresholdMb);

        // Both thresholds at 0 means include everything
        if (cpuThreshold == 0 && memThreshold == 0)
            return new List<ProcessInfo>(processes);

        // A threshold of 0 disables that dimension; process must exceed at least one active threshold
        return processes
            .Where(p =>
                (cpuThreshold > 0 && p.CpuPercent >= cpuThreshold) ||
                (memThreshold > 0 && p.MemoryMb >= memThreshold))
            .ToList();
    }
}

/// <summary>
/// Identifies the top N resource-consuming processes by CPU or memory.
/// </summary>
public static class TopConsumers
{
    public static List<ProcessInfo> ByCpu(List<ProcessInfo> processes, int n)
    {
        if (n <= 0) return [];
        return processes
            .OrderByDescending(p => p.CpuPercent)
            .Take(n)
            .ToList();
    }

    public static List<ProcessInfo> ByMemory(List<ProcessInfo> processes, int n)
    {
        if (n <= 0) return [];
        return processes
            .OrderByDescending(p => p.MemoryMb)
            .Take(n)
            .ToList();
    }
}

/// <summary>
/// Generates a formatted alert report for processes exceeding thresholds.
/// </summary>
public static class AlertReport
{
    public static string Generate(List<ProcessInfo> alertedProcesses, ThresholdConfig config)
    {
        var sb = new StringBuilder();

        sb.AppendLine("========================================");
        sb.AppendLine("  PROCESS MONITOR ALERT REPORT");
        sb.AppendLine("========================================");
        sb.AppendLine();
        sb.AppendLine($"Thresholds: CPU >= {config.CpuThreshold}% | Memory >= {config.MemoryThresholdMb} MB");
        sb.AppendLine($"Alerted processes: {alertedProcesses.Count}");
        sb.AppendLine();

        if (alertedProcesses.Count == 0)
        {
            sb.AppendLine("No processes exceeded the configured thresholds.");
            return sb.ToString();
        }

        // Table header
        sb.AppendLine($"{"PID",-10} {"Name",-20} {"CPU %",-10} {"Memory MB",-12}");
        sb.AppendLine(new string('-', 52));

        foreach (var p in alertedProcesses)
        {
            var name = p.Name ?? "(unknown)";
            sb.AppendLine($"{p.Pid,-10} {name,-20} {p.CpuPercent,-10:F1} {p.MemoryMb,-12:F1}");
        }

        sb.AppendLine();
        sb.AppendLine("--- End of Report ---");
        return sb.ToString();
    }
}

/// <summary>
/// Parses command-line arguments into ThresholdConfig and topN value.
/// Provides sensible defaults and meaningful error messages.
/// </summary>
public static class ArgParser
{
    public static (ThresholdConfig Config, int TopN) Parse(string[] args)
    {
        double cpu = 10.0;
        double memory = 500.0;
        int topN = 5;

        for (int i = 0; i < args.Length; i += 2)
        {
            var flag = args[i];
            if (i + 1 >= args.Length)
                throw new ArgumentException($"Missing value for argument '{flag}'.");

            var value = args[i + 1];

            switch (flag)
            {
                case "--cpu":
                    if (!double.TryParse(value, out cpu))
                        throw new ArgumentException($"Invalid value for --cpu: '{value}'. Expected a number.");
                    break;
                case "--memory":
                    if (!double.TryParse(value, out memory))
                        throw new ArgumentException($"Invalid value for --memory: '{value}'. Expected a number.");
                    break;
                case "--top":
                    if (!int.TryParse(value, out topN))
                        throw new ArgumentException($"Invalid value for --top: '{value}'. Expected an integer.");
                    break;
                default:
                    throw new ArgumentException($"Unknown argument: '{flag}'. Valid options: --cpu, --memory, --top");
            }
        }

        return (new ThresholdConfig(cpu, memory), topN);
    }
}
