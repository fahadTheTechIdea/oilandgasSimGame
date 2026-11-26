# Serve the project over HTTP so the preview can fetch manifests and GLB files.
#   powershell -ExecutionPolicy Bypass -File preview\serve.ps1
param([int]$Port = 8000)

$root = Split-Path -Parent $PSScriptRoot
$py = (Get-Command python -ErrorAction SilentlyContinue).Source

if (-not $py) {
    $py = Get-ChildItem "C:\Program Files\Blender Foundation" -Recurse -Filter python.exe `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\python\\bin\\python\.exe$' } |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $py) {
    Write-Error "No Python found. Install Python 3 or Blender 4.2+."
    exit 1
}

$url = "http://localhost:$Port/preview/"
Write-Host ""
Write-Host "  Oil & Gas Asset Kit - preview server" -ForegroundColor Yellow
Write-Host "  root : $root"
Write-Host "  url  : $url" -ForegroundColor Cyan
Write-Host "  stop : Ctrl+C"
Write-Host ""

Start-Process $url
& $py -m http.server $Port --directory $root
