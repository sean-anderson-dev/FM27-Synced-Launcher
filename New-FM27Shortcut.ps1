# Creates an "FM27 (Synced)" shortcut that runs FM27-Launch.ps1, using the FM27 icon.
# Keep this file in the same folder as FM27-Launch.ps1, then run
# Add -StartMenu to also create a Start menu shortcut (pin that one, not the desktop one).

param([switch]$StartMenu)

$ErrorActionPreference = 'Stop'

# Launcher script must sit next to this file
$launcher = Join-Path $PSScriptRoot "FM27-Launch.ps1"
if (-not (Test-Path $launcher)) {
    Write-Host "FM27-Launch.ps1 not found in $PSScriptRoot - keep both scripts in the same folder." -ForegroundColor Red
    exit 1
}

# Find fm.exe across all Steam library folders (for the icon)
$fmExe = $null
$steamPath = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
if ($steamPath) {
    $libraries = @($steamPath)
    $vdf = Join-Path $steamPath "steamapps\libraryfolders.vdf"
    if (Test-Path $vdf) {
        $libraries += [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"') |
            ForEach-Object { $_.Groups[1].Value -replace '\\\\', '\' }
    }
    $fmExe = $libraries | Select-Object -Unique |
        ForEach-Object { Join-Path $_ "steamapps\common\Football Manager 27\fm.exe" } |
        Where-Object { Test-Path $_ } |
        Select-Object -First 1
}
if ($fmExe) {
    Write-Host "Found FM27: $fmExe" -ForegroundColor Green
} else {
    Write-Host "Couldn't find fm.exe - the shortcut will use the PowerShell icon (you can change it in Properties)." -ForegroundColor Yellow
}

# Create shortcut(s)
$targets = @([Environment]::GetFolderPath('Desktop'))
if ($StartMenu) { $targets += Join-Path ([Environment]::GetFolderPath('StartMenu')) "Programs" }

$ws = New-Object -ComObject WScript.Shell
foreach ($folder in $targets) {
    $path = Join-Path $folder "FM27 (Synced).lnk"
    $lnk = $ws.CreateShortcut($path)
    $lnk.TargetPath       = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $lnk.Arguments        = "-NoProfile -ExecutionPolicy Bypass -File `"$launcher`""
    $lnk.WorkingDirectory = $PSScriptRoot
    $lnk.Description      = "Launch FM27 with OneDrive save sync"
    if ($fmExe) { $lnk.IconLocation = "$fmExe,0" }
    $lnk.Save()
    Write-Host "Shortcut created: $path" -ForegroundColor Green
}

Write-Host "Done. Launch FM27 from this shortcut, not from Steam." -ForegroundColor Cyan
