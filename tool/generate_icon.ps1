Add-Type -AssemblyName System.Drawing

function RoundRect($g, $x, $y, $w, $h, $r, $brush) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($x, $y, $r*2, $r*2, 180, 90)
    $path.AddArc($x+$w-$r*2, $y, $r*2, $r*2, 270, 90)
    $path.AddArc($x+$w-$r*2, $y+$h-$r*2, $r*2, $r*2, 0, 90)
    $path.AddArc($x, $y+$h-$r*2, $r*2, $r*2, 90, 90)
    $path.CloseFigure()
    $g.FillPath($brush, $path)
}

function RoundTopRect($g, $x, $y, $w, $h, $r, $brush) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($x, $y, $r*2, $r*2, 180, 90)
    $path.AddArc($x+$w-$r*2, $y, $r*2, $r*2, 270, 90)
    $path.AddLine($x+$w, $y+$r*2, $x+$w, $y+$h)
    $path.AddLine($x+$w, $y+$h, $x, $y+$h)
    $path.AddLine($x, $y+$h, $x, $y+$r*2)
    $path.CloseFigure()
    $g.FillPath($brush, $path)
}

function RoundBottomRect($g, $x, $y, $w, $h, $r, $brush) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddLine($x, $y, $x+$w, $y)
    $path.AddArc($x+$w-$r*2, $y+$h-$r*2, $r*2, $r*2, 0, 90)
    $path.AddArc($x, $y+$h-$r*2, $r*2, $r*2, 90, 90)
    $path.AddLine($x, $y, $x+$r*2, $y)
    $path.CloseFigure()
    $g.FillPath($brush, $path)
}

$size = 1024
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'HighQuality'
$g.InterpolationMode = 'HighQualityBicubic'
$g.PixelOffsetMode = 'HighQuality'
$g.Clear([System.Drawing.Color]::Transparent)

# Background rounded rect
$bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle 40, 40, 944, 944),
    [System.Drawing.Color]::FromArgb(255, 255, 107, 53),
    [System.Drawing.Color]::FromArgb(255, 162, 57, 234),
    [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
)
RoundRect $g 40 40 944 944 96 $bgBrush

# Kiosk body (white)
$whiteBrush = [System.Drawing.Brushes]::White
RoundBottomRect $g 240 440 544 400 24 $whiteBrush

# Counter top (white, flat bottom)
$grayLight = [System.Drawing.Color]::FromArgb(255, 245, 245, 245)
$grayBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle 200, 370, 624, 56),
    [System.Drawing.Color]::White,
    $grayLight,
    [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
)
RoundTopRect $g 200 370 624 56 28 $grayBrush

# Awning (orange gradient)
$awBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle 240, 248, 544, 140),
    [System.Drawing.Color]::FromArgb(255, 255, 209, 102),
    [System.Drawing.Color]::FromArgb(255, 255, 159, 28),
    [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
)
RoundTopRect $g 240 248 544 140 18 $awBrush

# Awning stripes
$stripePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(50, 200, 80, 0)), 1
for ($x = 294; $x -le 740; $x += 34) {
    $g.DrawLine($stripePen, $x, 248, $x, 388)
}

# Shelf
$shelfBrush = [System.Drawing.Brushes]::Silver
$g.FillRectangle($shelfBrush, 296, 492, 432, 12)

# Soda can
$canBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle 330, 432, 44, 60),
    [System.Drawing.Color]::OrangeRed,
    [System.Drawing.Color]::FromArgb(255, 180, 30, 30),
    [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
)
$g.FillRectangle($canBrush, 330, 432, 44, 60)
$g.FillRectangle([System.Drawing.Brushes]::WhiteSmoke, 340, 442, 24, 4)
$g.FillEllipse([System.Drawing.Brushes]::Silver, 348, 488, 8, 8)

# Ice cream
$creamBrush = [System.Drawing.Brushes]::Gold
$g.FillEllipse($creamBrush, 420, 408, 36, 36)
$g.FillEllipse([System.Drawing.Brushes]::Orange, 444, 412, 30, 30)
$g.FillEllipse([System.Drawing.Brushes]::White, 420, 430, 20, 20)
$coneBrush = [System.Drawing.Brushes]::SandyBrown
$conePoints = @(
    [System.Drawing.Point]::new(448, 492),
    [System.Drawing.Point]::new(432, 444),
    [System.Drawing.Point]::new(464, 444)
)
$g.FillPolygon($coneBrush, $conePoints)

# Cookie
$cookieCol = [System.Drawing.Color]::FromArgb(255, 222, 184, 135)
$cookieBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle 520, 460, 56, 48),
    [System.Drawing.Color]::Peru,
    [System.Drawing.Color]::SandyBrown,
    [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
)
$g.FillEllipse($cookieBrush, 520, 460, 56, 48)
$chipCol = [System.Drawing.Brushes]::SaddleBrown
$g.FillEllipse($chipCol, 528, 468, 8, 8)
$g.FillEllipse($chipCol, 548, 470, 8, 8)
$g.FillEllipse($chipCol, 536, 486, 7, 7)
$g.FillEllipse($chipCol, 556, 480, 6, 6)

# Cupcake base
$cupCake = [System.Drawing.Color]::FromArgb(255, 200, 160, 220)
$cupBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle 590, 448, 48, 44),
    [System.Drawing.Color]::MediumPurple,
    $cupCake,
    [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
)
$g.FillRectangle($cupBrush, 590, 448, 48, 44)
$g.FillEllipse([System.Drawing.Brushes]::Gold, 582, 432, 64, 36)
$g.FillEllipse([System.Drawing.Brushes]::Tomato, 608, 430, 12, 12)

# Tag "KIOSCO"
$tagBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle 600, 312, 180, 48),
    [System.Drawing.Color]::Tomato,
    [System.Drawing.Color]::Firebrick,
    [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
)
RoundRect $g 600 312 180 48 24 $tagBrush

$font = New-Object System.Drawing.Font("Segoe UI", 22, [System.Drawing.FontStyle]::Bold)
$textBrush = [System.Drawing.SolidBrush][System.Drawing.Color]::White
$format = New-Object System.Drawing.StringFormat
$format.Alignment = 'Center'
$format.LineAlignment = 'Center'
$g.DrawString("KIOSCO", $font, $textBrush, 690, 336, $format)

# Decorative dots
$dotBrush1 = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(130, 255, 209, 102))
$dotBrush2 = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(80, 255, 209, 102))
$g.FillEllipse($dotBrush1, 800, 140, 80, 80)
$g.FillEllipse($dotBrush2, 750, 200, 40, 40)

$g.Dispose()

$outputPath = Join-Path (Split-Path $PSScriptRoot -Parent) "assets\app_icon.png"
$bmp.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Host "Icon generated: $outputPath"
