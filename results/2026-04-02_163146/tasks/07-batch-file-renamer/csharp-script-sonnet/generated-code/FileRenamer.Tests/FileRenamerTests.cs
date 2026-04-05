// FileRenamerTests.cs - TDD tests for the batch file renamer
// Following red/green TDD: write failing tests first, then implement minimum code to pass

using System;
using System.Collections.Generic;
using System.Linq;
using Xunit;

namespace FileRenamer.Tests
{
    // Mock file system for testing - stores files in memory
    public class MockFileSystem : IFileSystem
    {
        private readonly Dictionary<string, string> _files;

        public MockFileSystem(Dictionary<string, string>? initialFiles = null)
        {
            _files = initialFiles ?? new Dictionary<string, string>();
        }

        public IEnumerable<string> GetFiles(string directory)
        {
            // Return all keys that start with the directory path
            return _files.Keys
                .Where(k => k.StartsWith(directory, StringComparison.OrdinalIgnoreCase))
                .ToList();
        }

        public void RenameFile(string oldPath, string newPath)
        {
            if (!_files.ContainsKey(oldPath))
                throw new InvalidOperationException($"File not found: {oldPath}");
            if (_files.ContainsKey(newPath))
                throw new InvalidOperationException($"Destination file already exists: {newPath}");

            var content = _files[oldPath];
            _files.Remove(oldPath);
            _files[newPath] = content;
        }

        public bool FileExists(string path)
        {
            return _files.ContainsKey(path);
        }

        public void WriteAllText(string path, string content)
        {
            _files[path] = content;
        }

        public string ReadAllText(string path)
        {
            return _files.TryGetValue(path, out var content) ? content : string.Empty;
        }

        public IReadOnlyDictionary<string, string> Files => _files;
    }

    public class FileRenamerTests
    {
        private const string TestDir = "/test/files/";

        // =============================================
        // BASIC REGEX RENAME TESTS
        // =============================================

        [Fact]
        public void Execute_RenamesFilesMatchingPattern()
        {
            // Arrange
            var fs = new MockFileSystem(new Dictionary<string, string>
            {
                { "/test/files/photo_001.jpg", "" },
                { "/test/files/photo_002.jpg", "" },
                { "/test/files/document.pdf", "" }
            });

            var renamer = new BatchFileRenamer(fs);

            // Act - rename photo_NNN.jpg to image_NNN.jpg
            renamer.Execute(TestDir, @"photo_(\d+)\.jpg", "image_$1.jpg");

            // Assert
            Assert.True(fs.FileExists("/test/files/image_001.jpg"));
            Assert.True(fs.FileExists("/test/files/image_002.jpg"));
            Assert.False(fs.FileExists("/test/files/photo_001.jpg"));
            Assert.False(fs.FileExists("/test/files/photo_002.jpg"));
            Assert.True(fs.FileExists("/test/files/document.pdf")); // Unmatched file unchanged
        }

        [Fact]
        public void Execute_DoesNotRenameFilesNotMatchingPattern()
        {
            // Arrange
            var fs = new MockFileSystem(new Dictionary<string, string>
            {
                { "/test/files/document.pdf", "" },
                { "/test/files/readme.txt", "" }
            });

            var renamer = new BatchFileRenamer(fs);

            // Act
            renamer.Execute(TestDir, @"photo_(\d+)\.jpg", "image_$1.jpg");

            // Assert - files unchanged
            Assert.True(fs.FileExists("/test/files/document.pdf"));
            Assert.True(fs.FileExists("/test/files/readme.txt"));
        }

        [Fact]
        public void Execute_ReturnsRenameResults()
        {
            // Arrange
            var fs = new MockFileSystem(new Dictionary<string, string>
            {
                { "/test/files/photo_001.jpg", "" },
                { "/test/files/document.pdf", "" }
            });

            var renamer = new BatchFileRenamer(fs);

            // Act
            var results = renamer.Execute(TestDir, @"photo_(\d+)\.jpg", "image_$1.jpg");

            // Assert
            Assert.Single(results);
            Assert.Equal("/test/files/photo_001.jpg", results[0].OldPath);
            Assert.Equal("/test/files/image_001.jpg", results[0].NewPath);
            Assert.True(results[0].Success);
        }

        // =============================================
        // PREVIEW MODE TESTS
        // =============================================

        [Fact]
        public void Preview_ReturnsWhatWouldChange_WithoutActuallyChanging()
        {
            // Arrange
            var fs = new MockFileSystem(new Dictionary<string, string>
            {
                { "/test/files/photo_001.jpg", "" },
                { "/test/files/photo_002.jpg", "" },
                { "/test/files/document.pdf", "" }
            });

            var renamer = new BatchFileRenamer(fs);

            // Act
            var previews = renamer.Preview(TestDir, @"photo_(\d+)\.jpg", "image_$1.jpg");

            // Assert - shows what would change
            Assert.Equal(2, previews.Count);
            Assert.Contains(previews, p => p.OldPath == "/test/files/photo_001.jpg" && p.NewPath == "/test/files/image_001.jpg");
            Assert.Contains(previews, p => p.OldPath == "/test/files/photo_002.jpg" && p.NewPath == "/test/files/image_002.jpg");

            // Files should NOT be changed
            Assert.True(fs.FileExists("/test/files/photo_001.jpg"));
            Assert.True(fs.FileExists("/test/files/photo_002.jpg"));
            Assert.False(fs.FileExists("/test/files/image_001.jpg"));
            Assert.False(fs.FileExists("/test/files/image_002.jpg"));
        }

        [Fact]
        public void Preview_ReturnsEmptyList_WhenNoFilesMatch()
        {
            // Arrange
            var fs = new MockFileSystem(new Dictionary<string, string>
            {
                { "/test/files/document.pdf", "" }
            });

            var renamer = new BatchFileRenamer(fs);

            // Act
            var previews = renamer.Preview(TestDir, @"photo_(\d+)\.jpg", "image_$1.jpg");

            // Assert
            Assert.Empty(previews);
        }

        // =============================================
        // CONFLICT DETECTION TESTS
        // =============================================

        [Fact]
        public void DetectConflicts_ReturnsConflicts_WhenTwoFilesWouldGetSameName()
        {
            // Arrange - two files that would both rename to the same target
            var fs = new MockFileSystem(new Dictionary<string, string>
            {
                { "/test/files/photo_001.jpg", "" },
                { "/test/files/Photo_001.jpg", "" }  // Different case, same target
            });

            var renamer = new BatchFileRenamer(fs);

            // Act - both would become "image_001.jpg"
            var conflicts = renamer.DetectConflicts(TestDir, @"[Pp]hoto_(\d+)\.jpg", "image_$1.jpg");

            // Assert
            Assert.NotEmpty(conflicts);
            Assert.Contains(conflicts, c => c.ConflictingNewPath == "/test/files/image_001.jpg");
        }

        [Fact]
        public void DetectConflicts_ReturnsEmpty_WhenNoConflicts()
        {
            // Arrange
            var fs = new MockFileSystem(new Dictionary<string, string>
            {
                { "/test/files/photo_001.jpg", "" },
                { "/test/files/photo_002.jpg", "" }
            });

            var renamer = new BatchFileRenamer(fs);

            // Act
            var conflicts = renamer.DetectConflicts(TestDir, @"photo_(\d+)\.jpg", "image_$1.jpg");

            // Assert
            Assert.Empty(conflicts);
        }

        [Fact]
        public void DetectConflicts_ReturnsConflict_WhenTargetAlreadyExists()
        {
            // Arrange - rename photo_001.jpg to image_001.jpg, but image_001.jpg already exists
            var fs = new MockFileSystem(new Dictionary<string, string>
            {
                { "/test/files/photo_001.jpg", "" },
                { "/test/files/image_001.jpg", "" }  // Already exists!
            });

            var renamer = new BatchFileRenamer(fs);

            // Act
            var conflicts = renamer.DetectConflicts(TestDir, @"photo_(\d+)\.jpg", "image_$1.jpg");

            // Assert
            Assert.NotEmpty(conflicts);
        }

        [Fact]
        public void Execute_ThrowsException_WhenConflictsDetected()
        {
            // Arrange - two files that would both rename to the same target
            var fs = new MockFileSystem(new Dictionary<string, string>
            {
                { "/test/files/photo_001.jpg", "" },
                { "/test/files/Photo_001.jpg", "" }
            });

            var renamer = new BatchFileRenamer(fs);

            // Act & Assert - should throw when there are conflicts
            Assert.Throws<InvalidOperationException>(() =>
                renamer.Execute(TestDir, @"[Pp]hoto_(\d+)\.jpg", "image_$1.jpg"));
        }

        // =============================================
        // UNDO SCRIPT TESTS
        // =============================================

        [Fact]
        public void GenerateUndoScript_ReturnsScriptContent_ThatReversesRenames()
        {
            // Arrange
            var fs = new MockFileSystem(new Dictionary<string, string>
            {
                { "/test/files/photo_001.jpg", "" },
                { "/test/files/photo_002.jpg", "" }
            });

            var renamer = new BatchFileRenamer(fs);

            // Act - execute renames, then generate undo script
            var results = renamer.Execute(TestDir, @"photo_(\d+)\.jpg", "image_$1.jpg");
            var undoScript = renamer.GenerateUndoScript(results);

            // Assert - script should contain mv commands to reverse renames
            Assert.NotEmpty(undoScript);
            Assert.Contains("mv", undoScript);
            // Should rename back: image_001.jpg -> photo_001.jpg
            Assert.Contains("image_001.jpg", undoScript);
            Assert.Contains("photo_001.jpg", undoScript);
            Assert.Contains("image_002.jpg", undoScript);
            Assert.Contains("photo_002.jpg", undoScript);
        }

        [Fact]
        public void GenerateUndoScript_WritesToFile_WhenPathProvided()
        {
            // Arrange
            var fs = new MockFileSystem(new Dictionary<string, string>
            {
                { "/test/files/photo_001.jpg", "" }
            });

            var renamer = new BatchFileRenamer(fs);
            var results = renamer.Execute(TestDir, @"photo_(\d+)\.jpg", "image_$1.jpg");

            // Act
            renamer.GenerateUndoScript(results, "/test/undo.sh");

            // Assert - file should be written
            Assert.True(fs.FileExists("/test/undo.sh"));
            var scriptContent = fs.ReadAllText("/test/undo.sh");
            Assert.Contains("mv", scriptContent);
        }

        [Fact]
        public void GenerateUndoScript_ContainsShebangLine()
        {
            // Arrange
            var fs = new MockFileSystem(new Dictionary<string, string>
            {
                { "/test/files/photo_001.jpg", "" }
            });

            var renamer = new BatchFileRenamer(fs);
            var results = renamer.Execute(TestDir, @"photo_(\d+)\.jpg", "image_$1.jpg");

            // Act
            var undoScript = renamer.GenerateUndoScript(results);

            // Assert - should be a valid shell script
            Assert.StartsWith("#!/bin/bash", undoScript);
        }

        // =============================================
        // EDGE CASE TESTS
        // =============================================

        [Fact]
        public void Execute_HandlesEmptyDirectory()
        {
            // Arrange
            var fs = new MockFileSystem();
            var renamer = new BatchFileRenamer(fs);

            // Act
            var results = renamer.Execute(TestDir, @"photo_(\d+)\.jpg", "image_$1.jpg");

            // Assert
            Assert.Empty(results);
        }

        [Fact]
        public void Execute_HandlesComplexRegexPatterns()
        {
            // Arrange - files with date patterns
            var fs = new MockFileSystem(new Dictionary<string, string>
            {
                { "/test/files/2024-01-15_report.pdf", "" },
                { "/test/files/2024-02-20_report.pdf", "" }
            });

            var renamer = new BatchFileRenamer(fs);

            // Act - rename to report_YYYY-MM-DD.pdf
            var results = renamer.Execute(TestDir, @"(\d{4}-\d{2}-\d{2})_report\.pdf", "report_$1.pdf");

            // Assert
            Assert.Equal(2, results.Count);
            Assert.True(fs.FileExists("/test/files/report_2024-01-15.pdf"));
            Assert.True(fs.FileExists("/test/files/report_2024-02-20.pdf"));
        }

        [Fact]
        public void Preview_DoesNotModifyFilesWhenConflictsExist()
        {
            // Arrange
            var fs = new MockFileSystem(new Dictionary<string, string>
            {
                { "/test/files/photo_001.jpg", "" },
                { "/test/files/Photo_001.jpg", "" }
            });

            var renamer = new BatchFileRenamer(fs);

            // Act - preview should just show planned renames, not throw or modify
            var previews = renamer.Preview(TestDir, @"[Pp]hoto_(\d+)\.jpg", "image_$1.jpg");

            // Assert - files unchanged
            Assert.True(fs.FileExists("/test/files/photo_001.jpg"));
            Assert.True(fs.FileExists("/test/files/Photo_001.jpg"));
        }
    }
}
