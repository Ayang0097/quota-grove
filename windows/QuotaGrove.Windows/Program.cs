using System.IO;
using System.Globalization;
using System.Threading;
using System.Windows;
using System.Windows.Threading;
using QuotaGrove.Core;

namespace QuotaGrove.Windows;

internal static class Program
{
    private static readonly TimeSpan QuotaRefreshInterval = TimeSpan.FromSeconds(10);

    [STAThread]
    public static int Main(string[] args)
    {
        ApplyLanguageOverride(args);
        var application = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        if (args.Contains("--smoke-test", StringComparer.OrdinalIgnoreCase))
        {
            return RunPreview(application, 54, Path.Combine(Path.GetTempPath(), $"quota-grove-smoke-{Guid.NewGuid():N}.png"), expanded: false, leafBurst: false, deleteAfter: true);
        }

        var previewIndex = Array.FindIndex(args, value => value.Equals("--render-preview", StringComparison.OrdinalIgnoreCase));
        if (previewIndex >= 0 && args.Length > previewIndex + 2 &&
            double.TryParse(args[previewIndex + 1], System.Globalization.CultureInfo.InvariantCulture, out var previewPercent))
        {
            return RunPreview(
                application,
                previewPercent,
                args[previewIndex + 2],
                args.Contains("--expanded", StringComparer.OrdinalIgnoreCase),
                args.Contains("--leaf-burst", StringComparer.OrdinalIgnoreCase),
                deleteAfter: false);
        }

        using var mutex = new Mutex(initiallyOwned: true, "Local\\Ayang.QuotaGrove.Windows", out var createdNew);
        if (!createdNew) return 0;

        var store = new SettingsStore();
        var settings = store.Load();
        if (settings.LayoutVersion < 2)
        {
            settings.LayoutVersion = 2;
            settings.Left = null;
            settings.Top = null;
            store.Save(settings);
        }
        var source = new LocalRateLimitSource();
        var refreshGate = new SemaphoreSlim(1, 1);
        MainWindow? window = null;
        DispatcherTimer? refreshTimer = null;

        application.Startup += async (_, _) =>
        {
            window = new MainWindow(settings, store);
            window.RefreshRequested += async (_, _) => await RefreshAsync();
            window.Show();

            refreshTimer = new DispatcherTimer { Interval = QuotaRefreshInterval };
            refreshTimer.Tick += async (_, _) => await RefreshAsync();
            refreshTimer.Start();
            await RefreshAsync();
        };

        application.Exit += (_, _) =>
        {
            refreshTimer?.Stop();
            refreshGate.Dispose();
        };

        return application.Run();

        async Task RefreshAsync()
        {
            if (window is null || !await refreshGate.WaitAsync(0)) return;
            try
            {
                var snapshot = await Task.Run(source.LatestSnapshot);
                if (snapshot is not null &&
                    (settings.LastSnapshot is null || snapshot.FetchedAt >= settings.LastSnapshot.FetchedAt))
                {
                    settings.LastSnapshot = snapshot;
                    window.ApplySnapshot(snapshot);
                    store.Save(settings);
                }
            }
            finally
            {
                refreshGate.Release();
            }
        }
    }

    private static void ApplyLanguageOverride(string[] args)
    {
        var languageIndex = Array.FindIndex(args, value => value.Equals("--language", StringComparison.OrdinalIgnoreCase));
        if (languageIndex < 0 || args.Length <= languageIndex + 1) return;
        var culture = args[languageIndex + 1].StartsWith("zh", StringComparison.OrdinalIgnoreCase)
            ? CultureInfo.GetCultureInfo("zh-CN")
            : CultureInfo.GetCultureInfo("en-US");
        CultureInfo.CurrentCulture = culture;
        CultureInfo.CurrentUICulture = culture;
    }

    private static int RunPreview(Application application, double percent, string path, bool expanded, bool leafBurst, bool deleteAfter)
    {
        var exitCode = 0;
        application.Startup += (_, _) =>
        {
            try
            {
                var window = new MainWindow(new SettingsState(), settingsStore: null, previewMode: true)
                {
                    Left = -10_000,
                    Top = -10_000
                };
                window.ApplySnapshot(QuotaSnapshot.Demo(percent));
                window.SetExpandedForPreview(expanded);
                window.ContentRendered += (_, _) =>
                {
                    void SaveAndClose()
                    {
                        try
                        {
                            window.SavePreview(path);
                            if (deleteAfter) File.Delete(path);
                        }
                        catch
                        {
                            exitCode = 1;
                        }
                        finally
                        {
                            window.Close();
                            application.Shutdown(exitCode);
                        }
                    }

                    if (!leafBurst)
                    {
                        SaveAndClose();
                        return;
                    }

                    window.PlayLeafBurstForPreview();
                    var previewTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(900) };
                    previewTimer.Tick += (_, _) =>
                    {
                        previewTimer.Stop();
                        SaveAndClose();
                    };
                    previewTimer.Start();
                };
                window.Show();
            }
            catch
            {
                exitCode = 1;
                application.Shutdown(exitCode);
            }
        };
        return application.Run();
    }
}
