[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase
$root = Split-Path -Parent $PSScriptRoot
$output = Join-Path $root 'artifacts\branding'
New-Item -ItemType Directory -Force $output | Out-Null
# Render the approved vector, not a resized screenshot or substitute logo.
$xaml = (Get-Content (Join-Path $root 'src\CommonCopy.Windows\Assets\CommonCopyLogo.xaml') -Raw).Replace('{DynamicResource LogoInkBrush}', 'Black')
$dictionary = [Windows.Markup.XamlReader]::Parse($xaml)
$logo = $dictionary['ApprovedLogo']
function Render-Logo([int]$width, [int]$height, [bool]$white) {
    $visual = [Windows.Media.DrawingVisual]::new()
    $dc = $visual.RenderOpen()
    if ($white) { $dc.DrawRectangle([Windows.Media.Brushes]::White, $null, [Windows.Rect]::new(0,0,$width,$height)) }
    $scale = [Math]::Min($width / $logo.Width, $height / $logo.Height) * 0.9
    $w = $logo.Width * $scale; $h = $logo.Height * $scale
    $dc.DrawImage($logo, [Windows.Rect]::new(($width-$w)/2,($height-$h)/2,$w,$h))
    $dc.Close()
    $bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new($width,$height,96,96,[Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($visual)
    return $bitmap
}
$bmp = [Windows.Media.Imaging.BmpBitmapEncoder]::new()
$bmp.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create((Render-Logo 512 628 $true)))
$stream = [IO.File]::Create((Join-Path $output 'CommonCopy.bmp'))
try { $bmp.Save($stream) } finally { $stream.Dispose() }
$images = @(); $sizes = @(16,24,32,48,64,128,256)
foreach ($size in $sizes) {
    $encoder = [Windows.Media.Imaging.PngBitmapEncoder]::new()
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create((Render-Logo $size $size $false)))
    $memory = [IO.MemoryStream]::new()
    $encoder.Save($memory)
    $images += ,$memory.ToArray()
    $memory.Dispose()
}
$writer = [IO.BinaryWriter]::new([IO.File]::Create((Join-Path $output 'CommonCopy.ico')))
try {
    $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$sizes.Count)
    $offset = 6 + 16 * $sizes.Count
    for ($i=0; $i -lt $sizes.Count; $i++) {
        $dimension = if ($sizes[$i] -eq 256) { 0 } else { $sizes[$i] }
        $writer.Write([byte]$dimension); $writer.Write([byte]$dimension)
        $writer.Write([byte]0); $writer.Write([byte]0)
        $writer.Write([uint16]1); $writer.Write([uint16]32)
        $writer.Write([uint32]$images[$i].Length); $writer.Write([uint32]$offset)
        $offset += $images[$i].Length
    }
    foreach ($bytes in $images) { $writer.Write([byte[]]$bytes) }
} finally { $writer.Dispose() }
