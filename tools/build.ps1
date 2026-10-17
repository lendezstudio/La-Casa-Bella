# La Casa Bella static site build (no Node required).
# Usage:  powershell -ExecutionPolicy Bypass -File tools\build.ps1
# Assembles src\pages\*.html into src\layout.html, expands image tokens into
# responsive markup, copies assets and writes the publishable site to docs\.
# Finishes with an internal link check and exits 1 on any broken reference.

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
# Absolute site URL once a domain or GitHub Pages address is approved, e.g.
# 'https://lacasabella.ph' or 'https://username.github.io/la-casa-bella'.
# Enables canonical links, absolute Open Graph images and sitemap.xml.
$SiteUrl = 'https://lendezstudio.github.io/La-Casa-Bella'

# Path the site is served from, e.g. '/la-casa-bella/' for a GitHub Pages project
# site, or '/' for a custom domain. Used only by 404.html. Leave '' to auto-detect.
$BasePath = '/La-Casa-Bella/'

# Concept mode keeps the preview out of search engines (noindex + robots.txt).
$ConceptMode = $true

# Official contact channels. Publish ONLY after La Casa Bella confirms each one.
$Channels = @{
    Confirmed = $false
    Facebook  = ''   # e.g. https://www.facebook.com/...
    Instagram = ''
    Phone     = ''   # display format, e.g. 0935 253 1419
    PhoneHref = ''   # e.g. +639352531419
    Email     = ''
}

# ---------------------------------------------------------------------------
$root    = Split-Path $PSScriptRoot -Parent
$src     = Join-Path $root 'src'
$out     = Join-Path $root 'docs'
$utf8    = New-Object System.Text.UTF8Encoding($false)
$version = (Get-Date).ToString('yyyyMMddHHmm')

function Read-Text($path) { [IO.File]::ReadAllText($path, $utf8) }
function Write-Text($path, $text) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    [IO.File]::WriteAllText($path, $text, $utf8)
}
function Esc($s) { [System.Net.WebUtility]::HtmlEncode($s) }

$manifest = (Read-Text (Join-Path $src 'data\images.json')) | ConvertFrom-Json
$layout   = Read-Text (Join-Path $src 'layout.html')
Add-Type -AssemblyName System.Drawing
$logoImg  = [System.Drawing.Image]::FromFile((Join-Path $src 'assets\img\brand\wordmark-bronze.png'))
$logoH    = $logoImg.Height; $logoImg.Dispose()

$arrow = '<svg class="icon-arrow" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M4 12h15m-6-6 6 6-6 6" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/></svg>'

$categoryLabels = @{ place = 'The Place'; stay = 'Staycations'; celebrations = 'Celebrations'; catering = 'Catering' }

function Photo-Url($slug, $w, $rootPath) { "${rootPath}assets/img/photos/$slug-$w.jpg" }

function Build-Gallery {
    $sb = New-Object System.Text.StringBuilder
    $i = 0
    foreach ($p in $manifest.PSObject.Properties) {
        $info = $p.Value
        if (-not $info.categories) { continue }
        $cats = $info.categories -split '\|'
        $label = $categoryLabels[$cats[0]]
        $full = $info.widths | Select-Object -Last 1
        [void]$sb.AppendLine(("<li class=""gallery-item"" data-cat=""{0}"">" -f ($cats -join ' ')))
        [void]$sb.AppendLine(("  <button type=""button"" class=""gallery-item__btn"" data-lightbox-item data-full=""{{{{root}}}}assets/img/photos/{0}-{1}.jpg"" data-label=""{2}"" data-w=""{3}"" data-h=""{4}"" aria-label=""View larger: {5}"">" -f $p.Name, $full, $label, $info.w, $info.h, (Esc $info.alt)))
        [void]$sb.AppendLine(("    <img data-img=""{0}"" sizes=""(min-width: 1200px) 31vw, (min-width: 700px) 46vw, 92vw"">" -f $p.Name))
        [void]$sb.AppendLine("  </button>")
        [void]$sb.AppendLine("</li>")
        $i++
    }
    $sb.ToString()
}

function Count-Category($cat) {
    $n = 0
    foreach ($p in $manifest.PSObject.Properties) {
        $c = $p.Value.categories
        if (-not $c) { continue }
        if ($cat -eq 'all' -or (($c -split '\|') -contains $cat)) { $n++ }
    }
    $n
}

function Expand-Images([string]$html, [string]$rootPath) {
    $script:imgRoot = $rootPath
    $html = [regex]::Replace($html, '<img\b[^>]*\bdata-img="([^"]+)"[^>]*>', {
        param($m)
        $slug = $m.Groups[1].Value
        $info = $manifest.$slug
        if (-not $info) { throw "Unknown image slug '$slug'" }
        $srcset = ($info.widths | ForEach-Object { "$(Photo-Url $slug $_ $script:imgRoot) ${_}w" }) -join ', '
        $fallbackW = if ($info.widths -contains 960) { 960 } else { $info.widths | Select-Object -Last 1 }
        $tag = $m.Value.Replace("data-img=""$slug""", ("src=""{0}"" srcset=""{1}"" width=""{2}"" height=""{3}""" -f (Photo-Url $slug $fallbackW $script:imgRoot), $srcset, $info.w, $info.h))
        $extra = ''
        if ($tag -notmatch '\salt=')      { $extra += " alt=""$(Esc $info.alt)""" }
        if ($tag -notmatch '\ssizes=')    { $extra += ' sizes="(min-width: 1024px) 50vw, 100vw"' }
        if ($tag -notmatch '\sloading=')  { $extra += ' loading="lazy"' }
        if ($tag -notmatch '\sdecoding=') { $extra += ' decoding="async"' }
        $tag -replace '^<img', "<img$extra"
    })
    [regex]::Replace($html, '<source\b[^>]*\bdata-srcset="([^"]+)"[^>]*>', {
        param($m)
        $slug = $m.Groups[1].Value
        $info = $manifest.$slug
        if (-not $info) { throw "Unknown image slug '$slug'" }
        $srcset = ($info.widths | ForEach-Object { "$(Photo-Url $slug $_ $script:imgRoot) ${_}w" }) -join ', '
        $m.Value.Replace("data-srcset=""$slug""", ("srcset=""{0}"" width=""{1}"" height=""{2}""" -f $srcset, $info.w, $info.h))
    })
}

function Apply-Conditionals([string]$html) {
    $keep = if ($Channels.Confirmed) { 'channels' } else { 'no-channels' }
    $drop = if ($Channels.Confirmed) { 'no-channels' } else { 'channels' }
    $html = [regex]::Replace($html, "<!--if:$drop-->.*?<!--endif-->", '', 'Singleline')
    $html = $html.Replace("<!--if:$keep-->", '')
    [regex]::Replace($html, '<!--endif-->', '')
}

# ---------------------------------------------------------------------------
# Clean output (only if it is a folder this script generated)
# ---------------------------------------------------------------------------
if (Test-Path $out) {
    if (-not (Test-Path (Join-Path $out '.generated'))) { throw "docs\ exists but was not created by this build; refusing to clear it." }
    Remove-Item $out -Recurse -Force
}
New-Item -ItemType Directory -Force $out | Out-Null
Write-Text (Join-Path $out '.generated') "Generated by tools/build.ps1. Edit files in src/ instead."

# ---------------------------------------------------------------------------
# Pages
# ---------------------------------------------------------------------------
$galleryMarkup = Build-Gallery
$siteBase = $SiteUrl.TrimEnd('/')
$pages = Get-ChildItem (Join-Path $src 'pages') -Filter *.html
$sitemap = @()

foreach ($page in $pages) {
    $raw = Read-Text $page.FullName
    $m = [regex]::Match($raw, '^\s*<!--(.*?)-->', 'Singleline')
    if (-not $m.Success) { throw "$($page.Name): missing front matter" }
    $meta = @{}
    foreach ($line in ($m.Groups[1].Value -split "`n")) {
        if ($line -match '^\s*([a-z]+)\s*:\s*(.+?)\s*$') { $meta[$matches[1]] = $matches[2] }
    }
    $body = $raw.Substring($m.Length).Trim()
    $path = $meta.path
    $depth = ($path.Split('/').Count - 1)
    $rootPath = if ($meta.key -eq '404') { '' } else { '../' * $depth }

    $urlPath = $path -replace 'index\.html$', ''
    $canonical = ''
    $ogImage = "${rootPath}assets/img/og-share.jpg"
    if ($siteBase) {
        $canonical = "<link rel=""canonical"" href=""$siteBase/$urlPath"">`n"
        $ogImage = "$siteBase/assets/img/og-share.jpg"
        if ($meta.key -ne '404') { $sitemap += "$siteBase/$urlPath" }
    }
    $baseTag = ''
    if ($meta.key -eq '404') {
        $baseTag = if ($BasePath) { "<base href=""$BasePath"">" }
                   else { '<script>(function(){var p=location.pathname.split("/");var b=/\.github\.io$/.test(location.hostname)&&p.length>2?"/"+p[1]+"/":"/";document.write(''<base href="''+b+''">'');})();</script>' }
    }

    $html = $layout.Replace('{{content}}', $body)
    $html = $html.Replace('{{gallery}}', $galleryMarkup)
    foreach ($c in @('all', 'place', 'stay', 'celebrations', 'catering')) { $html = $html.Replace("{{count:$c}}", (Count-Category $c)) }
    $html = Apply-Conditionals $html
    $robots = if ($ConceptMode -or $meta.key -eq '404') { "<meta name=""robots"" content=""noindex, nofollow"">`n" } else { '' }

    $tokens = @{
        '{{basetag}}' = $baseTag; '{{title}}' = (Esc $meta.title); '{{description}}' = (Esc $meta.description)
        '{{ogtitle}}' = (Esc $(if ($meta.ogtitle) { $meta.ogtitle } else { $meta.title }))
        '{{ogdescription}}' = (Esc $(if ($meta.ogdescription) { $meta.ogdescription } else { $meta.description }))
        '{{ogimage}}' = $ogImage; '{{robots}}' = $robots; '{{canonical}}' = $canonical; '{{preload}}' = ''
        '{{key}}' = $meta.key; '{{hero}}' = $meta.hero; '{{version}}' = $version; '{{logoh}}' = "$logoH"
        '{{arrow}}' = $arrow
        '{{facebook}}' = $Channels.Facebook; '{{instagram}}' = $Channels.Instagram
        '{{phone}}' = $Channels.Phone; '{{phonehref}}' = $Channels.PhoneHref; '{{email}}' = $Channels.Email
    }
    foreach ($k in $tokens.Keys) { $html = $html.Replace($k, $tokens[$k]) }
    $html = $html.Replace('{{root}}', $rootPath)
    $html = Expand-Images $html $rootPath
    $html = [regex]::Replace($html, "data-nav=""$($meta.key)""", "data-nav=""$($meta.key)"" aria-current=""page""")

    if ($html -match '\{\{[a-z:]+\}\}') { throw "$($page.Name): unreplaced token $($matches[0])" }
    Write-Text (Join-Path $out ($path -replace '/', '\')) $html
    Write-Host ("  {0,-26} -> {1}" -f $page.Name, $path)
}

# ---------------------------------------------------------------------------
# Static files
# ---------------------------------------------------------------------------
Copy-Item (Join-Path $src 'assets') (Join-Path $out 'assets') -Recurse
Write-Text (Join-Path $out '.nojekyll') ''
Write-Text (Join-Path $out 'site.webmanifest') (@'
{
  "name": "La Casa Bella Resort & Events Place",
  "short_name": "La Casa Bella",
  "icons": [
    { "src": "assets/img/brand/favicon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "assets/img/brand/icon-512.png", "sizes": "512x512", "type": "image/png" }
  ],
  "theme_color": "#28372F",
  "background_color": "#F4F0E7",
  "display": "browser"
}
'@)
if ($ConceptMode) { Write-Text (Join-Path $out 'robots.txt') "User-agent: *`nDisallow: /`n" }
else {
    $r = "User-agent: *`nAllow: /`n"
    if ($siteBase) { $r += "Sitemap: $siteBase/sitemap.xml`n" }
    Write-Text (Join-Path $out 'robots.txt') $r
}
if ($sitemap.Count) {
    $xml = '<?xml version="1.0" encoding="UTF-8"?>' + "`n" + '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' + "`n"
    foreach ($u in $sitemap) { $xml += "  <url><loc>$u</loc></url>`n" }
    Write-Text (Join-Path $out 'sitemap.xml') ($xml + "</urlset>`n")
}

# ---------------------------------------------------------------------------
# Internal link check
# ---------------------------------------------------------------------------
$broken = @()
foreach ($file in Get-ChildItem $out -Recurse -Filter *.html) {
    $html = Read-Text $file.FullName
    $baseDir = if ($file.Name -eq '404.html') { $out } else { $file.DirectoryName }
    $refs = @()
    foreach ($mm in [regex]::Matches($html, '\s(?:href|src|data-full)="([^"]+)"')) { $refs += $mm.Groups[1].Value }
    foreach ($mm in [regex]::Matches($html, '\ssrcset="([^"]+)"')) {
        foreach ($part in $mm.Groups[1].Value -split ',') { $refs += ($part.Trim() -split '\s+')[0] }
    }
    foreach ($ref in $refs) {
        if ($ref -match '^(https?:|mailto:|tel:|#|data:|javascript:)' -or $ref -eq '' -or $ref -match "[''+]" -or $ref.StartsWith('/')) { continue }
        $clean = ($ref -split '[?#]')[0]
        if ($clean -eq '') { continue }
        $target = [IO.Path]::GetFullPath((Join-Path $baseDir ($clean -replace '/', '\')))
        if ($clean.EndsWith('/') -or (Test-Path $target -PathType Container)) { $target = Join-Path $target 'index.html' }
        if (-not (Test-Path $target)) { $broken += "$($file.FullName.Substring($out.Length + 1)): $ref" }
    }
}
if ($broken.Count) {
    Write-Host "Broken internal references:" -ForegroundColor Red
    $broken | Sort-Object -Unique | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    exit 1
}
Write-Host "Build complete: $out (no broken internal links)" -ForegroundColor Green
