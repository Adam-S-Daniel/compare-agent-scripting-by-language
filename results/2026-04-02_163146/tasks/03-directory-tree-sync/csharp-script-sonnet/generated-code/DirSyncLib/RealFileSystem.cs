// Production IFileSystem implementation that delegates to System.IO.

namespace DirSyncLib;

public class RealFileSystem : IFileSystem
{
    public bool FileExists(string path) => File.Exists(path);

    public bool DirectoryExists(string path) => Directory.Exists(path);

    public IEnumerable<string> EnumerateFiles(string directory)
    {
        if (!Directory.Exists(directory))
            return Enumerable.Empty<string>();

        return Directory.EnumerateFiles(directory, "*", SearchOption.AllDirectories);
    }

    public byte[] ReadAllBytes(string path) => File.ReadAllBytes(path);

    public void WriteAllBytes(string path, byte[] data) => File.WriteAllBytes(path, data);

    public void CopyFile(string source, string destination)
    {
        var dir = Path.GetDirectoryName(destination);
        if (!string.IsNullOrEmpty(dir))
            Directory.CreateDirectory(dir);

        File.Copy(source, destination, overwrite: true);
    }

    public void DeleteFile(string path) => File.Delete(path);

    public void CreateDirectory(string path) => Directory.CreateDirectory(path);
}
