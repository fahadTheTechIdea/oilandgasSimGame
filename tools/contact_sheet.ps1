# Tile all preview PNGs into a labelled contact sheet (Windows, System.Drawing).
param(
    [string]$PreviewDir = "$PSScriptRoot\..\assets\previews",
    [string]$Out = "$PSScriptRoot\..\assets\previews\contact_sheet.png",
    [int]$Tile = 160,
    [int]$Cols = 10
)

Add-Type -AssemblyName System.Drawing

$files = Get-ChildItem -Path $PreviewDir -Filter *.png |
    Where-Object { $_.Name -ne 'contact_sheet.png' -and $_.Name -ne 'demo_field.png' } |
    Sort-Object Name

if ($files.Count -eq 0) { Write-Error "no previews found"; exit 1 }

$rows = [math]::Ceiling($files.Count / $Cols)
$pad = 6
$cap = 18
$cellW = $Tile + $pad
$cellH = $Tile + $cap + $pad

$bmp = New-Object System.Drawing.Bitmap ($Cols * $cellW), ($rows * $cellH)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'HighQuality'
$g.InterpolationMode = 'HighQualityBicubic'
$g.Clear([System.Drawing.Color]::FromArgb(28, 31, 34))

$font = New-Object System.Drawing.Font "Consolas", 8
$brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(200, 205, 210))

for ($i = 0; $i -lt $files.Count; $i++) {
    $col = $i % $Cols
    $row = [math]::Floor($i / $Cols)
    $x = $col * $cellW + $pad / 2
    $y = $row * $cellH + $pad / 2

    $img = [System.Drawing.Image]::FromFile($files[$i].FullName)
    $g.DrawImage($img, $x, $y, $Tile, $Tile)
    $img.Dispose()

    $label = $files[$i].BaseName
    if ($label.Length -gt 24) { $label = $label.Substring(0, 24) }
    $g.DrawString($label, $font, $brush, $x, ($y + $Tile + 2))
}

$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()

Write-Output "wrote $Out ($($files.Count) tiles, $($Cols)x$rows)"
