// ProcessMonitor.cs — Main entry point using .NET 10 top-level statements.
// Run with: dotnet run ProcessMonitor.cs [--cpu N] [--memory N] [--top N]
//
// This script reads process information, filters by configurable thresholds,
// identifies top N resource consumers, and generates an alert report.
// All process data access goes through IProcessProvider for testability.

#:package System.Diagnostics.Process

try
{
    // Parse command-line arguments (with sensible defaults)
    var (config, topN) = ArgParser.Parse(args);

    Console.WriteLine($"Process Monitor starting...");
    Console.WriteLine($"  CPU threshold:    {config.CpuThreshold}%");
    Console.WriteLine($"  Memory threshold: {config.MemoryThresholdMb} MB");
    Console.WriteLine($"  Top N:            {topN}");
    Console.WriteLine();

    // Read live process data from the system
    IProcessProvider provider = new SystemProcessProvider();
    var allProcesses = provider.GetProcesses();
    Console.WriteLine($"Found {allProcesses.Count} running processes.");

    // Filter by thresholds — processes exceeding EITHER threshold are flagged
    var filtered = ProcessFilter.Apply(allProcesses, config);
    Console.WriteLine($"Processes exceeding thresholds: {filtered.Count}");
    Console.WriteLine();

    // Identify top N consumers by CPU and memory
    var topByCpu = TopConsumers.ByCpu(filtered, topN);
    var topByMemory = TopConsumers.ByMemory(filtered, topN);

    // Display top CPU consumers
    Console.WriteLine($"=== Top {topN} by CPU ===");
    foreach (var p in topByCpu)
        Console.WriteLine($"  PID {p.Pid,-8} {p.Name,-20} CPU: {p.CpuPercent:F1}%  Mem: {p.MemoryMb:F1} MB");
    Console.WriteLine();

    // Display top memory consumers
    Console.WriteLine($"=== Top {topN} by Memory ===");
    foreach (var p in topByMemory)
        Console.WriteLine($"  PID {p.Pid,-8} {p.Name,-20} CPU: {p.CpuPercent:F1}%  Mem: {p.MemoryMb:F1} MB");
    Console.WriteLine();

    // Generate and display the full alert report
    var report = AlertReport.Generate(filtered, config);
    Console.WriteLine(report);
}
catch (ArgumentException ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
    Console.Error.WriteLine();
    Console.Error.WriteLine("Usage: dotnet run ProcessMonitor.cs [--cpu N] [--memory N] [--top N]");
    Console.Error.WriteLine("  --cpu N      CPU threshold percentage (default: 10)");
    Console.Error.WriteLine("  --memory N   Memory threshold in MB (default: 500)");
    Console.Error.WriteLine("  --top N      Number of top consumers to show (default: 5)");
    Environment.Exit(1);
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Unexpected error: {ex.Message}");
    Environment.Exit(2);
}
