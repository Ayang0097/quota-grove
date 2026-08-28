using System.IO;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using QuotaGrove.Core;

namespace QuotaGrove.Windows;

internal enum EdgeSide
{
    Left,
    Right
}

internal sealed class MainWindow : Window
{
    private const double CardWidth = 268;
    private const double CollapsedHeight = 107;
    private const double ExpandedHeight = 238;
    private const double StashedWidth = 21;
    private const double SafeInset = 27;
    private const double ShellRadius = 24;
    private const double CardBorderThickness = 0.625;
    private const double ContentInset = 20;
    private const double ContentWidth = 228;
    private const double ProgressHeight = 7;
    private const double StashedTrackHeight = 87;

    private readonly SettingsState _settings;
    private readonly SettingsStore? _settingsStore;
    private readonly bool _previewMode;
    private readonly Border _shell;
    private readonly Canvas _leafLayer;
    private readonly LeafBurstAnimator _leafAnimator;
    private readonly Canvas _summary;
    private readonly Canvas _details;
    private readonly Grid _stashedPanel;
    private readonly TextBlock _titleText;
    private readonly TextBlock _resetText;
    private readonly TextBlock _percentText;
    private readonly TextBlock _remainingText;
    private readonly Border _progressFill;
    private readonly Border _verticalFill;
    private readonly TextBlock _detailQuota;
    private readonly TextBlock _detailReset;
    private readonly TextBlock _detailPlan;
    private readonly TextBlock _detailUpdated;
    private readonly DispatcherTimer _clockTimer;
    private readonly DispatcherTimer _singleClickTimer;
    private readonly DispatcherTimer _restashTimer;
    private QuotaSnapshot? _snapshot;
    private bool _expanded;
    private bool _isStashed;
    private bool _dragging;
    private bool _suppressClickAfterDrag;
    private bool _suppressClickAfterDoubleClick;
    private Point _pointerDown;
    private EdgeSide? _edgeSide;
    private double _fullLeft;
    private double _fullTop;
    private QuotaTheme _theme = QuotaTheme.Forest;

    public event EventHandler? RefreshRequested;

    public MainWindow(SettingsState settings, SettingsStore? settingsStore, bool previewMode = false)
    {
        _settings = settings;
        _settingsStore = settingsStore;
        _previewMode = previewMode;
        _expanded = settings.Expanded;
        _edgeSide = Enum.TryParse<EdgeSide>(settings.EdgeSide, out var restoredEdge) ? restoredEdge : null;

        Title = "Quota Grove";
        Width = CardWidth;
        Height = _expanded ? ExpandedHeight : CollapsedHeight;
        MinWidth = StashedWidth;
        MinHeight = CollapsedHeight;
        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        ShowInTaskbar = false;
        Topmost = true;
        WindowStartupLocation = WindowStartupLocation.Manual;
        SnapsToDevicePixels = true;
        UseLayoutRounding = true;

        _shell = new Border
        {
            CornerRadius = new CornerRadius(ShellRadius),
            BorderThickness = new Thickness(CardBorderThickness),
            ClipToBounds = true,
            SnapsToDevicePixels = true
        };

        var root = new Grid();
        _shell.Child = root;
        Content = _shell;

        root.Children.Add(new Border
        {
            CornerRadius = new CornerRadius(ShellRadius),
            Background = new LinearGradientBrush(
                new GradientStopCollection
                {
                    new(Color.FromArgb(166, 0, 0, 0), 0),
                    new(Color.FromArgb(26, 0, 0, 0), 0.58),
                    new(Color.FromArgb(102, 0, 0, 0), 1)
                },
                new Point(0, 0.5),
                new Point(1, 0.5))
        });

        _leafLayer = new Canvas
        {
            ClipToBounds = true,
            IsHitTestVisible = false
        };
        root.Children.Add(_leafLayer);
        _leafAnimator = new LeafBurstAnimator(_leafLayer);

        _summary = new Canvas { Width = CardWidth, Height = CollapsedHeight, VerticalAlignment = VerticalAlignment.Top };
        root.Children.Add(_summary);

        var titlePanel = new StackPanel { Orientation = Orientation.Horizontal };
        Canvas.SetLeft(titlePanel, ContentInset);
        Canvas.SetTop(titlePanel, 21);
        _titleText = Text(AppText.SevenDayQuota, 17, FontWeights.Medium, Color.FromArgb(245, 255, 255, 255));
        titlePanel.Children.Add(_titleText);
        titlePanel.Children.Add(new Image
        {
            Width = 20,
            Height = 20,
            Margin = new Thickness(5, -0.5, 0, 0),
            Source = LoadImage("CodexIcon.png")
        });
        _summary.Children.Add(titlePanel);

        _resetText = Text(AppText.WaitingForQuota, 14, FontWeights.Medium, Color.FromArgb(158, 255, 255, 255));
        Canvas.SetLeft(_resetText, ContentInset);
        Canvas.SetTop(_resetText, 48);
        _summary.Children.Add(_resetText);

        _percentText = Text("--%", 31, FontWeights.SemiBold, Colors.White);
        _percentText.FontFamily = new FontFamily("Cascadia Mono, Consolas");
        _percentText.TextAlignment = TextAlignment.Right;
        _percentText.Width = 100;
        Canvas.SetLeft(_percentText, 148);
        Canvas.SetTop(_percentText, 14);
        _summary.Children.Add(_percentText);

        _remainingText = Text(AppText.Remaining, AppText.CurrentLanguage == AppLanguage.English ? 11 : 12.5, FontWeights.Medium, Color.FromArgb(158, 255, 255, 255));
        _remainingText.TextAlignment = TextAlignment.Right;
        _remainingText.Width = 60;
        Canvas.SetLeft(_remainingText, 188);
        Canvas.SetTop(_remainingText, 52);
        _summary.Children.Add(_remainingText);

        var progressTrack = new Border
        {
            Width = ContentWidth,
            Height = ProgressHeight,
            CornerRadius = new CornerRadius(ProgressHeight / 2),
            Background = new SolidColorBrush(Color.FromArgb(112, 0, 0, 0))
        };
        Canvas.SetLeft(progressTrack, ContentInset);
        Canvas.SetTop(progressTrack, 84);
        _summary.Children.Add(progressTrack);

        _progressFill = new Border
        {
            Width = 0,
            Height = ProgressHeight,
            CornerRadius = new CornerRadius(ProgressHeight / 2),
            HorizontalAlignment = HorizontalAlignment.Left
        };
        progressTrack.Child = _progressFill;

        _details = new Canvas
        {
            Width = CardWidth,
            Height = ExpandedHeight - CollapsedHeight,
            Margin = new Thickness(0, CollapsedHeight, 0, 0),
            VerticalAlignment = VerticalAlignment.Top,
            Visibility = _expanded ? Visibility.Visible : Visibility.Collapsed
        };
        root.Children.Add(_details);

        var divider = new Border
        {
            Width = ContentWidth,
            Height = 1,
            Background = new SolidColorBrush(Color.FromArgb(41, 255, 255, 255))
        };
        Canvas.SetLeft(divider, ContentInset);
        Canvas.SetTop(divider, 4);
        _details.Children.Add(divider);

        _detailQuota = AddDetailRow(AppText.SevenDayQuota, 20);
        _detailQuota.FontSize = AppText.CurrentLanguage == AppLanguage.English ? 12.5 : 14;
        _detailReset = AddDetailRow(AppText.TimeToReset, 47);
        _detailPlan = AddDetailRow(AppText.SubscriptionPlan, 74);
        _detailUpdated = AddDetailRow(AppText.DataUpdated, 101);

        _stashedPanel = new Grid { Visibility = Visibility.Collapsed, Width = StashedWidth, Height = CollapsedHeight };
        root.Children.Add(_stashedPanel);
        var verticalTrack = new Border
        {
            Width = ProgressHeight,
            Height = StashedTrackHeight,
            CornerRadius = new CornerRadius(ProgressHeight / 2),
            Background = new SolidColorBrush(Color.FromArgb(189, 5, 7, 6)),
            VerticalAlignment = VerticalAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Center
        };
        _verticalFill = new Border
        {
            Width = ProgressHeight,
            Height = 0,
            CornerRadius = new CornerRadius(ProgressHeight / 2),
            VerticalAlignment = VerticalAlignment.Bottom
        };
        verticalTrack.Child = _verticalFill;
        _stashedPanel.Children.Add(verticalTrack);

        _clockTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(5) };
        _clockTimer.Tick += (_, _) => UpdateText();
        _singleClickTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(240) };
        _singleClickTimer.Tick += (_, _) =>
        {
            _singleClickTimer.Stop();
            if (_edgeSide is null) SetExpanded(!_expanded, save: true);
        };
        _restashTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(650) };
        _restashTimer.Tick += (_, _) =>
        {
            _restashTimer.Stop();
            if (_edgeSide is { } edge && !_dragging && !IsMouseOver) Stash(edge, save: true);
        };

        MouseEnter += OnMouseEntered;
        MouseLeave += OnMouseExited;
        PreviewMouseLeftButtonDown += OnMouseLeftButtonDown;
        PreviewMouseLeftButtonUp += OnMouseLeftButtonUp;
        PreviewMouseMove += OnMouseMove;
        Loaded += OnLoaded;
        Closed += (_, _) =>
        {
            _clockTimer.Stop();
            _leafAnimator.Dispose();
            SaveSettings();
        };

        ContextMenu = BuildContextMenu();
        ApplySnapshot(settings.LastSnapshot);
    }

    public void ApplySnapshot(QuotaSnapshot? snapshot)
    {
        _snapshot = snapshot;
        var theme = QuotaThemes.Select(snapshot?.RemainingPercent ?? 100);
        _theme = theme;
        var style = QuotaThemes.Style(theme);
        _shell.Background = new ImageBrush(LoadImage(style.BackgroundAsset))
        {
            Stretch = Stretch.UniformToFill,
            AlignmentX = AlignmentX.Center,
            AlignmentY = AlignmentY.Center
        };
        _shell.BorderBrush = new SolidColorBrush(WithAlpha(ParseColor(style.BorderHex), 204));
        var accent = ParseColor(style.AccentHex);
        _progressFill.Background = ProgressGradient(accent);
        _verticalFill.Background = ProgressGradient(accent, vertical: true);
        var progressWidth = snapshot is null ? 0 : Math.Max(snapshot.RemainingPercent > 0 ? 4 : 0, ContentWidth * snapshot.RemainingPercent / 100);
        _progressFill.Width = progressWidth;
        _verticalFill.Height = snapshot is null ? 0 : Math.Max(snapshot.RemainingPercent > 0 ? 5 : 0, StashedTrackHeight * snapshot.RemainingPercent / 100);
        UpdateText();
    }

    public void SetExpandedForPreview(bool expanded) => SetExpanded(expanded, save: false);

    public void PlayLeafBurstForPreview() =>
        _leafAnimator.PlayBurst(_theme, CardWidth, ActualHeight > 0 ? ActualHeight : Height, ignoreReducedMotion: true);

    public void SavePreview(string path)
    {
        UpdateLayout();
        var width = Math.Max(1, (int)Math.Ceiling(ActualWidth));
        var height = Math.Max(1, (int)Math.Ceiling(ActualHeight));
        var bitmap = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
        bitmap.Render(this);
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path))!);
        using var stream = File.Create(path);
        encoder.Save(stream);
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        var workArea = NativeMethods.WorkArea(this);
        _fullLeft = _settings.Left ?? workArea.Right - CardWidth - SafeInset;
        _fullTop = _settings.Top ?? workArea.Top + SafeInset;
        (_fullLeft, _fullTop) = Constrain(_fullLeft, _fullTop, CardWidth, _expanded ? ExpandedHeight : CollapsedHeight, workArea);
        Left = _fullLeft;
        Top = _fullTop;
        _clockTimer.Start();
        if (_edgeSide is { } edge && !_previewMode) Stash(edge, save: false);
    }

    private TextBlock AddDetailRow(string label, double top)
    {
        var labelText = Text(label, 14, FontWeights.Medium, Color.FromArgb(143, 255, 255, 255));
        Canvas.SetLeft(labelText, ContentInset);
        Canvas.SetTop(labelText, top);
        _details.Children.Add(labelText);

        var valueText = Text("--", 14, FontWeights.Medium, Color.FromArgb(235, 255, 255, 255));
        valueText.FontFamily = new FontFamily("Cascadia Mono, Consolas");
        valueText.TextAlignment = TextAlignment.Right;
        valueText.Width = 154;
        Canvas.SetLeft(valueText, 94);
        Canvas.SetTop(valueText, top);
        _details.Children.Add(valueText);
        return valueText;
    }

    private void UpdateText()
    {
        _titleText.Text = _snapshot?.WindowTitle ?? AppText.SevenDayQuota;
        _percentText.Text = _snapshot is null ? "--%" : $"{_snapshot.RoundedRemaining}%";
        _remainingText.Text = AppText.Remaining;
        _resetText.Text = SummaryResetText();
        _detailQuota.Text = _snapshot is null ? "--" : AppText.QuotaUsage(_snapshot.RoundedRemaining, _snapshot.RoundedUsed);
        _detailReset.Text = ExactResetText();
        _detailPlan.Text = _snapshot?.ReadablePlan ?? "--";
        _detailUpdated.Text = DataAgeText();
        UpdateAccessibility();
    }

    private string SummaryResetText()
    {
        if (_snapshot?.ResetsAt is not { } reset) return _snapshot is null ? AppText.WaitingForQuota : AppText.ResetTimeUnknown;
        var remaining = reset - DateTimeOffset.Now;
        if (remaining <= TimeSpan.Zero) return AppText.ResettingSoon;
        var days = (int)remaining.TotalDays;
        var hours = remaining.Hours;
        var minutes = Math.Max(1, remaining.Minutes);
        return AppText.ResetCountdown(days, hours, minutes, includeResetPrefix: true);
    }

    private string ExactResetText()
    {
        if (_snapshot?.ResetsAt is not { } reset) return "--";
        var remaining = reset - DateTimeOffset.Now;
        if (remaining <= TimeSpan.Zero) return AppText.ResettingSoon;
        var days = (int)remaining.TotalDays;
        var hours = remaining.Hours;
        var minutes = Math.Max(1, remaining.Minutes);
        return AppText.ResetCountdown(days, hours, minutes, includeResetPrefix: false);
    }

    private string DataAgeText()
    {
        if (_snapshot is null) return "--";
        return AppText.DataAge(DateTimeOffset.Now - _snapshot.FetchedAt);
    }

    private void SetExpanded(bool expanded, bool save)
    {
        _expanded = expanded;
        if (!_isStashed)
        {
            Width = CardWidth;
            Height = expanded ? ExpandedHeight : CollapsedHeight;
            _details.Visibility = expanded ? Visibility.Visible : Visibility.Collapsed;
        }
        UpdateAccessibility();
        if (save) SaveSettings();
    }

    private void Stash(EdgeSide side, bool save)
    {
        _singleClickTimer.Stop();
        if (!_isStashed)
        {
            _fullLeft = Left;
            _fullTop = Top;
        }
        _edgeSide = side;
        _isStashed = true;
        _leafAnimator.Clear();
        _leafLayer.Visibility = Visibility.Collapsed;
        var workArea = NativeMethods.WorkArea(this);
        Width = StashedWidth;
        Height = CollapsedHeight;
        Left = side == EdgeSide.Left ? workArea.Left : workArea.Right - StashedWidth;
        Top = Math.Clamp(_fullTop, workArea.Top, workArea.Bottom - CollapsedHeight);
        _summary.Visibility = Visibility.Collapsed;
        _details.Visibility = Visibility.Collapsed;
        _stashedPanel.Visibility = Visibility.Visible;
        _shell.CornerRadius = side == EdgeSide.Left
            ? new CornerRadius(0, ShellRadius, ShellRadius, 0)
            : new CornerRadius(ShellRadius, 0, 0, ShellRadius);
        UpdateAccessibility();
        if (save) SaveSettings();
    }

    private void Reveal(EdgeSide side)
    {
        _isStashed = false;
        var workArea = NativeMethods.WorkArea(this);
        Width = CardWidth;
        Height = _expanded ? ExpandedHeight : CollapsedHeight;
        Left = side == EdgeSide.Left ? workArea.Left : workArea.Right - CardWidth;
        Top = Math.Clamp(_fullTop, workArea.Top, workArea.Bottom - Height);
        _summary.Visibility = Visibility.Visible;
        _details.Visibility = _expanded ? Visibility.Visible : Visibility.Collapsed;
        _stashedPanel.Visibility = Visibility.Collapsed;
        _leafLayer.Visibility = Visibility.Visible;
        _shell.CornerRadius = new CornerRadius(ShellRadius);
        UpdateAccessibility();
    }

    private void OnMouseEntered(object sender, MouseEventArgs e)
    {
        _restashTimer.Stop();
        if (_isStashed && _edgeSide is { } edge) Reveal(edge);
    }

    private void OnMouseExited(object sender, MouseEventArgs e)
    {
        if (_edgeSide is not null && !_dragging)
        {
            _restashTimer.Stop();
            _restashTimer.Start();
        }
    }

    private void OnMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        _pointerDown = e.GetPosition(this);
        _dragging = false;
        if (e.ClickCount >= 2)
        {
            _singleClickTimer.Stop();
            _suppressClickAfterDoubleClick = true;
            _leafAnimator.PlayBurst(_theme, CardWidth, ActualHeight > 0 ? ActualHeight : Height);
            RefreshRequested?.Invoke(this, EventArgs.Empty);
            e.Handled = true;
            return;
        }
        CaptureMouse();
    }

    private void OnMouseLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        if (IsMouseCaptured) ReleaseMouseCapture();
        if (_suppressClickAfterDoubleClick)
        {
            _suppressClickAfterDoubleClick = false;
            e.Handled = true;
            return;
        }
        if (_suppressClickAfterDrag)
        {
            _suppressClickAfterDrag = false;
            e.Handled = true;
            return;
        }
        if (_dragging) return;
        if (_edgeSide is null)
        {
            _singleClickTimer.Stop();
            _singleClickTimer.Start();
        }
        e.Handled = true;
    }

    private void OnMouseMove(object sender, MouseEventArgs e)
    {
        if (e.LeftButton != MouseButtonState.Pressed || _dragging) return;
        var point = e.GetPosition(this);
        if (Math.Abs(point.X - _pointerDown.X) < 4 && Math.Abs(point.Y - _pointerDown.Y) < 4) return;

        _dragging = true;
        _suppressClickAfterDrag = true;
        _singleClickTimer.Stop();
        _restashTimer.Stop();
        _edgeSide = null;
        _isStashed = false;
        _summary.Visibility = Visibility.Visible;
        _stashedPanel.Visibility = Visibility.Collapsed;
        _leafLayer.Visibility = Visibility.Visible;
        _details.Visibility = _expanded ? Visibility.Visible : Visibility.Collapsed;
        _shell.CornerRadius = new CornerRadius(ShellRadius);
        Width = CardWidth;
        Height = _expanded ? ExpandedHeight : CollapsedHeight;
        if (IsMouseCaptured) ReleaseMouseCapture();
        try
        {
            DragMove();
        }
        catch (InvalidOperationException) { }
        finally
        {
            _fullLeft = Left;
            _fullTop = Top;
            MaybeStashAfterDrag();
            SaveSettings();
            _dragging = false;
        }
    }

    private void MaybeStashAfterDrag()
    {
        var workArea = NativeMethods.WorkArea(this);
        if (Math.Abs(Left - workArea.Left) <= 7) Stash(EdgeSide.Left, save: true);
        else if (Math.Abs(Left + Width - workArea.Right) <= 7) Stash(EdgeSide.Right, save: true);
        else
        {
            (_fullLeft, _fullTop) = Constrain(Left, Top, Width, Height, workArea);
            Left = _fullLeft;
            Top = _fullTop;
        }
    }

    private ContextMenu BuildContextMenu()
    {
        var menu = new ContextMenu();
        var refresh = new MenuItem { Header = AppText.RefreshQuota };
        refresh.Click += (_, _) => RefreshRequested?.Invoke(this, EventArgs.Empty);
        menu.Items.Add(refresh);

        var launch = new MenuItem { Header = AppText.LaunchAtLogin, IsCheckable = true, IsChecked = StartupManager.IsEnabled };
        launch.Click += (_, _) =>
        {
            try
            {
                StartupManager.SetEnabled(launch.IsChecked);
            }
            catch (Exception error) when (error is InvalidOperationException or UnauthorizedAccessException)
            {
                MessageBox.Show(error.Message, AppText.LaunchUpdateFailed, MessageBoxButton.OK, MessageBoxImage.Information);
                launch.IsChecked = StartupManager.IsEnabled;
            }
        };
        menu.Items.Add(launch);
        menu.Items.Add(new Separator());

        var reset = new MenuItem { Header = AppText.ResetCardPosition };
        reset.Click += (_, _) => ResetPosition();
        menu.Items.Add(reset);

        var about = new MenuItem { Header = AppText.AboutAndPrivacy };
        about.Click += (_, _) => MessageBox.Show(
            AppText.AboutMessage,
            AppText.AboutTitle,
            MessageBoxButton.OK,
            MessageBoxImage.Information);
        menu.Items.Add(about);
        menu.Items.Add(new Separator());

        var quit = new MenuItem { Header = AppText.Quit };
        quit.Click += (_, _) => Application.Current.Shutdown();
        menu.Items.Add(quit);
        return menu;
    }

    private void ResetPosition()
    {
        _edgeSide = null;
        _isStashed = false;
        SetExpanded(_expanded, save: false);
        var workArea = NativeMethods.WorkArea(this);
        _fullLeft = workArea.Right - CardWidth - SafeInset;
        _fullTop = workArea.Top + SafeInset;
        Left = _fullLeft;
        Top = _fullTop;
        _summary.Visibility = Visibility.Visible;
        _details.Visibility = _expanded ? Visibility.Visible : Visibility.Collapsed;
        _stashedPanel.Visibility = Visibility.Collapsed;
        _leafLayer.Visibility = Visibility.Visible;
        _shell.CornerRadius = new CornerRadius(ShellRadius);
        SaveSettings();
    }

    private void SaveSettings()
    {
        if (_previewMode || _settingsStore is null) return;
        if (!_isStashed && _edgeSide is null)
        {
            _fullLeft = Left;
            _fullTop = Top;
        }
        _settings.Left = _fullLeft;
        _settings.Top = _fullTop;
        _settings.Expanded = _expanded;
        _settings.EdgeSide = _edgeSide?.ToString();
        _settings.LastSnapshot = _snapshot;
        _settingsStore.Save(_settings);
    }

    private static (double Left, double Top) Constrain(double left, double top, double width, double height, Rect workArea)
    {
        var constrainedLeft = Math.Clamp(left, workArea.Left, Math.Max(workArea.Left, workArea.Right - width));
        var constrainedTop = Math.Clamp(top, workArea.Top, Math.Max(workArea.Top, workArea.Bottom - height));
        return (constrainedLeft, constrainedTop);
    }

    private static TextBlock Text(string text, double size, FontWeight weight, Color color) => new()
    {
        Text = text,
        FontFamily = new FontFamily("Segoe UI, Microsoft YaHei UI"),
        FontSize = size,
        FontWeight = weight,
        Foreground = new SolidColorBrush(color),
        TextTrimming = TextTrimming.CharacterEllipsis
    };

    private static BitmapImage LoadImage(string fileName)
    {
        var image = new BitmapImage();
        image.BeginInit();
        image.CacheOption = BitmapCacheOption.OnLoad;
        image.UriSource = new Uri($"pack://application:,,,/Assets/{fileName}", UriKind.Absolute);
        image.EndInit();
        image.Freeze();
        return image;
    }

    private static Color ParseColor(string hex) => (Color)ColorConverter.ConvertFromString(hex)!;

    private static Color WithAlpha(Color color, byte alpha) => Color.FromArgb(alpha, color.R, color.G, color.B);

    private void UpdateAccessibility()
    {
        QuotaTheme? theme = _snapshot is null ? null : QuotaThemes.Select(_snapshot.RemainingPercent);
        AutomationProperties.SetName(_shell, AppText.AccessibilityName(
            _snapshot?.WindowTitle ?? AppText.SevenDayQuota,
            _snapshot?.RoundedRemaining,
            theme,
            _isStashed,
            _expanded));
        AutomationProperties.SetHelpText(_shell, AppText.AccessibilityHelp);
    }

    private static LinearGradientBrush ProgressGradient(Color accent, bool vertical = false)
    {
        var start = Blend(accent, Colors.Black, 0.42);
        var middle = Blend(accent, Colors.Black, 0.14);
        var end = Blend(accent, Colors.White, 0.08);
        return new LinearGradientBrush(
            new GradientStopCollection
            {
                new(start, 0),
                new(middle, 0.55),
                new(end, 1)
            },
            new Point(0, vertical ? 1 : 0.5),
            new Point(vertical ? 0 : 1, vertical ? 0 : 0.5));
    }

    private static Color Blend(Color source, Color target, double fraction)
    {
        byte Mix(byte first, byte second) => (byte)Math.Round(first + (second - first) * fraction);
        return Color.FromRgb(Mix(source.R, target.R), Mix(source.G, target.G), Mix(source.B, target.B));
    }
}
