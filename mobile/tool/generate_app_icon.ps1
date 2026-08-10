Add-Type -AssemblyName System.Drawing

function New-RoundedPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function Draw-SoftBlob($graphics, [float]$cx, [float]$cy, [float]$radius, [System.Drawing.Color]$color) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse($cx - $radius, $cy - $radius, $radius * 2, $radius * 2)
    $brush = New-Object System.Drawing.Drawing2D.PathGradientBrush $path
    $brush.CenterPoint = New-Object System.Drawing.PointF $cx, $cy
    $brush.CenterColor = [System.Drawing.Color]::FromArgb(156, $color.R, $color.G, $color.B)
    $brush.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $color.R, $color.G, $color.B))
    $graphics.FillPath($brush, $path)
    $brush.Dispose(); $path.Dispose()
}

function Draw-Background($graphics, [int]$size) {
    $graphics.Clear([System.Drawing.Color]::FromArgb(255, 247, 250, 254))
    Draw-SoftBlob $graphics ($size * .64) ($size * .30) ($size * .35) ([System.Drawing.Color]::FromArgb(82, 204, 247))
    Draw-SoftBlob $graphics ($size * .30) ($size * .48) ($size * .31) ([System.Drawing.Color]::FromArgb(248, 218, 82))
    Draw-SoftBlob $graphics ($size * .43) ($size * .76) ($size * .33) ([System.Drawing.Color]::FromArgb(244, 123, 174))
    Draw-SoftBlob $graphics ($size * .76) ($size * .69) ($size * .33) ([System.Drawing.Color]::FromArgb(154, 136, 242))
}

function Draw-Foreground($graphics, [int]$size, [bool]$monochrome) {
    $scale = $size / 1024.0
    $glass = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(198, 255, 255, 255))
    $glassPath = New-RoundedPath (272 * $scale) (272 * $scale) (480 * $scale) (480 * $scale) (154 * $scale)
    $graphics.FillPath($glass, $glassPath)
    $glass.Dispose(); $glassPath.Dispose()

    $ink = if ($monochrome) { [System.Drawing.Color]::Black } else { [System.Drawing.Color]::FromArgb(23, 58, 107) }
    $orbit = New-Object System.Drawing.Pen $ink, (58 * $scale)
    $orbit.Alignment = [System.Drawing.Drawing2D.PenAlignment]::Center
    $graphics.DrawEllipse($orbit, 338 * $scale, 338 * $scale, 348 * $scale, 348 * $scale)
    $orbit.Dispose()

    $hubBrush = New-Object System.Drawing.SolidBrush $ink
    $hubPath = New-RoundedPath (430 * $scale) (430 * $scale) (164 * $scale) (164 * $scale) (48 * $scale)
    $graphics.FillPath($hubBrush, $hubPath)
    $hubBrush.Dispose(); $hubPath.Dispose()

    $nodes = @(
        @(512, 330, 92, 140, 255),
        @(694, 512, 65, 199, 190),
        @(512, 694, 255, 110, 145),
        @(330, 512, 242, 211, 79)
    )
    foreach ($node in $nodes) {
        $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
        $graphics.FillEllipse($white, ($node[0] - 63) * $scale, ($node[1] - 63) * $scale, 126 * $scale, 126 * $scale)
        $white.Dispose()
        $nodeColor = if ($monochrome) { [System.Drawing.Color]::Black } else { [System.Drawing.Color]::FromArgb($node[2], $node[3], $node[4]) }
        $brush = New-Object System.Drawing.SolidBrush $nodeColor
        $graphics.FillEllipse($brush, ($node[0] - 55) * $scale, ($node[1] - 55) * $scale, 110 * $scale, 110 * $scale)
        $brush.Dispose()
    }
}

function New-Icon([int]$size, [string]$path, [bool]$foregroundOnly = $false, [bool]$monochrome = $false) {
    $bitmap = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    if ($foregroundOnly) { $graphics.Clear([System.Drawing.Color]::Transparent) } else { Draw-Background $graphics $size }
    Draw-Foreground $graphics $size $monochrome
    $directory = Split-Path -Parent $path
    New-Item -ItemType Directory -Force $directory | Out-Null
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $bitmap.Dispose()
}

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$res = Join-Path $root 'android\app\src\main\res'
New-Icon 1024 (Join-Path $root 'assets\icon\memory-hub-app-icon-1024.png')
New-Icon 432 (Join-Path $res 'drawable\ic_launcher_foreground.png') $true
New-Icon 432 (Join-Path $res 'drawable\ic_launcher_monochrome.png') $true $true
$sizes = @{ 'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192 }
foreach ($entry in $sizes.GetEnumerator()) {
    New-Icon $entry.Value (Join-Path $res ("mipmap-{0}\ic_launcher.png" -f $entry.Key))
}

$ios = Join-Path $root 'ios\Runner\Assets.xcassets\AppIcon.appiconset'
$iosSizes = @{
    'Icon-App-20x20@1x.png' = 20; 'Icon-App-20x20@2x.png' = 40; 'Icon-App-20x20@3x.png' = 60
    'Icon-App-29x29@1x.png' = 29; 'Icon-App-29x29@2x.png' = 58; 'Icon-App-29x29@3x.png' = 87
    'Icon-App-40x40@1x.png' = 40; 'Icon-App-40x40@2x.png' = 80; 'Icon-App-40x40@3x.png' = 120
    'Icon-App-60x60@2x.png' = 120; 'Icon-App-60x60@3x.png' = 180
    'Icon-App-76x76@1x.png' = 76; 'Icon-App-76x76@2x.png' = 152
    'Icon-App-83.5x83.5@2x.png' = 167; 'Icon-App-1024x1024@1x.png' = 1024
}
foreach ($entry in $iosSizes.GetEnumerator()) {
    New-Icon $entry.Value (Join-Path $ios $entry.Key)
}

$web = Join-Path $root 'web'
New-Icon 32 (Join-Path $web 'favicon.png')
New-Icon 192 (Join-Path $web 'icons\Icon-192.png')
New-Icon 512 (Join-Path $web 'icons\Icon-512.png')
New-Icon 192 (Join-Path $web 'icons\Icon-maskable-192.png')
New-Icon 512 (Join-Path $web 'icons\Icon-maskable-512.png')
