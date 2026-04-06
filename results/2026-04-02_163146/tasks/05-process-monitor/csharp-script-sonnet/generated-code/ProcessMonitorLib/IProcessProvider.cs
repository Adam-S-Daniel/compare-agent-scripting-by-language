// IProcessProvider.cs — abstraction over OS process enumeration
// By coding against this interface, tests can inject any list of ProcessInfo
// without touching the live system. The real implementation uses
// System.Diagnostics.Process; tests use in-memory stubs.

using ProcessMonitorLib.Models;

namespace ProcessMonitorLib;

/// <summary>
/// Abstraction for reading the current process list.
/// Implement this interface with a mock in tests to avoid live system state.
/// </summary>
public interface IProcessProvider
{
    /// <summary>
    /// Returns a snapshot of currently running processes with their resource metrics.
    /// </summary>
    IReadOnlyList<ProcessInfo> GetProcesses();
}
