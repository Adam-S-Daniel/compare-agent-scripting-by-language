// Custom exception for parse errors with meaningful context.

using System;

public class TestResultParseException : Exception
{
    public TestResultParseException(string message) : base(message) { }
    public TestResultParseException(string message, Exception inner) : base(message, inner) { }
}
