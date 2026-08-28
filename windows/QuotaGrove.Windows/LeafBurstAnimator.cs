using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Effects;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using QuotaGrove.Core;

namespace QuotaGrove.Windows;

internal sealed class LeafBurstAnimator : IDisposable
{
    public const int BurstLeafCount = 48;

    private readonly Canvas _layer;
    private readonly DispatcherTimer _timer;
    private readonly Random _random = new(0x47524F56);
    private readonly Dictionary<string, BitmapImage> _spriteCache = [];
    private readonly List<LeafVisual> _leaves = [];
    private DateTime _previousTick;
    private double _layerHeight;

    public LeafBurstAnimator(Canvas layer)
    {
        _layer = layer;
        _timer = new DispatcherTimer(DispatcherPriority.Render)
        {
            Interval = TimeSpan.FromSeconds(1.0 / 30.0)
        };
        _timer.Tick += OnTick;
    }

    public void PlayBurst(QuotaTheme theme, double width, double height, bool ignoreReducedMotion = false)
    {
        if (!ignoreReducedMotion && !SystemParameters.ClientAreaAnimation) return;
        if (width <= 0 || height <= 0) return;

        Clear();
        _layerHeight = height;
        var generated = new List<LeafVisual>(BurstLeafCount);
        for (var index = 0; index < BurstLeafCount; index++)
        {
            var wave = index / 12;
            var waveIndex = index % 12;
            var depth = NextDouble(0.14, 0.98);
            var size = NextDouble(12, 23) * (0.78 + depth * 0.28);
            var focus = index % 4;
            var image = new Image
            {
                Source = LoadSprite(theme, _random.Next(1, 4)),
                Width = size,
                Height = size,
                Opacity = 0,
                Stretch = Stretch.Uniform,
                IsHitTestVisible = false,
                RenderTransformOrigin = new Point(0.5, 0.5)
            };
            if (focus != 0)
            {
                image.Effect = new BlurEffect { Radius = focus == 1 ? 0.8 : 1.7 };
            }

            generated.Add(new LeafVisual
            {
                Image = image,
                X = NextDouble(width * 0.05, width * 1.05),
                Y = -size - NextDouble(-4, height * 0.3),
                VelocityX = NextDouble(-24, 11) * (0.84 + depth * 0.28),
                VelocityY = NextDouble(62, 94) * (0.8 + depth * 0.36),
                SwayPhase = NextDouble(0, Math.PI * 2),
                SwaySpeed = NextDouble(1.6, 3.4),
                SwayAmplitude = NextDouble(2.4, 8.2) * (0.7 + depth * 0.38),
                Rotation = NextDouble(-72, 72),
                AngularVelocity = NextDouble(-96, 96) * (0.74 + depth * 0.38),
                Depth = depth,
                Age = -(wave * 0.18 + waveIndex * 0.035 + NextDouble(0, 0.16)),
                Lifetime = NextDouble(2.8, 4.0)
            });
        }

        foreach (var leaf in generated.OrderBy(leaf => leaf.Depth))
        {
            leaf.Image.RenderTransform = new RotateTransform(leaf.Rotation);
            _layer.Children.Add(leaf.Image);
            _leaves.Add(leaf);
        }

        _previousTick = DateTime.UtcNow;
        _timer.Start();
    }

    public void Clear()
    {
        _timer.Stop();
        _leaves.Clear();
        _layer.Children.Clear();
    }

    public void Dispose()
    {
        _timer.Tick -= OnTick;
        Clear();
    }

    private void OnTick(object? sender, EventArgs e)
    {
        var now = DateTime.UtcNow;
        var delta = Math.Clamp((now - _previousTick).TotalSeconds, 0, 1.0 / 15.0);
        _previousTick = now;

        for (var index = _leaves.Count - 1; index >= 0; index--)
        {
            var leaf = _leaves[index];
            leaf.Age += delta;
            if (leaf.Age < 0)
            {
                leaf.Image.Opacity = 0;
                continue;
            }

            leaf.X += leaf.VelocityX * delta;
            leaf.Y += leaf.VelocityY * delta;
            leaf.SwayPhase += leaf.SwaySpeed * delta;
            leaf.Rotation += leaf.AngularVelocity * delta;

            if (leaf.Age >= leaf.Lifetime || leaf.Y > _layerHeight + leaf.Image.Height * 1.5)
            {
                _layer.Children.Remove(leaf.Image);
                _leaves.RemoveAt(index);
                continue;
            }

            var fadeIn = Math.Min(1, leaf.Age / 0.16);
            var fadeOut = Math.Min(1, (leaf.Lifetime - leaf.Age) / 0.5);
            leaf.Image.Opacity = Math.Max(0, Math.Min(fadeIn, fadeOut)) * (0.56 + leaf.Depth * 0.4);
            Canvas.SetLeft(leaf.Image, leaf.X + Math.Sin(leaf.SwayPhase) * leaf.SwayAmplitude);
            Canvas.SetTop(leaf.Image, leaf.Y);
            ((RotateTransform)leaf.Image.RenderTransform).Angle = leaf.Rotation;
        }

        if (_leaves.Count == 0) _timer.Stop();
    }

    private BitmapImage LoadSprite(QuotaTheme theme, int variant)
    {
        var key = $"{theme.ToString().ToLowerInvariant()}-{variant}";
        if (_spriteCache.TryGetValue(key, out var cached)) return cached;

        var image = new BitmapImage();
        image.BeginInit();
        image.CacheOption = BitmapCacheOption.OnLoad;
        image.UriSource = new Uri($"pack://application:,,,/Assets/Leaves/{key}.png", UriKind.Absolute);
        image.EndInit();
        image.Freeze();
        _spriteCache[key] = image;
        return image;
    }

    private double NextDouble(double minimum, double maximum) =>
        minimum + _random.NextDouble() * (maximum - minimum);

    private sealed class LeafVisual
    {
        public required Image Image { get; init; }
        public double X { get; set; }
        public double Y { get; set; }
        public double VelocityX { get; init; }
        public double VelocityY { get; init; }
        public double SwayPhase { get; set; }
        public double SwaySpeed { get; init; }
        public double SwayAmplitude { get; init; }
        public double Rotation { get; set; }
        public double AngularVelocity { get; init; }
        public double Depth { get; init; }
        public double Age { get; set; }
        public double Lifetime { get; init; }
    }
}
