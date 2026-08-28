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
    private static readonly int[] BurstWaveCounts = [4, 10, 19, 10, 5];
    private static readonly double[] BurstWaveStartDelays = [0, 0.18, 0.38, 0.66, 0.94];

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
        var index = 0;
        var gravityBase = Math.Clamp(height / 2.4, 42, 64);
        for (var wave = 0; wave < BurstWaveCounts.Length; wave++)
        {
            for (var waveIndex = 0; waveIndex < BurstWaveCounts[wave]; waveIndex++)
            {
                var depth = NextDouble(0.14, 0.98);
                var size = NextDouble(12, 23) * (0.78 + depth * 0.28);
                var focus = index % 4;
                var baseBlurRadius = focus == 0 ? 0 : focus == 1 ? 0.8 : 1.7;
                var blurEffect = new BlurEffect { Radius = baseBlurRadius };
                var scaleTransform = new ScaleTransform(1, 1);
                var rotationTransform = new RotateTransform(0);
                var transformGroup = new TransformGroup();
                transformGroup.Children.Add(scaleTransform);
                transformGroup.Children.Add(rotationTransform);
                var image = new Image
                {
                    Source = LoadSprite(theme, _random.Next(1, 4)),
                    Width = size,
                    Height = size,
                    Opacity = 0,
                    Stretch = Stretch.Uniform,
                    IsHitTestVisible = false,
                    RenderTransformOrigin = new Point(0.5, 0.5),
                    RenderTransform = transformGroup,
                    Effect = blurEffect
                };

                generated.Add(new LeafVisual
                {
                    Image = image,
                    ScaleTransform = scaleTransform,
                    RotationTransform = rotationTransform,
                    BlurEffect = blurEffect,
                    BaseBlurRadius = baseBlurRadius,
                    X = NextDouble(width * 0.72, width * 1.16),
                    Y = -size - NextDouble(-6, height * 0.2),
                    VelocityX = -NextDouble(58, 82) * (0.84 + depth * 0.28),
                    VelocityY = NextDouble(6, 14) * (0.82 + depth * 0.28),
                    Gravity = NextDouble(gravityBase, gravityBase + 18) * (0.82 + depth * 0.28),
                    HorizontalDrag = NextDouble(0.12, 0.24),
                    WindAccelerationX = -NextDouble(34, 58) * (0.84 + depth * 0.28),
                    SwayPhase = NextDouble(0, Math.PI * 2),
                    SwaySpeed = NextDouble(1.6, 3.4),
                    SwayAmplitude = NextDouble(2.4, 8.2) * (0.7 + depth * 0.38),
                    Rotation = NextDouble(-72, 72),
                    AngularVelocity = NextDouble(-96, 96) * (0.74 + depth * 0.38),
                    Depth = depth,
                    Age = -(BurstWaveStartDelays[wave] + waveIndex * 0.012 + NextDouble(0, 0.12)),
                    Lifetime = NextDouble(3.0, 4.2)
                });
                index++;
            }
        }

        foreach (var leaf in generated.OrderBy(leaf => leaf.Depth))
        {
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

            var gustStrength = Math.Exp(-leaf.Age * 2.35);
            leaf.VelocityY += leaf.Gravity * delta;
            leaf.VelocityX += leaf.WindAccelerationX * gustStrength * delta;
            leaf.VelocityX *= Math.Max(0, 1 - leaf.HorizontalDrag * delta);
            leaf.X += leaf.VelocityX * delta;
            leaf.Y += leaf.VelocityY * delta;
            leaf.SwayPhase += leaf.SwaySpeed * delta;
            leaf.Rotation += leaf.AngularVelocity * delta;
            var departure = BottomDepartureProgress(leaf.Y, _layerHeight);

            if (leaf.Age >= leaf.Lifetime || departure >= 1 || leaf.Y > _layerHeight + leaf.Image.Height * 1.5)
            {
                _layer.Children.Remove(leaf.Image);
                _leaves.RemoveAt(index);
                continue;
            }

            var fadeIn = Math.Min(1, leaf.Age / 0.16);
            var fadeOut = Math.Min(1, (leaf.Lifetime - leaf.Age) / 0.5);
            var departureOpacity = Math.Pow(1 - departure, 1.18);
            leaf.Image.Opacity = Math.Max(0, Math.Min(fadeIn, fadeOut)) * (0.56 + leaf.Depth * 0.4) * departureOpacity;
            var departureScale = 1 - departure * 0.46;
            leaf.ScaleTransform.ScaleX = departureScale;
            leaf.ScaleTransform.ScaleY = departureScale;
            leaf.BlurEffect.Radius = leaf.BaseBlurRadius + departure * 2.4;
            Canvas.SetLeft(leaf.Image, leaf.X + Math.Sin(leaf.SwayPhase) * leaf.SwayAmplitude);
            Canvas.SetTop(leaf.Image, leaf.Y);
            leaf.RotationTransform.Angle = leaf.Rotation;
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

    private static double BottomDepartureProgress(double y, double height)
    {
        if (height <= 0) return 0;
        var startY = height * 0.66;
        var endY = height * 0.98;
        var linear = Math.Clamp((y - startY) / Math.Max(1, endY - startY), 0, 1);
        return linear * linear * (3 - 2 * linear);
    }

    private sealed class LeafVisual
    {
        public required Image Image { get; init; }
        public required ScaleTransform ScaleTransform { get; init; }
        public required RotateTransform RotationTransform { get; init; }
        public required BlurEffect BlurEffect { get; init; }
        public double BaseBlurRadius { get; init; }
        public double X { get; set; }
        public double Y { get; set; }
        public double VelocityX { get; set; }
        public double VelocityY { get; set; }
        public double Gravity { get; init; }
        public double HorizontalDrag { get; init; }
        public double WindAccelerationX { get; init; }
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
