// Custom exception for API errors with meaningful messages.
// Includes the HTTP status code and response body for debugging.

namespace RestApiClient;

public class ApiException : Exception
{
    public int StatusCode { get; }
    public string? ResponseBody { get; }

    public ApiException(int statusCode, string message, string? responseBody = null)
        : base(message)
    {
        StatusCode = statusCode;
        ResponseBody = responseBody;
    }
}
