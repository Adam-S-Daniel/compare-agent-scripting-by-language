using Xunit;
using BatchFileRenamer;

// =============================================================================
// TDD Tests for Batch File Renamer
// Written FIRST (RED), then FileRenamer.cs is implemented to make them pass (GREEN).
//
// Test categories:
// 1. Basic regex-based renaming
// 2. Preview mode (show changes without applying)
// 3. Conflict detection (two files mapping to same name)
// 4. Undo script generation
// 5. Error handling
// =============================================================================

namespace BatchFileRenamer.Tests;

/// <summary>
/// Tests use a mock file system (IFileSystem) so we don't touch the real disk.
/// </summary>
public class MockFileSystem : IFileSystem
{
    private readonly HashSet<string> _files;
    public List<(string From, string To)> RenameLog { get; } = new();

    public MockFileSystem(IEnumerable<string> files)
    {
        _files = new HashSet<string>(files);
    }

    public IEnumerable<string> GetFiles(string directory)
    {
        return _files.Where(f => Path.GetDirectoryName(f) == directory || directory == ".");
    }

    public bool FileExists(string path) => _files.Contains(path);

    public void RenameFile(string oldPath, string newPath)
    {
        if (!_files.Contains(oldPath))
            throw new FileNotFoundException($"File not found: {oldPath}");
        _files.Remove(oldPath);
        _files.Add(newPath);
        RenameLog.Add((oldPath, newPath));
    }

    public void WriteAllText(string path, string content)
    {
        // For undo script writing — just track it
        _files.Add(path);
    }
}

// ============================================================
// 1. Basic regex rename tests
// ============================================================
public class RegexRenameTests
{
    [Fact]
    public void Rename_SimplePatternReplacement_RenamesMatchingFiles()
    {
        // RED: Test that files matching a regex pattern get renamed
        var fs = new MockFileSystem(new[]
        {
            "dir/photo_001.jpg",
            "dir/photo_002.jpg",
            "dir/photo_003.jpg"
        });

        var renamer = new FileRenamer(fs);
        var result = renamer.Execute("dir", @"photo_(\d+)", "img_$1", preview: false);

        Assert.Equal(3, result.RenamedCount);
        Assert.True(fs.FileExists("dir/img_001.jpg"));
        Assert.True(fs.FileExists("dir/img_002.jpg"));
        Assert.True(fs.FileExists("dir/img_003.jpg"));
        Assert.False(fs.FileExists("dir/photo_001.jpg"));
    }

    [Fact]
    public void Rename_OnlyMatchingFilesAreRenamed()
    {
        // RED: Non-matching files should be left untouched
        var fs = new MockFileSystem(new[]
        {
            "dir/report.pdf",
            "dir/photo_001.jpg",
            "dir/notes.txt"
        });

        var renamer = new FileRenamer(fs);
        var result = renamer.Execute("dir", @"photo_(\d+)", "img_$1", preview: false);

        Assert.Equal(1, result.RenamedCount);
        Assert.True(fs.FileExists("dir/img_001.jpg"));
        Assert.True(fs.FileExists("dir/report.pdf"));
        Assert.True(fs.FileExists("dir/notes.txt"));
    }

    [Fact]
    public void Rename_ExtensionChange_WorksCorrectly()
    {
        // RED: Regex can match the extension part too
        var fs = new MockFileSystem(new[]
        {
            "dir/file1.jpeg",
            "dir/file2.jpeg"
        });

        var renamer = new FileRenamer(fs);
        var result = renamer.Execute("dir", @"\.jpeg$", ".jpg", preview: false);

        Assert.Equal(2, result.RenamedCount);
        Assert.True(fs.FileExists("dir/file1.jpg"));
        Assert.True(fs.FileExists("dir/file2.jpg"));
    }

    [Fact]
    public void Rename_NoMatchingFiles_ReturnsZero()
    {
        // RED: If no files match, nothing changes
        var fs = new MockFileSystem(new[]
        {
            "dir/readme.md",
            "dir/notes.txt"
        });

        var renamer = new FileRenamer(fs);
        var result = renamer.Execute("dir", @"photo_\d+", "img", preview: false);

        Assert.Equal(0, result.RenamedCount);
        Assert.Empty(result.Renames);
    }

    [Fact]
    public void Rename_CaptureGroupsWork()
    {
        // RED: Multiple capture groups in regex should work
        var fs = new MockFileSystem(new[]
        {
            "dir/2024-01-15_report.txt",
            "dir/2024-02-20_report.txt"
        });

        var renamer = new FileRenamer(fs);
        var result = renamer.Execute("dir", @"(\d{4})-(\d{2})-(\d{2})_(.+)", "$4_$1$2$3", preview: false);

        Assert.Equal(2, result.RenamedCount);
        Assert.True(fs.FileExists("dir/report.txt_20240115"));
        Assert.True(fs.FileExists("dir/report.txt_20240220"));
    }
}

// ============================================================
// 2. Preview mode tests
// ============================================================
public class PreviewModeTests
{
    [Fact]
    public void Preview_ShowsWhatWouldChange_WithoutRenaming()
    {
        // RED: Preview mode should list renames but NOT perform them
        var fs = new MockFileSystem(new[]
        {
            "dir/photo_001.jpg",
            "dir/photo_002.jpg"
        });

        var renamer = new FileRenamer(fs);
        var result = renamer.Execute("dir", @"photo_(\d+)", "img_$1", preview: true);

        // Should report what would happen
        Assert.Equal(2, result.Renames.Count);
        Assert.True(result.IsPreview);

        // But files should NOT actually be renamed
        Assert.True(fs.FileExists("dir/photo_001.jpg"));
        Assert.True(fs.FileExists("dir/photo_002.jpg"));
        Assert.False(fs.FileExists("dir/img_001.jpg"));
    }

    [Fact]
    public void Preview_ReturnsCorrectMappings()
    {
        // RED: The rename mappings should show old -> new names
        var fs = new MockFileSystem(new[]
        {
            "dir/old_name.txt"
        });

        var renamer = new FileRenamer(fs);
        var result = renamer.Execute("dir", @"old", "new", preview: true);

        Assert.Single(result.Renames);
        Assert.Equal("old_name.txt", result.Renames[0].OldName);
        Assert.Equal("new_name.txt", result.Renames[0].NewName);
    }

    [Fact]
    public void Preview_RenamedCountIsZero_BecauseNothingActuallyRenamed()
    {
        // RED: In preview mode, RenamedCount should be 0 (nothing was actually renamed)
        var fs = new MockFileSystem(new[]
        {
            "dir/photo_001.jpg"
        });

        var renamer = new FileRenamer(fs);
        var result = renamer.Execute("dir", @"photo", "img", preview: true);

        Assert.Equal(0, result.RenamedCount);
        Assert.Single(result.Renames);
    }
}

// ============================================================
// 3. Conflict detection tests
// ============================================================
public class ConflictDetectionTests
{
    [Fact]
    public void Conflict_TwoFilesMappingToSameName_Detected()
    {
        // RED: If two files would get the same new name, detect the conflict
        var fs = new MockFileSystem(new[]
        {
            "dir/file_a1.txt",
            "dir/file_b1.txt"
        });

        var renamer = new FileRenamer(fs);
        // Both files match the pattern, and both would become "file_1.txt"
        var result = renamer.Execute("dir", @"file_[ab](\d+)", "file_$1", preview: false);

        Assert.True(result.HasConflicts);
        Assert.NotEmpty(result.Conflicts);
        Assert.Equal(0, result.RenamedCount); // Should not rename when conflicts exist
    }

    [Fact]
    public void Conflict_NewNameMatchesExistingFile_Detected()
    {
        // RED: Renaming would overwrite an existing file
        var fs = new MockFileSystem(new[]
        {
            "dir/photo_001.jpg",
            "dir/img_001.jpg"   // This already exists!
        });

        var renamer = new FileRenamer(fs);
        var result = renamer.Execute("dir", @"photo_(\d+)", "img_$1", preview: false);

        Assert.True(result.HasConflicts);
        Assert.NotEmpty(result.Conflicts);
        Assert.Equal(0, result.RenamedCount);
    }

    [Fact]
    public void Conflict_InPreviewMode_StillDetected()
    {
        // RED: Conflicts should be detected even in preview mode
        var fs = new MockFileSystem(new[]
        {
            "dir/file_a1.txt",
            "dir/file_b1.txt"
        });

        var renamer = new FileRenamer(fs);
        var result = renamer.Execute("dir", @"file_[ab](\d+)", "file_$1", preview: true);

        Assert.True(result.HasConflicts);
        Assert.NotEmpty(result.Conflicts);
    }

    [Fact]
    public void Conflict_MessageIncludesConflictingFileNames()
    {
        // RED: Conflict info should identify which files conflict
        var fs = new MockFileSystem(new[]
        {
            "dir/a_report.txt",
            "dir/b_report.txt"
        });

        var renamer = new FileRenamer(fs);
        var result = renamer.Execute("dir", @"[ab]_", "", preview: true);

        var conflict = result.Conflicts[0];
        Assert.Equal("report.txt", conflict.TargetName);
        Assert.Contains("a_report.txt", conflict.SourceFiles);
        Assert.Contains("b_report.txt", conflict.SourceFiles);
    }

    [Fact]
    public void NoConflict_RenameProceeds()
    {
        // RED: When there are no conflicts, renaming should proceed normally
        var fs = new MockFileSystem(new[]
        {
            "dir/photo_001.jpg",
            "dir/photo_002.jpg"
        });

        var renamer = new FileRenamer(fs);
        var result = renamer.Execute("dir", @"photo", "img", preview: false);

        Assert.False(result.HasConflicts);
        Assert.Equal(2, result.RenamedCount);
    }
}

// ============================================================
// 4. Undo script generation tests
// ============================================================
public class UndoScriptTests
{
    [Fact]
    public void Undo_GeneratesReverseMappings()
    {
        // RED: After renaming, an undo script should contain reverse mappings
        var fs = new MockFileSystem(new[]
        {
            "dir/photo_001.jpg",
            "dir/photo_002.jpg"
        });

        var renamer = new FileRenamer(fs);
        var result = renamer.Execute("dir", @"photo_(\d+)", "img_$1", preview: false);

        var undoScript = renamer.GenerateUndoScript(result);

        // The undo script should contain the reverse rename commands
        Assert.Contains("img_001.jpg", undoScript);
        Assert.Contains("photo_001.jpg", undoScript);
        Assert.Contains("img_002.jpg", undoScript);
        Assert.Contains("photo_002.jpg", undoScript);
    }

    [Fact]
    public void Undo_ScriptIsValidBashScript()
    {
        // RED: The undo script should be a valid shell script with a shebang
        var fs = new MockFileSystem(new[]
        {
            "dir/old.txt"
        });

        var renamer = new FileRenamer(fs);
        var result = renamer.Execute("dir", @"old", "new", preview: false);

        var undoScript = renamer.GenerateUndoScript(result);

        Assert.StartsWith("#!/bin/bash", undoScript);
        Assert.Contains("mv", undoScript);
    }

    [Fact]
    public void Undo_EmptyResult_GeneratesEmptyScript()
    {
        // RED: If nothing was renamed, undo script should be minimal
        var fs = new MockFileSystem(new[] { "dir/readme.md" });

        var renamer = new FileRenamer(fs);
        var result = renamer.Execute("dir", @"nonexistent", "replacement", preview: false);

        var undoScript = renamer.GenerateUndoScript(result);

        Assert.StartsWith("#!/bin/bash", undoScript);
        Assert.Contains("No renames to undo", undoScript);
    }

    [Fact]
    public void Undo_SavesScriptToFile()
    {
        // RED: Can save the undo script to a file via the file system
        var fs = new MockFileSystem(new[]
        {
            "dir/photo_001.jpg"
        });

        var renamer = new FileRenamer(fs);
        var result = renamer.Execute("dir", @"photo", "img", preview: false);

        renamer.SaveUndoScript(result, "dir/undo.sh");
        Assert.True(fs.FileExists("dir/undo.sh"));
    }

    [Fact]
    public void Undo_ScriptHandlesSpecialCharactersInFilenames()
    {
        // RED: File names with spaces/special chars should be quoted in undo script
        var fs = new MockFileSystem(new[]
        {
            "dir/my file (1).txt"
        });

        var renamer = new FileRenamer(fs);
        var result = renamer.Execute("dir", @"\(1\)", "(2)", preview: false);

        var undoScript = renamer.GenerateUndoScript(result);

        // Should properly quote file names with spaces and parens
        Assert.Contains("\"my file (2).txt\"", undoScript);
        Assert.Contains("\"my file (1).txt\"", undoScript);
    }
}

// ============================================================
// 5. Error handling tests
// ============================================================
public class ErrorHandlingTests
{
    [Fact]
    public void InvalidRegex_ThrowsMeaningfulError()
    {
        // RED: Invalid regex pattern should produce a clear error
        var fs = new MockFileSystem(new[] { "dir/file.txt" });
        var renamer = new FileRenamer(fs);

        var ex = Assert.Throws<RenameException>(() =>
            renamer.Execute("dir", @"[invalid", "replacement", preview: false));

        Assert.Contains("Invalid regex pattern", ex.Message);
    }

    [Fact]
    public void EmptyDirectory_ReturnsEmptyResult()
    {
        // RED: An empty directory should return a clean empty result
        var fs = new MockFileSystem(Array.Empty<string>());
        var renamer = new FileRenamer(fs);

        var result = renamer.Execute("dir", @"pattern", "replacement", preview: false);

        Assert.Equal(0, result.RenamedCount);
        Assert.Empty(result.Renames);
        Assert.False(result.HasConflicts);
    }

    [Fact]
    public void EmptyPattern_ThrowsMeaningfulError()
    {
        // RED: Empty pattern should be rejected
        var fs = new MockFileSystem(new[] { "dir/file.txt" });
        var renamer = new FileRenamer(fs);

        var ex = Assert.Throws<RenameException>(() =>
            renamer.Execute("dir", "", "replacement", preview: false));

        Assert.Contains("Pattern cannot be empty", ex.Message);
    }

    [Fact]
    public void NullPattern_ThrowsMeaningfulError()
    {
        // RED: Null pattern should be rejected
        var fs = new MockFileSystem(new[] { "dir/file.txt" });
        var renamer = new FileRenamer(fs);

        var ex = Assert.Throws<RenameException>(() =>
            renamer.Execute("dir", null!, "replacement", preview: false));

        Assert.Contains("Pattern cannot be empty", ex.Message);
    }

    [Fact]
    public void RenameResultSameAsOriginal_SkipsFile()
    {
        // RED: If regex matches but replacement yields the same name, skip it
        var fs = new MockFileSystem(new[]
        {
            "dir/file_test.txt"
        });

        var renamer = new FileRenamer(fs);
        // This pattern matches "test" and replaces with "test" — no actual change
        var result = renamer.Execute("dir", @"test", "test", preview: false);

        Assert.Equal(0, result.RenamedCount);
        Assert.Empty(result.Renames);
    }
}
