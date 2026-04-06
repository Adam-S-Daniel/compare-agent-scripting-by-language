// SystemProcessProvider.cs — live OS process enumeration
//
// This is the ONLY class that reads live system state.
// It is never used in tests — tests inject MockProcessProvider instead.
// CPU% is computed via a two-sample delta: (delta CPU time / wall-clock interval / cores) * 100.

using System.Diagnostics;
using ProcessMonitorLib.Models;

namespace ProcessMonitorLib;

/// <summary>
/// Real implementation of IProcessProvider that reads from the OS.
/// Uses a two-sample CPU measurement with a configurable sample interval.
/// </summary>
public sealed class SystemProcessProvider : IProcessProvider
{
    private readonly TimeSpan _sampleInterval;

    public SystemProcessProvider(TimeSpan? sampleInterval = null)
        => _sampleInterval = sampleInterval ?? TimeSpan.FromMilliseconds(500);

    /// <summary>
    /// Returns a snapshot of running processes with CPU% and memory figures.
    /// CPU% = (delta CPU time / wall-clock delta / processor count) * 100.
    /// </summary>
    public IReadOnlyList<ProcessInfo> GetProcesses()
    {
        int cpuCount = Environment.ProcessorCount;

        // First sample: record CPU times
        var firstSample = SnapshotCpuTimes();

        Thread.Sleep(_sampleInterval);
        double wallMs = _sampleInterval.TotalMilliseconds;

        // Second sample: record CPU times + name + memory
        var secondSample = SnapshotWithMeta();

        var results = new List<ProcessInfo>();
        foreach (var (pid, cpu2, name, memMb) in secondSample)
        {
            TimeSpan cpu1 = firstSample.TryGetValue(pid, out var t) ? t : TimeSpan.Zero;
            double cpuDeltaMs = (cpu2 - cpu1).TotalMilliseconds;
            double cpuPercent  = Math.Clamp(
                (cpuDeltaMs / wallMs / cpuCount) * 100.0, 0.0, 100.0);

            results.Add(new ProcessInfo
            {
                Pid        = pid,
                Name       = name,
                CpuPercent = Math.Round(cpuPercent, 2),
                MemoryMb   = Math.Round(memMb, 2),
            });
        }
        return results.AsReadOnly();
    }

    // Lightweight first pass: PID → total CPU time only
    private static Dictionary<int, TimeSpan> SnapshotCpuTimes()
    {
        var dict = new Dictionary<int, TimeSpan>();
        foreach (var proc in Process.GetProcesses())
        {
            try   { dict[proc.Id] = proc.TotalProcessorTime; }
            catch { /* process exited or access denied — skip */ }
            finally { proc.Dispose(); }
        }
        return dict;
    }

    // Second pass: PID, CPU time, process name, memory
    private static List<(int pid, TimeSpan cpu, string name, double memMb)>
        SnapshotWithMeta()
    {
        var list = new List<(int, TimeSpan, string, double)>();
        foreach (var proc in Process.GetProcesses())
        {
            try
            {
                list.Add((
                    proc.Id,
                    proc.TotalProcessorTime,
                    proc.ProcessName,
                    proc.WorkingSet64 / (1024.0 * 1024.0)));
            }
            catch { /* skip inaccessible processes */ }
            finally { proc.Dispose(); }
        }
        return list;
    }
}
