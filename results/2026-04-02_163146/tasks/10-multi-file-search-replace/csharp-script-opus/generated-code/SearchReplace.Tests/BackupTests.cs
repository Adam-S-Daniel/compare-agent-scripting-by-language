// TDD RED → GREEN: Tests for backup creation.
// Before modifying a file, the tool should create a .bak copy of the original.

using Xunit;

public class BackupTests : IDisposable
{
    private readonly string _tempDir;

    public BackupTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), "sr_backup_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_tempDir);
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempDir))
            Directory.Delete(_tempDir, recursive: true);
    }

    private string CreateFile(string name, string content)
    {
        var path = Path.Combine(_tempDir, name);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, content);
        return path;
    }

    [Fact]
    public void CreateBackup_CreatesBackupFile()
    {
        var original = CreateFile("data.txt", "important data");

        var backupPath = SearchReplaceTool.CreateBackup(original);

        Assert.True(File.Exists(backupPath), "Backup file should exist");
    }

    [Fact]
    public void CreateBackup_BackupHasBakExtension()
    {
        var original = CreateFile("data.txt", "content");

        var backupPath = SearchReplaceTool.CreateBackup(original);

        Assert.EndsWith(".bak", backupPath);
    }

    [Fact]
    public void CreateBackup_BackupContainsOriginalContent()
    {
        var content = "line1\nline2\nline3\n";
        var original = CreateFile("source.cs", content);

        var backupPath = SearchReplaceTool.CreateBackup(original);

        Assert.Equal(content, File.ReadAllText(backupPath));
    }

    [Fact]
    public void CreateBackup_OriginalFileUnchanged()
    {
        var content = "don't touch me";
        var original = CreateFile("safe.txt", content);

        SearchReplaceTool.CreateBackup(original);

        Assert.Equal(content, File.ReadAllText(original));
    }

    [Fact]
    public void CreateBackup_BackupPathIsNextToOriginal()
    {
        var original = CreateFile("sub/dir/file.txt", "data");

        var backupPath = SearchReplaceTool.CreateBackup(original);

        Assert.Equal(Path.GetDirectoryName(original), Path.GetDirectoryName(backupPath));
    }

    [Fact]
    public void FullPipeline_WithBackups_CreatesBackupFiles()
    {
        var content = "replace_me\n";
        CreateFile("a.txt", content);
        CreateFile("b.txt", content);

        var options = new SearchReplaceOptions
        {
            RootDirectory = _tempDir,
            GlobPattern = "**/*.txt",
            SearchPattern = "replace_me",
            Replacement = "replaced",
            PreviewOnly = false,
            CreateBackups = true
        };

        SearchReplaceTool.Run(options);

        // Verify backups exist
        Assert.True(File.Exists(Path.Combine(_tempDir, "a.txt.bak")));
        Assert.True(File.Exists(Path.Combine(_tempDir, "b.txt.bak")));
        // Backups have original content
        Assert.Equal(content, File.ReadAllText(Path.Combine(_tempDir, "a.txt.bak")));
    }
}
