using System.IO;
using System.Text.Json;
using QuotaGrove.Core;

namespace QuotaGrove.Windows;

internal sealed class SettingsState
{
    public double? Left { get; set; }
    public double? Top { get; set; }
    public bool Expanded { get; set; }
    public string? EdgeSide { get; set; }
    public QuotaSnapshot? LastSnapshot { get; set; }
}

internal sealed class SettingsStore
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    private readonly string _path;

    public SettingsStore()
    {
        var directory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "QuotaGrove");
        _path = Path.Combine(directory, "settings.json");
    }

    public SettingsState Load()
    {
        try
        {
            if (!File.Exists(_path)) return new SettingsState();
            return JsonSerializer.Deserialize<SettingsState>(File.ReadAllText(_path), JsonOptions)
                ?? new SettingsState();
        }
        catch (IOException) { return new SettingsState(); }
        catch (UnauthorizedAccessException) { return new SettingsState(); }
        catch (JsonException) { return new SettingsState(); }
    }

    public void Save(SettingsState state)
    {
        try
        {
            var directory = Path.GetDirectoryName(_path)!;
            Directory.CreateDirectory(directory);
            var temporaryPath = _path + ".tmp";
            File.WriteAllText(temporaryPath, JsonSerializer.Serialize(state, JsonOptions));
            File.Move(temporaryPath, _path, overwrite: true);
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
    }
}
