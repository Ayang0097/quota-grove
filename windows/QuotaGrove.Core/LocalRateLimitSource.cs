using System.Text;
using System.Text.Json;

namespace QuotaGrove.Core;

public sealed class LocalRateLimitSource
{
    private const int SearchChunkSize = 256 * 1024;
    private const int IncrementalSearchLimit = 16 * 1024 * 1024;
    private readonly IReadOnlyList<string> _roots;
    private readonly Dictionary<string, QuotaSnapshot> _snapshotsByFile = new(StringComparer.OrdinalIgnoreCase);

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
        QuotaSnapshot? newestSnapshot = null;
        foreach (var file in DiscoverCandidates().Take(32))
        {
            if (newestSnapshot is not null && file.Modified <= newestSnapshot.FetchedAt.UtcDateTime) break;

            _snapshotsByFile.TryGetValue(file.Path, out var cachedSnapshot);
            var scannedSnapshot = SnapshotFromEnd(
                file.Path,
                cachedSnapshot is null ? null : IncrementalSearchLimit);
            var fileSnapshot = Newer(scannedSnapshot, cachedSnapshot);
            if (fileSnapshot is null) continue;

            _snapshotsByFile[file.Path] = fileSnapshot;
            newestSnapshot = Newer(newestSnapshot, fileSnapshot);
        }
        return newestSnapshot;
    }

    private IEnumerable<(string Path, DateTime Modified)> DiscoverCandidates()
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
        return candidates.OrderByDescending(item => item.Modified);
    }

    private static QuotaSnapshot? SnapshotFromEnd(string path, int? maximumBytes)
    {
        try
        {
            using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
            var minimumOffset = maximumBytes is { } limit
                ? Math.Max(0, stream.Length - limit)
                : 0;
            var cursor = stream.Length;
            var suffix = Array.Empty<byte>();

            while (cursor > minimumOffset)
            {
                var start = Math.Max(minimumOffset, cursor - SearchChunkSize);
                var beginsAtLineBoundary = start == 0;
                if (start > 0)
                {
                    stream.Seek(start - 1, SeekOrigin.Begin);
                    beginsAtLineBoundary = stream.ReadByte() == '\n';
                }

                var byteCount = checked((int)(cursor - start));
                var buffer = new byte[byteCount + suffix.Length];
                stream.Seek(start, SeekOrigin.Begin);
                stream.ReadExactly(buffer.AsSpan(0, byteCount));
                suffix.CopyTo(buffer, byteCount);

                var ranges = LineRanges(buffer);
                var firstCompleteLine = beginsAtLineBoundary ? 0 : 1;
                for (var index = ranges.Count - 1; index >= firstCompleteLine; index--)
                {
                    var (lineStart, lineLength) = ranges[index];
                    if (lineLength == 0) continue;
                    var line = Encoding.UTF8.GetString(buffer, lineStart, lineLength).TrimEnd('\r');
                    if (!line.Contains("\"rate_limits\"", StringComparison.Ordinal)) continue;
                    try
                    {
                        var snapshot = QuotaEventParser.ParseLine(line);
                        if (snapshot is not null) return snapshot;
                    }
                    catch (JsonException) { }
                    catch (QuotaParseException) { }
                    catch (ArgumentOutOfRangeException) { }
                }

                if (beginsAtLineBoundary || ranges.Count == 0)
                {
                    suffix = Array.Empty<byte>();
                }
                else
                {
                    var (lineStart, lineLength) = ranges[0];
                    suffix = buffer.AsSpan(lineStart, lineLength).ToArray();
                }
                cursor = start;
            }
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
        return null;
    }

    private static List<(int Start, int Length)> LineRanges(byte[] data)
    {
        var ranges = new List<(int Start, int Length)>();
        var lineStart = 0;
        for (var index = 0; index < data.Length; index++)
        {
            if (data[index] != (byte)'\n') continue;
            ranges.Add((lineStart, index - lineStart));
            lineStart = index + 1;
        }
        ranges.Add((lineStart, data.Length - lineStart));
        return ranges;
    }

    private static QuotaSnapshot? Newer(QuotaSnapshot? left, QuotaSnapshot? right)
    {
        if (left is null) return right;
        if (right is null) return left;
        return left.FetchedAt >= right.FetchedAt ? left : right;
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
