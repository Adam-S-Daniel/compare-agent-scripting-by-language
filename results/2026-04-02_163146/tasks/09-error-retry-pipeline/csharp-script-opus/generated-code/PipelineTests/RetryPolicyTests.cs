// TDD RED: First write failing tests for the retry policy with exponential backoff.
// The retry policy should calculate delays using exponential backoff and respect max retries.

using Xunit;
using Pipeline;

namespace PipelineTests;

public class RetryPolicyTests
{
    // RED: Test that the default retry policy has sensible defaults
    [Fact]
    public void RetryPolicy_DefaultValues_AreReasonable()
    {
        var policy = new RetryPolicy();

        Assert.Equal(3, policy.MaxRetries);
        Assert.Equal(TimeSpan.FromMilliseconds(100), policy.BaseDelay);
    }

    // RED: Test configurable max retries
    [Fact]
    public void RetryPolicy_CanConfigureMaxRetries()
    {
        var policy = new RetryPolicy { MaxRetries = 5, BaseDelay = TimeSpan.FromMilliseconds(200) };

        Assert.Equal(5, policy.MaxRetries);
        Assert.Equal(TimeSpan.FromMilliseconds(200), policy.BaseDelay);
    }

    // RED: Test exponential backoff delay calculation
    [Theory]
    [InlineData(0, 100)]   // First retry: 100ms * 2^0 = 100ms
    [InlineData(1, 200)]   // Second retry: 100ms * 2^1 = 200ms
    [InlineData(2, 400)]   // Third retry: 100ms * 2^2 = 400ms
    [InlineData(3, 800)]   // Fourth retry: 100ms * 2^3 = 800ms
    public void RetryPolicy_CalculatesExponentialBackoffDelay(int attempt, int expectedMs)
    {
        var policy = new RetryPolicy { BaseDelay = TimeSpan.FromMilliseconds(100) };

        var delay = policy.GetDelay(attempt);

        Assert.Equal(TimeSpan.FromMilliseconds(expectedMs), delay);
    }

    // RED: Test that ShouldRetry returns true when under max retries
    [Fact]
    public void RetryPolicy_ShouldRetry_TrueWhenUnderMaxRetries()
    {
        var policy = new RetryPolicy { MaxRetries = 3 };

        Assert.True(policy.ShouldRetry(0));
        Assert.True(policy.ShouldRetry(1));
        Assert.True(policy.ShouldRetry(2));
    }

    // RED: Test that ShouldRetry returns false when at or over max retries
    [Fact]
    public void RetryPolicy_ShouldRetry_FalseWhenAtOrOverMaxRetries()
    {
        var policy = new RetryPolicy { MaxRetries = 3 };

        Assert.False(policy.ShouldRetry(3));
        Assert.False(policy.ShouldRetry(4));
    }
}
