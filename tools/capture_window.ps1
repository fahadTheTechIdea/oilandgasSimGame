param(
    [string]$TitlePattern = "Oilfield Tycoon",
    [string]$Out = "$env:TEMP\godot_shot.png",
    [int]$WaitSeconds = 8
)

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W32 {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

Start-Sleep -Seconds $WaitSeconds

$proc = Get-Process | Where-Object { $_.MainWindowTitle -like "*$TitlePattern*" } | Select-Object -First 1
if (-not $proc) {
    Write-Output "NO WINDOW MATCHING '$TitlePattern'"
    Get-Process | Where-Object { $_.ProcessName -like "*odot*" } | Select-Object Id, ProcessName, MainWindowTitle | Format-Table -AutoSize
    exit 1
}

[W32]::ShowWindow($proc.MainWindowHandle, 9) | Out-Null
[W32]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 900

$rect = New-Object W32+RECT
[W32]::GetWindowRect($proc.MainWindowHandle, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left
$h = $rect.Bottom - $rect.Top
if ($w -le 0 -or $h -le 0) { Write-Output "BAD RECT"; exit 1 }

$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, (New-Object System.Drawing.Size($w, $h)))
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()

Write-Output "captured $w x $h -> $Out"
