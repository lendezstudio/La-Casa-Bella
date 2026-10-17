# Local preview server for the built site (docs\). No Node or Python needed.
# Usage:  powershell -ExecutionPolicy Bypass -File tools\serve.ps1 [-Port 4317]
# Then open http://localhost:4317/ . Press Ctrl+C to stop.
param([int]$Port = 4317)
$ErrorActionPreference = 'Stop'

$root = Join-Path (Split-Path $PSScriptRoot -Parent) 'docs'
if (-not (Test-Path $root)) { throw "Run tools\build.ps1 first." }
$types = @{
  '.html' = 'text/html; charset=utf-8'; '.css' = 'text/css; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'
  '.jpg' = 'image/jpeg'; '.png' = 'image/png'; '.svg' = 'image/svg+xml'; '.webmanifest' = 'application/manifest+json'
  '.txt' = 'text/plain; charset=utf-8'; '.xml' = 'application/xml'; '.ico' = 'image/x-icon'
}
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $root at http://localhost:$Port/  (Ctrl+C to stop)"
try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $path = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
    $file = Join-Path $root ($path -replace '/', '\')
    if (Test-Path $file -PathType Container) { $file = Join-Path $file 'index.html' }
    $status = 200
    if (-not (Test-Path $file -PathType Leaf) -or -not ([IO.Path]::GetFullPath($file).StartsWith($root))) {
      $file = Join-Path $root '404.html'; $status = 404
    }
    $bytes = [IO.File]::ReadAllBytes($file)
    $ext = [IO.Path]::GetExtension($file).ToLower()
    $ctx.Response.StatusCode = $status
    $ctx.Response.ContentType = $(if ($types[$ext]) { $types[$ext] } else { 'application/octet-stream' })
    $ctx.Response.ContentLength64 = $bytes.Length
    try { $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length) } catch {}
    $ctx.Response.Close()
  }
} finally { if ($listener.IsListening) { $listener.Stop() } }
