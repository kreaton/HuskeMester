# Generates the app / home-screen icons for HuskeMester: four cards from the game, two by two. Two are
# face down (blue, dotted, with a "?") and two are a found pair: white with a yellow star and the green ring.
# Run with Windows PowerShell (System.Drawing):  powershell -File tools\make-icons.ps1
param(
    [string]$OutDir = (Join-Path $PSScriptRoot "..\src\HuskeMester\wwwroot\icons"),
    # The front page (KidsGames) shows each game's 512 px icon. Pass its billeder folder to copy it there,
    # e.g. -FrontPageDir ..\KidsGames\billeder
    [string]$FrontPageDir = ""
)

Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $OutDir | Out-Null

function Color([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }
function Brush([string]$hex) { New-Object System.Drawing.SolidBrush (Color $hex) }

function New-RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = 2 * $r
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

# A five-pointed star centred on (cx, cy).
function New-Star([float]$cx, [float]$cy, [float]$outer) {
    $inner = $outer * 0.45
    $pts = New-Object 'System.Drawing.PointF[]' 10
    for ($i = 0; $i -lt 10; $i++) {
        $r = if ($i % 2 -eq 0) { $outer } else { $inner }
        $a = -[Math]::PI / 2 + $i * [Math]::PI / 5
        $pts[$i] = New-Object System.Drawing.PointF ($cx + $r * [Math]::Cos($a)), ($cy + $r * [Math]::Sin($a))
    }
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddPolygon($pts)
    return $p
}

# A face-down card: blue with lighter dots, a white inner rim and a "?".
function Draw-Back($g, [float]$x, [float]$y, [float]$w, [float]$detail) {
    $r = $w * 0.16
    $g.FillPath((Brush '#1864ab'), (New-RoundRect $x ($y + $w * 0.05) $w $w $r))
    $card = New-RoundRect $x $y $w $w $r
    $g.FillPath((Brush '#1c7ed6'), $card)

    if ($detail) {
        $g.SetClip($card)
        $dot = Brush '#339af0'
        $step = $w / 4
        $dr = $step * 0.2
        for ($i = 0; $i -lt 4; $i++) {
            for ($j = 0; $j -lt 4; $j++) {
                $g.FillEllipse($dot, $x + ($i + 0.5) * $step - $dr, $y + ($j + 0.5) * $step - $dr, 2 * $dr, 2 * $dr)
            }
        }
        $g.ResetClip()
        $rim = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(60, 255, 255, 255)), ($w * 0.05)
        $inset = $w * 0.05
        $g.DrawPath($rim, (New-RoundRect ($x + $inset / 2) ($y + $inset / 2) ($w - $inset) ($w - $inset) ($r * 0.85)))
    }

    $font = New-Object System.Drawing.Font 'Segoe UI', ($w * 0.5), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = 'Center'
    $fmt.LineAlignment = 'Center'
    $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(220, 255, 255, 255))
    $ty = $y + $w * 0.02
    $g.DrawString('?', $font, $white, (New-Object System.Drawing.RectangleF $x, $ty, $w, $w), $fmt)
}

# A found card: white, the green "pair" ring, and a yellow star.
function Draw-Found($g, [float]$x, [float]$y, [float]$w) {
    $r = $w * 0.16
    $g.FillPath((Brush '#2f9e44'), (New-RoundRect $x ($y + $w * 0.05) $w $w $r))
    $g.FillPath((Brush '#2f9e44'), (New-RoundRect $x $y $w $w $r))
    $ring = $w * 0.08
    $g.FillPath((Brush '#ffffff'), (New-RoundRect ($x + $ring) ($y + $ring) ($w - 2 * $ring) ($w - 2 * $ring) ($r * 0.7)))
    $cx = $x + $w / 2
    $cy = $y + $w / 2 + $w * 0.03
    $g.FillPath((Brush '#e67700'), (New-Star $cx ($cy + $w * 0.03) ($w * 0.33)))
    $g.FillPath((Brush '#fcc419'), (New-Star $cx $cy ($w * 0.33)))
}

# content: 1.0 = full size, 0.78 = keep inside the maskable safe zone
function Draw-Icon([int]$size, [string]$file, [float]$content = 1.0, [bool]$detail = $true) {
    $S = [float]$size
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'

    # Background: the game's mint-to-sky gradient (full square, iOS applies its own rounded mask)
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.PointF 0, 0), (New-Object System.Drawing.PointF 0, $S), (Color '#96f2d7'), (Color '#d0ebff')
    $g.FillRectangle($bg, 0, 0, $S, $S)

    # Four cards, two by two: a found pair on one diagonal, two face-down cards on the other
    $B = $S * 0.76 * $content
    $gap = $B * 0.08
    $w = ($B - $gap) / 2
    $x0 = ($S - $B) / 2
    $y0 = ($S - $B) / 2 - $S * 0.02 * $content
    Draw-Found $g $x0 $y0 $w
    Draw-Back $g ($x0 + $w + $gap) $y0 $w $detail
    Draw-Back $g $x0 ($y0 + $w + $gap) $w $detail
    Draw-Found $g ($x0 + $w + $gap) ($y0 + $w + $gap) $w

    $g.Dispose()
    $bmp.Save((Join-Path $OutDir $file), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "  $file"
}

Write-Host "Writing icons to $OutDir"
Draw-Icon 180  'apple-touch-icon.png'
Draw-Icon 167  'apple-touch-icon-167.png'
Draw-Icon 152  'apple-touch-icon-152.png'
Draw-Icon 192  'icon-192.png'
Draw-Icon 512  'icon-512.png'
Draw-Icon 1024 'icon-1024.png'
Draw-Icon 512  'icon-512-maskable.png' 0.78
Draw-Icon 32   'favicon-32.png' 1.0 $false

if ($FrontPageDir -and (Test-Path $FrontPageDir)) {
    Copy-Item (Join-Path $OutDir 'icon-512.png') (Join-Path $FrontPageDir 'huskemester.png')
    Write-Host "Copied icon-512.png to $FrontPageDir\huskemester.png"
}
