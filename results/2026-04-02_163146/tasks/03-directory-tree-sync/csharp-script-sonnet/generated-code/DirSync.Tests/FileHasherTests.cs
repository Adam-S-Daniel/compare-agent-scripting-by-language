// RED phase: First failing test for FileHasher
// TDD Step 1: Write the test BEFORE the implementation.
// These tests verify SHA-256 hash computation using a mock filesystem.

using DirSyncLib;
using Xunit;

namespace DirSync.Tests;

public class FileHasherTests
{
    // Test 1: Same content produces the same hash
    [Fact]
    public void ComputeHash_SameContent_ReturnsSameHash()
    {
        var fs = new MockFileSystem();
        fs.AddFile("/src/hello.txt", "Hello, World!"u8.ToArray());
        fs.AddFile("/src/hello2.txt", "Hello, World!"u8.ToArray());

        var hasher = new FileHasher(fs);

        var hash1 = hasher.ComputeHash("/src/hello.txt");
        var hash2 = hasher.ComputeHash("/src/hello2.txt");

        Assert.Equal(hash1, hash2);
    }

    // Test 2: Different content produces different hashes
    [Fact]
    public void ComputeHash_DifferentContent_ReturnsDifferentHash()
    {
        var fs = new MockFileSystem();
        fs.AddFile("/src/a.txt", "Content A"u8.ToArray());
        fs.AddFile("/src/b.txt", "Content B"u8.ToArray());

        var hasher = new FileHasher(fs);

        var hashA = hasher.ComputeHash("/src/a.txt");
        var hashB = hasher.ComputeHash("/src/b.txt");

        Assert.NotEqual(hashA, hashB);
    }

    // Test 3: Hash is a valid 64-character hex string (SHA-256 = 32 bytes = 64 hex chars)
    [Fact]
    public void ComputeHash_ReturnsValidSha256HexString()
    {
        var fs = new MockFileSystem();
        fs.AddFile("/file.txt", "test content"u8.ToArray());

        var hasher = new FileHasher(fs);
        var hash = hasher.ComputeHash("/file.txt");

        Assert.Equal(64, hash.Length);
        Assert.Matches("^[0-9a-f]{64}$", hash);
    }

    // Test 4: Empty file has a known SHA-256 hash
    [Fact]
    public void ComputeHash_EmptyFile_ReturnsExpectedHash()
    {
        var fs = new MockFileSystem();
        fs.AddFile("/empty.txt", Array.Empty<byte>());

        var hasher = new FileHasher(fs);
        var hash = hasher.ComputeHash("/empty.txt");

        // SHA-256 of empty content is well-known
        Assert.Equal("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", hash);
    }
}
