# Generates web-ready photography, logo variants, icons and the social share image.
# Usage:  powershell -ExecutionPolicy Bypass -File tools\optimize-images.ps1
# Re-run only when source photos or the logo change. Output goes to src\assets\img
# and src\data\images.json (used by build.ps1 to write srcset/width/height).

$ErrorActionPreference = 'Stop'
$root    = Split-Path $PSScriptRoot -Parent
$srcDir  = Join-Path $root 'Initial Images'
$logoSrc = Join-Path $root 'La Casa Bella Elegant Logo.png'
$imgOut  = Join-Path $root 'src\assets\img'
$photoOut = Join-Path $imgOut 'photos'
$brandOut = Join-Path $imgOut 'brand'
$widths  = @(480, 960, 1600, 2048)
$quality = 80

Add-Type -Path (Join-Path $PSScriptRoot 'Imaging.cs') -ReferencedAssemblies System.Drawing
New-Item -ItemType Directory -Force $photoOut, $brandOut | Out-Null

# --- Photography -----------------------------------------------------------
$rows = Import-Csv (Join-Path $root 'src\data\images.csv')
$manifest = [ordered]@{}
foreach ($row in $rows) {
    $file = Get-ChildItem $srcDir -Filter "$($row.id)_*.jpg" | Select-Object -First 1
    if (-not $file) { throw "Source photo not found for id $($row.id)" }
    $done = @()
    $dims = $null
    foreach ($w in $widths) {
        $dst = Join-Path $photoOut "$($row.slug)-$w.jpg"
        $dims = [LcbImaging]::Resize($file.FullName, $dst, $w, $quality)
        $actualW = [int]($dims.Split('x')[0])
        if ($actualW -ne $w) {
            # Source is narrower than this step: rename to its true width and stop.
            $final = Join-Path $photoOut "$($row.slug)-$actualW.jpg"
            if (Test-Path $final) { Remove-Item $final }
            Move-Item $dst $final
            if ($done -notcontains $actualW) { $done += $actualW }
            break
        }
        $done += $w
    }
    $wh = $dims.Split('x')
    $manifest[$row.slug] = [ordered]@{ w = [int]$wh[0]; h = [int]$wh[1]; widths = $done; categories = $row.categories; alt = $row.alt }
    Write-Host ("  {0,-34} {1}  [{2}]" -f $row.slug, $dims, ($done -join ','))
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $root 'src\data\images.json') -Encoding UTF8

# Social share image (1200x630) from the garden lounge photograph.
$og = Get-ChildItem $srcDir -Filter '686363859_*.jpg' | Select-Object -First 1
[LcbImaging]::Cover($og.FullName, (Join-Path $imgOut 'og-share.jpg'), 1200, 630, 0.55, 0.55, 84)

# --- Logo ------------------------------------------------------------------
$ink = [LcbImaging]::Wordmark($logoSrc, (Join-Path $brandOut 'wordmark-bronze.png'), 0, 0, 0, 1200, $true)
[void][LcbImaging]::Wordmark($logoSrc, (Join-Path $brandOut 'wordmark-ivory.png'), 0xF4, 0xF0, 0xE7, 1200, $false)
Write-Host "  wordmark ink colour: $ink"

# --- Icons -----------------------------------------------------------------
$font = 'Palatino Linotype'
[LcbImaging]::Monogram((Join-Path $brandOut 'favicon-32.png'), 32, $font)
[LcbImaging]::Monogram((Join-Path $brandOut 'favicon-192.png'), 192, $font)
[LcbImaging]::Monogram((Join-Path $brandOut 'apple-touch-icon.png'), 180, $font)
[LcbImaging]::Monogram((Join-Path $brandOut 'icon-512.png'), 512, $font)

Write-Host "Done."
