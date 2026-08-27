using System.Text;
using System.Text.Json;

namespace QuotaGrove.Core;

public sealed class LocalRateLimitSource
{
    private const int TailLimit = 256 * 1024;
    private readonly IReadOnlyList<string> _roots;

    public LocalRateLimitSource(IEnumerable<string>? roots = null)
    {
        _roots = (roots ?? DefaultRoots())
            .Where(path => !string.IsNullOrWhiteSpace(path))
            .Select(Path.GetFullPath)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    public IReadOnlyList<string> Roots => _roots;

    public QuotaSnapshot? LatestSnapshot()
    {
        foreach (var file in DiscoverCandidates().Take(32))
        {
            var snapshot = SnapshotFromTail(file);
            if (snapshot is not null) return snapshot;
        }
        return null;
    }

    private IEnumerable<string> DiscoverCandidates()
    {
        var candidates = new List<(string Path, DateTime Modified)>();
        foreach (var root in _roots)
        {
            if (!Directory.Exists(root)) continue;
            try
            {
                foreach (var file in Directory.EnumerateFiles(root, "*.jsonl", SearchOption.AllDirectories))
                {
                    try
                    {
                        candidates.Add((file, File.GetLastWriteTimeUtc(file)));
                    }
                    catch (IOException) { }
                    catch (UnauthorizedAccessException) { }
                }
            }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }
        return candidates.OrderByDescending(item => item.Modified).Select(item => item.Path);
    }

    private static QuotaSnapshot? SnapshotFromTail(string path)
    {
        try
        {
            using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
            var start = Math.Max(0, stream.Length - TailLimit);
            stream.Seek(start, SeekOrigin.Begin);
            using var reader = new StreamReader(stream, Encoding.UTF8, true, 16 * 1024, leaveOpen: false);
            var data = reader.ReadToEnd();
            var lines = data.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            for (var index = lines.Length - 1; index >= 0; index--)
            {
                if (!lines[index].Contains("\"rate_limits\"", StringComparison.Ordinal)) continue;
                try
                {
                    var snapshot = QuotaEventParser.ParseLine(lines[index]);
                    if (snapshot is not null) return snapshot;
                }
                catch (JsonException) { }
                catch (QuotaParseException) { }
                catch (ArgumentOutOfRangeException) { }
            }
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
        return null;
    }

    private static IEnumerable<string> DefaultRoots()
    {
        var explicitHome = Environment.GetEnvironmentVariable("QUOTA_GROVE_CODEX_HOME")
            ?? Environment.GetEnvironmentVariable("CODEX_HOME");
        if (!string.IsNullOrWhiteSpace(explicitHome))
        {
            yield return Path.Combine(explicitHome, "sessions");
        }

        var userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        yield return Path.Combine(userProfile, ".codex", "sessions");

        var roaming = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        yield return Path.Combine(roaming, "OpenAI", "Codex", "sessions");

        var local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        yield return Path.Combine(local, "OpenAI", "Codex", "sessions");
    }
}
